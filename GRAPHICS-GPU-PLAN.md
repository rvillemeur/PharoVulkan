# Plan — real GPU coverage for the graphics path

Written 10 October 2026. Every fact in the "Verified state" section was read out of the live
image on that date, so no one has to re-derive it.

This plan is written to be executed by someone — or some model — who has not seen the survey
that produced it. It names the selectors to add, the structure layouts to write, the tests to
write first and the assertions they make. Where a value could not be confirmed on this machine,
the plan says so and gives the step that confirms it.

---

## 1. The gap this plan closes

`PVGraphicsTest` has fourteen tests. None of them touches a GPU:

- four build shader modules and hand the bytes to `spirv-val`
  (`testVertexShaderBuilds`, `testFragmentShaderBuilds`, `testGlslSceneVertexShaderBuilds`,
  `testGlslSceneFragmentShaderBuilds`);
- one asserts the vertex data is 60 bytes (`testVertexDataSize`);
- the rest drive the scene lifecycle and the OSWindow driver through two stubs,
  `PVRecordingContextStub` and `PVFailingTriangleSceneStub`.

No test creates an instance, a device, a surface, a swapchain, a render pass, a framebuffer or a
frame. Phase 6's actual deliverable — a triangle on the screen, stable over frames — is checked
only by a human running the README playground snippet.

The compute path is in the opposite position: `PVComputeTest` dispatches on the device and
compares against a CPU reference, which is what made every Phase 7 claim honest.

So today a green suite says nothing about whether this project can draw. That is the gap.

---

## 2. Verified state of the image

### 2.1 What already exists and will be reused

| Thing | Where | Note |
| --- | --- | --- |
| Memory allocate-and-bind pattern | `VkBuffer >> allocate` | hand-written `VkBufferCreateInfo`, then `getBufferMemoryRequirements`, `findMemoryType:properties:`, `allocateMemory:`, `bindBufferMemory:` |
| Image view creation | `VkSwapchain >> createImageViews` | 80-byte `VkImageViewCreateInfo` per swapchain image; the offscreen path needs the same for one image |
| Render pass | `VkRenderPass class >> createColorPassDevice:format:` → `initializeDevice:format:` | `finalLayout` hardcoded to `VkImageLayout presentSrcKHR` |
| Framebuffer | `VkFramebuffer class >> on:renderPass:imageView:width:height:` | takes a bare image view, so it works for an offscreen image unchanged |
| Command pool and buffer | `VkCommandPool class >> on:queueFamilyIndex:`, `allocateBuffer`, `reset`; `VkCommandBuffer >> do:` | `do:` wraps begin/end |
| Command recording | `VkCommandBuffer >> beginRenderPass:framebuffer:extent:`, `bindGraphicsPipeline:`, `setViewport:`, `setScissor:`, `bindVertexBuffer:`, `draw:`, `endRenderPass` | clear colour hardcoded `0,0,0,1` inside `beginRenderPass:framebuffer:extent:` |
| Pipeline | `VkGraphicsPipeline class >> createDevice:renderPass:vertexModule:fragmentModule:extent:` | surface-free already |
| Shader modules | `VkShaderModule class >> fromBytes:device:` | |
| Semaphore-free submit | `VkQueue >> submit:andWait:` | `VK_STRUCTURE_TYPE_SUBMIT_INFO_2`, then `waitIdle` |
| Host readback of a buffer | `VkBuffer >> map`, `unmap`, `copyToByteArray`, `getF32s`, `elementsAs:` | `copyToByteArray` answers a `ByteArray` of the whole buffer |
| Capability-based device choice | `VkContext class >> computeContextRequiring:`, `VkContext >> deviceRequirements`, `deviceSatisfiesRequirements:`, `unsatisfiedRequirementsMessage` | added in 7-H |
| Capability predicate precedent | `VkPhysicalDevice >> supportsCooperativeMatrix`, `supportsSubgroupArithmetic`, `supportsVulkanMemoryModel` | |
| Handle class for images | `VkImage_H` | exists already |
| Driver install/uninstall | `PVVulkanDriver class >> installDuring:` | |

Queue families, measured: `findGraphicsQueueFamily` prefers a family with both the graphics and
compute bits (`(flags bitAnd: 3) = 3`) and falls back to graphics only; `findComputeQueueFamily`
takes the first family with bit 2. On the Intel Iris Plus in this machine both answer 0, so
`VkContext computeContext` already hands back a queue that can draw — but nothing in the code
says that is required, which is what phase G-1 fixes.

`VkContext >> fetchGraphicsQueue` and `fetchComputeQueue` are byte-identical: both read queue
family `computeQueueFamily` into the `computeQueue` slot. That is not a bug this plan fixes; it
is why an offscreen context can simply use `ctx computeQueue`.

### 2.2 What is missing

Bindings absent from `Vk` (82 class-side selectors today):

- `vkCreateImage`, `vkDestroyImage`, `vkGetImageMemoryRequirements`, `vkBindImageMemory`
- `vkCmdCopyImageToBuffer`
- `vkCmdPipelineBarrier2`

Classes absent: a `VkImage` wrapper, an offscreen render target, an offscreen scene.

Constants absent:

| Class | Has today | Needs adding |
| --- | --- | --- |
| `VkImageLayout` | `undefined` (0), `colorAttachmentOptimal` (2), `presentSrcKHR` (1000001002) | `transferSrcOptimal` (6) |
| `VkImageUsage` | `colorAttachmentBit` (16) | `transferSrcBit` (1) |
| `VkMemoryProperty` | `hostVisibleAndCoherent` (**3** — see 2.4) | `deviceLocalBit` (1), `hostVisibleBit` (2), `hostCoherentBit` (4) |
| `VkFormat` | `b8g8r8a8Unorm` (44), `r32g32Sfloat`, `r32g32b32Sfloat` | nothing for this plan |
| `VkStructureType` | 49 entries, incl. `imageViewCreateInfo` (15), `submitInfo2` (1000314004) | `imageCreateInfo` (14), `memoryBarrier2` (1000314000), `dependencyInfo` (1000314003) |
| new `VkImageType` | — | `type2D` (1) |
| new `VkImageTiling` | — | `optimal` (0) |
| new `VkPipelineStage2` | — | `allTransferBit` (16r1000), `hostBit` (16r4000) |
| new `VkAccess2` | — | `transferWriteBit` (16r1000), `hostReadBit` (16r2000) |
| new `VkBufferUsage` | — | `transferDstBit` (2) |

Constants classes live in package `PharoVulkan`, tag `Constants`, as plain `Object` subclasses
with class-side methods — `VkImageLayout`, `VkImageUsage`, `VkMemoryProperty`, `VkRenderConfig`,
`VkFormat`, `VkAttachmentOp`, `VkShaderStage`, `VkStructureType`, `VkApiVersion`. Put the new
ones there, not in a new home.

### 2.3 Structure-type values, and how to check the three unconfirmed ones

Read from the image: `submitInfo2` = 1000314004, `semaphoreSubmitInfo` = 1000314005,
`commandBufferSubmitInfo` = 1000314006, `imageViewCreateInfo` = 15. The
`VK_KHR_synchronization2` block is contiguous and ordered `MEMORY_BARRIER_2`,
`BUFFER_MEMORY_BARRIER_2`, `IMAGE_MEMORY_BARRIER_2`, `DEPENDENCY_INFO`, `SUBMIT_INFO_2`,
`SEMAPHORE_SUBMIT_INFO`, `COMMAND_BUFFER_SUBMIT_INFO`, which those three known values confirm.
So `memoryBarrier2` is 1000314000 and `dependencyInfo` is 1000314003, and `imageCreateInfo` is
14, one below `imageViewCreateInfo`.

The Vulkan headers are **not** installed on this machine (`/usr/include/vulkan/vulkan_core.h`
does not exist), so none of this can be grepped. The check is behavioural: a wrong `sType` makes
the driver answer a non-zero `VkResult` at once and `Vk checkResult:` raises, so the first test
that creates an image or submits a barrier is the confirmation. If one of them fails, re-derive
the value — do not paper over it by changing a structure size.

### 2.4 A defect this survey found: `VkMemoryProperty hostVisibleAndCoherent` answers 3

`VkMemoryProperty class >> hostVisibleAndCoherent` is `^ 3`. The Vulkan bits are `DEVICE_LOCAL`
1, `HOST_VISIBLE` 2, `HOST_COHERENT` 4, so 3 asks for device-local **and** host-visible and
never asks for coherent, which is the one property the name promises and the one `map`/`unmap`
depends on. `VkBuffer >> allocate` passes it for every buffer in the project.

It works here by luck: on this integrated GPU every host-visible memory type is also coherent
and device-local. On a discrete GPU, 3 selects a BAR heap that need not be coherent, and a
readback would be allowed to answer stale bytes — exactly the failure a pixel assertion would
report as "the GPU drew the wrong thing".

This is a real bug, so it gets a failing test first, and it must land before any pixel assertion
is trusted. It is phase G-0.

### 2.5 Ground truth for pixel assertions

`PVHelloTriangleScene >> buildVertexData` writes 60 bytes: three vertices of `x y r g b` as
`float32`, namely `(-0.5, 0.5)` red `(1,0,0)`, `(0.5, 0.5)` green `(0,1,0)`, `(0.0, -0.5)` blue
`(0,0,1)`. `buildFragmentShader` passes the interpolated `vec3` through and writes alpha `1.0`.
`beginRenderPass:framebuffer:extent:` clears to `(0.0, 0.0, 0.0, 1.0)`.

Vulkan clip space has y pointing down and the vertex shader applies no transform, so `(-0.5,
0.5)` should land at the bottom left of the image and `(0.0, -0.5)` at the top centre. A test
that asserts which corner is red is asserting the y direction, which is worth having — but write
it from a measured render, not from this paragraph: render once, inspect the pixels, then write
the assertion the picture justifies, and name the observed direction in the test comment.

The swapchain format on this machine is `b8g8r8a8Unorm` (44), so bytes come back in **B, G, R,
A** order. Use that format for the offscreen image too, so both paths agree, and convert to
named channels in one place rather than indexing raw bytes in each test.

### 2.6 Conventions every phase obeys (read before writing any code)

- **Edit through the image.** `mcp__pharo__compile_method`, `class_create`, `delete_method`,
  `class_comment`. Never edit `src/**.class.st`; it is Iceberg's export artefact. Never call
  `TonelWriter` or `fileOut`. Iceberg manages commits; do not use git directly.
- **CR line endings** when multi-line source goes through `evaluate_pharo`: join with
  `String cr`. `compile_method` normalises LF itself.
- **The cycle, every time: red, green, refactor, example, view, critics.** A unit is not done
  until the failing test existed first, the suite is green, a class-side `<sampleInstance>`
  example exists, an `<inspectorPresentationOrder:title:>` view exists, and `run_critics` is
  clean on what changed.
- **Examples live on the class they exemplify**, class-side, no argument, rebuilding the object
  each call, asserting nothing, one click from the browser. This project has no `-Examples`
  package; the pattern to copy is `VkBuffer class >> exampleStorageBufferOfFourFloats`, which
  creates a context, builds the object, destroys both in an `ensure:` and still answers an
  object whose inspector says something useful. An example that opens a window is named `open…`,
  except the one that already exists (`PVHelloTriangleScene class >> renderTriangle`).
- **Views never mutate the inspected object** and ask the real rule rather than restating it.
  `PVHelloTriangleScene >> inspectorLifecycle:` reflects over `allInstVarNames` through
  `lifecycleReport`; `VkPhysicalDevice >> inspectorCompute:` asks the same accessors the
  compiler asks. Copy that habit: a pixel view samples kept bytes, it never submits work.
- **No magic values.** Named class-side constant in the matching `Vk…` class in the `Constants`
  tag.
- **Every new class gets a class comment** — one paragraph, purpose and key methods. Comments
  say why, never what.
- **Hand-written structures**: `ExternalAddress allocate: <size>`, a comment header listing the
  **1-based** offsets as `VkBuffer >> allocate` does, every field written explicitly including
  the zeros, `ensure: [ … free ]` around each buffer, `Vk checkResult:` on every result.
  Pointers with `pointerAt:put:`, 32-bit fields with `unsignedLongAt:put:`, 64-bit with
  `unsignedLongLongAt:put:`, floats with `floatAt:put:`.
- **Test placement**: `VkCoreTest` (tag `Core`) for context, device and image facts,
  `VkBindingsTest` (tag `Bindings`) for raw binding facts, `PVGraphicsTest` (tag `Graphics`) for
  scenes, targets and pixels. The device-test pattern is `PVComputeTest >> setUp`: build the
  context in `setUp`, `ctx destroy` in `tearDown`.
- **A capability that may be missing is asked, and the reason stated.**
  `PVComputeTest >> testMatmulF16OnDeviceHoldsAtTheBenchmarkSize` opens with
  `ctx halfPrecisionAvailable ifFalse: [ ^ self skip ]`. Do the same for a display and for any
  format a device refuses, and say in the comment what the skip costs.
- **Suite gate after every phase.** Run the whole project as a real `TestSuite` over the
  concrete test classes — `PVCompilerTest`, `PVComputeTest`, `PVGraphicsTest`,
  `PVSpirvValidatorTest`, `SpvBuilderTest`, `SpvEmitterTest`, `VkBindingsTest`, `VkCoreTest` —
  257 tests as of 7-H. Never a package-level count: `PVSubgroupDotProduct` has a concrete
  subclass stub, so package-level numbers double-count.
- **Fresh image before GPU graphics work.** `VkHandle >> finalize` is a no-op and the window
  path installs a driver, so run the window examples in a fresh image, as the README tip says.

---

## 3. Phase G-0 — `hostVisibleAndCoherent` must ask for coherent

**Goal.** Make mapped memory mean what its name says, before any assertion depends on reading
mapped memory back.

**Why first.** Phases G-3 and G-4 assert bytes read through `map`. If the memory type need not be
coherent, a wrong byte is ambiguous between a bad render and a missing flush. Removing that
ambiguity costs one constant.

1. **Red.** `VkCoreTest >> testHostVisibleAndCoherentAsksForBothProperties`:

   ```smalltalk
   self
     assert: (VkMemoryProperty hostVisibleAndCoherent bitAnd: VkMemoryProperty hostVisibleBit)
     equals: VkMemoryProperty hostVisibleBit.
   self
     assert: (VkMemoryProperty hostVisibleAndCoherent bitAnd: VkMemoryProperty hostCoherentBit)
     equals: VkMemoryProperty hostCoherentBit
   ```

   Red twice over today: the two bit constants do not exist, and 3 does not carry bit 4.
2. **Green.** Add `deviceLocalBit` (1), `hostVisibleBit` (2), `hostCoherentBit` (4), each with
   its spec name in a comment, and make `hostVisibleAndCoherent` answer
   `self hostVisibleBit bitOr: self hostCoherentBit`.
3. **Second test, on the device.** `VkCoreTest >> testStorageBufferMemoryTypeIsCoherent`: build
   `VkBuffer storageBuffer: 4 on: ctx device`, then assert the memory type
   `findMemoryType:properties:` chose reports `hostCoherentBit`. This needs a reader for a
   type's flags, so add `VkPhysicalDevice >> memoryPropertyFlagsOfType: anIndex` using the same
   arithmetic `findMemoryType:properties:` already uses (`memoryProperties unsignedLongAt:
   5 + (i * 8)`), and have `findMemoryType:properties:` call it, so the two cannot disagree.
4. **Smoke.** Run `PVComputeTest` in full: every compute buffer in the project goes through this
   path, so a regression shows there first.
5. **Example.** `VkPhysicalDevice class >> exampleMemoryTypesOfThisMachine` — `<sampleInstance>`,
   builds a context, answers the physical device so the memory view opens, destroys the context
   in an `ensure:`. Follow `VkPhysicalDevice class >> exampleExtensionsOfThisMachine`.
6. **View.** `VkPhysicalDevice >> inspectorMemoryTypes:` — one row per memory type with its
   index, decoded property-flag names and heap index, plus a column saying whether
   `findMemoryType:properties:` would pick it for `hostVisibleAndCoherent`. That column calls
   the real selector; it does not restate the rule.
7. `run_critics` on `VkMemoryProperty`, `VkPhysicalDevice`, `VkBuffer`. Suite gate.

**Done when** the constant asks for coherent memory, a device test proves the chosen type has
it, and the compute suite is unchanged.

---

## 4. Phase G-1 — a graphics-capable context with no window

**Goal.** Make "a device that can draw" something the code requires and states, not something
the first enumerated device happens to be. This is the 7-H capability mechanism applied to
graphics.

**Why now.** Every later phase needs a context with a graphics-capable queue and no surface.
`graphicsContextForExtensions:` demands window extensions; `computeContext` works here only by
coincidence.

1. **Red.** `VkCoreTest >> testOffscreenGraphicsContextQueueCanDraw`:

   ```smalltalk
   | context |
   context := VkContext offscreenGraphicsContext.
   [ self assert: context physicalDevice supportsGraphics.
     self
       assert: context computeQueueFamily
       equals: context physicalDevice findGraphicsQueueFamily ] ensure: [ context destroy ]
   ```

   Fails today: neither `offscreenGraphicsContext` nor `supportsGraphics` exists.
2. **Green.**
   - `VkPhysicalDevice >> supportsGraphics` — `^ self findGraphicsQueueFamily notNil`.
   - `VkPhysicalDevice >> supportsGraphicsAndComputeOnOneQueue` — whether
     `findGraphicsQueueFamily` equals `findComputeQueueFamily`, both non-nil. This is the
     requirement the offscreen context actually needs, because `selectPhysicalDevice` takes its
     queue family from `findComputeQueueFamily` and the scene submits graphics work on that
     queue.
   - `VkContext class >> offscreenGraphicsContext` —
     `^ self computeContextRequiring: #( #supportsGraphicsAndComputeOnOneQueue )`. Comment why: a
     device whose graphics and compute families differ would need a second queue, which this
     context does not create, so it does not qualify rather than failing later.
3. **Second red, then green.** `VkCoreTest >> testUnsatisfiableGraphicsRequirementNamesItself`:
   requiring a predicate no device answers raises `VkError` whose message contains the selector
   name. `unsatisfiedRequirementsMessage` already builds that string; this pins it for a
   graphics requirement, and pins that an unknown predicate raises rather than silently failing
   the device — `deviceSatisfiesRequirements:` already does the latter.
4. **Example.** `VkContext class >> exampleOffscreenContextOnThisMachine` — `<sampleInstance>`,
   builds the context, reads `chosenDeviceName` and the queue families, destroys it and answers
   it, following `exampleDeviceChosenByCapabilityOnThisMachine`.
5. **View.** `VkPhysicalDevice >> inspectorQueueFamilies:` — one row per family index with its
   queue flags decoded by name and two columns saying whether `findGraphicsQueueFamily` and
   `findComputeQueueFamily` chose it. Note: `fetchQueueFamilyProperties` keeps only the flags
   word of each family, so a queue-count column would need that method widened. Widening is a
   code change without a bug behind it, so leave the column out and say why in the comment.
6. `run_critics` on `VkContext`, `VkPhysicalDevice`. Suite gate.

**Done when** a test proves the context handed back can draw, on any machine, with no window and
no surface extensions.

---

## 5. Phase G-2 — `VkImage`: a colour attachment this project owns

**Goal.** Allocate an image and its memory outside a swapchain, so there is something to render
into that the host can later read.

**New class.** `VkImage`, superclass `Object`, package `PharoVulkan`, tag `Graphics`, instance
variables `device format extent usage handle memory view memorySize`. Class comment: the
swapchain owns its images, so rendering without a surface needs an image this project creates,
allocates, views and destroys itself.

In Pharo 13 `subclass:instanceVariableNames:…` is gone; `Object << #VkImage` gives a builder
that needs `install` — or use `mcp__pharo__class_create`.

1. **Red.** `VkCoreTest >> testColorAttachmentImageIsCreatedAndBound`, with `ctx` built in
   `setUp` by `VkContext offscreenGraphicsContext`:

   ```smalltalk
   | image |
   image := VkImage
              on: ctx device
              format: VkFormat b8g8r8a8Unorm
              extent: 64 @ 64
              usage: (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
   [ self deny: image handle getHandle isNull.
     self assert: image extent equals: 64 @ 64.
     self assert: image format equals: VkFormat b8g8r8a8Unorm ] ensure: [ image destroy ]
   ```
2. **Green: four bindings** on `Vk`, class side, in the exact `ffiCall:` shape of
   `createImageView:createInfo:allocator:pView:`:

   ```smalltalk
   createImage: device createInfo: pCreateInfo allocator: pAllocator pImage: pImage
       ^ self ffiCall: #( int32 vkCreateImage (
           VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pImage ) )

   destroyImage: device image: image allocator: pAllocator
       ^ self ffiCall: #( void vkDestroyImage (
           VkDevice_H device, VkImage_H image, void* pAllocator ) )

   getImageMemoryRequirements: device image: image memoryRequirements: pRequirements
       ^ self ffiCall: #( void vkGetImageMemoryRequirements (
           VkDevice_H device, VkImage_H image, void* pRequirements ) )

   bindImageMemory: device image: image memory: memory memoryOffset: offset
       ^ self ffiCall: #( int32 vkBindImageMemory (
           VkDevice_H device, VkImage_H image, VkDeviceMemory_H memory, uint64 offset ) )
   ```

   Check the handle-class names and the `uint64` spelling against the twin binding
   `bindBufferMemory:buffer:memory:memoryOffset:` before compiling.
3. **Green: `VkImageCreateInfo`, 88 bytes**, 1-based offsets as the comment header must list
   them:

   | Offset | Field | Value |
   | --- | --- | --- |
   | 1 | sType | `VkStructureType imageCreateInfo` |
   | 9 | pNext | `ExternalAddress null` |
   | 17 | flags | 0 |
   | 21 | imageType | `VkImageType type2D` |
   | 25 | format | the format argument |
   | 29, 33, 37 | extent width, height, depth | `extent x`, `extent y`, 1 |
   | 41 | mipLevels | 1 |
   | 45 | arrayLayers | 1 |
   | 49 | samples | `VkRenderConfig sampleCount1Bit` |
   | 53 | tiling | `VkImageTiling optimal` |
   | 57 | usage | the usage argument |
   | 61 | sharingMode | `VkRenderConfig sharingModeExclusive` |
   | 65 | queueFamilyIndexCount | 0 |
   | 73 | pQueueFamilyIndices | `ExternalAddress null` |
   | 81 | initialLayout | `VkImageLayout undefined` |

   Offsets 69 and 85 are padding; do not write them. If the driver rejects the structure,
   suspect this table before anything else: a non-zero `VkResult` out of `vkCreateImage` on a
   plausible-looking call is nearly always a layout error.
4. **Green: `VkImage >> allocate`**, mirroring `VkBuffer >> allocate` from its
   `getBufferMemoryRequirements` line down: 24-byte `VkMemoryRequirements` (1 size u64,
   9 alignment u64, 17 memoryTypeBits u32), then
   `findMemoryType: (memReqs unsignedLongAt: 17) properties: VkMemoryProperty deviceLocalBit`,
   a 32-byte `VkMemoryAllocateInfo` (1 sType, 9 pNext, 17 allocationSize u64, 25
   memoryTypeIndex), `allocateMemory:`, then `bindImageMemory:`. Keep the size the driver asked
   for in `memorySize`; the view shows it.
5. **Green: `VkImage >> createView`** — the body of `VkSwapchain >> createImageViews` for one
   image, writing `handle getHandle` at offset 25, keeping and answering a `VkImageView_H`.
   `VkFramebuffer class >> on:renderPass:imageView:width:height:` takes that view unchanged.
6. **Green: `VkImage >> destroy`** — view, then image, then free the memory, nilling each slot
   so a second call is safe. Follow the `ifNotNil:` style of `PVHelloTriangleScene >> destroy`.
7. **Degenerate cases, each its own red test.**
   - `testImageDestroyIsIdempotent` — two `destroy` calls, no raise.
   - `testZeroExtentImageIsRefused` — `0 @ 0` raises `VkError`. Observe what the driver actually
     answers first and pin that, rather than asserting a result code from memory.
   - `testImageReportsTheMemorySizeTheDriverAsked` — `memorySize` is at least
     `width * height * 4`, which catches a `memoryTypeBits` read from the wrong offset.
8. **Format support is a question, not an assumption.** If a device refuses `b8g8r8a8Unorm` as a
   colour attachment with transfer-source usage, then — and only then — add
   `vkGetPhysicalDeviceFormatProperties`, a `VkPhysicalDevice >> supportsColorAttachmentFormat:`
   predicate, and a skip whose reason names the format. Do not add the binding speculatively:
   there is no bug until a device refuses.
9. **Example.** `VkImage class >> exampleColorAttachmentOnThisMachine` — `<sampleInstance>`,
   builds the offscreen context, creates a 64×64 image with a view, destroys both and answers
   the image, which still reports format, extent, usage and memory size.
10. **View.** `VkImage >> inspectorImage:` — format by name, extent, decoded usage bit names, the
    memory size the driver asked for, and whether a view exists. Reads slots only. A format name
    needs `VkFormat class >> nameForValue:`; copy `VkStructureType class >> nameForValue:`,
    which already exists and derives its answer from `constantSelectors` rather than a second
    table.
11. `run_critics` on `VkImage`, `Vk`, and the new constants classes. Suite gate.

**Done when** an image with its own memory can be created, viewed and destroyed on the device,
with no swapchain anywhere, and the degenerate cases are pinned.

---

## 6. Phase G-3 — readback, proven by a clear

**Goal.** Get pixels from the device to the host, and prove they are the pixels the GPU wrote.

**Why a clear before a triangle.** A clear needs no pipeline, no shaders and no vertex buffer. If
the triangle test came first, a failure would not say whether the readback or the draw was
wrong. One cleared image separates them for good.

**Why the clear colour must become a parameter.** It is hardcoded `(0,0,0,1)` inside
`beginRenderPass:framebuffer:extent:`. A black readback cannot be told apart from untouched
memory, so the first pixel assertion in the suite would be vacuous. That is a real coverage
defect, so it gets its own test first.

1. **Red.** `PVGraphicsTest >> testRenderPassClearsToTheColourItWasGiven`: render nothing into a
   target cleared to `(0.25, 0.5, 0.75, 1.0)`, then assert every sampled pixel is
   `(64, 128, 191, 255)` in R, G, B, A, within one unorm step. Expected bytes are
   `(value * 255) rounded`; allow ±1 and say in the comment that unorm rounding is
   driver-defined.
2. **Green: the clear colour parameter.** Add
   `VkCommandBuffer >> beginRenderPass:framebuffer:extent:clearColor:` taking an `Array` of four
   floats — the layer speaks in numbers, not in `Color` — and leave
   `beginRenderPass:framebuffer:extent:` delegating with `#( 0.0 0.0 0.0 1.0 )`. `find_senders`
   first: `PVHelloTriangleScene >> renderFrame` is the only sender and must keep working
   untouched.
3. **Green: the offscreen render pass.** `VkRenderPass class >>
   createOffscreenColorPassDevice:format:`. Extract the body of `initializeDevice:format:` into
   one method taking the final layout, so the two variants cannot drift: the window variant
   passes `VkImageLayout presentSrcKHR`, the offscreen one `VkImageLayout transferSrcOptimal`.
   The render pass therefore performs the layout transition itself and no barrier is needed
   before the copy — say that in the comment, because its absence otherwise looks like an
   omission.
4. **Green: two bindings.**

   ```smalltalk
   cmdCopyImageToBuffer: cmdBuf srcImage: image srcImageLayout: layout dstBuffer: buffer
       regionCount: count pRegions: pRegions
       ^ self ffiCall: #( void vkCmdCopyImageToBuffer (
           VkCommandBuffer_H cmdBuf, VkImage_H image, int32 layout,
           VkBuffer_H buffer, uint32 count, void* pRegions ) )

   cmdPipelineBarrier2: cmdBuf pDependencyInfo: pDependencyInfo
       ^ self ffiCall: #( void vkCmdPipelineBarrier2 (
           VkCommandBuffer_H cmdBuf, void* pDependencyInfo ) )
   ```

   `vkCmdPipelineBarrier2` is the core 1.3 entry point and `initializeCompute` creates the
   instance with `VkApiVersion vulkan13`, so no `KHR` suffix. If the symbol fails to resolve,
   fall back to `vkCmdPipelineBarrier2KHR` and record why in a comment.
5. **Green: `VkBufferImageCopy`, 56 bytes**, 1-based:

   | Offset | Field | Value |
   | --- | --- | --- |
   | 1 | bufferOffset (u64) | 0 |
   | 9 | bufferRowLength | 0 (tightly packed) |
   | 13 | bufferImageHeight | 0 |
   | 17 | imageSubresource.aspectMask | `VkRenderConfig imageAspectColorBit` |
   | 21 | mipLevel | 0 |
   | 25 | baseArrayLayer | 0 |
   | 29 | layerCount | 1 |
   | 33, 37, 41 | imageOffset x, y, z | 0, 0, 0 |
   | 45, 49, 53 | imageExtent width, height, depth | `extent x`, `extent y`, 1 |

   Wrap it in `VkCommandBuffer >> copyImage:layout:toBuffer:extent:`.
6. **Green: the host-read barrier.** `VkMemoryBarrier2`, 48 bytes: 1 sType
   (`VkStructureType memoryBarrier2`), 9 pNext, 17 srcStageMask (u64), 25 srcAccessMask (u64),
   33 dstStageMask (u64), 41 dstAccessMask (u64). `VkDependencyInfo`, 64 bytes: 1 sType
   (`dependencyInfo`), 9 pNext, 17 dependencyFlags 0, 21 memoryBarrierCount 1,
   25 pMemoryBarriers, 33 bufferMemoryBarrierCount 0, 41 pBufferMemoryBarriers null,
   49 imageMemoryBarrierCount 0, 57 pImageMemoryBarriers null.

   Masks: src stage `VkPipelineStage2 allTransferBit`, src access
   `VkAccess2 transferWriteBit`, dst stage `VkPipelineStage2 hostBit`, dst access
   `VkAccess2 hostReadBit`. They are 64-bit in synchronization2, so write them with
   `unsignedLongLongAt:put:`, and give each constant its spec name in a comment. A wrong mask is
   **not** reported by the driver, so if a readback is wrong, suspect the masks and the copy
   region in that order, and bisect by re-running with a deliberately conservative
   all-commands/all-access barrier before narrowing again.

   Wrap it in `VkCommandBuffer >> barrierForHostRead`, whose comment says why it is needed
   although `submit:andWait:` waits: that call waits with `waitIdle`, not with a fence, so the
   host-read availability the specification grants on fence signal is not what happens here.
7. **Green: `PVOffscreenTarget`.** Package `PharoVulkan`, tag `Graphics`, instance variables
   `device extent image renderPass framebuffer readbackBuffer clearColor pixelBytes`. Class
   comment: an offscreen target is what makes a rendered picture assertable, because a presented
   swapchain image cannot be read back.
   - `class >> on: aDevice extent: aPoint` — creates the image with colour-attachment plus
     transfer-source usage and its view, the offscreen render pass, the framebuffer, and a
     readback `VkBuffer` of `width * height * 4` bytes with `VkBufferUsage transferDstBit`.
     Guard with `ifCurtailed: [ target destroy ]`, as `PVHelloTriangleScene class >>
     prepare:backendWindow:` does, so a part-built target cannot strand Vulkan objects.
   - `clearColor:` — defaults to the scene's black, so a target behaves like the window path
     unless told otherwise.
   - `renderWith: aBlock on: aQueue pool: aCommandPool` — records begin-render-pass with the
     clear colour, evaluates `aBlock` with the command buffer so a caller can draw (G-4 uses
     this; G-3 passes an empty block), ends the render pass, copies the image to the readback
     buffer, adds the host-read barrier, submits with `submit:andWait:`, then reads
     `readbackBuffer copyToByteArray` into `pixelBytes`.
   - `pixels` — answers `pixelBytes`.
   - `pixelAtX: x y: y` — an `Array` of four integers in R, G, B, A order, converting from the
     format's B, G, R, A byte order in this one place. Coordinates outside the extent raise
     rather than reading a neighbouring row.
   - `destroy` — reverse order, nilling slots, safe twice. `pixelBytes` survives destruction on
     purpose, which is what lets the example answer a useful object.
8. **Degenerate cases.**
   - `testOffscreenTargetPixelOutsideTheExtentIsRefused`.
   - `testOffscreenTargetOfOnePixelReadsBack` — a 1×1 target. This catches a row pitch assumed
     from the width, or a copy region built from the wrong extent.
   - `testOffscreenTargetDestroyIsIdempotent`.
9. **Example.** `PVOffscreenTarget class >> exampleClearedTargetOnThisMachine` —
   `<sampleInstance>`, builds the offscreen context, clears a 32×32 target to a visibly
   non-black colour, destroys the Vulkan objects and answers the target, which still answers
   `pixels` from the bytes it kept.
10. **View.** `PVOffscreenTarget >> inspectorPixels:` — the readback as a grid of colour cells,
    or, if a swatch grid is awkward in this Spec2 version, a table of sampled coordinates with
    R, G, B, A and a colour cell. It reads `pixelBytes`; it never submits work and never re-maps
    the buffer, so opening the inspector cannot change what is inspected.
11. `run_critics` on `PVOffscreenTarget`, `VkRenderPass`, `VkCommandBuffer`, `Vk`, `VkBufferUsage`,
    `VkPipelineStage2`, `VkAccess2`. Suite gate.

**Done when** the suite asserts, on the device, the exact bytes of a non-black clear, and a 1×1
target reads back correctly.

---

## 7. Phase G-4 — the triangle, by pixel

**Goal.** Prove the hello-triangle path rasterises what it claims, with the assertions a human
currently makes by eye.

**Why it must share code with the window scene.** A separate offscreen copy of the pipeline setup
would prove only that the copy works. The test has to drive the same construction the window path
drives, or it says nothing about Phase 6.

1. **Refactor first, with the existing fourteen tests as the net.** Extract a superclass
   `PVTriangleScene` (package `PharoVulkan`, tag `Graphics`) from `PVHelloTriangleScene`, whose
   slots today are `ctx surface swapchain renderPass framebuffers commandPool
   vertexShaderModule fragmentShaderModule pipeline imageAvailable renderFinished inFlightFence
   vertexBuffer commandBuffer`.
   - superclass slots: `ctx renderPass commandPool commandBuffer vertexShaderModule
     fragmentShaderModule pipeline vertexBuffer`;
   - superclass methods: `buildVertexShader`, `buildFragmentShader`, `buildVertexData`,
     `putFloat:into:at:`, `waitForIdleGpu`, `lifecycleReport`, `inspectorLifecycle:`, the
     accessors, the shared half of initialisation and teardown, and class-side `liveLabel`,
     `releasedLabel`, `unownedSlotNames`;
   - `PVHelloTriangleScene` keeps `surface swapchain framebuffers imageAvailable renderFinished
     inFlightFence`, `initializeCtx:backendWindow:`, `renderFrame`, and its class side
     unchanged — `prepare:backendWindow:`, `renderTriangle`, `windowTitle`, `exampleExtent`,
     `exampleFrameCount`.

   Mechanics that matter:
   - `lifecycleReport` already reflects over `self class allInstVarNames`, so it keeps reporting
     every slot after the split, inherited ones included. `unownedSlotNames` stays `#( #ctx )`.
   - `destroy` splits into the superclass method, which releases the shared slots in reverse
     creation order, and a hook the subclass overrides for its presentation slots. The resulting
     order is fence, semaphores, framebuffers, swapchain, surface, then vertex buffer, pipeline,
     shader modules, command pool, render pass. That differs from today's order — framebuffers
     and swapchain now go before the render pass — and it is legal: destroying a framebuffer
     before the image views it references is the safer direction.
     `testSceneDestroyIsIdempotent` and `testLifecycleReportTracksReleasedSlots` are the guard.
   - `find_senders` on every moved selector before moving it. `PVGlslTriangleScene` is a
     subclass of `PVHelloTriangleScene` and overrides `buildVertexShader` and
     `buildFragmentShader`, so it must still find them.
   - Run the full suite after the move and before adding anything. The fourteen graphics tests
     passing is what says the extraction was faithful.
2. **Green: `PVOffscreenTriangleScene`**, subclass of `PVTriangleScene`, slot `target`.
   - `class >> on: aVkContext extent: aPoint` — build the offscreen render pass, the target, the
     command pool on `ctx computeQueueFamily`, the command buffer, the two shader modules, the
     pipeline from the offscreen render pass, and the vertex buffer (60 bytes,
     `VkBuffer on:size:usage:`), reusing the superclass's builders, with the same
     `ifCurtailed: [ scene destroy ]` guard.
   - `renderOnce` —
     `target renderWith: [ :c | c bindGraphicsPipeline: pipeline. c setViewport: target extent.
     c setScissor: target extent. c bindVertexBuffer: vertexBuffer. c draw: 3 ]
     on: ctx computeQueue pool: commandPool`. That block is the same sequence `renderFrame`
     records; if the two drift the test stops covering the window path, so say so in the
     comment.
   - `pixelAtX:y:` delegating to the target.
3. **Red, one fact per test**, all in `PVGraphicsTest`:
   - `testOffscreenTriangleLeavesTheCornersCleared` — all four corners equal the clear colour.
   - `testOffscreenTriangleCoversTheCentroid` — the centroid pixel is not the clear colour.
   - `testOffscreenTriangleCentroidMixesAllThreeVertexColours` — at the centroid the three
     channels are within a stated tolerance of each other and each is well above zero. Derive
     the tolerance from a measured render and say so in the comment.
   - `testOffscreenTriangleIsRedNearItsRedVertex`, and the green and blue twins — a pixel a few
     per cent of the extent inside each vertex is dominated by that vertex's colour. These pin
     the winding and the y direction; a symmetric assertion would pass with the picture upside
     down. Write them from an observed render and record which corner measured red.
   - `testOffscreenTriangleIsOpaqueEverywhere` — alpha 255 at every sampled point, cleared
     corners included.
4. **Then the GLSL-like shaders, same treatment.** `PVGlslTriangleScene` only validates its
   SPIR-V today. Move the two GLSL builder bodies to `PVGlslTriangleShaders class >>
   vertexShaderBytes` and `fragmentShaderBytes` (new class, tag `Graphics`), with
   `PVGlslTriangleScene`'s overrides delegating, so nothing is duplicated and the window path is
   unchanged. Then add `PVGlslOffscreenTriangleScene`, a subclass of `PVOffscreenTriangleScene`
   overriding the two builders the same way, and
   `testGlslSceneDrawsTheSamePictureAsTheHandBuiltShaders`: render both and compare every
   sampled point within a stated tolerance. That turns the vector-and-matrix DSL claim from
   "emits valid SPIR-V" into "draws the same picture".
5. **Example.** `PVOffscreenTriangleScene class >> exampleRenderedTriangleOnThisMachine` —
   `<sampleInstance>`, builds the context, renders once, destroys everything and answers the
   scene, so one click opens the pixel comparison view.
6. **View.** `PVOffscreenTriangleScene >> inspectorExpectedVersusMeasured:` — one row per sampled
   point (four corners, centroid, one near each vertex) with the measured colour, the name of
   the rule that point must satisfy, and its verdict. Factor each rule into a method the tests
   and the view both call, so the view cannot drift from the suite. It reads kept bytes and
   renders nothing.
7. `run_critics` on `PVTriangleScene`, `PVHelloTriangleScene`, `PVOffscreenTriangleScene`,
   `PVGlslTriangleScene`, `PVGlslOffscreenTriangleScene`, `PVGlslTriangleShaders`. Suite gate.

**Done when** the suite proves on the device that the triangle is drawn where it should be, in
the colours it should be, the right way up, and that the DSL shaders draw the same picture as
the hand-built ones.

---

## 8. Phase G-5 — the window path: the frames nobody counts

**Goal.** Cover what only a surface can exercise — surface creation, swapchain images, acquire,
semaphore submit, present, teardown — against a real device instead of a stub.

**What this phase cannot prove.** There is no readback from a presented image without another
copy, so this phase proves the loop runs and the handles are managed. It does not prove what
appears on screen; G-4 is where pixels are proven. Say that in the test comments, so the next
reader does not mistake one for the other.

1. **Availability is asked, and the reason stated.** `PVHelloTriangleScene class >>
   displayAvailable` and `displayUnavailableReason`, reading the platform's display environment
   (`DISPLAY`, `WAYLAND_DISPLAY`). Every test here opens with
   `self class displayAvailable ifFalse: [ ^ self skip ]` and a comment naming what the skip
   costs, following `PVComputeTest`'s half-precision skips.
2. **Red, then green, one fact per test.** Each test needs a real window, so each runs inside
   `PVVulkanDriver installDuring:` and tears down in reverse order exactly as
   `PVHelloTriangleScene class >> renderTriangle` does: window, context, scene, each released by
   its own `ensure:`. Factor that scaffolding into one test-side helper taking a block, so a
   raise cannot leak a window or a `VkInstance`.
   - `testSwapchainHasAnImageViewForEveryImage` — at least two images, one view each, extent
     equal to the drawable extent.
   - `testRenderFrameCyclesThroughTheSwapchainImages` — render `imageCount * 2 + 1` frames and
     assert the acquired indices cover every image at least once. This is the "stable frames"
     claim of Phase 6, asserted. It needs the index exposed, so have `renderFrame` answer the
     index it used — additive, breaks no caller, `find_senders` first.
   - `testSceneDestroyReleasesEverySlotOnARealDevice` — `lifecycleReport` says released for
     every owned slot and live only for `ctx`, against a device rather than
     `PVRecordingContextStub`.
   - `testInterruptedFrameStrandsNothing` — raise inside the render loop, then assert the driver
     is restored and the scene's slots are released. The 9 October crash lived here, and only
     the stub covers it today.
3. **Keep the stub tests.** They cover failure branches a real device will not produce on demand.
   These tests are additions, not replacements.
4. **Example.** `PVHelloTriangleScene class >> renderTriangle` is already the `<sampleInstance>`
   for this path. Extend it only if a window-side object gains state worth inspecting.
5. **View.** `PVHelloTriangleScene >> inspectorSwapchain:` — image count, extent, format by name,
   present mode by name, and per image whether a framebuffer exists for it. Reads slots.
6. `run_critics` on `PVHelloTriangleScene`, `VkSwapchain`, `VkSurface`. Suite gate.

**Done when** the window path is exercised against a device, or skipped with a reason the test
output states.

---

## 9. Phase G-6 — keep the gap shut

**Goal.** Make a silent return of this gap impossible, and correct the documents that describe
it.

1. **Red.** `PVGraphicsTest >> testEveryGraphicsClassIsExercisedOnADeviceOrSaysWhyNot`: reflect
   over the classes tagged `Graphics` in package `PharoVulkan` —

   ```smalltalk
   (PackageOrganizer default packageNamed: #PharoVulkan) definedClasses
     select: [ :each | each packageTag name = 'Graphics' ]
   ```

   — and for each assert either that some device-touching test method references it, or that it
   is named in an explicit class-side list of classes that are CPU-only by design. That list
   names the class **and** the reason, so adding to it is a visible decision rather than an
   omission. Today's thirteen graphics classes are `Vk`, `VkCommandBuffer`, `VkContext`,
   `VkFenceWrapper`, `VkFramebuffer`, `VkGraphicsPipeline`, `VkQueue`, `VkRenderPass`,
   `VkSemaphoreWrapper`, `VkSurface`, `VkSwapchain`, `VkVertexAttributeDescription`,
   `VkVertexBindingDescription`. Note that `RPackageOrganizer` is gone in Pharo 13 and
   `Package >> classTags` does not exist — a class answers its own tag with `packageTag name`.
2. **Documents.**
   - README: remove the **No automated GPU coverage** limitation, replace it with what is now
     covered and the one thing the window path still cannot assert, and add
     `GRAPHICS-GPU-PLAN.md` to the Documentation table.
   - `~/.claude/projects/-home-me/memory/project_pharovulkan.md`: replace the note that a green
     suite proves nothing about rendering with what the suite now proves, and record the
     `hostVisibleAndCoherent` finding from G-0 as a **How to apply** line.
3. **Final gate.** `run_critics` on every class this plan touched, then the whole project as a
   real `TestSuite` over the eight concrete test classes plus whatever this plan added.

**Done when** the README describes the coverage that exists, and a test fails if a new graphics
class arrives with neither device coverage nor a stated reason.

---

## 10. Risks, and what each one costs

**Hand-written structure offsets.** `VkImageCreateInfo`, `VkBufferImageCopy`, `VkMemoryBarrier2`
and `VkDependencyInfo` are written by hand. Unlike the Phase 7-A overrun, these are *inputs* the
driver validates immediately, so a wrong offset usually raises rather than corrupting object
memory — with one exception, the barrier masks, which the driver does not check. Mitigation:
offsets in a comment header beside the code, a must-succeed test per structure, and for the
masks, a deliberately conservative barrier as the bisection step when a readback looks wrong.

**Unorm rounding.** `b8g8r8a8Unorm` quantises, so a clear of `0.5` may be 127 or 128. Every
colour assertion carries a stated tolerance of one step, and the interpolated centroid a wider,
named tolerance. No test asserts an exact float.

**Channel order.** The format is B, G, R, A in memory. Convert in one place
(`PVOffscreenTarget >> pixelAtX:y:`) and never index raw bytes in a test.

**Row pitch.** A copy into a tightly packed buffer has a pitch equal to the width, and assuming
that silently breaks for odd extents. The 1×1 test in G-3 exists for this.

**Device variation.** Everything here was measured on an Intel Iris Plus, with Mesa lavapipe
present as a second device. Where a capability may be absent, the predicate is asked and the
reason stated — the discipline that kept the cooperative matrix claims honest in 7-F and 7-H.

**Scope creep.** The temptation in G-5 is to fix resize handling, depth buffers or uniform
buffers, all listed as known limitations. None of them is a bug, and none is in this plan. Two
literals noticed during the survey — the vertex buffer's `usage: 128` in
`initializeCtx:backendWindow:`, and the pool sizes in `VkDescriptorPool >> create:` — belong to
the no-magic-values work in `DEFECTS-PLAN.md`, not here.

---

## 11. Order of work, and what each phase leaves behind

| Phase | Leaves behind | Blocks |
| --- | --- | --- |
| G-0 | `VkMemoryProperty` bits, a coherent-memory device test, a memory-type view | every pixel assertion |
| G-1 | `supportsGraphics`, `offscreenGraphicsContext`, queue-family view | G-2 to G-5 |
| G-2 | `VkImage`, four bindings, image constants, single-image view | G-3 |
| G-3 | `PVOffscreenTarget`, offscreen render pass, copy and barrier, clear-colour parameter, the first real pixel assertion | G-4 |
| G-4 | `PVTriangleScene`, `PVOffscreenTriangleScene`, the triangle asserted by pixel, the DSL shaders compared with the hand-built ones | G-6 |
| G-5 | window-path device tests with a stated skip | G-6 |
| G-6 | the reflection test that keeps the gap shut, corrected README and memory | — |

G-5 depends only on G-1, so it can be taken before G-4 if a display is at hand and the offscreen
work stalls. Everything else is in dependency order.

Each phase ends with a prose Iceberg commit message handed over for the user to commit from the
Iceberg GUI.
