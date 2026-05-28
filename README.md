# PharoVulkan

Vulkan uFFI bindings and SPIR-V DSL for Pharo 13. No third-party Pharo
packages — only the system Vulkan loader and SDL2.

Two goals:
1. **Full Vulkan API** exposed via uFFI with named constants (no magic numbers)
2. **Pharo→SPIR-V compiler** — annotate a Pharo method with `<gpu>` and
   `<param:named:>` pragmas and it compiles to a SPIR-V compute shader

---

## Requirements

| Dependency | Minimum version | Notes |
|---|---|---|
| Pharo | 13.1.0 | Tested on 13.1.0 SNAPSHOT |
| libvulkan.so.1 | Vulkan 1.3 | Or 1.2 + VK_KHR_synchronization2 |
| libSDL2.so | 2.0.6+ | Graphics path only |
| GPU | Any with Vulkan 1.3 compute | Tested on AMD/NVIDIA on Linux |

Linux only at this stage (uFFI library paths are Linux-specific).

---

## Package layout

| Package | What it contains |
|---|---|
| `PharoVulkan-Bindings` | uFFI Vulkan commands, handle wrappers, named constant classes |
| `PharoVulkan-Core` | VkContext, VkDevice, VkQueue, VkBuffer, VkCommandPool/Buffer, VkShaderModule |
| `PharoVulkan-Compute` | Descriptor set layout, pipeline layout, compute pipeline, descriptor pool/set |
| `Pharovulkan-graphics` | Swapchain, render pass, framebuffer, graphics pipeline, sync wrappers, hello-triangle scene |
| `PharoVulkan-SPIRV` | SPIR-V IR builder (SpvModule, SpvBuilder, SpvFunction, SpvBlock, types, constants, serialiser) |
| `PharoVulkan-Compiler` | Pharo bytecode → SPIR-V: 9-stage pipeline (decode, CFG, SSA, type inference, emit) |
| `PharoVulkan-SDL2` | SDL2 Vulkan surface integration, window driver override |
| `PharoVulkan-Generator` | Reads vk.xml / spirv.core.grammar.json and emits binding classes |

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

```smalltalk
| ctx buf spirv kernel result |

"1. Create context (no window needed)"
ctx := VkContext computeContext.

"2. Allocate a 16-byte buffer (4 floats)"
buf := VkBuffer on: ctx device size: 16 usage: 4.   "4 = STORAGE_BUFFER_BIT"

"3. Fill with [1.0, 2.0, 3.0, 4.0]"
| data |
data := ByteArray new: 16.
#(1.0 2.0 3.0 4.0) doWithIndex: [:v :i |
    | bits base |
    bits := v asIEEE32BitWord.
    base := (i - 1) * 4 + 1.
    data at: base   put: (bits        bitAnd: 255).
    data at: base+1 put: ((bits >>  8) bitAnd: 255).
    data at: base+2 put: ((bits >> 16) bitAnd: 255).
    data at: base+3 put: ((bits >> 24) bitAnd: 255)].
buf copyFromByteArray: data.

"4. Compile a relu kernel with the Pharo→SPIR-V compiler"
spirv := PVKernelCompiler compile: (PVKernelExamples >> #relu:).

"5. Run"
kernel := PVComputeKernel on: ctx spirv: spirv.
kernel bindBuffer: buf.
kernel prepare.
kernel dispatch: 1 y: 1 z: 1.

"6. Read back"
result := buf copyToByteArray.

"7. Clean up"
kernel destroy.
buf destroy.
ctx destroy.
```

For a full walkthrough see `doc/compute-tutorial.md`.

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

---

## Documentation

| File | Contents |
|---|---|
| `doc/architecture.md` | Layer diagram, all key classes, compute and graphics flows |
| `doc/compute-tutorial.md` | Step-by-step compute: context, buffers, kernel annotation, compiler, dispatch, readback |
| `doc/graphics-tutorial.md` | Step-by-step graphics: window, surface, swapchain, shaders, pipeline, render loop |

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

### Buffer usage flags
Use named constants, not integers:
```smalltalk
VkImageUsage storageBit          "= 4  — compute storage buffer"
VkImageUsage colorAttachmentBit  "= 16 — swapchain image"
VkImageUsage transferSrcBit      "= 1  — copy source"
VkImageUsage transferDstBit      "= 2  — copy destination"
"Vertex buffer (128 = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT) is not yet in
 VkImageUsage — use the integer 128 for now."
```

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

### No Vulkan validation layers in the current setup
The context creation does not enable `VK_LAYER_KHRONOS_validation`. If you
hit a strange crash or incorrect result, add `VK_KHRONOS_validation` to the
instance layers in `initializeCompute` / `initializeGraphicsWithExtensions:`
temporarily to get driver-level error messages.

---

## Known limitations and gotchas

### Pharo→SPIR-V compiler (Phase 1–6 scope)

- **No buffer indexing from compiled kernels.** The compiler emits scalar
  compute functions. It cannot yet emit `OpAccessChain` to index into a
  runtime array. For real workloads (per-element processing), build the SPIR-V
  shader manually with `SpvBuilder` as shown in `PVComputeTest`.
- **No `gl_GlobalInvocationID` in compiled kernels.** The emitter does not
  yet wire in the built-in invocation ID. Again, use `SpvBuilder` for
  anything needing per-thread indexing.
- **Integer literals beyond 0.** Pharo `SmallInteger` literals in a `<gpu>`
  method may not round-trip cleanly through the type inferencer for all
  operators. `0`, `1`, `0.0`, `1.0` are safe; arbitrary literals may cause
  `PVTypeError`.
- **One level of control flow.** The CFG recogniser handles one
  `ifTrue:ifFalse:` or one `whileTrue:` per method. Nested conditions or
  loops raise `PVTypeError signal: 'Unrecognized CFG shape'`.
- **No cross-method calls.** The compiler does not inline callees. Each
  kernel must be self-contained.

### Graphics path

- **No resize handling.** The swapchain is created once for the initial
  extent. If the window is resized, `vkAcquireNextImageKHR` or
  `vkQueuePresentKHR` will return `VK_ERROR_OUT_OF_DATE_KHR` and
  `VkError` will be signalled. Recreating the swapchain is not yet
  implemented.
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
