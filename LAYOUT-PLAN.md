# Declared layout plan

Every Vulkan structure this project hands to the driver should be declared field by field, so
uFFI computes its offsets, rather than written as a block of bytes with the offsets counted by
hand. Counting by hand has already cost this project one class of bug twice: an offset counted
short of the struct writes outside it, and nothing says so until an unrelated object changes.
`PHASE7-PLAN.md` §5 records the crash that came from it.

Defects D, E and F in `DEFECTS-PLAN.md` converted the descriptor path — the pool create info,
the set allocate info, the buffer info and the write — and established the shape each remaining
unit should take. This plan records what is left, in the order it is worth taking.

Written 13 October 2026. The inventory was taken from the exported sources, counting methods
that write three or more distinct offsets into a block of bytes they allocated.

## What a unit looks like

One structure, or one small group of structures written by the same method:

1. The failing layout test first. It reads the names, the offsets, the widths, each field's
   self-alignment and the struct size back from the compiled field specification, never from a
   second copy of the declaration. `VkStructure class >> layoutRows` is what it reads.
2. A test for whatever the structure's own `initializeConstantFields` is supposed to leave in
   the store, including the degenerate state: what a zeroed field would mean to the driver.
3. The declaration, then `defineFields`, which generates both the offsets and the accessors.
   `compileFields` generates offsets only — it compiles the specification `withAccessors:
   #never` — so it is the wrong one.
4. The writing method rewritten through the generated accessors, split so that each piece owns
   one step and one `ensure:`. The reflective test that no method mentioning the structure
   sends `unsignedLongAt:put:` and friends keeps it that way.
5. A class-side `<sampleInstance>` example, built in object memory so a click frees nothing,
   with any pointer to a store the example does not own left null.
6. `run_critics` on everything that changed.

The driver leg is the suite that already exercises the path: the structure being accepted by
uFFI proves nothing by itself. `VkCoreTest`, `PVComputeTest`, `PVGraphicsTest` and `VkImageTest`
are the ones that call into the driver.

## Rules the units so far established

- **A pointer field is one pointer wide.** `FFIExternalStructureType` answers the pointed-to
  structure's size for `externalTypeSize`, so a layout read naively reports a pointer to a
  twenty-four-byte struct as twenty-four bytes wide and overlapping the field after it.
  `layoutRows` asks `isPointer` first.
- **Nothing may be written in `initialize`.** `FFIStructure class >> fromHandle:` sends
  `initialize` after setting the store, and uFFI's getter for a field that points at another
  structure answers that structure through `fromHandle:`. So `initialize` runs on every read of
  such a field, over the pointee's store or over a null pointer. `VkStructure >> initialize`
  therefore guards on a null store and defers to `initializeConstantFields`, and what goes
  there must be constant for the type — `sType` and a cleared `pNext`. A data field written
  there is rewritten in the pointee on every read.
- **Declare handles as handles.** A `VkFoo_H*` field is pointer wide; declaring it `uint32`
  shifts every field after it.
- **Name the constants.** The counts and sentinels that used to sit inline become class-side
  methods: `VkDescriptorPool class >> setAllocationCount`, `handleByteCount`,
  `VkDescriptorSet class >> descriptorsPerWrite`, `VkDescriptorBufferInfo class >> wholeSize`.
- **An array field is not a structure.** A `void*` or `float*` field's getter answers an
  `ExternalData`, which is not indexable, so the array behind it is read through `getHandle` by a
  named stride. Allocate it in its own method and free it in the method paired with the builder,
  never in the caller: a caller that frees the structure and forgets the array leaks.
- **A wide struct earns `ReExcessiveVariablesRule`.** One `OFFSET_` class variable per field is
  what declaring the struct costs; `VkPhysicalDeviceLimits` and `VkWriteDescriptorSet` both
  carry the critique and it is accepted, not worked around.

## 1 — Instance and device creation

Taken first: every test in the project goes through it, and it is the only place with `pNext`
chains, where a short write lands in another structure rather than in slack.

| Method | Offsets written | Structures |
|---|---|---|
| ~~`VkContext >> buildDeviceCreateInfo:`~~ | ~~10~~ | `VkDeviceCreateInfo` — **done 13 October 2026** |
| ~~`VkContext >> buildDeviceQueueCreateInfo:`~~ | ~~8~~ | `VkDeviceQueueCreateInfo` — **done 13 October 2026** |
| `VkContext >> initializeCompute` | 9 | device and queue create infos |
| `VkContext >> initializeGraphicsWithExtensions:` | 9 | same, with extensions |
| ~~`VkContext >> createGraphicsDevice`~~ | ~~10~~ | same — **done 13 October 2026** |
| `VkContext >> buildFeatureChain` | 3 | `VkPhysicalDeviceSynchronization2Features` |
| `VkContext >> buildHalfPrecisionFeatures` | 6 | `VkPhysicalDeviceShaderFloat16Int8Features` |
| `VkContext >> buildCooperativeMatrixFeatures` | 4 | cooperative matrix features |

`VkDeviceQueueCreateInfo` had a stub class whose `fieldsDesc` was in a syntax uFFI could not
resolve; it was deleted under defect F, so this unit declares it properly.

### 1a — the queue create info, done 13 October 2026

`VkDeviceQueueCreateInfo` is declared field by field: forty bytes over offsets 0, 8, 16, 20, 24
and 32, the three `uint32` members filling the twelve bytes after `pNext` and four bytes of
padding before `pQueuePriorities`. `buildDeviceQueueCreateInfo:` fills it through the generated
accessors, `queuePriorityArrayOutsideObjectMemory` builds the array of priorities, and
`freeDeviceQueueCreateInfo:` releases both blocks. The counts and the priority became
`VkContext class >> queuesPerFamily`, `queuePriority` and `queuePriorityByteCount`, and the count
the device create info carries became `queueCreateInfosPerDevice`, which is a different number
with a different meaning — one create info for one family, however many queues that family is
asked for.

**A real leak was fixed with it.** Both callers released the structure but reached
`(queueInfo pointerAt: 33) free` — the priority array — only on the path where device creation
succeeded, so every failed `vkCreateDevice` leaked four bytes outside object memory, and the two
tests in `VkCoreTest` that build a create info by hand repeated the same pair of frees. The
paired `freeDeviceQueueCreateInfo:` in an `ensure:` is what makes it impossible to free one and
not the other; the hand-written offset 33 is gone from all four call sites.

Three tests, red first: the layout test, a structure-type test whose degenerate state is the
zeroed store (family zero with zero queues, which is not a legal request, so initialization may
not fill it in), and `testDeviceQueueCreateWritesThroughDeclaredFields`, which finds every method
of `VkContext` that mentions the class and asserts it pokes no raw offset.
`VkCoreTest >> testDeviceQueueCreateInfoAsksForOneQueueAtFullPriority` is the driver leg: it reads
the family, the count and each priority back out of the struct that goes to `vkCreateDevice`.
Example `exampleOneQueueOnTheFirstFamily`, Layout and Fields tabs inherited from `VkStructure`,
critics clean on the new class.

**`void*` getters answer an `ExternalData` that is not indexable.** Declaring the field `float*`
rather than `void*` did not help: the getter answers an `ExternalData` either way, and
`at: 1` on it fails with `Instances of ExternalData are not indexable`. So an array field is read
through `getHandle` by a named stride, and `ExternalData >> free` (inherited from
`ExternalStructure`) frees the pointed-to block, which is what the paired free relies on.

`createGraphicsDevice` keeps its `ReLongMethodsRule` and `ReCyclomaticComplexityRule` critiques:
it still writes the device create info, the synchronization2 features and the extension name
array by hand, and splitting it belongs to the unit that declares those.

### 1b — the device create info, done 13 October 2026

`VkDeviceCreateInfo` is declared field by field: seventy two bytes over offsets 0, 8, 16, 20, 24,
32, 40, 48, 56 and 64, each `uint32` count sitting in the four bytes before a pointer and padded
to it. The layout test asserts the struct size against `VkContext class >> deviceCreateInfoSize`
as well as against seventy two, so the old hand-written size cannot drift from the declaration
while both exist.

Only `sType` is constant for the type, so `initializeConstantFields` writes nothing else: `pNext`
carries the feature chain, which differs per device, and the structure-type test asserts the
class declares no `initialize` of its own. The degenerate state is what `externalInstance`
answers, a device asked for with no queues, no layers and no extensions, which is why the builder
no longer writes the zeros and nulls the hand-written version wrote out field by field.

Both device paths now build and free through the accessors:

- `buildDeviceCreateInfo:` keeps asking the physical device what it offers.
- `buildGraphicsDeviceCreateInfo:` is new: the graphics path used to write its own seventy two
  byte block inline, with the swapchain extension name spelled out mid-method. The name moved to
  `VkContext class >> graphicsExtensionNames` and the single-structure chain to
  `buildSynchronization2Features`.
- `createDeviceFromCreateInfo:` is the one `vkCreateDevice` call both paths make; it was written
  twice before, once in each.
- `freeDeviceCreateInfo:` reads the chain and the name array back through the accessors, and
  `freeExtensionNameArray:count:` is its pair for the array of C strings, which is an array and
  not a structure.
- `extensionNamesIn:` reads the count and the array through the accessors rather than at offsets
  49 and 57. Reading at a hand-written offset is the same hazard as writing at one, so
  `testDeviceCreateWritesAndReadsThroughDeclaredFields` bans both in any method that mentions the
  class.

`createGraphicsDevice` is four lines and its `ReLongMethodsRule` and `ReCyclomaticComplexityRule`
critiques are gone. `VkDeviceCreateInfo` earns `ReExcessiveVariablesRule` on both sides, accepted
as ten fields' worth of `OFFSET_` variables. `initializeCompute` and
`initializeGraphicsWithExtensions:` keep their critiques: they still write the application info
and the instance create info by hand, which is unit 1d.

Three tests red first — layout, structure type with the zeroed store, and the poke-and-read test
— with `VkCoreTest >> testDeviceCreateInfoCarriesEveryEnabledExtension` and
`testDeviceCreateInfoChainsTheHalfPrecisionFeatureStructs` as the driver legs, both already
reading the struct the driver gets. Example `exampleGraphicsDeviceRequest`; Layout and Fields tabs
inherited.

### 1c — the feature chain

`buildFeatureChain`, `buildOptionalFeatureChain`, `buildHalfPrecisionFeatures`,
`buildCooperativeMatrixFeatures` and `buildSynchronization2Features` still write their structures
as blocks. `featureChainTypesIn:` and `freeFeatureChain:` walk a chain of structures whose types
are not known at that point, reading `sType` at 0 and `pNext` at 8 — the common header every
Vulkan structure starts with. The specification has a type for exactly that, `VkBaseOutStructure`,
so declaring it gives both walkers accessors instead of two hand-written offsets.

### 1d — the instance create info

`initializeCompute` and `initializeGraphicsWithExtensions:` each write a `VkApplicationInfo` and a
`VkInstanceCreateInfo` inline, although both classes have been declared field by field since
defect D. The two methods are near copies of each other and both carry long-method critiques.

## 2 — Buffers, memory and the small create infos

| Method | Offsets written | Structures |
|---|---|---|
| `VkBuffer >> allocate` | 8 | `VkBufferCreateInfo`, `VkMemoryAllocateInfo` |
| `VkImage >> allocate` | 4 | `VkMemoryRequirements`, allocate info |
| `VkDescriptorSetLayout >> create` | 5 | `VkDescriptorSetLayoutBinding`, layout create info |
| `VkShaderModule >> initializeFromBytes:` | 5 | `VkShaderModuleCreateInfo` |
| `VkCommandPool class >> on:` and `VkDevice >> createCommandPool:` | 4 each | `VkCommandPoolCreateInfo` |
| `VkCommandPool >> allocateBuffer` | 5 | `VkCommandBufferAllocateInfo` |
| `VkFenceWrapper >> initializeDevice:` | 3 | `VkFenceCreateInfo` |
| `VkSemaphoreWrapper >> initializeDevice:` | 3 | `VkSemaphoreCreateInfo` |

The two command pool create infos are written twice, by two methods, from the same five values;
the unit that declares the structure should leave one writer.

## 3 — Command recording and submission

| Method | Offsets written | Structures |
|---|---|---|
| `VkCommandBuffer >> begin` | 4 | `VkCommandBufferBeginInfo` |
| `VkCommandBuffer >> barrierForHostRead` | 9 | memory barrier and dependency info |
| `VkCommandBuffer >> copyImage:` | 13 | `VkBufferImageCopy` |
| `VkCommandBuffer >> beginRenderPass:` | 10 | render pass begin info, `VkClearValue` |
| `VkCommandBuffer >> setViewport:` | 6 | `VkViewport` |
| `VkCommandBuffer >> setScissor:` | 4 | `VkRect2D` |
| `VkQueue >> submit:` | 9 | `VkSubmitInfo2`, command buffer submit info |
| `VkQueue >> submitGraphics:` | 9 | same, with `VkSemaphoreSubmitInfo` |

`VkViewport` and `VkRect2D` are plain value structures with no `sType`, so they are the cheapest
units in the plan and a good place to confirm the shape on a structure without a chain pointer.

## 4 — Graphics

Last, because the graphics path is the one the tests exercise least and the structures are the
widest.

| Method | Offsets written | Structures |
|---|---|---|
| `VkGraphicsPipeline >> initializeDevice:` | 29 | the whole pipeline create info tree |
| `VkSwapchain >> initializeDevice:` | 19 | `VkSwapchainCreateInfoKHR`, surface capabilities |
| `VkSwapchain >> createImageViews` | 15 | `VkImageViewCreateInfo` |
| `VkSwapchain >> present:` | 8 | `VkPresentInfoKHR` |
| `VkImage >> create` | 17 | `VkImageCreateInfo` |
| `VkImage >> createView` | 15 | `VkImageViewCreateInfo` |
| `VkRenderPass >> initializeDevice:` | 13 | attachment, subpass and render pass create infos |
| `VkFramebuffer >> initializeDevice:` | 9 | `VkFramebufferCreateInfo` |
| `VkComputePipeline >> create` | 13 | `VkComputePipelineCreateInfo`, shader stage create info |

`VkImage >> createView` and `VkSwapchain >> createImageViews` write the same structure from two
places, so declaring `VkImageViewCreateInfo` should leave one writer, as with the command pool.
`VkGraphicsPipeline >> initializeDevice:` is a tree of nine structures written by one method;
it is worth splitting into one unit per structure rather than taken whole.
