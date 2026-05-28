# PharoVulkan Graphics API Tutorial

This tutorial walks through every step required to render a frame with
PharoVulkan's graphics path: window creation, Vulkan context, shaders,
swapchain, render pass, framebuffers, pipeline, vertex buffer, sync objects,
and the render loop. `PVHelloTriangleScene` is the reference implementation —
all code here mirrors exactly what that class does.

---

## Prerequisites

- PharoVulkan loaded in a Pharo 13 image
- `libvulkan.so.1` and `libSDL2.so` present on the system
- A GPU with Vulkan 1.3 support (or VK_KHR_synchronization2)
- `PVVulkanDriver` installed as the OSWindow driver (see step 1)

---

## Step 1 — Install the Vulkan driver

The graphics path requires `PVVulkanDriver`, a subclass of `OSSDL2Driver`
that adds `SDL_WINDOW_VULKAN` to the window flags and returns an
`OSSDL2VulkanBackendWindow` instead of a plain `OSSDL2BackendWindow`.

```smalltalk
PVVulkanDriver install.
```

To restore the standard driver afterwards:

```smalltalk
PVVulkanDriver uninstall.
```

`install` calls `OSWindowDriver driverClass: PVVulkanDriver`. Any
subsequent `OSWindow createWithAttributes:` will go through this driver.

---

## Step 2 — Open a Vulkan-capable SDL2 window

Use `PVWindowAttributes` to signal that a Vulkan surface is needed.

```smalltalk
| attrs win backendWin |
attrs := PVWindowAttributes newVulkan.
attrs title: 'My Vulkan App'.
attrs extent: 800@600.
attrs windowCentered: true.

win := OSWindow createWithAttributes: attrs.

"The backend window is OSSDL2VulkanBackendWindow."
backendWin := win backendWindow.
```

`PVWindowAttributes newVulkan` sets `vulkanAttributes` to an
`OSVulkanAttributes` instance. `PVVulkanDriver>>createWindowWithAttributes:osWindow:`
detects this and ORs `SDL_WINDOW_VULKAN` into the SDL flags before calling
`SDL2 createWindow:...`.

---

## Step 3 — Collect required instance extensions

SDL2 knows which Vulkan instance extensions the platform needs (e.g.
`VK_KHR_surface`, `VK_KHR_xcb_surface` on Linux). Ask the backend window
for them:

```smalltalk
| extNames |
extNames := backendWin requiredInstanceExtensions.
"=> #('VK_KHR_surface' 'VK_KHR_xcb_surface') on Linux/X11"
```

`requiredInstanceExtensions` calls `SDL_Vulkan_GetInstanceExtensions` twice
(once for count, once for names) and returns an Array of String.

You **must** pass these to context creation in the next step. The swapchain
extension (`VK_KHR_swapchain`) is added automatically by
`VkContext>>createGraphicsDevice`.

---

## Step 4 — Create the graphics VkContext

```smalltalk
| ctx |
ctx := VkContext graphicsContextForExtensions: extNames.
```

Internally this calls `initializeGraphicsWithExtensions:` which:

1. Allocates a `VkApplicationInfo` with `VkApiVersion vulkan13` as `apiVersion`
2. Creates a `VkInstance` with the SDL2 extensions enabled
3. Calls `selectGraphicsPhysicalDevice` — picks the first GPU with a
   graphics+compute queue family
4. Calls `createGraphicsDevice` — creates a `VkDevice` with
   `VK_KHR_swapchain` and `VkPhysicalDeviceSynchronization2Features` enabled
5. Calls `fetchGraphicsQueue` — retrieves the `VkQueue`

After this call:
- `ctx instance` — the `VkInstance_H`
- `ctx physicalDevice` — the selected `VkPhysicalDevice`
- `ctx device` — the `VkDevice` wrapper
- `ctx computeQueue` — the `VkQueue` (used for both graphics and compute
  since they share the same queue family)
- `ctx computeQueueFamily` — the queue family index

---

## Step 5 — Create the VkSurface

```smalltalk
| surface |
surface := VkSurface
    fromWindow: backendWin
    instance: ctx instance
    physicalDevice: ctx physicalDevice.
```

`VkSurface>>initializeWithWindow:instance:physicalDevice:` calls
`backendWin createVulkanSurface: ctx instance` which in turn calls
`SDL_Vulkan_CreateSurface`. The returned `VkSurfaceKHR_H` handle is stored.

---

## Step 6 — Query the drawable extent

On Wayland (and with HiDPI screens) the drawable size can differ from the
window size. Always use:

```smalltalk
| ext |
ext := backendWin vulkanDrawableExtent.
"=> aPoint e.g. 800@600"
```

This calls `SDL_Vulkan_GetDrawableSize`. Use this `ext` (a `Point`) for
swapchain and framebuffer creation throughout.

---

## Step 7 — Create the VkSwapchain

```smalltalk
| swapchain |
swapchain := VkSwapchain on: ctx device surface: surface extent: ext.
```

`initializeDevice:surface:extent:` does:

1. Calls `vkGetPhysicalDeviceSurfaceCapabilitiesKHR` to get min/max image
   counts and the `currentTransform`
2. Calls `vkGetPhysicalDeviceSurfaceFormatsKHR` — prefers
   `VkFormat b8g8r8a8Unorm` (44) if available, falls back to first reported
   format
3. Creates `VkSwapchainKHR` with:
   - `imageUsage = VkImageUsage colorAttachmentBit`
   - `imageSharingMode = VkRenderConfig sharingModeExclusive`
   - `compositeAlpha = VkRenderConfig compositeAlphaOpaqueBit`
   - `presentMode = VkRenderConfig presentModeFifo` (vsync)
4. Retrieves all swapchain `VkImage_H` handles
5. Creates one `VkImageView_H` per image via `createImageViews`

After creation:
- `swapchain imageCount` — number of swapchain images
- `swapchain imageViews` — `OrderedCollection` of `VkImageView_H`
- `swapchain format` — the chosen `VkFormat` integer
- `swapchain extent` — the `Point` passed in

---

## Step 8 — Create the VkRenderPass

```smalltalk
| renderPass |
renderPass := VkRenderPass createColorPassDevice: ctx device format: swapchain format.
```

This creates a render pass with a single colour attachment:
- `loadOp = VkAttachmentOp loadClear` — clear to the clear colour at start
- `storeOp = VkAttachmentOp storeStore` — write result to memory
- `stencilLoadOp = VkAttachmentOp loadDontCare`
- `stencilStoreOp = VkAttachmentOp storeDiscard`
- `initialLayout = VkImageLayout undefined`
- `finalLayout = VkImageLayout presentSrcKHR`
- One subpass, graphics bind point, one colour attachment reference at
  `VkImageLayout colorAttachmentOptimal`

---

## Step 9 — Create the VkFramebuffers

One framebuffer per swapchain image view:

```smalltalk
| framebuffers |
framebuffers := swapchain imageViews collect: [:view |
    VkFramebuffer
        on: ctx device
        renderPass: renderPass
        imageView: view
        width: ext x
        height: ext y].
```

Each framebuffer binds exactly one image view to the render pass.

---

## Step 10 — Build shaders with SpvModule

Graphics shaders are built directly using the SPIR-V IR builder — no
Pharo→SPIR-V compiler is involved here.

### Vertex shader

A vertex shader receives per-vertex data from the vertex buffer and writes
clip-space position + any varyings.

```smalltalk
buildVertexShader
    | mod tr cp f32 vec2 vec3 vec4 perVertexStruct
      pOutPerVertex pOutVec4 pInVec2 pInVec3 pOutVec3
      voidType funcType
      inPos inColor outPerVertex outColor
      zero32 one32 zeroUInt32
      fn blk
      posValId posXId posYId posVec4Id posChainId colorValId |

    mod := SpvModule new initialize.
    mod addCapability: 1.                        "Capability::Shader"
    mod setAddressingModel: 0 memoryModel: 1.    "Logical / GLSL450"

    tr := mod typeRegistry.
    cp := mod constantPool.

    "--- types ---"
    f32  := tr floatType: 32.
    vec2 := tr vectorType: f32 count: 2.
    vec3 := tr vectorType: f32 count: 3.
    vec4 := tr vectorType: f32 count: 4.

    "gl_PerVertex block (contains gl_Position)"
    perVertexStruct := tr structType: (Array with: vec4).
    mod addDecoration: perVertexStruct id
        decoration: SpvDecoration block literals: #().
    mod addMemberDecoration: perVertexStruct id member: 0
        decoration: SpvDecoration builtIn
        literals: (Array with: SpvBuiltIn position).

    pOutPerVertex := tr pointerType: SpvStorageClass output type: perVertexStruct.
    pOutVec4  := tr pointerType: SpvStorageClass output type: vec4.
    pInVec2   := tr pointerType: SpvStorageClass input  type: vec2.
    pInVec3   := tr pointerType: SpvStorageClass input  type: vec3.
    pOutVec3  := tr pointerType: SpvStorageClass output type: vec3.

    voidType  := tr voidType.
    funcType  := tr functionType: voidType paramTypes: #().

    "--- interface variables ---"
    inPos       := SpvGlobalVariable on: mod type: pInVec2  storageClass: SpvStorageClass input.
    inColor     := SpvGlobalVariable on: mod type: pInVec3  storageClass: SpvStorageClass input.
    outPerVertex:= SpvGlobalVariable on: mod type: pOutPerVertex storageClass: SpvStorageClass output.
    outColor    := SpvGlobalVariable on: mod type: pOutVec3 storageClass: SpvStorageClass output.

    mod addGlobalVariable: inPos.
    mod addGlobalVariable: inColor.
    mod addGlobalVariable: outPerVertex.
    mod addGlobalVariable: outColor.

    "location = 0 → position, location = 1 → colour"
    mod addDecoration: inPos    id decoration: SpvDecoration location literals: (Array with: 0).
    mod addDecoration: inColor  id decoration: SpvDecoration location literals: (Array with: 1).
    mod addDecoration: outColor id decoration: SpvDecoration location literals: (Array with: 0).

    "--- constants ---"
    zero32    := cp constantFloat32: 0.0.
    one32     := cp constantFloat32: 1.0.
    zeroUInt32:= cp constantUInt32:  0.

    "--- function ---"
    fn := SpvFunction new
        id: mod newId; returnType: voidType; functionType: funcType;
        module: mod; initialize; yourself.
    mod addFunction: fn.
    blk := fn addBlock.

    "load inPos (vec2), expand to vec4 with z=0 w=1, store via AccessChain"
    posValId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad
        resultType: vec2 id resultId: posValId
        operands: (Array with: inPos id)).

    posXId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract
        resultType: f32 id resultId: posXId
        operands: (Array with: posValId with: 0)).

    posYId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract
        resultType: f32 id resultId: posYId
        operands: (Array with: posValId with: 1)).

    posVec4Id := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeConstruct
        resultType: vec4 id resultId: posVec4Id
        operands: (Array with: posXId with: posYId with: zero32 with: one32)).

    "store to gl_Position via AccessChain into member 0 of gl_PerVertex"
    posChainId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opAccessChain
        resultType: pOutVec4 id resultId: posChainId
        operands: (Array with: outPerVertex id with: zeroUInt32)).
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore
        operands: (Array with: posChainId with: posVec4Id)).

    "pass colour through unchanged"
    colorValId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad
        resultType: vec3 id resultId: colorValId
        operands: (Array with: inColor id)).
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore
        operands: (Array with: outColor id with: colorValId)).

    blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()).

    mod addEntryPoint: fn
        executionModel: SpvExecutionModel vertex
        name: 'main'
        interfaces: (Array with: inPos with: inColor with: outPerVertex with: outColor).

    ^ mod serialize    "=> ByteArray (SPIR-V binary)"
```

### Fragment shader

```smalltalk
buildFragmentShader
    | mod tr cp f32 vec3 vec4 pInVec3 pOutVec4
      voidType funcType inColor outColor one32
      fn blk colorValId rId gId bId outVec4Id |

    mod := SpvModule new initialize.
    mod addCapability: 1.
    mod setAddressingModel: 0 memoryModel: 1.

    tr := mod typeRegistry.
    cp := mod constantPool.

    f32    := tr floatType: 32.
    vec3   := tr vectorType: f32 count: 3.
    vec4   := tr vectorType: f32 count: 4.
    pInVec3  := tr pointerType: SpvStorageClass input  type: vec3.
    pOutVec4 := tr pointerType: SpvStorageClass output type: vec4.
    voidType := tr voidType.
    funcType := tr functionType: voidType paramTypes: #().

    inColor  := SpvGlobalVariable on: mod type: pInVec3  storageClass: SpvStorageClass input.
    outColor := SpvGlobalVariable on: mod type: pOutVec4 storageClass: SpvStorageClass output.
    mod addGlobalVariable: inColor.
    mod addGlobalVariable: outColor.
    mod addDecoration: inColor  id decoration: SpvDecoration location literals: (Array with: 0).
    mod addDecoration: outColor id decoration: SpvDecoration location literals: (Array with: 0).

    one32 := cp constantFloat32: 1.0.

    fn := SpvFunction new
        id: mod newId; returnType: voidType; functionType: funcType;
        module: mod; initialize; yourself.
    mod addFunction: fn.
    blk := fn addBlock.

    "load vec3 colour, extract r/g/b, construct vec4 with alpha=1"
    colorValId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad
        resultType: vec3 id resultId: colorValId
        operands: (Array with: inColor id)).

    rId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract
        resultType: f32 id resultId: rId operands: (Array with: colorValId with: 0)).
    gId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract
        resultType: f32 id resultId: gId operands: (Array with: colorValId with: 1)).
    bId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract
        resultType: f32 id resultId: bId operands: (Array with: colorValId with: 2)).

    outVec4Id := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeConstruct
        resultType: vec4 id resultId: outVec4Id
        operands: (Array with: rId with: gId with: bId with: one32)).
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore
        operands: (Array with: outColor id with: outVec4Id)).
    blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()).

    mod addEntryPoint: fn
        executionModel: SpvExecutionModel fragment
        name: 'main'
        interfaces: (Array with: inColor with: outColor).
    mod addExecutionMode: fn mode: 7 literals: #().    "OriginUpperLeft"

    ^ mod serialize
```

Key rules for the SPIR-V builder:
- Every result needs a fresh ID from `mod newId`
- `SpvTypeRegistry` deduplicates — call `tr floatType: 32` as many times as
  you like, always returns the same type object
- `SpvConstantPool` deduplicates constants — `cp constantFloat32: 1.0` is
  idempotent
- `addEntryPoint:executionModel:name:interfaces:` must list every Input and
  Output global variable in `interfaces`
- Fragment shaders need `addExecutionMode: fn mode: 7 literals: #()` (mode 7
  = `OriginUpperLeft`)
- `mod serialize` validates then returns a `ByteArray`

---

## Step 11 — Create VkShaderModules

```smalltalk
| vertexShaderModule fragmentShaderModule |
vertexShaderModule   := VkShaderModule fromBytes: self buildVertexShader   device: ctx device.
fragmentShaderModule := VkShaderModule fromBytes: self buildFragmentShader device: ctx device.
```

`VkShaderModule>>initializeFromBytes:device:` calls `vkCreateShaderModule`.
Destroy after pipeline creation if memory is tight (they are no longer needed
once the pipeline is built), or keep alive and destroy with the scene.

---

## Step 12 — Create the VkCommandPool

```smalltalk
| commandPool |
commandPool := VkCommandPool on: ctx device queueFamilyIndex: ctx computeQueueFamily.
```

Created with `RESET_COMMAND_BUFFER_BIT` so individual command buffers can be
re-recorded each frame without resetting the whole pool.

---

## Step 13 — Create the VkGraphicsPipeline

```smalltalk
| pipeline |
pipeline := VkGraphicsPipeline
    createDevice: ctx device
    renderPass: renderPass
    vertexModule: vertexShaderModule
    fragmentModule: fragmentShaderModule
    extent: ext.
```

The pipeline is configured with:
- Two shader stages: vertex (`VkShaderStage vertexBit`) + fragment
  (`VkShaderStage fragmentBit`)
- Vertex input: one binding at stride 20 (5 floats per vertex), two
  attributes:
  - location 0: `VkFormat r32g32Sfloat` at offset 0 (xy position)
  - location 1: `VkFormat r32g32b32Sfloat` at offset 8 (rgb colour)
- `topology = VkRenderConfig primitiveTopologyTriangleList`
- Viewport and scissor are dynamic (set per-frame via `setViewport:` /
  `setScissor:`)
- Rasterization: filled polygons, no culling, no depth bias
- Multisample: `VkRenderConfig sampleCount1Bit`
- Colour blend attachment: blending disabled,
  `colorWriteMask = VkRenderConfig colorWriteMaskRGBA`
- An empty pipeline layout (no descriptor sets for this pass-through shader)

---

## Step 14 — Upload the vertex buffer

Vertex data layout: 3 vertices × 5 floats = 60 bytes.
Each vertex: `[x f32] [y f32] [r f32] [g f32] [b f32]`.

```smalltalk
| vertexBuffer data |
data := ByteArray new: 60.

"Helper: write IEEE 754 float little-endian at byte offset"
putFloat: aFloat into: data at: offset [
    | bits |
    bits := aFloat asIEEE32BitWord.
    data at: offset   put: (bits bitAnd: 16rFF).
    data at: offset+1 put: ((bits >> 8)  bitAnd: 16rFF).
    data at: offset+2 put: ((bits >> 16) bitAnd: 16rFF).
    data at: offset+3 put: ((bits >> 24) bitAnd: 16rFF) ]

"Vertex 0: top-center, red"
self putFloat: -0.5 into: data at:  1.    "x"
self putFloat:  0.5 into: data at:  5.    "y"
self putFloat:  1.0 into: data at:  9.    "r"
self putFloat:  0.0 into: data at: 13.    "g"
self putFloat:  0.0 into: data at: 17.    "b"

"Vertex 1: bottom-right, green"
self putFloat:  0.5 into: data at: 21.
self putFloat:  0.5 into: data at: 25.
self putFloat:  0.0 into: data at: 29.
self putFloat:  1.0 into: data at: 33.
self putFloat:  0.0 into: data at: 37.

"Vertex 2: bottom-left, blue"
self putFloat:  0.0 into: data at: 41.
self putFloat: -0.5 into: data at: 45.
self putFloat:  0.0 into: data at: 49.
self putFloat:  0.0 into: data at: 53.
self putFloat:  1.0 into: data at: 57.

vertexBuffer := VkBuffer on: ctx device size: 60 usage: 128.
"usage 128 = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT"
vertexBuffer allocate.
vertexBuffer copyFromByteArray: data.
```

`allocate` creates the `VkBuffer` + `VkDeviceMemory` with
`VkMemoryProperty hostVisibleAndCoherent` backing. `copyFromByteArray:`
maps, copies, and unmaps in one call.

---

## Step 15 — Create synchronisation objects

One semaphore signals that the swapchain image is ready for rendering.
One semaphore signals that rendering is done and the image can be presented.
One fence lets the CPU wait for the previous frame to finish before recording
the next one.

```smalltalk
| imageAvailable renderFinished inFlightFence |
imageAvailable := VkSemaphoreWrapper createDevice: ctx device.
renderFinished := VkSemaphoreWrapper createDevice: ctx device.
inFlightFence  := VkFenceWrapper createSignaledDevice: ctx device.
```

`createSignaledDevice:` creates the fence in the signaled state so the
first `waitTimeout:` in the render loop returns immediately.

---

## Step 16 — The render loop

```smalltalk
renderFrame [
    | imageIndex cb |

    "Wait for previous frame. Timeout = UINT64_MAX = wait forever."
    inFlightFence waitTimeout: 16rFFFFFFFFFFFFFFFF.
    inFlightFence reset.

    "Acquire the next presentable swapchain image."
    imageIndex := swapchain acquireNextImage: imageAvailable handle fence: ExternalAddress null.

    "Allocate + record a command buffer."
    cb := commandPool allocateBuffer.
    cb do: [:c |
        c beginRenderPass: renderPass
          framebuffer: (framebuffers at: imageIndex + 1)    "1-indexed"
          extent: ext.
        c bindGraphicsPipeline: pipeline.
        c setViewport: ext.
        c setScissor: ext.
        c bindVertexBuffer: vertexBuffer.
        c draw: 3].                                          "3 vertices"

    "Submit: wait on imageAvailable, signal renderFinished, signal fence."
    ctx computeQueue
        submitGraphics: cb
        waitSemaphore: imageAvailable
        signalSemaphore: renderFinished
        fence: inFlightFence.

    "Present."
    swapchain present: imageIndex queue: ctx computeQueue waitSemaphore: renderFinished handle.
]
```

### What each step does

| Call | Effect |
|---|---|
| `inFlightFence waitTimeout:` | CPU blocks until GPU finished previous frame |
| `inFlightFence reset` | Unsignal the fence so `submitGraphics:` can signal it again |
| `swapchain acquireNextImage:fence:` | Gets next image index; `imageAvailable` signals when GPU can write |
| `commandPool allocateBuffer` | Allocates a fresh `VkCommandBuffer` |
| `cb do: [...]` | Calls `begin`, runs the block, calls `end` |
| `beginRenderPass:framebuffer:extent:` | Clears the image (black), begins the subpass |
| `bindGraphicsPipeline:` | Binds the graphics PSO |
| `setViewport:` / `setScissor:` | Dynamic state: full-window viewport and scissor |
| `bindVertexBuffer:` | Binds binding 0 to the vertex buffer |
| `draw: 3` | Draws 3 vertices (1 triangle), 1 instance |
| `submitGraphics:...` | `vkQueueSubmit2` with sync2 semaphore info |
| `swapchain present:...` | `vkQueuePresentKHR` — displays the image |

`cb do:` also implicitly ends the render pass before `end` because
`beginRenderPass:` and `endRenderPass` bracket the recording block. Wait —
`endRenderPass` is actually called by the command buffer's `end` method
only if explicitly issued. In the current implementation the render pass
is ended by the driver at `vkEndCommandBuffer` via implicit subpass end.
Actually looking at the code, `beginRenderPass:` calls
`vkCmdBeginRenderPass` but there is no explicit `vkCmdEndRenderPass` call
visible. Check `VkCommandBuffer>>end` if needed, or add `c endRenderPass`
before the block closes.

---

## Step 17 — Destroy everything (reverse order)

Always destroy in reverse creation order to avoid dangling references:

```smalltalk
inFlightFence   destroy.
renderFinished  destroy.
imageAvailable  destroy.
vertexBuffer    destroy.
pipeline        destroy.    "also destroys the embedded empty layout"
fragmentShaderModule destroy.
vertexShaderModule   destroy.
commandPool     destroy.
framebuffers do: [:fb | fb destroy].
renderPass      destroy.
swapchain       destroy.    "destroys image views first, then swapchain"
surface         destroy.
ctx             destroy.    "destroys device, then instance"
```

`VkContext>>destroy` destroys the device (`vkDestroyDevice`) then the
instance (`vkDestroyInstance`). It does not destroy the surface — you must
destroy the surface **before** the instance.

---

## Full example — wiring it all together

`PVHelloTriangleScene` encapsulates all the steps above:

```smalltalk
"Setup"
PVVulkanDriver install.
attrs := PVWindowAttributes newVulkan.
attrs title: 'Hello Triangle'; extent: 800@600; windowCentered: true.
win := OSWindow createWithAttributes: attrs.
backendWin := win backendWindow.

ctx   := VkContext graphicsContextForExtensions: backendWin requiredInstanceExtensions.
scene := PVHelloTriangleScene prepare: ctx backendWindow: backendWin.

"Render loop — run for 300 frames then exit"
1 to: 300 do: [:i | scene renderFrame].

"Teardown"
ctx computeQueue waitIdle.
scene destroy.
ctx destroy.
win destroy.
PVVulkanDriver uninstall.
```

`PVHelloTriangleScene>>prepare:backendWindow:` is a factory that calls
`initializeCtx:backendWindow:` which runs all steps 5–15 internally. The
render loop calls `renderFrame` which is step 16.

---

## Extending with custom geometry

To render different geometry, subclass `PVHelloTriangleScene` and override
`buildVertexData` and the vertex count passed to `draw:`:

```smalltalk
MyScene subclass: #PVHelloTriangleScene
    instanceVariableNames: ''
    ...

MyScene >> buildVertexData [
    "Return a ByteArray with your vertex data.
     Layout must match the pipeline: [x f32][y f32][r f32][g f32][b f32]
     per vertex, stride 20 bytes."
    ^ ...
]

MyScene >> renderFrame [
    "Same as super but with different vertex count."
    | imageIndex cb |
    inFlightFence waitTimeout: 16rFFFFFFFFFFFFFFFF.
    inFlightFence reset.
    imageIndex := swapchain acquireNextImage: imageAvailable handle fence: ExternalAddress null.
    cb := commandPool allocateBuffer.
    cb do: [:c |
        c beginRenderPass: renderPass framebuffer: (framebuffers at: imageIndex + 1) extent: swapchain extent.
        c bindGraphicsPipeline: pipeline.
        c setViewport: swapchain extent.
        c setScissor: swapchain extent.
        c bindVertexBuffer: vertexBuffer.
        c draw: myVertexCount].
    ctx computeQueue submitGraphics: cb waitSemaphore: imageAvailable signalSemaphore: renderFinished fence: inFlightFence.
    swapchain present: imageIndex queue: ctx computeQueue waitSemaphore: renderFinished handle.
]
```

To add a uniform buffer or texture, you will need to:
1. Add a `VkDescriptorSetLayout` with the appropriate bindings
2. Create a `VkPipelineLayout` wrapping that layout
3. Pass the layout to `VkGraphicsPipeline` (modify `initializeDevice:...`)
4. Allocate a `VkDescriptorPool` + `VkDescriptorSet`
5. Update the descriptor set with the buffer/image view
6. Add `cb bindDescriptorSets: ... pipelineLayout: ...` to the render loop
   (using bind point 0 = graphics, not 1 = compute)

---

## Synchronisation summary

```
Frame N:                           Frame N+1:
  waitFence  ←──────────────────────────────────────────────────┐
  resetFence                                                     │
  acquireImage ── imageAvailable(semaphore) ──► GPU starts      │
                                                renderPass       │
  submitGraphics:                              ...               │
    wait:   imageAvailable                    done              │
    signal: renderFinished ──────────────────► present          │
    fence:  inFlightFence ──────────────────────────────────────┘
  present: waitSemaphore: renderFinished
```

The fence serialises CPU frames. The two semaphores serialise GPU stages
(acquire → render → present). All semaphore stage masks use
`VkPipelineStage2 colorAttachmentOutputBit`.
