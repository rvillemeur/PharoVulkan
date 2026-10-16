# PharoVulkan

Vulkan uFFI bindings and SPIR-V DSL for Pharo 13. No third-party Pharo
packages — only the system Vulkan loader and SDL2.

Two goals:
1. **Full Vulkan API** exposed via uFFI with named constants (no magic numbers)
2. **Pharo→SPIR-V compiler** — annotate a Pharo method with `<gpu>` and
   `<param:named:>` pragmas and it compiles to SPIR-V: a compute shader when
   the parameters include storage buffers, a plain function otherwise

---

## Requirements

| Dependency | Minimum version | Notes |
|---|---|---|
| Pharo | 13.1.0 | Tested on 13.1.0 SNAPSHOT |
| libvulkan.so.1 | Vulkan 1.3 | Or 1.2 + VK_KHR_synchronization2 |
| libSDL2.so | 2.0.6+ | Graphics path only |
| GPU | Any with Vulkan 1.3 compute | Developed against an Intel Iris Plus (ICL GT2) and Mesa lavapipe on Linux |
| SPIRV-Tools | v2026.1 | Optional. `PVSpirvValidator` finds `spirv-val` on `PATH`; without it the validation tests report the tool as missing rather than failing |

Linux only at this stage (uFFI library paths are Linux-specific).

---

## Loading

There is no published repository yet, so load from a clone on disk:

```smalltalk
Metacello new
	baseline: 'PharoVulkan';
	repository: 'tonel:///path/to/PharoVulkan/src';
	load.

"or one group only:"
Metacello new
	baseline: 'PharoVulkan';
	repository: 'tonel:///path/to/PharoVulkan/src';
	load: 'compiler'.
```

`load` with no argument loads the `default` group: bindings, core, compute and graphics — enough
to open a device, dispatch a kernel and draw. Named groups load less, or more:

| Group | Loads | Needs a driver |
|---|---|---|
| `bindings` | `PharoVulkan-Bindings` | yes, to call anything |
| `spirv` | `PharoVulkan-SPIRV` | no |
| `compiler` | SPIR-V builder and the Pharo→SPIR-V compiler | no — it answers bytes |
| `core` | the Vulkan lifecycle, on the bindings | yes |
| `compute` | the compute path | yes |
| `graphics` | the graphics path, including SDL2 | yes, and a display server |
| `default` | bindings, core, compute, graphics | yes |
| `examples` | the `<Subject>Examples` classes | depends on the example |
| `generator` | the `vk.xml` and grammar readers | no |
| `tests` | everything, including all seven test packages | yes for most of the suite |

The `compiler` group is the one that loads on a machine with no `libvulkan.so.1`: nothing in it
reaches the bindings, which is a rule `PVArchitectureTest` enforces rather than a claim.

---

## Package layout

Fifteen packages: eight of code and seven of tests. Inside each, class tags group the classes for
the browser and carry no meaning beyond that.

| Package | Classes | What it contains |
|---|---|---|
| `PharoVulkan-Bindings` | 144 | uFFI Vulkan commands, structures, handle wrappers, every named constant class, `VkResult` and `VkError` |
| `PharoVulkan-SPIRV` | 51 | SPIR-V IR builder: `SpvModule`, `SpvBuilder`, `SpvFunction`, `SpvBlock`, the type hierarchy, constant pool, serialiser, validator |
| `PharoVulkan-Compiler` | 31 | Pharo bytecode → SPIR-V: decode, CFG, recogniser, SSA, type inference, emit, the DSL selector table, and the `spirv-val` wrapper |
| `PharoVulkan-Core` | 17 | `VkContext`, `VkDevice`, `VkPhysicalDevice`, `VkQueue`, `VkBuffer`, command pool and buffer, `VkShaderModule`, `VkPipelineLayout`, the device capability survey |
| `PharoVulkan-Compute` | 15 | Descriptor set layout, descriptor pool and set, compute pipeline, `PVComputeKernel`, the cooperative matrix path, the benchmarks |
| `PharoVulkan-Graphics` | 17 | `VkSurface`, `VkSwapchain`, `VkRenderPass`, `VkFramebuffer`, `VkGraphicsPipeline`, offscreen targets, the sync wrappers, the scenes, and the SDL2 integration |
| `PharoVulkan-Generator` | 13 | Reads `vk.xml` and `spirv.core.grammar.json` and emits binding classes |
| `PharoVulkan-Examples` | 18 | One `<Subject>Examples` class per subject, holding every `<sampleInstance>` example |

| Test package | Test classes (tests) |
|---|---|
| `PharoVulkan-Bindings-Tests` | `VkBindingsTest` (286) |
| `PharoVulkan-SPIRV-Tests` | `SpvBuilderTest` (16), `SpvEmitterTest` (2) |
| `PharoVulkan-Compiler-Tests` | `PVCompilerTest` (80), `PVSpirvValidatorTest` (30) |
| `PharoVulkan-Core-Tests` | `VkCoreTest` (68) |
| `PharoVulkan-Compute-Tests` | `PVComputeTest` (59) |
| `PharoVulkan-Graphics-Tests` | `PVGraphicsTest` (52), `VkImageTest` (8) |
| `PharoVulkan-Tests` | `PVArchitectureTest` (20) |

621 tests in all. Each test package also carries a `Fixtures` tag for the stubs its tests build, so
the `Tests` tag holds test classes and nothing else.

Which package may depend on which is stated as a test, not as a paragraph:
`PVArchitectureTest class >> allowedDependencies` declares the allowed outgoing edges of all
fifteen packages, and its twenty tests fail both on an edge the code makes and the table does not
grant, and on an edge the table grants that the baseline does not declare.

See `doc/architecture.md` for the full layer diagram and class descriptions.

---

## Running the compute example

The test suite includes a GPU vector-add: 64 floats `a[i] + b[i]` dispatched
with 64 threads, verified against a CPU reference.

```smalltalk
"In a Pharo Playground:"
PVComputeTest new testVectorAdd
```

Or run the full compute test suite:

```smalltalk
TestRunner runClass: PVComputeTest
```

### What the test does

1. Builds a SPIR-V compute shader directly with `SpvBuilder` (accesses
   `gl_GlobalInvocationID` and three storage buffers)
2. Creates a headless `VkContext` (no window)
3. Allocates three 256-byte buffers (64 × f32)
4. Fills buffer A with `[0.0, 1.0, … 63.0]`, buffer B with the same
5. Runs `PVComputeKernel dispatch: 1 y: 1 z: 1` (64 threads via LocalSize)
6. Reads buffer C back and asserts `c[i] == i * 2.0`

### Minimal headless compute in a Playground

This runs `PVKernelExamples >> #vectorAdd:a:b:out:` — a four-parameter compute
kernel, one `WorkItem` plus three storage buffers — through the Pharo→SPIR-V
compiler. It is the same sequence as `PVComputeTest >> #testVectorAddFromCompiledMethod`,
so it is covered by the suite.

```smalltalk
| n ctx bufA bufB bufC kernel result |
n := 64.

"1. Create context (no window needed)"
ctx := VkContext computeContext.

"2. Allocate three storage buffers of n floats each.
    storageBuffer:on: takes an element count and applies the usage flag for you."
bufA := VkBuffer storageBuffer: n on: ctx device.
bufB := VkBuffer storageBuffer: n on: ctx device.
bufC := VkBuffer storageBuffer: n on: ctx device.

"3. Fill the inputs; putF32s: does the IEEE-754 packing"
bufA putF32s: ((0 to: n - 1) asArray collect: [:i | i asFloat]).
bufB putF32s: ((0 to: n - 1) asArray collect: [:i | i asFloat]).
bufC putF32s: (Array new: n withAll: 0.0).

"4. Compile the kernel and build the pipeline.
    Buffers bind in parameter order: a, b, output."
kernel := PVComputeKernel fromMethod: (PVKernelExamples >> #vectorAdd:a:b:out:) on: ctx.
kernel bindBuffer: bufA; bindBuffer: bufB; bindBuffer: bufC.
kernel prepare.

"5. One workgroup, 64 invocations"
kernel dispatch: 1 y: 1 z: 1.

"6. Read back: [0.0, 2.0, 4.0, … 126.0]"
result := bufC getF32s.

"7. Clean up in reverse creation order"
kernel destroy.
bufA destroy. bufB destroy. bufC destroy.
ctx destroy.
```

### `<gpu>` alone does not produce a shader module

A `<gpu>` method whose parameters are all scalars — `PVKernelExamples >> #relu:`,
for example — compiles to a SPIR-V *function*: no `OpEntryPoint`, no execution
mode, no descriptor bindings. `PVComputeKernel` cannot load it, and `spirv-val`
rejects it on its own with `No OpEntryPoint instruction was found`. An entry
point is emitted only for

- a compute kernel: at least one storage buffer parameter, usually with a
  `#workItem` parameter beside it, as in `vectorAdd:a:b:out:` above, or
- a `<gpuVertex>` or `<gpuFragment>` shader.

`PVKernelCompiler class >> computeParamTypes` is the list that decides, and it
derives from the emitter's own tables rather than being written out by hand:
`#workItem`, the buffer types `#bufferOf_f32`, `#bufferOf_i32`, `#bufferOf_f16`,
`#matrixABufferOf_f16`, `#matrixBBufferOf_f16`, `#accumulatorBufferOf_f32`, and
the shared-memory types `#sharedOf_f32`, `#sharedOf_i32`, `#sharedOf_f16`.

Scalar `<gpu>` methods are lowering targets for those, not standalone shaders.
Giving them an entry point would mean inventing a descriptor-binding convention
for scalar parameters, which the `WorkItem`-plus-storage-buffer kernel ABI
deliberately does not have. Of the 32 methods in `PVKernelExamples`, 21 get an
entry point and 11 are scalar functions with no entry point for the validator to
start from. `PVSpirvValidatorTest` runs spirv-val over 10 of the 21, plus
`relu:` as the negative case that must be rejected with
`No OpEntryPoint instruction was found`.

For a full walkthrough see `doc/compute-tutorial.md`.

---

## Compute features beyond vector add

Everything in this section is covered by `PVComputeTest` on the device, not only
by compiler tests.

### Control flow

A compute kernel may contain one `ifTrue:ifFalse:`, one `whileTrue:`, or an
outer `whileTrue:` whose body is an inner `whileTrue:` and nothing else. See
"Known limitations" below for what is refused.

### Work item

`#workItem` parameters answer `x`, `y`, `z` for the global invocation id,
`localX`, `localY`, `localZ` for the position inside the workgroup, `gridWidth`
for the dispatch width in invocations, and `barrier` for a workgroup barrier.
`PVWorkItem` is the host-side class, so a kernel body also runs in the image.

### Workgroup size

`<localSize: #( 16 16 1 )>` on the kernel. The default is `#( 64 1 1 )`. The
grid must cover the problem exactly: a benchmark whose order is not a multiple
of the local size raises `PVTypeError`.

### Half precision

`#f16` and `#bufferOf_f16`, with `asF16` and `asF32` for conversion, and on the
host `VkBuffer storageBufferOfHalves:on:`, `storageBuffer:of:on:`, `put:as:` and
`elementsAs:`. `PVFloat16` does the IEEE-754 binary16 encode and decode.
`VkContext` enables `VK_KHR_shader_float16_int8` and `VK_KHR_16bit_storage`
where the device reports them.

### Subgroup reduction

`subgroupSum` on an `#f32` value, which lowers to
`OpGroupNonUniformFAdd … Reduce`. `PVSubgroupDotProduct` reduces a 1024 element
dot product in hardware and agrees with the host exactly.

The subgroup size a device reports is the **widest** subgroup it offers, not the
width a shader runs at — this driver reports 32 and ran the kernel 16 wide. The
kernel therefore measures its own width with a second reduction instead of
dividing by the reported number.

### Shared memory

`<shared: #f32 named: #tileA count: 256>` declares a Workgroup array. It is a
kernel parameter the host never binds; the pragma order says which arguments are
buffers and which are tiles. `PVTiledMatmulKernel` and
`PVKernelExamples >> tiledMatmulF32:a:b:out:tileA:tileB:` are the hand-built and
the compiled form of the same tiled matmul, and
`tiledMatmulF16:a:b:out:tileA:tileB:` is the half precision twin, with
`<shared: #f16 …>` tiles and the dot product still accumulated in float.

### Cooperative matrix

`coopMatLoad:`, `coopMatMulAdd:` and `coopMatStore:`, with the operand role
carried by the parameter type (`#matrixABufferOf_f16`, `#matrixBBufferOf_f16`,
`#accumulatorBufferOf_f32`), because one cooperative matrix type is fixed to one
role in SPIR-V. `VkContext cooperativeMatrixContext` selects a device by
capability rather than by position, and
`PVCooperativeMatrixSurvey` reports which devices offer the extension.

On this machine only Mesa lavapipe does, so this path is correctness only; see
the performance table.

### Benchmarks

`PVBenchmark on: ctx order: n repeats: k kernel: aCompiledMethod` times that
kernel and derives 2·N³/t GFLOP/s. The element width and the workgroup width are
read out of the kernel's own `<param:>` and `<localSize:>` pragmas, so the
buffers filled and the module dispatched cannot disagree; a kernel declaring
buffers of more than one width is refused. `on:order:repeats:elementType:` and
`on:order:repeats:` are the shorthands that pick a kernel out of
`PVKernelExamples matmulFor:`.

`PVPrecisionComparison on: ctx order: n repeats: k family: aFamily` times every
element type at one order within one kernel family — `PVKernelExamples
defaultMatmulFamily` for the naive kernels, `tiledMatmulFamily` for the tiled
ones. `PVTiledMatmulComparison` times naive, hand-built tiled and compiled tiled
on one set of buffers, and `PVCooperativeMatrixComparison` compares the
hand-built and compiled cooperative matrix kernels against a CPU reference.

Measured on the Intel Iris Plus, f32 matmul, host wall clock around a dispatch
that waits on the queue:

| Kernel | N | Time | Rate |
|---|---|---|---|
| Naive | 128 | 2.7 ms | 1.6 GFLOP/s |
| Naive | 256 | 6.0 ms | 5.6 GFLOP/s |
| Naive | 512 | 34.8 ms | 7.7 GFLOP/s |
| Tiled, hand-built | 512 | 7.5 ms | 35.8 GFLOP/s |
| Tiled, compiled from Pharo | 512 | 7.5 ms | 35.8 GFLOP/s |

Tiling is **4.6× faster** than the naive kernel, and going through the DSL costs
1.0 — the two tiled modules produce bit-identical output.

What half precision earns depends on the kernel, and the two kernels disagree.

On the naive kernel it earns nothing: 1.0 to 1.1, not the 1.5 to 2 that was
expected. N=256 6.8→6.2 ms, N=512 40.9→38.8 ms, N=1024 311.4→311.4 ms. The dot
product accumulates in f32, so only the loads and the store are narrower, and
the naive kernel re-reads each row and column N times, so traffic and latency
dominate the element width.

On the tiled kernel it earns 1.3 to 1.5, which is the comparison worth making,
because a tile held in shared memory is half the bytes in half precision and the
f32 kernel's own 4.6× says that this kernel is the one the memory system limits:

| Kernel | N | f32 | f16 | Ratio |
|---|---|---|---|---|
| Tiled | 256 | 2.2–2.4 ms | 1.6 ms | 1.38–1.50 |
| Tiled | 512 | 7.7–8.7 ms | 5.6–5.9 ms | 1.32–1.55 |
| Tiled | 1024 | 58.0–58.2 ms | 38.8 ms | 1.49–1.50 |

In rates, tiled f16 reaches 46.3 GFLOP/s at N=512 and 55.3 at N=1024, against
34.4 and 37.0 for tiled f32. Against the naive f32 baseline tiled f16 is 6.0× at
N=512 and 7.1× at N=1024, but that is not the same computation — the inputs and
the result are halves — so the project's like-for-like speedup claim stays the
4.6× above.

So quote a half-precision win for the tiled kernel only, and quote none for the
naive one.

The cooperative matrix kernel is 2 ms hand-built and 3 ms compiled for one 8×8
dispatch, both 6.7e-4 from the float reference and identical to each other.
Those numbers show only that it runs: the one device here offering the extension
is a CPU implementation, so no ratio measured on it says anything about a matrix
unit.

---

## Running the graphics example

Renders a RGB triangle in an SDL2 window for 300 frames then exits.

```smalltalk
"In a Pharo Playground — install driver first:"
PVVulkanDriver install.

"Open window"
| attrs win backendWin ctx scene |
attrs := PVWindowAttributes newVulkan.
attrs title: 'Hello Triangle'; extent: 800@600; windowCentered: true.
win := OSWindow createWithAttributes: attrs.
backendWin := win backendWindow.

"Create context + scene"
ctx   := VkContext graphicsContextForExtensions: backendWin requiredInstanceExtensions.
scene := PVHelloTriangleScene prepare: ctx backendWindow: backendWin.

"Render loop"
1 to: 300 do: [:i | scene renderFrame].

"Tear down"
ctx computeQueue waitIdle.
scene destroy.
ctx destroy.
win destroy.

"Restore default driver"
PVVulkanDriver uninstall.
```

For a full walkthrough see `doc/graphics-tutorial.md`.

The same path is covered by tests on the device: `PVGraphicsTest` asserts the
rendered pixels offscreen and opens a real window for the swapchain, frame and
teardown tests. See "Known limitations and gotchas" for what those tests prove
and what they cannot.

---

## Documentation

| File | Contents |
|---|---|
| `doc/architecture.md` | Layer diagram, all key classes, compute and graphics flows |
| `doc/compute-tutorial.md` | Step-by-step compute: context, buffers, kernel annotation, compiler, dispatch, readback |
| `doc/graphics-tutorial.md` | Step-by-step graphics: window, surface, swapchain, shaders, pipeline, render loop |
| `doc/glsl-api-tutorial.md` | The GLSL-like vector and matrix DSL |
| `PHASE7-PLAN.md` | Device measurements, and the write-up of every Phase 7 item from the capability query to cooperative matrix |
| `CFG-PLAN.md` | What the CFG recogniser accepts and refuses, and why |
| `GRAPHICS-GPU-PLAN.md` | How the graphics path got device coverage: offscreen rendering, the pixels asserted, the window tests, and what none of them can prove |
| `DEFECTS-PLAN.md` | The three incidental defects recorded during Phase 7, each with the verification behind it, and what is deliberately left out of scope |
| `LAYOUT-PLAN.md` | How every hand-counted Vulkan structure offset was replaced by a declared field, group by group |
| `PACKAGE-PLAN.md` | The split from one code package into fifteen: the measured dependency figures, the ten decisions, what each of the eleven units did, and the rules the split set |

---

## Tips

### Tear down in reverse creation order
Vulkan has strict destruction ordering. Reverse the construction sequence
exactly. The `VkContext>>destroy` handles device + instance, but everything
above that (buffers, pipelines, swapchain, surface) is your responsibility.
A destroyed-out-of-order handle causes a validation error at best, a segfault
at worst.

### Always wait before destroying
Call `ctx computeQueue waitIdle` before tearing down anything the GPU might
still be using. In the graphics loop this is done by waiting on `inFlightFence`
at the top of `renderFrame`; after the loop ends, call `waitIdle` once more.

### Save the image before every test run
MCP method compilation and image evaluation are in-memory. If a GPU hang or
Pharo crash occurs during a test, you lose unsaved work. Save before running
anything that touches the GPU.

### Commit to Iceberg before saving the image
Iceberg writes from image to disk. If you save the image first, Iceberg sees
a clean state and the commit will be empty. Always commit first, then save.

### Usage flags: buffers and images are separate enumerations
`VkBufferUsageFlagBits` and `VkImageUsageFlagBits` are different bitmasks, and
the same numeric value means different things in each. Use the named constants
that exist rather than literals:
```smalltalk
VkBuffer storageBufferUsage      "= 32 — VK_BUFFER_USAGE_STORAGE_BUFFER_BIT"
VkImageUsage colorAttachmentBit  "= 16 — VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT"
```
Prefer `VkBuffer storageBuffer: elementCount on: aDevice`, which applies the
usage flag and converts the element count to bytes, or
`storageBuffer: elementCount of: #f16 on: aDevice` when the elements are not
f32 — that form, with `put:as:` and `elementsAs:`, is the element-type front
door, and it asks the emitter's own table for the element size rather than
assuming 4 bytes. Other flags (transfer
source and destination, vertex buffer = 128) have no named constant yet; add
one to `VkBuffer` or `VkImageUsage` when you first need it instead of writing
the integer at the call site.

### Swapchain format selection
`VkSwapchain` prefers `VkFormat b8g8r8a8Unorm` (44). If the surface does not
support it, it falls back to the first reported format. Always use
`swapchain format` when creating the render pass — never hardcode 44.

### MCP line endings
When compiling Pharo methods via `compile:classified:` through the MCP tool,
line endings must be CR (ASCII 13). Use:
```smalltalk
| cr |
cr := String with: Character cr.
src := 'methodName' , cr , '    ^ self'.
MyClass compile: src classified: 'protocol'
```
The `\r` escape in a raw JSON string passes literally as two characters in
the current MCP tool — it does not become CR.

### SpvBuilder vs SpvModule
`SpvBuilder` is a higher-level facade that manages IDs for you and provides
named emit methods (`emitLoad:type:`, `emitBinaryOp:...`, etc.).
`SpvModule` is the raw module accumulator — use it when you need to emit
instructions that `SpvBuilder` does not yet wrap. Both serialize to the same
binary format via `mod serialize`.

### Device selection is by position unless you ask for capability
`VkContext computeContext` takes the first device with a compute queue, which on
a machine with a software rasteriser installed beside a real GPU may not be the
device you want. `VkContext computeContextRequiring: #( #supportsCooperativeMatrix )`
takes the first device answering true to every named `VkPhysicalDevice`
predicate instead. `PVCooperativeMatrixSurvey` and `VkContext deviceFeatureReport`
show what each device offers.

### Validate every module you emit
`PVSpirvValidator on: aByteArray` finds `spirv-val` on `PATH` and answers
`isValid`, `validationOutput` and `validationReport`, with a Validation
inspector tab. Treat a validation failure as a compiler bug.

Validation cannot see a *flattened* control-flow graph, though: a module whose
loop was silently dropped still validates. Assert on decoded opcode counts
(`OpLoopMerge`, `OpSelectionMerge`, `OpPhi`) whenever a change could flatten
control flow — `PVCompilerTest >> opcodeCountsIn:` does this, and
`PVSpirvValidator >> inspectorControlFlow:` shows the same per block.

### No Vulkan validation layers in the current setup
The context creation does not enable `VK_LAYER_KHRONOS_validation`. If you
hit a strange crash or incorrect result, add `VK_KHRONOS_validation` to the
instance layers in `initializeCompute` / `initializeGraphicsWithExtensions:`
temporarily to get driver-level error messages.

---

## Known limitations and gotchas

### Pharo→SPIR-V compiler

- **Scalar `<gpu>` methods are functions, not shader modules.** Only a compute
  kernel (a storage buffer parameter, usually with a `#workItem` beside it) or a
  `<gpuVertex>`/`<gpuFragment>` shader gets an `OpEntryPoint`. See
  "`<gpu>` alone does not produce a shader module" above.
- **One control-flow construct per method, plus one nesting pattern.** The CFG
  recogniser matches one `ifTrue:ifFalse:`, one `whileTrue:`, or an outer
  `whileTrue:` whose body is an inner `whileTrue:`, and the node it returns must
  cover every basic block of the method. Anything else — nested conditions, a
  condition inside a loop body, a loop followed by a condition, *and also* two
  constructs in sequence — raises
  `PVTypeError signal: 'Unrecognized CFG shape'`. The sequential cases were
  silently miscompiled before 2026-10-09; `PVCfgShapeFixture` pins every shape
  with its expected verdict.
- **No scalars passed to a kernel.** There are no push constants and no
  specialisation constants. A kernel learns its geometry from `wi gridWidth` or
  reads the value out of a `#bufferOf_i32`. This is why the matmul kernels take
  no order argument.
- **A kernel body may not send a message the selector table does not map**,
  which includes asking a class for a named constant. Tile width therefore
  appears as a literal in the tiled matmul, with a comment saying why.
  Arbitrary `#f32` and `#i32` literals are fine: a kernel adding `7` or
  multiplying by `2.5` compiles and passes spirv-val.
- **No cross-method calls.** The compiler does not inline callees. Each
  kernel must be self-contained.
- **No GPU-side timing.** There is no query pool and no `vkCmdWriteTimestamp`.
  Every benchmark number is host wall clock around a dispatch that waits on the
  queue — honest for whole-dispatch comparisons, useless for anything finer.

### Graphics path

- **No resize handling.** The swapchain is created once for the initial
  extent. A resize makes `vkAcquireNextImageKHR` or `vkQueuePresentKHR`
  answer `VK_SUBOPTIMAL_KHR`, which is a success code and is tolerated —
  the frame carries on with a swapchain that no longer matches the surface.
  Once the swapchain is genuinely out of date they answer
  `VK_ERROR_OUT_OF_DATE_KHR` and `VkError` is signalled. Recreating the
  swapchain is not yet implemented.
- **Single queue.** Both graphics and compute work go through
  `ctx computeQueue` (the graphics+compute queue family). Separate
  transfer or async-compute queues are not used.
- **No depth buffer.** The render pass has a single colour attachment only.
  Any geometry requiring depth testing needs a new render pass and
  framebuffer setup.
- **No uniform buffers or textures in the hello-triangle pipeline.** The
  graphics pipeline uses an empty layout. Adding uniforms requires a
  descriptor set layout, pool, and set — see the compute pipeline as the
  pattern to follow, using bind point 0 (graphics) instead of 1 (compute).
- **What the graphics tests do and do not prove.** The graphics path is now
  tested on the device. Offscreen, `PVOffscreenTriangleScene` renders into an
  image it owns and reads the pixels back, so the triangle's shape,
  orientation, colours and opacity are asserted pixel by pixel, and the
  DSL-compiled shaders are compared with the hand-built ones. On a window,
  `PVGraphicsTest` opens a real one and asserts the swapchain's image views,
  that rendering visits every swapchain image, and that teardown — including
  an interrupted frame — releases every handle. The stub tests
  (`PVRecordingContextStub`, `PVFailingTriangleSceneStub`) are kept for the
  failure branches a working device will not produce on demand. **What no test
  asserts is what appears on screen:** reading back a presented image needs
  another copy, so the window tests prove the loop runs and the handles are
  managed, and the offscreen tests are where pixels are proven. Where no
  display server is available the window tests skip and state the reason.
- **Run graphics examples in a fresh image before GPU tests.** A triangle
  example that is interrupted used to strand a live instance, device, surface
  and swapchain, and `VkCoreTest` then created a second device against it and
  segfaulted. `PVVulkanDriver class >> installDuring:` and `ensure:`-nested
  teardown fixed that, but `VkHandle >> finalize` is deliberately a no-op, so
  only an explicit `destroy` ever reclaims a stray handle. If an image dies
  during GPU tests, ask first whether a graphics example ran earlier in the
  session.

### General

- **Linux only.** Library paths (`libvulkan.so.1`, `libSDL2.so`) are
  Linux-specific. macOS (MoltenVK) and Windows would need different paths
  and potentially different surface extensions.
- **No error recovery.** `VkError` is signalled on any non-`VK_SUCCESS`
  result. There is no retry or fallback logic.
- **Memory leak on early Pharo exit.** If the image crashes or is closed
  without calling `destroy` on contexts, buffers, and pipelines, the OS
  reclaims GPU memory on process exit — but Vulkan objects are not cleanly
  destroyed. This can occasionally leave the GPU in a bad state until reboot
  on some drivers.
- **No pipeline cache.** `vkCreateGraphicsPipelines` and
  `vkCreateComputePipelines` are called with a null pipeline cache. Shader
  compilation happens every session startup. This is fine for development
  but would be slow for many pipelines in production.
