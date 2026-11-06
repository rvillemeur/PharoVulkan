# PharoVulkan Architecture

## Overview

PharoVulkan has two independent paths sharing the same binding and core layers:

1. **Compute path** — compile an annotated Pharo method to SPIR-V, dispatch
   on GPU, read back results. No window, no surface.
2. **Graphics path** — render frames via a Vulkan swapchain connected to an
   SDL2 window. Shaders built directly with the SPIR-V IR builder.

---

## Package Layers

Sixteen packages: nine of code, seven of tests. An arrow upward in this diagram is a dependency
downward in the layering, and nothing reaches up: `PharoVulkan-Bindings` and `PharoVulkan-SPIRV`
name no other package of this project at all.

```
┌─────────────────────────────────────────────────────────────────────┐
│  PharoVulkan-Examples        PharoVulkan-<Name>-Tests (6)           │
│  one <Subject>Examples       one test package per code package,     │
│  class per subject           plus PharoVulkan-Tests for the         │
│  PharoVulkan-Inspector       architecture, document and example     │
│  PVFactRow, one fact row     gates                                  │
├──────────────────────────────┬──────────────────────────────────────┤
│   PharoVulkan-Graphics       │      PharoVulkan-Compute             │
│  VkSurface  VkSwapchain      │  VkComputePipeline  VkDescriptorPool │
│  VkRenderPass VkFramebuffer  │  VkDescriptorSet  VkDescriptorSet-   │
│  VkGraphicsPipeline          │  Layout  PVComputeKernel             │
│  PVHelloTriangleScene        │  PVCooperativeMatrix                 │
│  SDL2 tag: SDL2Vulkan,       │                                      │
│  PVVulkanDriver,             │                                      │
│  OSSDL2VulkanBackendWindow   │                                      │
├──────────────────────────────┴──────────────────────────────────────┤
│                     PharoVulkan-Core                                │
│  VkContext   VkDevice   VkQueue   VkBuffer   VkPipelineLayout       │
│  VkCommandPool/Buffer   VkShaderModule   VkPhysicalDevice           │
├─────────────────────────────────────────────────────────────────────┤
│              PharoVulkan-Compiler                                   │
│  PVKernelCompiler  PVBytecodeDecoder  PVCFGBuilder                  │
│  PVStackSimulator  PVTypeInferencer                                 │
│  PVStructuredCFGRecognizer  PVSPIRVEmitter  PVSelectorTable         │
├──────────────────────────────┬──────────────────────────────────────┤
│   PharoVulkan-Bindings       │      PharoVulkan-SPIRV              │
│  Vk (FFI commands)           │  SpvModule  SpvBuilder  SpvFunction  │
│  VkStructureType  VkFormat   │  SpvBlock  SpvType hierarchy         │
│  VkShaderStage VkImageLayout │  SpvConstantPool  SpvSerializer      │
│  VkHandle subclasses (_H)    │  SpvValidator  PVTypeError           │
│  VkResult  VkError VkLibrary │                                      │
├──────────────────────────────┴──────────────────────────────────────┤
│              PharoVulkan-Generator  (dev-time only, outside default)│
│  VkBindingGenerator (reads vk.xml)                                  │
│  SpvBuilderGenerator (reads spirv.core.grammar.json)                │
├─────────────────────────────────────────────────────────────────────┤
│              System libraries                                       │
│  libvulkan.so.1          libSDL2.so                                 │
└─────────────────────────────────────────────────────────────────────┘
```

The compiler sits above the SPIR-V builder and beside the bindings rather than on them: it
answers bytes and calls no driver, which is what lets the `compiler` group load on a machine with
no `libvulkan.so.1`. `PharoVulkan-Core` reaches both the bindings it calls through and the SPIR-V
package, because `VkBuffer` raises `PVTypeError`.

### What enforces this

`PVArchitectureTest class >> allowedDependencies` declares the allowed outgoing edges of every one
of the sixteen packages, and twenty-two tests hold the code to that table:

- sixteen read one package's own methods — `package methods`, so an extension method this project
  adds to `Number` or `SequenceableCollection` is read as well — collect every package of this
  project their literals name, and fail naming each method whose reference the table does not
  grant;
- four hold the table itself to the code: every package has an entry, every edge names a package
  that exists, every edge is one the package really makes, and every edge is declared in
  `BaselineOfPharoVulkan` too, since an edge missing from the baseline loads here and fails for
  whoever loads the project a group at a time;
- one reads a reference planted inside three nested blocks, because a class named inside a block
  lives in the block's literals and not the method's — the first scan of this project missed 86
  edges that way;
- one holds every method of the project to naming the capability, the addressing model and the
  memory model it passes to `addCapability:` and `setAddressingModel:memoryModel:`, rather than
  writing the specification's numbers there.

`PVArchitectureTest class >> inspectorDependencies:` shows declared and actual edges side by side,
one row per package.

`PVDocumentationTest` holds this document to the image: every name it writes between backticks
outside a fenced block must be a class, a class variable of a code package or a package, and every
qualified form it writes, such as `SpvBuilder >> addCapability:`, must be answered by that
class. `PVExamplesTest` holds the views and the examples to their shape: a view takes the
presenter builder, an example is a one-click class-side method of `PharoVulkan-Examples`, and an
example that opens a window is named `open…` so that no gate runs it. Both skip rather than
fail in an image with no checkout of the repository.

### Baseline groups

| Group | Packages |
|---|---|
| `bindings` | Bindings |
| `spirv` | SPIRV |
| `compiler` | SPIRV, Compiler |
| `core` | Core |
| `compute` | Compute |
| `graphics` | Graphics |
| `default` | Bindings, Core, Compute, Graphics |
| `generator` | Generator |
| `examples` | Examples |
| `tests` | `default`, Examples, Generator and the seven test packages |

---

## Key Classes

### PharoVulkan-Bindings

| Class | Role |
|---|---|
| `Vk` | All raw vkXxx FFI calls, class-side |
| `VkLibrary` | Points uFFI at libvulkan.so.1 |
| `VkHandle` | Root of all opaque handle wrappers (`VkDevice_H`, etc.) |
| `VkStructureType` | Named constants for every sType field |
| `VkFormat`, `VkRenderConfig`, `VkShaderStage`, ... | Named constants for all other enums/flags |
| `VkResult`, `VkError` | Result checking and error signalling |

### PharoVulkan-Core

| Class | Role |
|---|---|
| `VkContext` | Owns instance + physical device selection + logical device + queue. Entry point for both paths. |
| `VkDevice` | Logical device wrapper; factory for pools, modules, buffers |
| `VkPhysicalDevice` | Device queries (memory types, queue families) |
| `VkQueue` | Submit compute or graphics work |
| `VkBuffer` | Device buffer + backing VkDeviceMemory; host-mapped |
| `VkCommandPool` / `VkCommandBuffer` | Command recording |
| `VkShaderModule` | Loads SPIR-V bytes into the driver |
| `VkPipelineLayout` | Wraps a descriptor set layout for pipeline creation; both pipeline kinds are built from one, which is why it sits here and not in Compute |

### PharoVulkan-Compute

| Class | Role |
|---|---|
| `VkDescriptorSetLayout` | Declares buffer bindings schema |
| `VkComputePipeline` | Wraps VkPipeline for compute |
| `VkDescriptorPool` / `VkDescriptorSet` | Allocate and bind storage buffers to shader slots |
| `PVComputeKernel` | High-level runner: compile → prepare → dispatch → read-back |

### PharoVulkan-Graphics

| Class | Role |
|---|---|
| `VkSurface` | SDL2 Vulkan surface, wraps `SDL_Vulkan_CreateSurface` |
| `VkSwapchain` | Swapchain images + image views, acquire/present |
| `VkRenderPass` | Single colour attachment, CLEAR/STORE/PRESENT |
| `VkFramebuffer` | Per-swapchain-image framebuffer |
| `VkGraphicsPipeline` | Full graphics pipeline state object |
| `VkFenceWrapper`, `VkSemaphoreWrapper` | CPU/GPU sync primitives |
| `PVHelloTriangleScene` | End-to-end triangle demo |

### PharoVulkan-SPIRV

| Class | Role |
|---|---|
| `SpvModule` | Owns the full SPIR-V program; accumulates instructions |
| `SpvBuilder` | High-level facade: emit instructions without tracking IDs manually |
| `SpvModuleEmitter` | Base for emitters; manages the current module |
| `SpvType` hierarchy | `SpvFloatType`, `SpvVectorType`, `SpvPointerType`, ... |
| `SpvConstantPool` | Deduplicates type/constant declarations |
| `SpvSerializer` | Writes the 5-word header + instruction stream to ByteArray |
| `SpvValidator` | Checks well-formedness before serialization |

### PharoVulkan-Compiler

| Class | Role |
|---|---|
| `PVKernelCompiler` | Entry point: a `CompiledMethod` in, SPIR-V bytes out, through the seven stages below |
| `PVBytecodeDecoder`, `PVStackSimulator` | Bytecode to a register IR |
| `PVCFGBuilder`, `PVStructuredCFGRecognizer` | Control flow: the basic blocks, and the shapes the emitter accepts |
| `PVTypeInferencer`, `PVTypeAnnotation` | Types, seeded from the `<gpu>` and `<param:named:>` pragmas |
| `PVSPIRVEmitter`, `PVSelectorTable` | Emission, and the table mapping a Pharo selector to a SPIR-V opcode |
| `PVSpirvValidator` | Wraps the external `spirv-val`, and reports the tool as missing rather than failing when it is absent |

### PharoVulkan-Generator

| Class | Role |
|---|---|
| `VkBindingGenerator` | Reads `vk.xml` and emits the binding classes |
| `SpvBuilderGenerator`, `SpvGrammarParser` | Read `spirv.core.grammar.json` and emit the builder |

### PharoVulkan-Examples

One class per subject — `VkContextExamples`, `VkPipelineExamples`, `PVCompilerExamples`,
`PVSceneExamples` and so on — each holding as class-side methods the `<sampleInstance>` examples of
the thing it is named after. An example rebuilds its object on every call, asserts nothing, and
runs from one click in the browser; the inspector views and the tests read them, which is why most
test packages depend on this one. Every `<sampleInstance>` of the project lives here, the two that
open a window included (`PVSceneExamples class >> openRenderTriangle` and `openGlslRenderTriangle`);
`renderTriangle` itself stays on the scene classes, because `doc/glsl-api-tutorial.md` documents it
as the method a user writes on their own scene.

---

## Compiler Pipeline (Pharo method → SPIR-V bytes)

Entry: `PVKernelCompiler compileMethod: aCompiledMethod`

```
CompiledMethod
    │
    ▼ Stage 1 — PVBytecodeDecoder
    List of PVBytecodeOp
    (push, send, return, jump, ...)
    │
    ▼ Stage 2 — PVStackSimulator
    List of PVRegisterOp
    (converts stack machine → register machine IR)
    │
    ▼ Stage 3 — PVTypeInferencer
    typeMap: reg → SpvType
    (seeded from <gpu> / <param: #f32 named: #x> pragmas)
    │
    ▼ Stage 4 — PVCFGBuilder buildBytecodeBlocks:
    List of PVBytecodeBlock
    (detects whether straight-line, selection, or loop)
    │
    ├── straight-line (1 block) ──────────────────────────────────┐
    │                                                             │
    ▼ Stage 5 — PVStructuredCFGRecognizer                         │
    PVSelectionNode  or  PVLoopNode  or  nil                      │
    │                                                             │
    ▼ Stage 6 — PVSPIRVEmitter                                    │
    SpvModule (built via SpvModuleEmitter superclass)             ◄┘
    │
    ▼ Stage 7 — SpvSerializer + SpvValidator
    ByteArray  (32-bit LE SPIR-V binary, spirv-val clean)
```

There is no SSA stage. `PVSPIRVEmitter` writes the `OpPhi` instructions a merge point needs
itself, by saving its register map before an arm and restoring it after. The Braun et al.
construction that `prompt.md` and `design-notes.md` specify as stage ⑤ was written as an identity
function, never wired into the pipeline, and removed on 2026-11-06 together with `PVSSAConstructor`,
`PVSSAVar`, `PVPhiNode`, `PVControlFlowGraph` and `PVBasicBlock`.

### Pragma annotations (compiler input contract)

```smalltalk
myKernel: workItem
    <gpu>
    <param: #u32 named: #n>
    <param: #f32 named: #x>
    ...
```

`<gpu>` marks the method as a GPU kernel.
`<param: type named: name>` declares each parameter's SPIR-V type.
`PVTypeAnnotation` reads these pragmas and seeds the type inferencer.

---

## Compute Dispatch Flow

```
ctx := VkContext computeContext.
buf := ctx device allocateBuffer: 1024 usage: VkImageUsage storageBit.
buf copyFromByteArray: inputData.

spirv := PVKernelCompiler compileMethod: (MyClass >> #myKernel:).

kernel := PVComputeKernel on: ctx spirv: spirv.
kernel bindBuffer: buf.
kernel prepare.          "builds shader module, descriptors, pipeline"
kernel dispatch: 64 y: 1 z: 1.
result := buf copyToByteArray.
kernel destroy.
ctx destroy.
```

Internally `prepare` wires:

```
VkShaderModule
VkDescriptorSetLayout  →  VkPipelineLayout  →  VkComputePipeline
VkDescriptorPool  →  VkDescriptorSet  (vkUpdateDescriptorSets)
VkCommandPool
```

---

## Graphics Render Loop

```
ctx := VkContext new initializeGraphicsWithExtensions: sdlExtensions.
scene := PVHelloTriangleScene prepare: ctx backendWindow: win.
[ scene renderFrame ] repeat.
```

`renderFrame` each iteration:

```
VkSwapchain acquireNextImage: imageAvailable fence: null
    │
    ▼
VkCommandBuffer record:
    vkCmdBeginRenderPass  (VkRenderPass, VkFramebuffer, clearColor)
    vkCmdBindPipeline     (VkGraphicsPipeline)
    vkCmdSetViewport / vkCmdSetScissor
    vkCmdBindVertexBuffers
    vkCmdDraw
    vkCmdEndRenderPass
    │
    ▼
VkQueue submitGraphics:
    waitSemaphore:   imageAvailable  (stage: COLOR_ATTACHMENT_OUTPUT)
    signalSemaphore: renderFinished
    fence:           inFlightFence
    │
    ▼
VkSwapchain present: idx queue: queue waitSemaphore: renderFinished
```

Graphics shaders are built directly with `SpvModule` / `SpvGlobalVariable`
(no Pharo→SPIR-V compiler involved — only the compute path goes through
`PVKernelCompiler`).

---

## SDL2 Surface Integration

```
OSSDL2Driver createWindowWithAttributes:osWindow:
    │  (PVVulkanDriver subclass overrides this)
    ▼
SDL2 createWindow: ... flags: (SDL_WINDOW_VULKAN | ...)
    │
    ▼
OSSDL2VulkanBackendWindow
    │
    ▼
SDL2Vulkan getInstanceExtensions:  →  fed into initializeGraphicsWithExtensions:
SDL2Vulkan createSurface:          →  VkSurface wraps the result
```

---

## Synchronisation Model

Only `VK_KHR_synchronization2` is used (no legacy `vkQueueSubmit`):

- `vkQueueSubmit2` with `VkSubmitInfo2` / `VkSemaphoreSubmitInfo` / `VkCommandBufferSubmitInfo`
- Stage mask: `VkPipelineStage2 colorAttachmentOutputBit` on both wait and signal semaphores
- Device feature enabled at device creation: `VkPhysicalDeviceSynchronization2Features`

---

## Named-Constant Strategy (no magic numbers)

Every numeric Vulkan constant is a named class-side method:

| Enum family | Class |
|---|---|
| `VkStructureType` | `VkStructureType` (37 methods) |
| `VkFormat` | `VkFormat` |
| `VkShaderStageFlagBits` | `VkShaderStage` |
| `VkDescriptorType` | `VkDescriptorType` |
| `VkMemoryPropertyFlagBits` | `VkMemoryProperty` |
| `VkImageUsageFlagBits` | `VkImageUsage` |
| `VkPipelineStageFlags2` | `VkPipelineStage2` |
| `VkAttachmentLoad/StoreOp` | `VkAttachmentOp` |
| `VkImageLayout` | `VkImageLayout` |
| Misc (sampleCount, viewType, ...) | `VkRenderConfig` |
| API version | `VkApiVersion` |
