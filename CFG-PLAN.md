# CFG recogniser: silent miscompile of sequential control flow

Status: items 1, 2 and 3 done (2026-10-09), and the README half of item 4 with them.
The `prompt.md` half of item 4 is not started. Item 5 deferred by decision.

## What was found (verified 2026-10-09)

The README claimed that the compiler handles "one level of control flow" and that
"nested conditions or loops raise `PVTypeError signal: 'Unrecognized CFG shape'`".
Probing seven synthetic kernels through `PVKernelCompiler compile:` showed the first
half is true and the second half is incomplete:

| Probe | Blocks | Recognised as | Result |
|---|---|---|---|
| one `ifTrue:ifFalse:` | 4 | `PVSelectionNode` | valid, 276 bytes |
| nested `if` in the true arm | 7 | nil | `PVTypeError: Unrecognized CFG shape` |
| `if` inside a `whileTrue:` body | 7 | nil | `PVTypeError: Unrecognized CFG shape` |
| nested `whileTrue:` | 7 | nil | `PVTypeError: Unrecognized CFG shape` |
| one `whileTrue:` | 4 | `PVLoopNode` | valid, 352 bytes |
| two sequential ifs | 7 | `PVSelectionNode` | **byte-identical to the one-if module** |
| loop then if | 7 | `PVLoopNode` | **invalid SPIR-V, no error raised** |

Truly nested control flow is rejected as documented. *Sequential* control flow is not
rejected at all; it is silently miscompiled:

- Two sequential selections compile to a module byte-for-byte equal to the single
  selection. The second one is dropped with no diagnostic.
- A loop followed by a selection emits a module `spirv-val` rejects:
  `error: line 25: OpReturnValue Value <id> '18[%18]'s type does not match OpFunction's
  return type.` The disassembly returns `%18 = OpSLessThan %bool` from a function
  declared `%int`: the trailing selection vanished and the bare comparison was returned
  in its place.

### Cause

`PVStructuredCFGRecognizer >> recognize` tries a selection at `blocks first`, and
failing that a loop headed at `blocks second`. `recognizeSelectionAt:` builds its node
with `trueBlocks: { trueBlk }` and `falseBlocks: { falseBlk }`; `recognizeLoopAt:` uses
`bodyBlocks: { bodyBlk }`. One block per arm, no recursion — which is the frozen design
decision, and fine. The defect is that **nothing checks that the recognised node covers
every block in the CFG.** A seven-block graph whose head matches a known pattern is
accepted and its tail is discarded.

## Plan

### 1. Make the recogniser reject what it cannot represent — DONE

Delivered as `PVStructuredCFGRecognizer >> covers:`, called at the end of
`recognize`: a candidate node is answered only when the blocks it accounts for include
every block in the graph. Coverage is asked of the node itself, through new
`PVSelectionNode >> coveredBlocks` and `PVLoopNode >> coveredBlocks`, so the check
cannot drift from what the emitters actually consume.

Both silent cases now raise `PVTypeError: 'Unrecognized CFG shape'`. All 19
`PVKernelExamples` still compile, so the check does not over-reject. A
`recognitionReport` plus a `Recognition` inspector tab show per-block coverage, and
`PVStructuredCFGRecognizer class >> exampleRecogniserOnLoopKernel` is the one-click
example for it.



Give `PVStructuredCFGRecognizer` a coverage check: a candidate node is answered only if
the set of blocks it accounts for is the whole block list. Otherwise answer nil, which
`PVKernelCompiler` already turns into `PVTypeError signal: 'Unrecognized CFG shape'`.

This adds no capability. It converts two silent miscompiles into the same honest error
that nesting already produces, which is the behaviour the README documents. Write the
failing tests first: the two sequential probes must go from "compiles" to "raises".

### 2. Keep the seven probes as regression tests — DONE

Delivered as `PVCfgShapeFixture` (package `PharoVulkan-Tests`, tag `Compiler`) holding
one kernel per shape, plus seven tests in `PVCompilerTest` driven by two helpers,
`assertShapeCompiles:` and `assertShapeRejected:`. Four further tests cover the
coverage report, the inspector view and the example. Suite went 74 → 85, all passing.



The probe kernels live in a fixture class in `PharoVulkan-Tests`, not in
`PVKernelExamples` — they are not examples anyone should run, they are CFG shapes with
known expected verdicts. Tests assert the verdict per shape: a valid module for the two
single-construct shapes, `PVTypeError` for the other five.

These pin the exact boundary of the recogniser. Phase 7 will touch this code, and
without the tests a future structurizer can silently widen or re-break coverage.

### 3. Fix the README's compute snippet, not the compiler — DONE

Delivered in `README.md`: the "Minimal headless compute in a Playground" snippet now
compiles `PVKernelExamples >> #vectorAdd:a:b:out:` and runs it over three storage
buffers, step for step as `PVComputeTest >> #testVectorAddFromCompiledMethod` does, so
the documented sequence is the one the suite covers. It uses
`VkBuffer storageBuffer:on:` and `putF32s:`/`getF32s` instead of the old
`usage: 4` literal — which was wrong anyway, the storage *buffer* bit is 32 — and the
hand-rolled IEEE-754 packing. A new section, "`<gpu>` alone does not produce a shader
module", states the entry-point rule and why 5 of 19 examples validate. The whole
snippet was compile-checked in the image (`noPattern: true`), so every global and
selector in it resolves.

Two further doc defects found next to it and fixed in the same pass: the stale
"no buffer indexing" and "no `gl_GlobalInvocationID`" limitation bullets, both
delivered in Phase A; and the "Buffer usage flags" tip, which listed three selectors
that do not exist (`VkImageUsage storageBit`, `transferSrcBit`, `transferDstBit`) and
gave 4 as the storage-buffer bit.

Original reasoning:

Plain `<gpu>` scalar kernels emit no `OpEntryPoint`:

```
relu:               hasEntryPoint=false   spirv-val: "No OpEntryPoint instruction was found"
vectorAdd:a:b:out:  hasEntryPoint=true    spirv-val: clean
triVertex:color:    hasEntryPoint=true    spirv-val: clean
```

So the README's "Minimal headless compute in a Playground" section cannot work: it
compiles `relu:` and then runs it through `PVComputeKernel`.

Fix the documentation. Giving every `<gpu>` scalar an entry point would mean inventing a
descriptor-binding convention for scalar parameters, which contradicts the frozen
decision that the kernel ABI is a `WorkItem` plus storage buffers. `<gpu>` scalars are
function-level lowering targets and are correct as they stand. The snippet should use
`vectorAdd:a:b:out:`, and the `<gpu>` pragma should be described as compiling to a
SPIR-V function rather than to a loadable shader module.

This also settles an earlier open question: `PVSpirvValidatorTest` covering 5 of 19
`PVKernelExamples` is **not** a coverage gap. The other 14 are `<gpu>` scalars with no
entry point, which standalone `spirv-val` must reject. Chasing 19/19 would be wrong.

### 4. Correct the remaining stale documentation

- `README.md`: the control-flow limitation bullet, once item 1 makes the error honest.
- `prompt.md`: Phase B and Phases 6.5-A, 6.5-B and 6.5-C are complete but still unmarked.

### 5. Deferred: real nesting support

General nested control flow needs a structurizer. `PVStructuredCFGRecognizer` exists
precisely to avoid writing one (frozen decision: "pattern recognizer, not general
structurizer", justified by the Pharo compiler being the sole producer of the bytecode).
Widening it is a Phase 7 scope decision, not part of this fix.
