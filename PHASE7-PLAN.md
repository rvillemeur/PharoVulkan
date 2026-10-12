# Phase 7 design — cooperative matrix and performance

Status: design, 2026-10-09. Nothing implemented yet.

This document is the design `prompt.md` asks for ("This phase is open-ended. Design when
Phase 6 is complete."). It records what the hardware actually offers, the blockers that
sit between today's compiler and any matmul at all, and a phase shape that can be
delivered against them.

## 1. What the device offers (measured, not assumed)

Read out of the live image on 2026-10-09 through throwaway uFFI probes
(`vkEnumerateDeviceExtensionProperties`, `vkGetPhysicalDeviceProperties2` with a
`VkPhysicalDeviceSubgroupProperties` in the `pNext` chain, and the existing
`Vk getPhysicalDeviceProperties:into:`). The probe class was removed afterwards; no
project code was changed.

Device: `Intel(R) Iris(R) Plus Graphics (ICL GT2)`, vendor `0x8086`, device type 1
(integrated), Vulkan API `1.4.354`. Gen11 Ice Lake. 195 device extensions.

| Thing | Value |
|---|---|
| `VK_KHR_cooperative_matrix` | **absent** |
| `VK_NV_cooperative_matrix` | **absent** |
| `VK_KHR_shader_float16_int8` | present |
| `VK_KHR_16bit_storage`, `VK_KHR_8bit_storage` | present |
| `VK_KHR_shader_integer_dot_product` | present |
| `VK_KHR_shader_subgroup_extended_types`, `_rotate`, `_uniform_control_flow` | present |
| `VK_EXT_shader_subgroup_ballot`, `_vote`, `VK_EXT_subgroup_size_control` | present |
| `VK_KHR_vulkan_memory_model` | present |
| `VK_KHR_buffer_device_address`, `VK_EXT_buffer_device_address` | present |
| `subgroupSize` | 32 |
| `subgroupSupportedStages` | 63 (all graphics stages plus compute) |
| `subgroupSupportedOperations` | 1791 — basic, vote, arithmetic, ballot, shuffle, shuffle-relative, clustered, quad, rotate, rotate-clustered |
| `quadOperationsInAllStages` | true |
| `maxComputeSharedMemorySize` | 49152 (48 KiB) |
| `maxComputeWorkGroupInvocations` | 1024 |
| `maxComputeWorkGroupSize` | 1024, 1024, 1024 |
| `maxComputeWorkGroupCount` | 2147483647, 65535, 65535 |
| `maxStorageBufferRange` | 134217728 (128 MiB) |

Consequence for the phase goal. The headline deliverable — "AI-grade matmul using
`VK_KHR_cooperative_matrix`" — **cannot be run on this hardware at all**. There are no
matrix units in Gen11 and the extension is not exposed. Everything else the phase names
(float16, subgroup reductions, a benchmarked matmul) is reachable on this device.

The table above is the Intel device. 7-F later found a second physical device on this
machine, Mesa's lavapipe (`llvmpipe (LLVM 22.1.8, 256 bits)`, 185 extensions), which *does*
report `VK_KHR_cooperative_matrix`. It is a CPU rasteriser, so it is a correctness target
only and carries no speedup claim. See §7-F.

Three storage buffers for a 512×512 float32 matmul are 1 MiB each, so the 128 MiB
storage-buffer range and the 48 KiB of shared memory are not constraints at this size.

## 2. Blockers found in our own code

### 2.1 A compute kernel containing a loop is silently miscompiled — FIXED by 7-B

This is the hard blocker, and it is a bug in the sense the global rules mean: it produces
wrong results with no diagnostic. The description below is what was measured before 7-B;
see 7-B for the fix.

`PVKernelCompiler >> compile` decides `isCompute` from the parameter types and then
returns `PVSPIRVEmitter compileComputeKernel: regOps …` **before** it ever calls
`PVCFGBuilder buildBytecodeBlocks:` or `PVStructuredCFGRecognizer`. The control-flow
machinery delivered in Phase 5 is on the non-compute path only.

Probed with a kernel that sums sixteen buffer elements in a `whileTrue:` loop:

```
bytes: 720   spirv-val: valid
45 instructions, 1 OpLabel, 0 OpLoopMerge, 0 OpBranchConditional, 1 OpFAdd
```

One basic block, one add: the loop was flattened to a single pass through its body and
the module still passes `spirv-val`, because a straight-line kernel is perfectly valid
SPIR-V. It just computes something nobody asked for.

The selection case fails differently — a compute kernel with one `ifTrue:ifFalse:` raises
`PVTypeError: No mapping for at:put:`, because type inference runs over the linearised
register ops. That one at least stops.

Both must be addressed before any matmul, naive or tiled: a per-element matmul is one
accumulation loop over `k`, and before 7-B that loop would vanish.

### 2.2 No baseline to beat

`prompt.md` says "benchmarks show speedup over Phase 5 scalar matmul". There is no scalar
matmul: `grep -rn "atMul\|matmul" src/` finds nothing, and Phase 5 delivered control flow,
not a matmul. The baseline has to be built as part of this phase, and it depends on 2.1.

### 2.3 No way to pass a scalar to a kernel — SOLVED DIFFERENTLY by 7-C

The frozen kernel ABI is a `WorkItem` plus storage buffers. There are no push constants
(`VkPipelineLayout >> create` writes `pushConstantRangeCount` 0 and there is no
`vkCmdPushConstants` binding) and no specialization constants. A matmul needs its matrix
order N.

Cheapest route that invents nothing: pass dimensions in a `bufferOf_i32` and read
`dims at: 0`. That works with today's ABI, costs one descriptor, and keeps push constants
out of this phase.

7-C did not take that route. A dims buffer makes the matmul kernel
`matmulF32:a:b:out:dims:`, which is five arguments, and `ReExcessiveArgumentsRule` fires at
five (`argumentsCount` is 5 and `basicCheck:` tests `numArgs >= self argumentsCount`), so
the kernel could not be clean. The matrix order is read from the dispatch geometry instead:
`wi gridWidth` answers NumWorkgroups.x × localSizeX, the kernel keeps four arguments, and no
extra descriptor is needed. The cost is that the grid must cover the matrix exactly, which
the kernel comment and `PVBenchmark` both state. Scalars that are *not* derivable from the
grid still have no route; a dims buffer or push constants remain open for a later phase.

### 2.4 Workgroup size is hardcoded — FIXED by 7-C

The three compute entry points end with
`addExecutionMode: … localSize literals: self class defaultLocalSize`, which 7-B named but
left at `#(64 1 1)`, and `PVComputeKernel >> dispatch:y:z:`
takes the group count from its arguments. A 512×512 matmul wants a 2-D local size
(16×16 = 256 invocations) and 32×32 groups. The local size must become part of the
annotation, not a literal in the emitter.

Done: a kernel declares `<localSize: #( 16 16 1 )>`, `PVTypeAnnotation` carries it, and
`finishComputeMain:interfaces:` writes `annotation localSize` as the LocalSize execution
mode. `PVTypeAnnotation class >> defaultLocalSize` answers `#( 64 1 1 )` for a kernel
without the pragma, so every kernel written before it keeps its old shape;
`PVSPIRVEmitter class >> defaultLocalSize` is gone.

### 2.5 No float16 buffer traffic

`VkBuffer` has `putF32s:`/`getF32s` only. The SPIR-V side is further along than the host
side: `SpvFloatType` already takes width 16, and `SpvSerializer class >> capabilityTable`
already maps `#Float16` → 9 and `#StorageBuffer16BitAccess` → 4423. Missing are the host
encode/decode of IEEE-754 binary16, an `#f16`/`#bufferOf_f16` type in `PVSelectorTable`
and `PVSPIRVEmitter`, and enabling `shaderFloat16` and `storageBuffer16BitAccess` as
device features in `VkContext` (today's device create info enables no features at all).

### 2.6 No GPU-side timing

No query pool, no `vkCmdWriteTimestamp`. Benchmarks must be host wall clock around
`dispatch:y:z:`, which already waits on the queue (`submit: cmd andWait: true`). That is
honest for whole-dispatch comparisons and useless for anything finer. Accept it; do not
build a query-pool binding for this phase.

### 2.7 Incidental defects, recorded not fixed

Found while reading the compute path. None of them blocks Phase 7; each needs its own
failing test before any change, per the bug workflow.

All three were fixed on 11 October 2026 — see `DEFECTS-PLAN.md`, which carries the
verification, the device observation behind the third one, and what each fix changed.

- `PVComputeKernel` stores `workgroupX`/`workgroupY`/`workgroupZ` and nothing ever reads
  them. `dispatch:y:z:` uses its arguments. Dead state, and misleading next to 2.4.
- `PVComputeKernel >> prepare` passes `stageFlags: 32` as a literal. 32 is
  `VK_SHADER_STAGE_COMPUTE_BIT`; the no-magic-values rule wants a named constant.
- `VkDescriptorPool >> create:` uses one number for both `maxSets` and the pool size's
  `descriptorCount`, and `PVComputeKernel >> prepare` passes `buffers size` for it. It
  happens to work because one set is always enough, but a zero-buffer kernel would ask
  for `maxSets` 0.

## 3. Proposed phase shape

Six items. Each is independently testable and carries the five artefacts the global rules
require — failing test first, then code, then refactor, then a class-side
`<sampleInstance>` example, then an `<inspectorPresentationOrder:title:>` view, then
`run_critics`. Items 7-A to 7-E run on this machine. 7-F runs as a query and a stated skip;
the kernel path it skips cannot run on the hardware device here, though §7-F records that the
software device reports the extension.

### 7-A — Device capability query — DONE (9 October 2026)

**Delivered.** The extension half came early with 7-D. The rest landed on 9 October 2026,
after the struct-overrun crash was fixed, and took the opposite approach to the one planned
below: rather than reading limits out of a byte blob at hand-counted offsets, the whole
`VkPhysicalDeviceLimits` structure is now declared field by field, so every offset comes
from the field specification uFFI compiled. `VkPhysicalDeviceLimits` is 504 bytes and is a
by-value member of `VkPhysicalDeviceProperties`; uFFI inserts the alignment pads the
`VkDeviceSize` and `size_t` members need, which a byte array member silently dropped.

`vkGetPhysicalDeviceProperties2` arrived as `Vk class >> getPhysicalDeviceProperties2:into:`
plus `VkPhysicalDeviceProperties2` (840 bytes) and `VkPhysicalDeviceSubgroupProperties`
(32 bytes). The chain is built outside the image by
`VkPhysicalDeviceProperties2 class >> of:chainedWith:do:`, because the driver follows
`pNext` and a ByteArray may move under the garbage collector; `VkStructure class >>
externalInstance` allocates and zeroes each block, and `VkStructure >> copyIntoObjectMemory`
copies the answer back into the image and clears the chain pointer that would otherwise
dangle. `VkSubgroupFeature` names the `VkSubgroupFeatureFlagBits` bits and
`VkPhysicalDeviceSubgroupProperties >> supportsFeature:` is the single rule that reads
`supportedOperations`.

`VkPhysicalDevice` answers `properties`, `limits`, `maxComputeSharedMemorySize`,
`maxComputeWorkGroupInvocations`, `maxComputeWorkGroupSize`, `subgroupProperties`,
`subgroupSize`, `supportsSubgroupArithmetic` and `supportsSubgroupFeature:`, each cached
after one query. This device: subgroup size 32, every named subgroup feature present
(`supportedOperations` 1791), 49152 bytes of shared memory, 1024 invocations per work group,
1024 in each dimension.

Measured offsets, correcting the numbers the probe reported before the overrun was fixed:
`limits` starts at byte **296** of `VkPhysicalDeviceProperties`, not 292, and
`maxComputeSharedMemorySize` sits **216** bytes into it, not 220. Both earlier readings were
four bytes out because the probe measured against a structure that was missing its
alignment pad.

Tests: `VkBindingsTest` has `testPhysicalDeviceLimitsFillsTheLimitsFieldExactly` (the
structure is exactly as long as the field holding it, and that field is eight byte aligned),
`testPhysicalDeviceLimitsRowsReadTheirOwnAccessors`,
`testSubgroupFeaturePredicateMatchesTheOperationBits` (both degenerate masks),
`testStructureCopyIntoObjectMemoryDetachesFromItsSource` and
`testNestedPropertiesNameReadsThroughTheOuterStore`. `VkCoreTest` has
`testComputeLimitsOfThisDeviceAgreeWithTheDriver`,
`testSubgroupPropertiesOfThisDeviceAgreeWithTheDriver` and
`testChainedPropertiesQueryLinksTheBlockItIsGiven`. Suite 181, all green.

One bug fell out of the nesting: `VkPhysicalDeviceProperties >> deviceNameString` read the
store through `handle basicAt:`, which fails once the structure is a member of another one,
where the handle is a reference into the outer store. It now reads through the generated
accessor.

Examples and views: `VkPhysicalDeviceLimits class >> exampleLimitsOfThisMachine` with a
Limits tab listing every member by performing its own accessor;
`VkPhysicalDeviceSubgroupProperties class >> exampleSubgroupPropertiesOfThisMachine` with a
Features tab asking `supportsFeature:` per named bit;
`VkPhysicalDeviceProperties2 class >> exampleChainedQueryOfThisMachine` with a Chain tab;
and a Compute tab on `VkPhysicalDevice`. `VkSubgroupFeature` is a constants-only class and
carries neither, as `VkStructureType` and `VkShaderStage` do not.

The original plan for this item follows.


The extension half of this item was built early, because 7-D's half precision code had to
be gated on it: `VkPhysicalDevice >> extensionNames`, `supportsExtension:`,
`halfPrecisionReport`, `VkContext >> halfPrecisionAvailable` and
`enabledDeviceExtensionNames`, pinned by `VkCoreTest`'s extension and gate tests. What
remains here is `vkGetPhysicalDeviceProperties2`, the subgroup properties accessor and the
compute limits, which 7-E needs.

Replace the throwaway probes with real bindings: `vkEnumerateDeviceExtensionProperties`
and `vkGetPhysicalDeviceProperties2`, plus a `VkPhysicalDeviceSubgroupProperties`
accessor. Surface them as `VkPhysicalDevice >> extensionNames`,
`supportsExtension: aString`, `subgroupSize`, `supportsSubgroupArithmetic` and the compute
limits the emitter will need (`maxComputeSharedMemorySize`,
`maxComputeWorkGroupInvocations`).

Structure offsets are the risk here — the limits block starts at byte 292 of
`VkPhysicalDeviceProperties` and `maxComputeSharedMemorySize` sits 220 bytes into it, both
confirmed by probe. Pin every offset in a test against a known value (subgroup size 32,
shared memory 49152 on this device) so a mis-offset cannot pass silently.

This is also the "skip on devices that lack it" mechanism the minimum spec asks for, and
every later item needs it.

**Done when** `VkCoreTest` asserts the extension list is non-empty, contains
`VK_KHR_shader_float16_int8`, does not contain `VK_KHR_cooperative_matrix`, and reports
subgroup size 32 and 48 KiB of shared memory on this device, with the cooperative-matrix
assertion written so it states a fact about *this* device rather than a universal rule.

### 7-B — Control flow in compute kernels — DONE (9 October 2026)

Route the compute path through the existing recogniser instead of around it.

Order of work, strictly:

1. Failing test: the loop kernel of §2.1 must stop compiling to one basic block. Assert
   on the module, not on the bytes — count `OpLoopMerge` — so the test says what it means.
2. Failing test: the selection kernel of §2.1 must stop raising `No mapping for at:put:`.
3. Make `compile` build the blocks and run `PVStructuredCFGRecognizer` for compute kernels
   as it already does for the others. Where no construct is recognised and there is more
   than one block, raise `PVTypeError: 'Unrecognized CFG shape'` — the honest error the
   non-compute path gives. That alone converts the silent miscompile into a refusal and is
   worth landing on its own.
4. Then add the two emitters that are actually missing:
   `compileComputeKernelLoop:` and `compileComputeKernelSelection:`. These are not the
   existing `compileLoop:`/`compileSelection:`: those build a value-returning function with
   an `OpReturnValue`, while a compute entry point returns void and stores through a
   buffer. The loop and phi emission can be reused; the prologue (built-in input variable,
   storage-buffer globals, descriptor decorations) and the epilogue (`OpReturn`) come from
   `compileComputeKernel:`.

Keep the frozen limit: exactly one construct per method, and `covers:` still has to
account for every block. That is enough for a naive matmul.

**Done when** a `whileTrue:` compute kernel emits one `OpLoopMerge`, validates, and
*returns the right numbers from the GPU* — the sum-of-16 kernel is the test, because
`spirv-val` demonstrably cannot catch this class of bug. Sequential and nested shapes in a
compute kernel raise `PVTypeError`, pinned in `PVCfgShapeFixture` alongside the existing
seven shapes.

#### What was built

`PVKernelCompiler >> compile` now builds the blocks before the compute branch and hands
them to `compileComputeBlocks:regOps:typeMap:selectorTable:`, which runs the recogniser:
one block goes to `compileComputeKernel:` as before, a `PVLoopNode` to
`compileComputeKernelLoop:annotation:selectorTable:`, a `PVSelectionNode` to
`compileComputeKernelSelection:annotation:selectorTable:`, and anything else raises
`PVTypeError: 'Unrecognized CFG shape'`.

Neither new emitter takes a typeMap. The whole-method `PVStackSimulator` numbering the
caller's map is built from is not the numbering `PVBlockSimulator` produces per block, so
passing that map in was itself the cause of the bogus `No mapping for at:put:`. Each
emitter simulates its blocks with one threaded numbering
(`computeLoopSimulations:…`, `computeSelectionSimulations:…`) and infers types over that
numbering with a single `PVTypeInferencer`, whose map accumulates across the blocks.

The three compute entry points share the prologue and epilogue:
`emitComputeInterfaces` (now split into `emitWorkItemInputForParam:` and
`emitStorageBufferParam:at:binding:decoratedArrays:`), `newComputeMainFunction` and
`finishComputeMain:interfaces:`. The literals they used are named class-side constants:
`defaultLocalSize`, `storageBufferArrayStride`, `computeDescriptorSet`,
`bufferMemberIndex`, `bufferMemberOffset`, `loopControlNone`, `selectionControlNone`.

The selection emitter emits the merge block's own register ops, which `compileSelection:`
never had to do: a value-returning function only returns the phi, while a compute kernel
does its store there.

#### Evidence

| Fact | How it is pinned |
|---|---|
| Loop kernel emits one `OpLoopMerge`, one `OpBranchConditional`, two `OpPhi` | `PVCompilerTest >> testComputeLoopKernelEmitsOneLoopMerge`, counting decoded opcodes |
| Selection kernel emits one `OpSelectionMerge`, one `OpPhi` | `PVCompilerTest >> testComputeSelectionKernelEmitsSelectionMerge` |
| Nested and sequential compute shapes are refused | `testComputeNestedLoopsRejected`, `testComputeSequentialSelectionsRejected` |
| Sum of the first 16 floats is 120 on the device | `PVComputeTest >> testComputeLoopSumOnDevice` |
| Negatives clamp to zero on the device | `PVComputeTest >> testComputeSelectionClampOnDevice` |
| Both modules validate | 848 and 748 bytes, `spirv-val --target-env vulkan1.3` clean |

Suites after the change: `PVCompilerTest` 45, `PVComputeTest` 4, `PVSpirvValidatorTest` 16,
`PVGraphicsTest` 13, `SpvBuilderTest` 6, `SpvEmitterTest` 2, `VkBindingsTest` 16,
`VkCoreTest` 3 — all passing.

Example and view: `PVKernelExamples >> sumFirst16:data:out:` and
`clampNegatives:data:out:` are the two kernels in the main package;
`PVSpirvValidator class >> exampleValidatorOnComputeLoopKernel` and
`exampleValidatorOnComputeSelectionKernel` are the one-click `<sampleInstance>` examples;
`PVSpirvValidator >> inspectorControlFlow:` adds a Control flow tab listing each basic
block with its merge and terminator, decoded from the bytes. That tab is what shows a
dropped loop, since the Validation tab says valid either way.

### 7-C — Scalar float32 matmul baseline — DONE (9 October 2026)

`PVKernelExamples >> matmulF32:a:b:out:dims:` — one invocation per output element, row and
column from `WorkItem` x and y, N from `dims at: 0`, a single `whileTrue:` over k. Local
size becomes part of the annotation (§2.4): add `<localSize: 16 by: 16>` or equivalent and
read it in the emitter instead of `#(64 1 1)`.

A benchmark needs somewhere to live. Propose `PVBenchmark` in `PharoVulkan-Compute`:
builds the buffers, runs a warm-up dispatch, times N repeats with
`Time millisecondsToRun:`, answers a result object carrying milliseconds, derived
GFLOP/s (2·N³ / t) and the configuration. Its inspector view is the natural place for the
table, and its example runs a small size so clicking it is cheap.

**Done when** 512×512 float32 matmul output matches a CPU reference within float32
tolerance, and `PVBenchmark` reports a time. No speed claim at this step — this *is* the
baseline.

#### What was built

The kernel is `PVKernelExamples >> matmulF32:a:b:out:` — four arguments, not five, because
the matrix order comes from the dispatch rather than a dims buffer (§2.3). It reads
`row := wi x`, `col := wi y`, `n := wi gridWidth`, and loops over k with one `whileTrue:`,
accumulating `(a at: row * n + k) * (b at: k * n + col)`. Row-major storage, no tiling, no
shared memory. It carries `<localSize: #( 16 16 1 )>`.

Three mechanisms were added underneath it.

*Local size in the annotation.* `PVTypeAnnotation` gained a `localSize` slot, the
`<localSize:>` pragma, and the class-side `defaultLocalSize` of `#( 64 1 1 )`. Adding two
statements to `fromMethod:` pushed it past `ReLongMethodsRule`, so the pragma loop became
`applyPragma:` plus `beGpuOfKind:` on the instance side. `PVSPIRVEmitter` reads
`annotation localSize` when it writes the execution mode and no longer owns a default.

*Grid geometry as a DSL selector.* `PVSelectorTable` maps `gridWidth` on `#workItem` to
`#workItemGridWidth` → `#u32`. `PVSPIRVEmitter >> emitGridWidth:block:` lazily creates one
Input `v3uint` variable decorated `BuiltIn NumWorkgroups` (24), extracts component x and
multiplies it by `annotation localSize first` from the constant pool. SPIR-V requires every
Input variable in the entry point's interface list, so `finishComputeMain:interfaces:` adds
that variable to the declared parameters' interfaces before serialising.
`initializeStandardMappings` was split into scalar, work-item and buffer halves for the
same long-method reason; its only sender is `PVSelectorTable class >> standard`.

*Host-side WorkItem.* `PVWorkItem` (slots `x y z gridWidth`) is the receiver the frozen
`#workItem` parameter type never had. Without it `gridWidth` was a message to nobody and
`ReSentNotImplementedRule` said so on both new kernels — `x`/`y`/`z` escaped the rule only
because unrelated classes happen to implement them. `kernelSelectors` asks
`PVSelectorTable standard` which selectors are mapped for a work item, so the class cannot
drift from the compiler and a mapping added without a method is visible.

The benchmark is `PVBenchmark` with `PVBenchmarkResult`, both in `PharoVulkan-Compute`.
`PVBenchmark class >> on:order:repeats:` raises `PVTypeError` when the order is not a
multiple of the kernel's own `localSize first`, since the grid could not then cover the
matrix. `run` fills two input matrices, throws the first dispatch away as warm-up, and
times the repeats with `Time millisecondsToRun:` around `dispatch:y:z:`, which waits on the
queue. `PVBenchmarkResult` carries order, milliseconds and repeats and derives
2·N³ / t GFLOP/s; it answers `nil` for the rate when the dispatch was quicker than the host
clock, rather than reporting zero or infinity.

#### Evidence

| Fact | How it is pinned |
|---|---|
| `<localSize: #( 16 16 1 )>` reaches the LocalSize execution mode | `PVCompilerTest >> testLocalSizePragmaReachesExecutionMode`, decoding the mode's literals |
| A kernel without the pragma still gets `#( 64 1 1 )` | `testDefaultLocalSizeWhenPragmaAbsent` |
| `wi gridWidth` emits a NumWorkgroups built-in | `testGridWidthEmitsNumWorkgroupsBuiltIn`, reading `OpDecorate` |
| The matmul module has one loop and a 2-D local size | `testMatmulKernelEmitsOneLoopAndA2DLocalSize`: one `OpLoopMerge`, literals `#( 16 16 1 )`, built-ins GlobalInvocationId + NumWorkgroups |
| `gridWidth` is the dispatch, not a constant | `PVComputeTest >> testGridWidthFromDispatchOnDevice`: the same module answers 120 with 2 groups and 496 with 4, with an untouched `-1.0` tail that also pins `<localSize: #( 8 1 1 )>` |
| 16×16 matmul matches a CPU reference at every element | `testMatmulOrder16MatchesReference` |
| 512×512 matmul matches at sampled positions | `testMatmulOrder512MatchesReferenceAtSampledPositions`: 81 full dot products at the corners, edges and interior, asymmetric small-magnitude inputs so a row/column swap fails, `precision: 0.01` |
| The benchmark refuses a grid that cannot cover the matrix | `testBenchmarkRejectsOrderThatTheGridCannotCover` |
| The benchmark reports a time, and no rate when the clock is too coarse | `testBenchmarkRunsMatmulAndReportsTime`, `testBenchmarkResultDerivesRateFromTime`, `testBenchmarkResultWithoutElapsedTimeHasNoRate` |
| The matmul module validates | 1208 bytes, `spirv-val --target-env vulkan1.3` clean |

Baseline on this device (the Iris Plus of §1, 3 repeats after warm-up, host clock around a
queue-waiting dispatch):

| N | ms | GFLOP/s |
|---|---|---|
| 128 | 2.7 | 1.6 |
| 256 | 6.0 | 5.6 |
| 512 | 34.7 | 7.7 |

No speed claim is attached to these: they are the number 7-D and 7-E have to beat. Host
transfer was measured first and left alone — `putF32s:` is about 60 ms per MiB and
`getF32s` about 34 ms, both outside the timed region.

Suites after the change: `PVCompilerTest` 53, `PVComputeTest` 12,
`PVSpirvValidatorTest` 19, `PVGraphicsTest` 13, `SpvBuilderTest` 6, `SpvEmitterTest` 2,
`VkBindingsTest` 16, `VkCoreTest` 3 — all passing.

Examples and views: `PVBenchmark class >> exampleBenchmarkOnOrder64Matmul` with
`inspectorBenchmark:` (Benchmark tab: order, milliseconds, repeats, rate);
`PVSpirvValidator class >> exampleValidatorOnMatmulKernel` with `inspectorEntryPoint:`
(Entry point tab: local size, invocations per group, built-ins read, all decoded from the
bytes and named by reflecting over `SpvBuiltIn class`); `PVWorkItem class >>
exampleWorkItemInA512Grid` with `inspectorDispatch:` (Dispatch tab: one row per selector
the table maps for a work item, with this item's answer).

Critics are clean on everything 7-C touched, with two exceptions, both pre-existing and
left alone per the no-cosmetic-change rule: `ReExcessiveMethodsRule` on `PVCompilerTest`
(53 tests in the one test class per package this project mandates) and the long-method and
cyclomatic-complexity critiques on `PVSPIRVEmitter`'s older `compile*`/`emitRegOp:`
methods, which fired before this item and are a structural job of their own.

### 7-D — float16 — DONE (9 October 2026)

Host side: `VkBuffer >> putF16s:`/`getF16s` with IEEE-754 binary16 encode and decode,
tested on the degenerate values (zero, negative zero, one, subnormal, the largest finite
half, infinity, round-to-nearest-even at the tie) rather than only on a happy path.

Device side: `#f16` and `#bufferOf_f16` in `PVSelectorTable` and in
`compileComputeKernel:`'s element-type choice, `#Float16` and
`#StorageBuffer16BitAccess` capabilities, `OpTypeFloat 16`, array stride 2 instead of the
hardcoded 4, and the `shaderFloat16` plus `storageBuffer16BitAccess` features enabled in
`VkContext`'s device create info — gated on 7-A reporting
`VK_KHR_shader_float16_int8`, so the code still runs on a device without it.

**Done when** a float16 vector-add runs correctly on the GPU, then a float16 matmul
matches the CPU reference within half-precision tolerance, and `PVBenchmark` reports both
f32 and f16 for the same size.

Expectation, stated so nobody is disappointed by an honest number: Gen11 executes fp16 at
up to twice the fp32 rate, and halving the bytes helps a memory-bound naive kernel. A
factor around 1.5 to 2 is the plausible outcome. There is no matrix unit here, so nothing
in this phase can produce the order-of-magnitude jump cooperative matrix is sold on.

#### What was built

*Host side.* `PVFloat16` encodes and decodes IEEE-754 binary16 (`wordForFloat:`,
`floatFromWord:`, `mantissaBits`, `bytesPerHalf`), with `VkBuffer class >>
storageBufferOfHalves:on:`, `putF16s:` and `getF16s` over it. One front door was added so a
caller working in either precision holds one branch rather than one per operation:
`VkBuffer class >> storageBuffer:of:on:`, `put:as:` and `elementsAs:`, each raising
`PVTypeError` on a width there is no buffer for.

*Gating.* The device extension query of 7-A was brought forward: `VkContext` enables
`VK_KHR_shader_float16_int8` and `VK_KHR_16bit_storage` and chains
`VkPhysicalDeviceShaderFloat16Int8Features` and `VkPhysicalDevice16BitStorageFeatures` into
`vkCreateDevice` only where the physical device reports both, so the image still runs on a
device without them and `halfPrecisionAvailable` is the single answer every half test and
the compiler ask.

*One source for the element type.* Three duplicated `#bufferOf_i32 ifTrue:` branches and a
hardcoded array stride of 4 were replaced by `PVSPIRVEmitter class >> bufferElementTypes`
(`#bufferOf_f32 -> #f32`, `#bufferOf_i32 -> #i32`, `#bufferOf_f16 -> #f16`) with
`elementTypeOf:`, `scalarByteWidths` and `storageBufferArrayStrideFor:` over it. The
declaration, every load and every store now ask `bufferElementTypeFor:`, because a module
whose three answers disagree declares one array and indexes another. An unknown buffer type
raises `PVTypeError` instead of silently taking the 4-byte default.
`PVKernelCompiler class >> computeParamTypes` derives the kernel parameter types from the
same dictionary, so a new element width is accepted by adding it in one place.

*Capabilities from the data, not from a pragma.* `declareCapabilitiesFor:` adds Float16 (9)
and StorageBuffer16BitAccess (4433) exactly when a buffer holds halves. Both are core in
SPIR-V 1.3 and the module targets 1.5, so no `OpExtension` is needed. A kernel therefore
cannot declare one width and use another.

*DSL.* `PVSelectorTable >> initializeHalfMappings` maps `+ - * / < <=` on `#f16` to the same
float instructions with a half result type, `at:`/`at:put:` on `#bufferOf_f16`, and the two
conversions `asF32` on `#f16` and `asF16` on `#f32` to `OpFConvert` (115, added to
`SpvOpcode`). The generic tail of `emitRegOp:` emits a unary mapped opcode unchanged, so
the conversions needed no emitter case. `Number >> asF16`/`asF32` are project extension
methods on Number, so a kernel body means the same thing run on the host as on the device;
without them `ReSentNotImplementedRule` was right to complain.

*Kernels.* `PVKernelExamples >> vectorAddF16:a:b:out:` and `matmulF16:a:b:out:`. The matmul
holds its matrices as halves and accumulates the dot product in float via `asF32`/`asF16`:
the error of an N-term sum grows with N, so accumulating in half would cost far more
accuracy than the storage format itself does. `matmulKernels` and `matmulFor:` name the
kernel per precision so the two cannot drift apart in their callers.

*Benchmark.* `PVBenchmark` now carries an element type: `on:order:repeats:elementType:`,
with `kernelMethodFor:`, `workgroupWidthFor:` and `elementTypes` asked of
`PVKernelExamples matmulKernels`, buffers built through `storageBuffer:of:on:`, and an
`Element type` row first in the report. `on:order:repeats:` still answers the float
baseline. `PVPrecisionComparison` runs one benchmark per precision at the same order and
repeat count in the one go — times measured minutes apart on a shared device are not a
comparison — and reports time, rate and the ratio against the baseline, answering nil for a
ratio when either dispatch was too quick for the host clock.

#### Evidence

| Fact | How it is pinned |
|---|---|
| binary16 encode and decode on the degenerate values | `VkBindingsTest` round-trip tests (zero, negative zero, subnormal, largest finite half, infinity, NaN, round-to-nearest-even tie) |
| A half buffer holds two bytes per element | `VkCoreTest >> testHalfBufferHoldsTwiceAsManyValuesAsAFloatBuffer` |
| A half buffer round-trip snaps to the nearest half | `testHalfBufferRoundtripSnapsEachValueToItsNearestHalf` |
| The element-type front door covers both widths and refuses a third | `testStorageBufferByElementTypeRoundtripsBothWidths`, `testStorageBufferRefusesAnUnknownElementType` |
| Half precision is enabled only where the device offers it | `testComputeContextEnablesHalfPrecisionWhenTheDeviceOffersIt`, `testDeviceCreateInfoChainsTheHalfPrecisionFeatureStructs` |
| `#f16` is a 16-bit `OpTypeFloat` | `PVCompilerTest >> testSpvTypeForHalfIsASixteenBitFloat` |
| A half kernel declares Float16 and StorageBuffer16BitAccess, a float kernel declares neither | `testHalfKernelDeclaresTheHalfPrecisionCapabilities`, `testCapabilitiesDeclaredForEachBufferType` |
| Array stride follows the element width | `testArrayStrideFollowsTheBufferElementWidth`, `testHalfKernelDecoratesItsArraysWithATwoByteStride` |
| An unknown buffer type raises rather than defaulting to 4 bytes | `testUnknownBufferTypeIsRefused` |
| The half kernel loads and stores halves only | `testHalfKernelLoadsAndStoresHalvesOnly` |
| The half matmul accumulates in single precision | `testHalfMatmulAccumulatesInSinglePrecision`: the module's float widths are exactly `#( 16 32 )` and it contains `OpFConvert` |
| Both modules are valid SPIR-V | `PVSpirvValidatorTest >> testVectorAddF16`, `testMatmulF16`, `spirv-val` clean |
| The half vector add is right on the device | `PVComputeTest >> testVectorAddF16OnDevice`: 64 elements chosen so every input and every sum is an exact half, so the assertion is equality and no tolerance hides a wrong answer |
| The half matmul matches the CPU reference | `testMatmulF16OnDeviceMatchesTheReferenceWithinHalfTolerance` (order 16, every element) and `testMatmulF16OnDeviceHoldsAtTheBenchmarkSize` (order 512 at 81 sampled positions), both through `assertHalf:matchesReference:` |
| The tolerance is derived, not guessed | `halfRoundoff` is 2⁻¹¹ from `PVFloat16 mantissaBits`; `halfErrorBudget` of 8 roundings is named and commented (one per input matrix, one for the stored result, the rest slack for the device's accumulation order) |
| The benchmark times the kernel of the precision it names | `testBenchmarkOfEachElementTypeDispatchesTheKernelOfThatWidth`, `testBenchmarkRefusesAnUnknownElementType`, `testBenchmarkReportNamesThePrecisionItMeasured` |
| Both precisions are measured at one size, in one run | `testPrecisionComparisonTimesEveryElementTypeAtTheSameOrder`, `testPrecisionComparisonReportsOneRowPerElementType`, `testPrecisionComparisonSpeedupNeedsTwoMeasuredTimes` |

Measured on this device (Iris Plus of §1, 5 to 10 repeats after warm-up, both precisions in
the same `PVPrecisionComparison` run):

| N | f32 ms | f16 ms | f16 speedup |
|---|---|---|---|
| 256 | 6.8 | 6.2 | 1.10 |
| 512 | 40.9 | 38.8 | 1.05 |
| 1024 | 311.4 | 311.4 | 1.00 |

The honest number is about 1.0 to 1.1, not the 1.5 to 2 expected above. Two reasons, both
visible in the code rather than guessed: the dot product accumulates in f32, so the
arithmetic is float arithmetic and only the loads and the store are narrower; and this naive
matmul re-reads each row and column N times, so it is limited by that redundant traffic and
by latency rather than by the byte width of a single element. A tiled kernel holding a block
in shared memory would be the thing to measure half precision against. 7-E as delivered
reduces across a subgroup and uses no shared memory, so the tiled kernel was left unwritten
here; 7-G wrote it in float and **7-I measures the pair, where the ratio is 1.3 to 1.5**. The
1024 row is the clearest statement of the result on this kernel: at that size the two
precisions are indistinguishable.

Suites after the change: `PVCompilerTest` 65, `PVComputeTest` 21, `PVSpirvValidatorTest` 21,
`PVGraphicsTest` 13, `SpvBuilderTest` 6, `SpvEmitterTest` 2, `VkBindingsTest` 26,
`VkCoreTest` 14 — 168 tests, all passing, none skipped, since this device has the
extensions.

Examples and views: `PVPrecisionComparison class >>
examplePrecisionComparisonOnOrder256Matmul` with `inspectorPrecision:` (Precision tab: one
row per precision with time, rate and ratio, each asked of the comparison rather than
written into the table); `PVBenchmark class >> exampleHalfBenchmarkOnOrder64Matmul` with the
existing `inspectorBenchmark:`, whose first row now names the precision;
`PVSpirvValidator class >> exampleValidatorOnHalfVectorAddKernel`, whose verdict is what
tells the two capabilities reached the module, since `spirv-val` refuses a 16-bit float in a
storage buffer without them.

Critics are clean on everything 7-D touched. `PVBenchmark` had no class comment and now has
one. Three critiques elsewhere are pre-existing and left alone per the no-cosmetic-change
rule: `ReLongMethodsRule` on `PVSPIRVEmitter >> spvTypeFor:` (over the 20-statement limit
before the one `#f16` line was added), on `PVKernelCompiler >> compile` and on
`PVComputeTest >> buildVectorAddSpirv`, plus `ReExcessiveMethodsRule` on `PVCompilerTest`,
which holds the one test class per package this project mandates.

### 7-E — Subgroup reduction — DONE (9 October 2026)

The one remaining item from the phase goal that this device supports well:
`subgroupSupportedOperations` includes arithmetic, so `OpGroupNonUniformFAdd` with
subgroup scope is available.

Smallest useful kernel is a dot product: each invocation multiplies its pair, the subgroup
reduces, lane 0 adds into the output. That needs `OpGroupNonUniformFAdd`, the
`GroupNonUniform` and `GroupNonUniformArithmetic` capabilities, and the subgroup scope
constant. None of those are in `SpvOpcode` (64 named opcodes today) or in
`SpvSerializer class >> capabilityTable`; add them as named constants taken from the
grammar, never as inline numbers.

A `dot:` or `reduceSum` selector on `#bufferOf_f32` is the DSL surface. Note that it is a
*group* operation, so unlike every selector in the table today its correctness depends on
all lanes reaching it — worth a comment on the mapping saying so.

**Done when** a subgroup dot product over 1024 float32 elements matches the CPU sum within
tolerance, and the kernel is skipped with a clear reason on a device whose
`subgroupSupportedOperations` lacks arithmetic.

#### Delivered

`PVKernelExamples >> subgroupDotOf:a:b:out:lanes:` multiplies one pair per invocation and
reduces the products across the subgroup, and `PVSubgroupDotProduct` dispatches it over 1024
float32 elements and recovers the dot product. On this device the result is 9216.0 against a
host sum of 9216.0, a difference of exactly zero, so no tolerance was needed after all.
`PVSubgroupDotProduct >> run` asks `VkContext >> subgroupArithmeticAvailable` first and
raises `unavailableReason` — "This device does not report subgroup arithmetic, so the
reduction cannot run" — rather than dispatching a kernel the device cannot honour.

The DSL surface is `subgroupSum` on `#f32`, not the `dot:` or `reduceSum` on
`#bufferOf_f32` proposed above. The reduction belongs on the scalar each lane holds, because
that is what the SPIR-V instruction takes: a buffer-level selector would have to hide a
whole dispatch behind one send and would not say which lanes contribute. The kernel body
reads `output at: i put: ((a at: i) * (b at: i)) subgroupSum`, which is the instruction
itself. `Number >> subgroupSum` answers the receiver on the host, since a single Pharo
process is a subgroup of one.

Every new number is a named constant: `SpvOpcode class >> opGroupNonUniformFAdd` (350, the
floating point neighbour of `OpGroupNonUniformIAdd` 349), `SpvScope class >> subgroup` (3),
`SpvGroupOperation class >> reduce` (0), and `PVSPIRVEmitter class >>
groupNonUniformCapability` (61) and `groupNonUniformArithmeticCapability` (63). The two new
enumerations are classes of their own rather than entries in `SpvSerializer class >>
capabilityTable`, because a scope and a group operation are not capabilities; the capability
pair is declared by `emitSubgroupReduceSum:resultTypeSymbol:block:` as it emits, so a kernel
that never reduces does not ask the driver for them. The scope operand is an *id* of a
`u32` constant while the group operation beside it is a *literal*, which is why the emitter
puts the scope through the constant pool.

The mapping in `PVSelectorTable >> initializeSubgroupMappings` carries the comment the plan
asked for: `subgroupSum` is a group operation, so every lane must reach it, and a send from
one arm of a branch is undefined. That is why the one kernel sending it has a straight-line
body.

#### The reported subgroup width is a maximum, not the width a shader runs at

The first device run failed, and the failure is the most useful thing 7-E found. Every one
of the 1024 slots held 144.0 where 32 lanes of mean product 9 would give 288.0:
`VkPhysicalDeviceSubgroupProperties subgroupSize` reports 32 on this device, but the driver
compiled this shader to a 16-wide subgroup. The reported size is the widest subgroup the
device offers. Pinning the width would need `VK_EXT_subgroup_size_control`, which this
project does not enable.

So the kernel measures the width of the subgroup it actually ran in: a second reduction,
`lanes at: i put: 1.0 subgroupSum`, writes the lane count into a fourth buffer.
`PVSubgroupDotProduct >> gpuTotal` then divides the sum of every slot by that measured
width. `Reduce` delivers the same total to every active lane, so each subgroup's total
appears once per lane of that subgroup; dividing by the measured width needs no assumption
about which invocations share a subgroup, which the specification leaves to the
implementation. `reportedSubgroupSize` and `measuredSubgroupSize` are both on the runner, so
the difference between them is visible rather than folded away.

#### Evidence

| Fact | How it is pinned |
|---|---|
| `subgroupSum` compiles to the group instruction and nothing else | `PVCompilerTest >> testSubgroupSumMapsToTheGroupNonUniformAdd` |
| It means the same thing on the host | `testSubgroupSumOnTheHostAnswersTheValueItself` |
| Both capabilities reach the module, named through the emitter | `testSubgroupDotKernelDeclaresTheGroupCapabilities` |
| Both reductions carry subgroup scope and `Reduce`, with the scope resolved back to the constant the module declares rather than a guessed id | `testSubgroupDotKernelReducesOverTheSubgroupScope`, via the `constantIdOfValue:in:` helper |
| The module is valid SPIR-V | `PVSpirvValidatorTest >> testSubgroupDotKernelValidates`, `spirv-val` clean |
| The device answer matches the host sum | `PVComputeTest >> testSubgroupDotOnDeviceMatchesTheCpuSum` (1024 elements) |
| Each slot really holds a reduction and not one lane's product | `testSubgroupDotSlotsHoldMoreThanOneLaneProduct` |
| The measured width is a power of two, no wider than the reported one, and the same in every slot | `testSubgroupDotMeasuresTheWidthTheShaderRanAt` |
| A device without the arithmetic is refused with a reason naming the subgroup | `testSubgroupDotRefusesADeviceWithoutTheArithmetic`, through `PVNoSubgroupArithmeticStub` |
| A run outlives the context an example builds for it | `testSubgroupDotExampleReportsEveryRowAfterItsContextIsGone` |
| The availability flag agrees with the device | `VkCoreTest >> testSubgroupArithmeticAvailabilityAgreesWithTheDevice` |

Suites after the change: `PVCompilerTest` 69, `PVComputeTest` 26, `PVSpirvValidatorTest` 22,
`PVGraphicsTest` 13, `SpvBuilderTest` 6, `SpvEmitterTest` 2, `VkBindingsTest` 34,
`VkCoreTest` 20 — 192 tests, all passing, none skipped, since this device reports subgroup
arithmetic.

Example and view: `PVSubgroupDotProduct class >> exampleSubgroupDotOf1024Elements` runs the
reduction on a context it builds and destroys, and `inspectorReduction:` shows the Reduction
tab — elements, workgroup width, workgroups dispatched, reported width, measured width, the
device total, the host total and the difference. The example answers the run even when the
device refuses it, so the tab states the reason instead of raising past the click.
`PVSpirvValidator class >> exampleValidatorOnSubgroupDotKernel` gives the verdict on the
module in one click.

Critics are clean on `PVSubgroupDotProduct`, `PVNoSubgroupArithmeticStub`, `SpvScope`,
`SpvGroupOperation`, `PVSelectorTable`, `PVSpirvValidator`, `PVSpirvValidatorTest`,
`VkCoreTest` and `Number >> subgroupSum`. One new critique stands:
`ReExcessiveArgumentsRule` on `subgroupDotOf:a:b:out:lanes:`, whose five parameters are the
kernel's descriptor bindings — the work item, two inputs and two outputs. Folding the lane
counts into the output buffer would silence the rule at the cost of index arithmetic in the
kernel body, which is a worse trade. Everything else reported on the touched classes is
pre-existing and left alone per the no-cosmetic-change rule.

### 7-F — Cooperative matrix: descope to a query and a documented skip — DONE (10 October 2026)

Not runnable here. Writing `coopMatLoad:`, `coopMatStore:` and `coopMatMulAdd:` against no
hardware would mean untestable code in the image, which is worse than an absent feature.

Proposal:

- Keep the query (7-A) and a documented skip, which is the half of the minimum spec that
  can be honoured.
- Do **not** add the `CoopMatrix` type or the three selectors to `PVSelectorTable` until
  there is a device to run them on.
- Record the open option: Mesa's `lavapipe` software device may expose
  `VK_KHR_cooperative_matrix`. If it does, it is a correctness target only — a CPU
  implementation cannot support any speedup claim. Verify before promising anything; the
  probe in 7-A is what answers it.

Rewrite the phase's **Done when** in `prompt.md` to match what can be delivered:

> **Done when**: device capabilities are queried and reported; compute kernels support one
> control-flow construct; a float32 matmul produces correct output and a benchmark number;
> a float16 matmul produces correct output and is benchmarked against it; a subgroup
> reduction produces correct output. Cooperative matrix is queried and skipped on hardware
> that lacks it, which includes this machine.

#### Delivered

The query is `VkPhysicalDevice >> supportsCooperativeMatrix`, over the name constant
`VkPhysicalDevice class >> cooperativeMatrixExtensionName`, which is built from
`extensionNamePrefix` so it cannot drift from the form a driver reports. `VkContext >>
cooperativeMatrixAvailable` answers for the device a kernel would actually run on.

`PVCooperativeMatrixSurvey` (tag Core) answers the machine-wide question, which turned out
to be the one that matters. It asks every device the loader offers, marks the one the context
chose, and states the skip reason in words:

> Intel(R) Iris(R) Plus Graphics (ICL GT2) does not report VK_KHR_cooperative_matrix, which
> llvmpipe (LLVM 22.1.8, 256 bits) does

`availableSomewhere` and `availableOnContextDevice` are kept apart, because neither answers
the other. The survey reads every fact in `setContext:`, since the example destroys the
context it built and a destroyed context enumerates nothing. `exampleSurveyOfThisMachine`
and `inspectorCooperativeMatrix:` show the devices beside the verdict in one click.

The `CoopMatrix` type and the three selectors were **not** added, as proposed above. That
absence is now pinned by `PVCompilerTest >> testNoCooperativeMatrixSelectorIsMappedYet`,
whose comment says to delete it in the same change that adds the first mapping, and to name
the device that ran it.

#### The lavapipe option is answered: it does report the extension

The open option above is no longer open. This machine has Mesa's lavapipe ICD installed
(`/usr/share/vulkan/icd.d/lvp_icd.x86_64.json`, one of twelve ICD manifests there), the
loader enumerates it as a second physical device, and it reports
`VK_KHR_cooperative_matrix`:

| Device | Extensions | `VK_KHR_cooperative_matrix` | `VK_NV_cooperative_matrix` |
|---|---|---|---|
| Intel(R) Iris(R) Plus Graphics (ICL GT2) | 195 | no | no |
| llvmpipe (LLVM 22.1.8, 256 bits) | 185 | **yes** | no |

So a correctness-only target exists on this machine, exactly as the proposal allowed for.
What it is not is a performance target: llvmpipe is a CPU rasteriser, so any number measured
on it says something about LLVM and nothing about a matrix unit. Nor is it free work —
`VkContext` selects the first device with a compute queue, which is the Intel one, so a
cooperative matrix path needs device selection by name or by capability, the extension and
its feature struct enabled at device creation, the supported shape and type combinations
queried through `vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR`, and then the SPIR-V
side: the `CooperativeMatrixKHR` capability, `OpTypeCooperativeMatrixKHR` and the load, store
and mul-add instructions, none of which the emitter has today.

That is a phase item in its own right, not a rider on this one. Recorded as the open 7-H
below; whether to spend it on a software device is the user's call.

#### Evidence

| Fact | How it is pinned |
|---|---|
| The extension name is the KHR one and carries the driver's prefix | `VkCoreTest >> testCooperativeMatrixExtensionNameIsTheKhrOne` |
| The predicate agrees with the list the driver reported | `testCooperativeMatrixSupportAgreesWithTheExtensionList` |
| The context answers for its own device | `testCooperativeMatrixAvailabilityOnTheContextAgreesWithItsDevice` |
| The survey covers every device, not only the chosen one | `testCooperativeMatrixSurveyCoversEveryPhysicalDevice` |
| Machine-wide availability and the supporting names cannot disagree | `testCooperativeMatrixSurveyNamesTheDevicesThatSupportIt` |
| The skip states a reason naming the extension, and nothing is skipped on a device that has it | `testCooperativeMatrixSkipReasonNamesTheExtensionWhenTheContextDeviceLacksIt`, written as an implication so it holds on a device of either kind |
| The survey still reports after its context is destroyed | `testCooperativeMatrixSurveyReportsAfterItsContextIsGone` |
| No cooperative matrix selector is mapped yet | `PVCompilerTest >> testNoCooperativeMatrixSelectorIsMappedYet` |

Suites after the change: `PVCompilerTest` 70, `PVComputeTest` 26, `PVSpirvValidatorTest` 22,
`PVGraphicsTest` 13, `SpvBuilderTest` 6, `SpvEmitterTest` 2, `VkBindingsTest` 34,
`VkCoreTest` 27 — 200 tests, all passing, none skipped.

Critics are clean on `PVCooperativeMatrixSurvey` and `VkCoreTest`. The one critique on
`VkPhysicalDevice` (`ReUnaryAccessingMethodWithoutReturnRule` on
`fetchQueueFamilyProperties`) is pre-existing and left alone.

### 7-G — Tiled matmul with shared memory — DONE (10 October 2026)

The item §4 left as a proposal, opened because 7-C produced the baseline §4 asked for. It
runs in three steps, and the third one was made conditional on the second one's measurement:
if tiling bought less than roughly 1.3× over the 7-C baseline, the work stopped there and
said so, because reversing the frozen "pattern recognizer (not general)" decision is only
worth it for a kernel shape that actually goes fast on this device.

**Step 1 — emitter primitives. DONE.** The three things the emitter lacked, each taken from
the grammar as a named constant: `SpvStorageClass workgroup`, a fixed-length array type
(`SpvArrayType` and `SpvTypeRegistry >> arrayType:length:`) so a shared tile can be declared
as a module-scope variable, and `OpControlBarrier` with its execution scope and memory
semantics (`SpvScope workgroup`, the `SpvMemorySemantics` bits, and
`SpvBuilder >> workgroupBarrier`, which answers the instruction so the caller decides which
block it belongs to). `SpvLoopControl` names the loop-control mask that `OpLoopMerge` needs.

One ordering bug surfaced here and is worth recording, because it is invisible until an array
type exists. `OpTypeArray` takes its length as the *id of a constant*, so a module that
declares a shared tile has a type whose operand is a constant — and the serializer used to
emit every type, then every constant, then every global. `SpvSerializer >>
emitTypesConstantsGlobals` now emits types, constants and globals interleaved in ascending
result id order, which is exactly the order in which they were created, so every definition
precedes its use. The SPIR-V 1.5 header also means the entry point's interface list must name
every module-scope variable the entry point touches, Workgroup tiles included.

**Step 2 — the kernel, hand-built, and the measurement. DONE.** `PVTiledMatmulKernel`
assembles the module through `SpvModule`/`SpvBuilder` directly, with no DSL in the path, so
the measurement answers "is tiling worth it on this device" without also depending on a
structurizer that does not exist yet. The shape: tile width 16, local size `#( 16 16 1 )`, two
shared tiles of 256 float32 each (2 KiB of the device's 64 KiB), nine blocks ordered so that a
block precedes every block it dominates, four `OpPhi` prepended once the blocks that feed them
exist, and two `OpControlBarrier` — one after the cooperative copy, one in the inner merge,
the second being the one without which a fast lane overwrites a tile slot a slower lane of the
same workgroup has not read yet. The outer loop steps the tile base by the tile width, so the
kernel needs neither a division nor a modulo. The matrix order comes from the dispatch grid,
the same convention `matmulF32:a:b:out:` uses, and row comes from x and column from y so the
two kernels are directly comparable.

`PVTiledMatmulComparison` times both kernels on one set of buffers, throwing away the first
dispatch of each, and reports the difference between their outputs as well as the times.

**Measured on the Intel Iris Plus (ICL GT2), N = 512, 20 repeats:**

| Kernel | Time | Rate |
|---|---|---|
| Tiled, shared memory (7-G) | 8.05 ms | 33.3 GFLOP/s |
| Naive (7-C baseline) | 35.6 ms | 7.5 GFLOP/s |

**4.42× speedup**, with the largest difference between the two outputs exactly 0.0. Repeated
runs of the tiled kernel landed at 8.05, 8.25, 8.45, 8.6 and 9.3 ms, so the margin over the
1.3× gate is far larger than the noise. The gate is passed, and step 3 is therefore
authorised.

#### Evidence

| Fact | How it is pinned |
|---|---|
| The module really declares two Workgroup arrays and two barriers | `PVComputeTest >> testTiledMatmulModuleDeclaresTwoSharedTilesAndTwoBarriers`, counted by walking the emitted bytes |
| The shared tiles fit the device | `testTiledMatmulSharedTilesFitTheDeviceLimit` |
| `spirv-val` accepts the module | `testTiledMatmulModuleIsValidSpirv` |
| The kernel is correct element by element | `testTiledMatmulMatchesTheReferenceAtOrder64` |
| It agrees with the naive kernel at the benchmark order | `testTiledMatmulAtOrder512MatchesTheNaiveKernelAtSampledPositions` |
| Both kernels are timed on the same data | `testTiledComparisonTimesBothKernelsOnTheSameData` |
| An order the grid cannot cover is refused rather than silently wrong | `testTiledComparisonRejectsAnOrderTheGridCannotCover` |
| The report reads before a run and after its context is destroyed | `testTiledComparisonReportBeforeAnyRun`, `testTiledComparisonExampleReportsEveryRowAfterItsContextIsGone` |
| The byte walk itself is tested, not just used | `PVSpirvValidatorTest >> testCountOfOpcodeCountsEveryInstructionOfThatOpcode`, `testVariableCountInStorageClassSeesTheSharedTiles` |

The instruction walk lives on `PVSpirvValidator` (`instructionWordIndicesDo:`,
`countOfOpcode:`, `variableCountInStorageClass:`) rather than in the tests, so the inspector
view and the tests read the real bytes through one tested walker.

Suite after steps 1 and 2: `PVCompilerTest` 70, `PVComputeTest` 35, `PVSpirvValidatorTest` 24,
`PVGraphicsTest` 13, `SpvBuilderTest` 11, `SpvEmitterTest` 2, `VkBindingsTest` 34,
`VkCoreTest` 27 — **216 tests, all passing, none skipped**, counted by running a real
`TestSuite` over the eight concrete test classes. Critics are clean on
`PVTiledMatmulKernel`, `PVTiledMatmulComparison`, `SpvLoopControl`, `PVSpirvValidator`,
`SpvBuilder` and `PVSpirvValidatorTest`. The two remaining critiques are pre-existing and
untouched by this work: `ReExcessiveMethodsRule` on `SpvOpcode class`, which is an opcode
table, and `ReLongMethodsRule` on `PVComputeTest >> buildVectorAddSpirv`.

**Step 3 — one nesting pattern in the recogniser, and the kernel in Pharo source. DONE.** In
scope because the gate passed. The target is the single shape step 2 built by hand: an outer
loop whose body contains barriers and an inner loop. Everything else the recogniser accepts
stays as it is, so this widens the pattern set by exactly one pattern rather than replacing
the recogniser with a general structurizer.

**Done when** a kernel written in Pharo source, with pragmas only, compiles to a module that
`spirv-val` accepts, matches the CPU reference, and is timed against the hand-built module of
step 2 so that any cost of going through the DSL is visible rather than assumed.

*Shared memory in the DSL.* A workgroup tile is declared with
`<shared: #f32 named: #tile count: 256>` and reaches the kernel body as an ordinary method
argument that the host never binds — the pragma order fixes which arguments are buffers and
which are tiles, so a tile consumes no descriptor and no binding index. `wi localX`, `localY`
and `localZ` read `LocalInvocationId`, and `wi barrier` emits the barrier. The barrier itself
has exactly one definition, `SpvModule >> workgroupBarrierInstruction`, which both the
hand-built kernel and the compiler ask for, pinned by
`SpvBuilderTest >> testModuleAnswersTheSameBarrierTheBuilderDoes`, so the two paths cannot
drift apart in scope or memory semantics.

*The nesting pattern.* `PVNestedLoopNode` holds the seven bytecode blocks of the shape and
`PVStructuredCFGRecognizer >> recognizeNestedLoopAt:preheader:` matches it. The nested pattern
is tried before the single-loop one, because a single-loop match on an outer header takes the
inner preheader for the whole body and is then refused by the coverage check — the single-loop
pattern would have shadowed the nested one otherwise.

The emitter uses **eight** SPIR-V blocks for those seven bytecode blocks: pre, outer header,
inner pre, inner header, inner body, inner merge, outer latch, exit. The extra block exists
because a block may not be both the merge block of one construct and the continue target of
another, and the inner merge is already the inner construct's merge block, so the outer loop's
continue target is emitted as a block of its own that only branches back to the outer header.

The phi bookkeeping is the part that needed care, and the order is load-bearing: reserve the
outer phi results and redirect the register map onto them, then the inner ones, capture the
outer latch ids *after* the inner loop has been emitted so a variable carried by the inner loop
resolves to the inner phi, and re-apply the outer redirect before the exit block, because an
inner phi does not dominate the outer merge. The outer phi set is the variables whose register
differs between the preheader and the inner merge, *union* the inner-phi variables that already
existed in the preheader — the union is what includes the accumulator, and the "already existed"
condition is what keeps the inner loop counter out, which otherwise raised `KeyNotFound` while
reading a register the preheader never defined.

**Measured on the Intel Iris Plus (ICL GT2), N = 512, 10 repeats:**

| Kernel | Time | Rate |
|---|---|---|
| Tiled, hand-built (step 2) | 7.5 ms | 35.8 GFLOP/s |
| Tiled, compiled from Pharo source (step 3) | 7.5 ms | 35.8 GFLOP/s |
| Naive (7-C baseline) | 34.8 ms | 7.7 GFLOP/s |

**Cost of going through the DSL: 1.0**, and the largest difference between the compiled and
hand-built outputs is exactly 0.0 — the compiler gave away nothing, and the two modules agree
element for element rather than merely to a tolerance.

#### Evidence for step 3

| Fact | How it is pinned |
|---|---|
| A tile is a Workgroup variable with no descriptor, and one invocation reads what another wrote | `PVComputeTest >> testSharedMemoryBroadcastWithinWorkgroupOnDevice` |
| The entry point names every Workgroup variable it touches | `PVSpirvValidatorTest >> testEveryWorkgroupVariableIsNamedByTheEntryPoint`, `testSharedBroadcastKernelDeclaresOneWorkgroupVariable` |
| A shared element type the emitter cannot declare is refused | `PVCompilerTest >> testSharedPragmaRefusesAnElementTypeTheEmitterCannotDeclare` |
| The nesting shape is recognised and every block accounted for | `PVCompilerTest >> testCfgShapeNestedLoopsRecognised` |
| The scalar path still refuses nesting | `testCfgShapeNestedLoopsRejected` |
| A nested kernel compiles and `spirv-val` accepts it | `testComputeNestedLoopsCompiles`, `PVSpirvValidatorTest >> testSharedBroadcastKernelValidates` |
| Nested loops give the right answer on the device, not just a valid module | `PVComputeTest >> testNestedLoopsOnDevice` — each of the three ways a block can be dropped gives a different wrong answer |
| The compiled tiled kernel is correct element by element | `testCompiledTiledMatmulMatchesTheReferenceAtOrder64` |
| All three kernels are timed on the same buffers and agree | `testTiledComparisonTimesTheCompiledKernelBesideTheHandBuiltOne` |
| The table shows the compiled kernel rather than hiding it | `testTiledComparisonReportNamesTheCompiledKernel` |
| The Roles view reads the node's slots and moves nothing | `PVCompilerTest >> testNestedLoopNodeRolesReadEverySlotWithoutMovingAnything` |

Suite after step 3: `PVCompilerTest` 73, `PVComputeTest` 41, `PVSpirvValidatorTest` 28,
`PVGraphicsTest` 13, `SpvBuilderTest` 12, `SpvEmitterTest` 2, `VkBindingsTest` 34,
`VkCoreTest` 27 — **230 tests, all passing, none skipped**, counted by running a real
`TestSuite` over the eight concrete test classes. Critics are clean on
`PVTiledMatmulComparison`, `PVNestedLoopNode`, `PVStructuredCFGRecognizer`,
`PVCfgShapeFixture`, `PVSelectorTable`, `PVTypeAnnotation` and `PVSpirvValidator`, and none
of the new emitter methods is flagged — two critiques the new code did raise were answered
rather than accepted: `recognizeNestedLoopAt:preheader:` was split into a
`isTwoWayHeader:` predicate and a `nestedLoopNodeAt:preheader:innerPreheader:innerHeader:`
builder, and `prependPhisFor:…` now reads the header, preheader and latch blocks off the loop
level it is given instead of taking them as three more arguments.

Two critiques on `PVKernelExamples >> tiledMatmulF32:a:b:out:tileA:tileB:` are accepted by
design, the same way `subgroupDotOf:a:b:out:lanes:` already is: the arguments of a kernel are
its parameters, so six of them is what one work item, three buffers and two tiles cost, and
the body is a tiled matmul, which is the length it is. The rest are pre-existing and
untouched: `ReExcessiveMethodsRule` on `SpvOpcode class`, `PVSPIRVEmitter`, `PVComputeTest`
and `PVCompilerTest`, `ReExcessiveVariablesRule` on `SpvModule`, `ReLongMethodsRule` on
`PVComputeTest >> buildVectorAddSpirv` and `PVKernelCompiler >> compile`.

### 7-H — Cooperative matrix on the software device — DONE (10 October 2026)

Only worth opening because 7-F found that lavapipe reports the extension. Correctness
target only. What it needed, in order: device selection by capability rather than by position;
the extension and `VkPhysicalDeviceCooperativeMatrixFeaturesKHR` enabled at device creation;
`vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR` to learn which M, N, K and type
combinations the device offers, since a kernel must use one of them exactly; the
`CooperativeMatrixKHR` capability and `OpTypeCooperativeMatrixKHR` in the emitter; and the
load, store and mul-add instructions behind the three selectors the minimum spec names. The
result is a matmul proven correct against the CPU reference and timed only to show it
runs, never as a speedup. It decides nothing against 7-G (the tiled shared-memory matmul),
which runs on the real hardware and so is where this project's performance claims stay.

**Step 1 — device selection by capability. DONE.** `VkContext class >>
computeContextRequiring:` takes the selectors a device must answer with true and picks the
first device that does, so the one device here that offers the extension is reachable
although it is not the first enumerated. `VkContext class >> cooperativeMatrixContext` asks
for `#supportsCooperativeMatrix` and `#supportsVulkanMemoryModel` together, because a module
that declares the capability needs both features at device creation.

**Step 2 — the extension and the features at device creation. DONE.** Enabling
`VkPhysicalDeviceCooperativeMatrixFeaturesKHR` alone is not enough: spirv-val refuses
`CooperativeMatrixKHR` in a Shader module unless `VulkanMemoryModel` is declared too, and
that capability needs the device feature behind it. So the optional feature chain carries
`VkPhysicalDeviceVulkanMemoryModelFeatures` as well, and both are chained only where the
device answers true for each.

Declaring `VkPhysicalDeviceFeatures2` cost more than it looks: it embeds
`VkPhysicalDeviceFeatures`, and uFFI has no array field, so all 55 boolean members are
spelled out by name. A short declaration would have let the driver write past the
allocation, which is the overrun 7-A already paid for once.

**Step 3 — the reported configurations. DONE.** `vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR`
reports four configurations on lavapipe, all M8 N8 K8 at subgroup scope: f16 into f16, f16
into f32, u8 into u32 and s8 into s32. The kernel uses f16 × f16 + f32 → f32, and
`PVCooperativeMatrixKernel class >> matrixOrder` is the single place the order 8 lives, so
the hand-built module, the compiled module and the comparison cannot disagree about the
shape the device demands.

**Step 4 — the emitter. DONE.** `SpvCooperativeMatrixShape` holds rows, columns, scope and
use; `SpvCooperativeMatrixType` is the SPIR-V type over a component type and a shape.
`OpTypeCooperativeMatrixKHR` takes its four shape operands as *ids of constants*, not as
literals, which is the one thing a reader of the grammar is likely to get wrong, so the type
declares those constants before it registers itself. `SpvBuilder` gained the load, store and
mul-add instructions; the store's operand order is the pointer first and the matrix second,
the other way round from its own selector, which is why it is assembled in one place and
`PVSPIRVEmitter` borrows the builder instead of repeating the order.

**Step 5 — correctness on the device. DONE.** The hand-built module is one block: three
loads, one mul-add, one store, no control flow, because every invocation of the subgroup
has to reach each cooperative matrix instruction. It matches the CPU reference within the
half precision tolerance, and a ramp times the identity reads back as the ramp, which pins
the row-major orientation.

**Step 6 — the three DSL selectors. DONE.** `coopMatLoad:`, `coopMatStore:` and
`coopMatMulAdd:`, which closes the two deferred bullets of the minimum spec.
`PVKernelExamples >> coopMatrixProductOf:by:into:` is the whole kernel in Pharo source, and
`PVCompilerTest >> testNoCooperativeMatrixSelectorIsMappedYet` is deleted, as it asked to
be, by the change that maps the first selector. The device that ran it is lavapipe
(`llvmpipe (LLVM 22.1.8, 256 bits)`).

Two decisions are worth recording. First, the operand role rides on the parameter type
(`#matrixABufferOf_f16`, `#matrixBBufferOf_f16`, `#accumulatorBufferOf_f32`) rather than on
an argument, because a cooperative matrix type is fixed to one role in SPIR-V: a load of the
A factor and a load of the B factor build different types and cannot share one selector
mapping. Second, `coopMatMulAdd:` adds to `OpConstantNull` of the accumulator type, so one
argument is enough and the DSL kernel computes exactly A × B. The hand-built kernel reads
its accumulator from the output binding instead, which lets the host decide what the product
is added to; with the output zeroed the two agree to the last bit, which is what
`PVCooperativeMatrixComparison` checks.

The capability, its extension and the Vulkan memory model are declared from the cooperative
matrix instructions themselves rather than from the module prologue, so a kernel that holds
none of them keeps the GLSL450 memory model and nothing else in the compiler changes
behaviour.

`PVCooperativeMatrix` is the host twin: a kernel body has to mean the same thing in the image
as on the device, and in one Pharo process there is no subgroup, so the honest twin is the
whole 8 by 8 matrix in one object with an ordinary triple loop for the product. The two
extension methods on `SequenceableCollection` are what make the kernel source readable Pharo
rather than markers for the compiler.

**Measurement.** One dispatch each on lavapipe: 2 ms hand-built, 3 ms compiled, both 6.7e-4
from the float reference and identical to each other. The numbers are here only to show the
kernel runs. The device is a CPU implementation, so no ratio from it means anything, and
4.6× from 7-G on the real hardware remains this project's only speedup claim.

### 7-I — Half precision on the tiled kernel — DONE (12 October 2026)

7-D measured f16 against f32 on the *naive* matmul, got 1.0 to 1.1, and said plainly what the
honest comparison would be: a tiled kernel holding a block in shared memory. 7-G wrote that
kernel in float. This step writes its half precision twin and measures the pair, on both
families, in the same runs.

What it needed, in order:

*The kernel.* `PVKernelExamples >> tiledMatmulF16:a:b:out:tileA:tileB:`, the twin of
`tiledMatmulF32:a:b:out:tileA:tileB:` with `<param: #bufferOf_f16 …>` buffers and
`<shared: #f16 named: … count: 256>` tiles. The dot product still accumulates in float, for
the same reason the naive half matmul does: the error of an N-term sum grows with N, so
accumulating in half would cost far more accuracy than the storage format itself does. A tile
pair is 1 KiB rather than 2 KiB, and each tile load moves half the bytes.

*One defect found on the way.* `PVSelectorTable >> initializeSharedMappings` wrote the `at:`
and `at:put:` mappings for `#sharedOf_f32` and `#sharedOf_i32` out by hand, although
`PVSPIRVEmitter class >> sharedElementTypes` — whose own comment claims to be the one source
for the type the emitter declares, the selector mappings for `at:` and `at:put:`, and the
compute parameter types — already listed `#sharedOf_f16`. The compiler could therefore declare
a tile type no kernel body was able to index, and the first attempt at the kernel failed with
`PVTypeError: 'No SPIR-V mapping for at:put: on sharedOf_f16'`. The mappings are now derived
from `sharedElementTypes`, so the claim in that comment is true, and
`PVCompilerTest >> testSharedMappingsCoverEveryTileTypeTheEmitterCanDeclare` states the rule
over those types rather than naming them.

*Kernel families.* A comparison has to say what it compares.
`PVKernelExamples class >> tiledMatmulKernels` and `tiledMatmulFor:` mirror `matmulKernels`
and `matmulFor:`; `matmulFamilies`, `matmulFor:family:`, `defaultMatmulFamily` (`#naive`) and
`tiledMatmulFamily` (`#tiled`) name the two families in one place.

*Benchmark.* `PVBenchmark` is given the kernel rather than a precision:
`on:order:repeats:kernel:` is the front door, and the element type of the buffers it fills
(`elementTypeOfKernel:`) and the workgroup width the grid is built from
(`workgroupWidthForKernel:`) are both read off that kernel's own pragmas. The benchmark can no
longer fill buffers of one width and dispatch a module of another, and a kernel whose buffers
mix widths — the cooperative matrix kernel, half inputs with a float accumulator — is refused
at creation rather than measured at one of them. `on:order:repeats:elementType:` and
`on:order:repeats:` still answer the naive kernels. The report gained a `Kernel` row, read off
the method that ran.

*Comparison.* `PVPrecisionComparison on:order:repeats:family:` fixes one family for the whole
comparison, because a ratio between two precisions measured on two different kernels says
nothing about either, and each row of the Precision tab now names the kernel it was measured
on.

**Measured on the Intel Iris Plus (ICL GT2), both precisions in the same
`PVPrecisionComparison` run, after warm-up — 5 repeats at N = 256 and 1024, 10 at N = 512,
two to three trials each:**

| N | Family | f32 ms | f16 ms | f16 speedup |
|---|---|---|---|---|
| 256 | tiled | 2.2 – 2.4 | 1.6 | 1.38 – 1.50 |
| 512 | tiled | 7.7 – 8.7 | 5.6 – 5.9 | 1.32 – 1.55 |
| 1024 | tiled | 58.0 – 58.2 | 38.8 | 1.49 – 1.50 |
| 256 | naive | 5.0 – 5.6 | 5.4 – 6.8 | 0.82 – 0.93 |
| 512 | naive | 34.8 – 37.9 | 34.8 – 35.3 | 0.99 – 1.07 |
| 1024 | naive | 274.0 – 274.2 | 274.2 – 280.0 | 0.98 – 1.00 |

As rates, taking the middle of each range: tiled f16 reaches 46.3 GFLOP/s at N = 512 and 55.3
at N = 1024, against 34.4 and 37.0 for tiled f32.

**Half precision earns 1.3 to 1.5 on the tiled kernel and nothing at all on the naive one.**
That is the answer 7-D could not give, and the reason is the same one 7-D gave for its own
number: the naive kernel re-reads each row and column N times, so it is limited by that
redundant global traffic and by latency rather than by the width of an element, and narrowing
the element changes neither. The tiled kernel reads each tile sixteen times out of shared
memory, so halving the tile halves both the shared memory it occupies and the global loads
that fill it, while the float accumulator leaves the arithmetic exactly as it was.

Against the 7-C naive f32 baseline, tiled f16 is 6.0× at N = 512 and 7.1× at N = 1024. That
is not the same computation — the inputs and the result are halves — so the project's
like-for-like speedup claim remains 7-G's 4.6×.

#### Evidence

| Fact | How it is pinned |
|---|---|
| Every tile type the emitter can declare can be indexed | `PVCompilerTest >> testSharedMappingsCoverEveryTileTypeTheEmitterCanDeclare`, stated over `sharedElementTypes` rather than over three type names |
| The half tiled module has the shape of a tiled kernel | `testTiledHalfMatmulHoldsHalfTilesAndAccumulatesInFloat`: two Workgroup variables, two `OpControlBarrier`, float widths exactly `#( 16 32 )`, and `OpFConvert` present |
| The half tiled module is valid SPIR-V | `testTiledHalfMatmulModuleIsValidSpirv` — half precision in the Workgroup storage class is not the same thing as half precision in a storage buffer, and `spirv-val` is what checks the module declares what the tiles need |
| The half tiled kernel is right on the device | `PVComputeTest >> testCompiledTiledMatmulF16MatchesTheReferenceAtOrder64`: every one of 4096 elements, through `assertHalf:matchesReference:`, at an order that walks the tile loop four times |
| A benchmark takes its precision and width from the kernel it was given | `testBenchmarkTakesPrecisionAndWidthFromTheKernelItWasGiven`, stated over every family and precision `matmulFamilies` holds |
| A kernel a benchmark cannot fill buffers for is refused | `testBenchmarkRefusesAKernelItCannotFillBuffersFor`, with the cooperative matrix kernel as the mixed-width case and an unknown family beside it |
| A table of rates says which kernel produced each | `testBenchmarkReportNamesTheKernelItDispatched`, `testPrecisionComparisonReportNamesTheKernelBesideEachPrecision` |
| Both precisions of one family are measured in one run | `testPrecisionComparisonOnTheTiledFamilyMeasuresTiledKernels` |

Suite after 7-I: **318 tests, all passing, none skipped**, counted by running a real
`TestSuite` over the nine concrete test classes.

Examples and views: `PVPrecisionComparison class >>
exampleTiledPrecisionComparisonOnOrder512Matmul` — one click for the measurement above, at the
order and repeat count 7-G measured the float kernel at — read through `inspectorPrecision:`,
which gained a `Kernel` column taken from the benchmark that produced each row; and
`PVBenchmark class >> exampleTiledHalfBenchmarkOnOrder256Matmul` with the existing
`inspectorBenchmark:`, whose first two rows now name the precision and the kernel under the
rate.

Critics are clean on `PVBenchmark`, `PVPrecisionComparison` and `PVSelectorTable`.
`PVPrecisionComparison` had no class comment and now has one; `PVBenchmark`'s was rewritten,
because its old one described the element type as what everything followed from.
`ReExcessiveArgumentsRule` and `ReLongMethodsRule` on the new
`tiledMatmulF16:a:b:out:tileA:tileB:` are accepted exactly as they already are on its float
twin: the arguments of a kernel are its parameters, so six of them is what one work item,
three buffers and two tiles cost, and the body is a tiled matmul. The rest are pre-existing and
untouched: `ReExcessiveMethodsRule` on `PVComputeTest` and `PVCompilerTest`, and
`ReLongMethodsRule` on `PVComputeTest >> buildVectorAddSpirv`.

## 4. The structurizer question

Deferred item 5 of `CFG-PLAN.md` asks whether Phase 7 needs general nested control flow,
which would reverse the frozen "pattern recognizer (not general)" decision.

Answer for 7-A to 7-E: **no**. A naive matmul is one loop. A dot product is one loop or a
subgroup op. The single-construct recogniser is sufficient, and 7-B widens it to the
compute path without widening what it accepts.

It becomes unavoidable only for a *tiled* matmul with shared memory, which is the
structure that actually goes fast: an outer loop over tiles, containing cooperative loads,
two barriers and an inner accumulation loop. That is nested by nature and also needs the
`Workgroup` storage class and `OpControlBarrier`, neither of which the emitter has today.

Proposal: keep it out of Phase 7's committed scope as an optional 7-G, and reopen the
frozen decision only when 7-C has produced a baseline that shows tiling is worth it on a
48 KiB, 32-lane, no-matrix-unit iGPU. Doing it in the other order would be writing a
structurizer on speculation.

**Answered by 7-G.** The baseline was produced, the tiled kernel was built by hand to keep
the measurement free of the structurizer question, and it runs 4.42× faster than the naive
kernel at N = 512. So the condition the proposal set is met, and the frozen decision is
reopened for exactly one shape: an outer loop whose body contains an inner loop. It is still
a pattern recogniser, with one more pattern — not a general structurizer. See §7-G.

## 5. Risks

- **Structure offsets in 7-A.** ~~A wrong offset gives a plausible-looking number, as the
  first probe attempt did (402653192 for shared memory). Mitigated by asserting known
  device values.~~ Closed: no offset into the limits block is hand counted any more, because
  `VkPhysicalDeviceLimits` is declared field by field and uFFI computes the offsets. The
  known device values are still asserted. The risk class remains open for any *new*
  structure declared as a byte blob — see the overrun that declaring one caused.
- **7-B touches the one path every compute test uses.** All 19 `PVKernelExamples` and both
  GPU tests go through `compileComputeKernel:`. Land step 3 (the honest error) separately
  from step 4 (the new emitters) so a regression is attributable.
- **Image crashes during GPU work.** Known hazard; `VkCoreTest` has died twice after a
  graphics example ran in the same session. Restart the image before trusting any
  benchmark number, and never interleave benchmarks with the triangle examples.
- **Benchmark noise on an iGPU.** Shared memory bandwidth with the CPU, no fixed clocks.
  Report a median of repeats and the spread, not a single number.
