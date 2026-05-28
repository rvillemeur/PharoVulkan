# PharoVulkan Architecture

## Overview

PharoVulkan has two independent paths sharing the same binding and core layers:

1. **Compute path** — compile an annotated Pharo method to SPIR-V, dispatch
   on GPU, read back results. No window, no surface.
2. **Graphics path** — render frames via a Vulkan swapchain connected to an
   SDL2 window. Shaders built directly with the SPIR-V IR builder.

---

## Package Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Application / Tests                           │
│  PVHelloTriangleScene   PVComputeKernel   PVKernelExamples          │
├──────────────────────────────┬──────────────────────────────────────┤
│   Pharovulkan-graphics       │      PharoVulkan-Compute             │
│  VkSwapchain  VkRenderPass   │  VkComputePipeline  VkDescriptorPool │
│  VkFramebuffer VkGraphics-   │  VkDescriptorSet    VkPipelineLayout │
│  Pipeline  VkSurface         │  PVComputeKernel                     │
├──────────────────────────────┴──────────────────────────────────────┤
│                     PharoVulkan-Core                                │
│  VkContext   VkDevice   VkQueue   VkBuffer                          │
│  VkCommandPool/Buffer   VkShaderModule   VkPhysicalDevice           │
├──────────────┬──────────────────────────────────────────────────────┤
│PharoVulkan-  │              PharoVulkan-Bindings                    │
│SDL2          │  Vk (FFI commands)   VkStructureType  VkFormat       │
│SDL2Vulkan    │  VkShaderStage  VkImageLayout  VkRenderConfig ...    │
│OSSDL2Vulkan- │  VkHandle subclasses (_H types)   VkResult  VkError │
│BackendWindow │  VkLibrary                                           │
├──────────────┴──────────────────────────────────────────────────────┤
│              PharoVulkan-SPIRV                                      │
│  SpvModule  SpvBuilder  SpvFunction  SpvBlock                       │
│  SpvType hierarchy  SpvConstantPool  SpvSerializer  SpvValidator    │
├─────────────────────────────────────────────────────────────────────┤
│              PharoVulkan-Compiler                                   │
│  PVKernelCompiler  PVBytecodeDecoder  PVCFGBuilder                  │
│  PVStackSimulator  PVSSAConstructor  PVTypeInferencer               │
│  PVStructuredCFGRecognizer  PVSPIRVEmitter                          │
├─────────────────────────────────────────────────────────────────────┤
│              PharoVulkan-Generator  (dev-time only)                 │
│  VkBindingGenerator (reads vk.xml)                                  │
│  SpvBuilderGenerator (reads spirv.core.grammar.json)               │
├─────────────────────────────────────────────────────────────────────┤
│              System libraries                                       │
│  libvulkan.so.1          libSDL2.so                                 │
└─────────────────────────────────────────────────────────────────────┘
```

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

### PharoVulkan-Compute

| Class | Role |
|---|---|
| `VkDescriptorSetLayout` | Declares buffer bindings schema |
| `VkPipelineLayout` | Wraps DSL for pipeline creation |
| `VkComputePipeline` | Wraps VkPipeline for compute |
| `VkDescriptorPool` / `VkDescriptorSet` | Allocate and bind storage buffers to shader slots |
| `PVComputeKernel` | High-level runner: compile → prepare → dispatch → read-back |

### Pharovulkan-graphics

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

---

## Compiler Pipeline (Pharo method → SPIR-V bytes)

Entry: `PVKernelCompiler compile: aCompiledMethod`

```
CompiledMethod
    │
    ▼ Stage 1 — PVBytecodeDecoder
    List of PVBytecodeOp
    (push, send, return, jump, ...)
    │
    ▼ Stage 2 — PVCFGBuilder buildBytecodeBlocks:
    List of PVBytecodeBlock
    (detects whether straight-line, selection, or loop)
    │
    ├── straight-line (1 block) ──────────────────────────────────┐
    │                                                             │
    ▼ Stage 3 — PVStackSimulator                                  │
    List of PVRegisterOp                                          │
    (converts stack machine → register machine IR)               │
    │                                                             │
    ▼ Stage 4 — PVCFGBuilder buildFrom:                           │
    PVControlFlowGraph                                            │
    │                                                             │
    ▼ Stage 5 — PVSSAConstructor  (Braun et al.)                  │
    SSA CFG (phi nodes inserted on-the-fly)                       │
    │                                                             │
    ▼ Stage 6 — PVTypeInferencer                                  │
    typeMap: reg → SpvType                                        │
    (seeded from <gpu> / <param: #f32 named: #x> pragmas)        │
    │                                                             │
    ▼ Stage 7 — PVStructuredCFGRecognizer                         │
    PVSelectionNode  or  PVLoopNode  or  nil                      │
    │                                                             │
    ▼ Stage 8 — PVSPIRVEmitter                                    │
    SpvModule (built via SpvModuleEmitter superclass)             ◄┘
    │
    ▼ Stage 9 — SpvSerializer + SpvValidator
    ByteArray  (32-bit LE SPIR-V binary, spirv-val clean)
```

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

spirv := PVKernelCompiler compile: (MyClass >> #myKernel:).

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
