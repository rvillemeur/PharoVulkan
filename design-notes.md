# PharoVulkan — Design Notes (brainstorm session, 2026-05-21)

## Project goal

Use Vulkan from Pharo without any Pharo-side third-party packages.
Create a DSL in Pharo that compiles to SPIR-V and serves as a unified
API for both Vulkan graphics and vector compute (AI/ML workloads).
This is a personal learning project — full native stack, no shortcuts.

---

## Architecture validity check

- **SDL2 + Vulkan**: SDL2 supports Vulkan since 2.0.6 via `SDL_Vulkan_*`
  functions. Pharo's existing SDL2 bindings do NOT expose these — they
  need to be added via uFFI. Estimated effort: days.
- **No third-party** means no Pharo packages. The system Vulkan loader
  (`libvulkan.so.1`) is required — it is a system library, not a package.
- **SPIR-V** is the only shader format Vulkan accepts: binary,
  little-endian, 32-bit word stream. The kernel/shader distinction is
  *pipeline type*, not file format. A compute kernel uses execution
  model `GLCompute`; graphics uses `Vertex`/`Fragment`/etc. Same emitter,
  different `OpEntryPoint` decoration.

---

## DSL scope (first iteration)

- **Monomorphic function calls and function chains only.**
  No dynamic dispatch, no polymorphism in the DSL.
  All call sites statically resolvable at compile time.
- Maps naturally to Pharo's context chain model: a kernel is a tree of
  method activations, all statically known.
- This eliminates the hardest compiler problem (devirtualization) and
  makes the compiler tractable.
- OOP can be added later once the foundation is proven.

---

## Unified API target

- **Resource layer** (instance, device, queue, buffer, image, descriptor
  sets, command buffers, sync): shared between graphics and compute.
- **Pipeline layer**: split by type.
  - Compute: storage buffers, push constants, workgroup-shared memory,
    cooperative matrix (`VK_KHR_cooperative_matrix`), subgroup ops,
    float16 (`VK_KHR_shader_float16_int8`).
  - Graphics: render passes, framebuffers, vertex input, rasterizer,
    blend state, swapchain, samplers.
- Build on `VK_KHR_synchronization2` from day one — not the original
  sync model.

---

## Bytecode → SPIR-V lowering pipeline (9 stages)

```
Pharo source (typed via pragmas)
    │
    ▼  ① compile via Pharo (already done by the system)
Sista bytecode + literal frame
    │
    ▼  ② decode → typed bytecode IR (per-op stack effect known)
Stack-VM ops in a flat list
    │
    ▼  ③ symbolic stack simulation → register IR
Register-based ops, virtual regs, no stack
    │
    ▼  ④ identify basic blocks by jump targets → CFG
Basic blocks with register ops + branch terminators
    │
    ▼  ⑤ SSA construction (Braun et al., on-the-fly variant)
SSA form with phi nodes
    │
    ▼  ⑥ type inference / selector resolution
Typed SSA; every send resolved to an op or a function call
    │
    ▼  ⑦ structured-CFG reconstruction (pattern recognizer)
SPIR-V-legal CFG with merge annotations
    │
    ▼  ⑧ emit SPIR-V (types, decorations, functions, instructions)
SPIR-V binary
    │
    ▼  ⑨ spirv-val
Validated module
```

### Stage notes

**②** Decode Sista bytecodes; each has known stack effect. Keep PC on each node.

**③** Walk IR, maintain compile-time stack of virtual register ids.
Stack depth is statically determined at every PC — this is a key property
of Sista bytecode.

**⑤** Use Braun et al., "Simple and Efficient Construction of SSA Form".
~200 lines, handles incomplete CFGs, no separate dominance pass needed.
Do NOT use the classic Cytron algorithm.

**⑥ Selector → SPIR-V op table (key mappings):**

| Pattern                        | SPIR-V                          |
|--------------------------------|---------------------------------|
| `Float32 + Float32`            | `OpFAdd`                        |
| `Float32 < Float32`            | `OpFOrdLessThan`                |
| `Int32 // Int32`               | `OpSDiv`                        |
| `Vec3f dot: Vec3f`             | `OpDot`                         |
| `Float32 sqrt`                 | `OpExtInst GLSL.std.450 Sqrt`   |
| `WorkItem globalId`            | `OpLoad` of `GlobalInvocationId`|
| `Buffer at:` / `at:put:`       | `OpAccessChain` + `OpLoad/Store`|
| user method on type T          | `OpFunctionCall` (compile recursively)|

Monomorphization key: `(selector × receiver-type × arg-types)`.
Cache compiled functions by this key.

**⑦ Structured CFG — pattern recognizer, not general structurizer.**
The Pharo compiler is the only producer of our input bytecode, so the
shapes are fixed and known. Recognize six patterns:

- `ifTrue:ifFalse:` → `OpSelectionMerge` + `OpBranchConditional`
- `whileTrue:` → `OpLoopMerge` + loop header
- `to:do:` → `OpLoopMerge` + init + compare + increment
- `timesRepeat:` → same as `to:do:` without accumulator
- Straight-line → just `OpBranch`
- Early return within straight-line block

Emit a clear error for unrecognized shapes rather than attempting recovery.

**⑧** Two passes: (1) collect all types/constants/decorations for the
preamble (SPIR-V requires forward decls and deduplication), then
(2) emit functions. Drive instruction encoding from `spirv.core.grammar.json`.

**⑨** Treat any `spirv-val` failure as a compiler bug, not user error.
Validate every output during development.

---

## Key schemas (machine-readable, drive code generation)

- `vk.xml` — Vulkan API registry (Khronos). Drive uFFI binding generator.
- `spirv.core.grammar.json` — SPIR-V instruction metadata. Drive both
  the SPIR-V emitter and the instruction builder API.

One generator tool consuming both schemas saves months of hand-writing.

---

## Roadmap

### Phase 1 — Bindings (2–3 months)
- uFFI generator from `vk.xml` → Vulkan bindings
- SPIR-V instruction builder API from `spirv.core.grammar.json`
- SDL2 `SDL_Vulkan_*` entry points via uFFI

Testable: Pharo can call `vkCreateInstance` and enumerate physical devices.

### Phase 2 — Bring-up (1 month)
- Instance, device, compute queue lifecycle
- Buffer allocation and mapping
- Dispatch a pre-compiled SPIR-V blob (built externally with glslc)
- Read result back and verify in Pharo

Testable: vector-add kernel runs from a hardcoded SPIR-V byte array.

### Phase 3 — SPIR-V emitter (1–2 months)
- Hand-build a compute SPIR-V module from Pharo via the builder API
- Reproduce the vector-add from Phase 2, constructed from IR nodes
- Validate every output with `spirv-val`

Testable: programmatically constructed SPIR-V equals the glslc reference.

### Phase 4 — Bytecode → SPIR-V, straight-line (2–3 months)
- Stages ②–⑥ for straight-line Pharo methods (no branches)
- Type pragma system
- SSA construction (Braun et al.)
- Selector resolution table for arithmetic
- End-to-end: `add: a to: b` Pharo method → runs on GPU

Testable: unit tests for each compiler stage; integration test against GPU.

### Phase 5 — Control flow (2 months)
- Stage ⑦: pattern recognizer for `to:do:` and `whileTrue:`
- Compile a dot product and matrix multiply from Pharo source
- Add `ifTrue:ifFalse:` for element-wise conditionals (clamp, relu)

Testable: tiled matmul output matches CPU reference within float tolerance.

### Phase 6 — Graphics path (2–3 months)
- Render pass, swapchain, SDL2 surface integration
- Vertex + fragment shader compilation from DSL
- Hello triangle from DSL-compiled shaders

Testable: window appears, triangle renders, no validation layer errors.

### Phase 7 — Cooperative matrix + perf (open-ended)
- `VK_KHR_cooperative_matrix` for AI matmul
- Float16, subgroup reductions
- Benchmarks against CPU baseline

---

## Key early design decisions (decide before writing compiler)

1. **Type annotation surface**: pragmas (`<gpu>`, `<param: #f32 named: #x>`)
   are the leading candidate. Decide format before writing type inference.

2. **Memory model exposure**: push constants + storage buffers + workgroup-
   shared from day one. These matter for perf.

3. **Parallelism surface**: how does a kernel receive `globalId`?
   Candidates: pseudo-global, method parameter, `WorkItem` context object.

4. **Sync model**: use `VK_KHR_synchronization2` exclusively. Do not implement
   the original Vulkan 1.0 sync primitives.

---

## Implementation bottom-up order

1. SPIR-V binary writer + builder (from `spirv.core.grammar.json`)
   — write vector-add by hand, validate, run.
2. Stage ⑧ fed by hand-built typed SSA IR.
3. Stages ②–④ on a simple method (straight-line only).
4. Add SSA ⑤ — vector-add end-to-end from Pharo source.
5. Type inference ⑥ on a multi-method chain.
6. Pattern recognizer ⑦ for `to:do:` — compile dot product.
7. `ifTrue:ifFalse:` — compile clamp/relu.
8. Tiled matmul — validates workgroup-shared memory and the full stack.

---

## Coding conventions

- Idiomatic Pharo Smalltalk throughout.
- CR-only line endings — LF is forbidden by Pharo.
- Every class has a class comment describing purpose and key methods.
- All code covered by unit tests (SUnit) or Example classes.
- Phased structure: each phase must be independently testable before
  the next begins.
- No comments explaining WHAT the code does — only WHY for non-obvious
  invariants or constraints.
