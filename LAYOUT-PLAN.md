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
- **A family of structures that differ only in their flags earns a superclass.** The five device
  feature structures are a chain header plus a run of `VkBool32` flags, so `VkFeatureStructure`
  holds the one `initializeConstantFields` and the one flag view, and a subclass declares only its
  fields and its class-side `structureType`.
- **A read-only view over someone else's structure declares no constant field.** `fromHandle:`
  sends `initialize`, so a constant `sType` on `VkBaseOutStructure` would overwrite the type of
  whatever structure a chain walker is reading.
- **A declared structure answers its own size.** Every `…Size` constant that duplicated a struct
  size became dead on conversion and was deleted rather than kept and asserted against.
- **A tab that explains a hierarchy needs a `…Context:` companion.** A class-side
  `inspectorPresentationOrder:title:` method shows on every subclass until a companion method of
  the same name plus `Context:` answers `aContext active:` with the position in the hierarchy,
  asked as a real question — `self subclasses isNotEmpty` — not as a comparison against a class
  name.
- **A field keeps its Vulkan name even when `Object` already answers it.** `VkBufferCreateInfo`
  and `VkMemoryRequirements` both declare a field called `size`, so the generated accessor
  overrides `Object >> size` for those two classes. That is correct: the field is `size` in the C
  structure and neither class is ever asked for a collection size. Renaming the field to avoid
  the override would hide the C name, which is the one thing a binding must not do.
- **A structure the driver fills is read through a declared view and copied before the block
  goes.** `VkMemoryRequirements externalInstance` is handed to the driver, read through its
  accessors, and answered as `copyIntoObjectMemory` so the caller keeps the numbers after the
  external block is freed. A test that hand-counted the same offsets is converted along with the
  code: `VkCoreTest >> testStorageBufferMemoryTypeIsCoherent` used to read `memoryTypeBits` at
  byte seventeen itself.
- **A wide struct earns `ReExcessiveVariablesRule`.** One `OFFSET_` class variable per field is
  what declaring the struct costs; `VkPhysicalDeviceLimits` and `VkWriteDescriptorSet` both
  carry the critique and it is accepted, not worked around.

## 1 — Instance and device creation — **done 13 October 2026**

Taken first: every test in the project goes through it, and it is the only place with `pNext`
chains, where a short write lands in another structure rather than in slack. All five methods are
converted, over units 1a to 1d; twenty-five of the original thirty-three remain, in groups 2 to 4.

| Method | Offsets written | Structures |
|---|---|---|
| ~~`VkContext >> buildDeviceCreateInfo:`~~ | ~~10~~ | `VkDeviceCreateInfo` — **done 13 October 2026** |
| ~~`VkContext >> buildDeviceQueueCreateInfo:`~~ | ~~8~~ | `VkDeviceQueueCreateInfo` — **done 13 October 2026** |
| ~~`VkContext >> initializeCompute`~~ | ~~9~~ | `VkApplicationInfo`, `VkInstanceCreateInfo` — **done 13 October 2026** |
| ~~`VkContext >> initializeGraphicsWithExtensions:`~~ | ~~9~~ | same, with extensions — **done 13 October 2026** |
| ~~`VkContext >> createGraphicsDevice`~~ | ~~10~~ | same — **done 13 October 2026** |
| ~~`VkContext >> buildFeatureChain`~~ | ~~3~~ | `VkPhysicalDeviceSynchronization2Features` — **done 13 October 2026** |
| ~~`VkContext >> buildHalfPrecisionFeatures`~~ | ~~6~~ | `VkPhysicalDeviceShaderFloat16Int8Features` — **done 13 October 2026** |
| ~~`VkContext >> buildCooperativeMatrixFeatures`~~ | ~~4~~ | cooperative matrix features — **done 13 October 2026** |

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
to it. The layout test asserted the struct size against `VkContext class >> deviceCreateInfoSize`
as well as against seventy two, so that the old hand-written size could not drift from the
declaration while both existed; unit 1c deleted that constant and the assertion with it.

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

### 1c — the feature chain, done 13 October 2026

Five structures are declared field by field and one is new in the hierarchy:

- `VkPhysicalDeviceSynchronization2Features`, twenty four bytes over offsets 0, 8 and 16.
- `VkPhysicalDeviceShaderFloat16Int8Features`, twenty four bytes over 0, 8, 16 and 20.
- `VkPhysicalDevice16BitStorageFeatures`, thirty two bytes over 0, 8, 16, 20, 24 and 28.
- `VkPhysicalDeviceCooperativeMatrixFeaturesKHR`, twenty four bytes over 0, 8, 16 and 20.
- `VkBaseOutStructure`, sixteen bytes over 0 and 8: the header every structure in a `pNext`
  chain starts with.

`VkPhysicalDeviceVulkanMemoryModelFeatures` was already declared, from the unit that added the
cooperative matrix path, so this unit only moved it into the new hierarchy.

**The five feature structures now share one superclass, `VkFeatureStructure`.** A feature
structure is a chain header followed by a run of `VkBool32` flags, and nothing else, so what was
duplicated five times — `initializeConstantFields`, which stamps the one structure type the class
names, and the `Flags` tab with the `flagRows` that feed it — lives once. A concrete subclass
declares `fieldsDesc` and the class-side `structureType`, and inherits the rest. The rows are
reflected out of the compiled field specification with `headerFieldNames` removed, so a flag added
to a `fieldsDesc` appears in that structure's view with no other method touched;
`testEveryFeatureStructureShowsEveryFlagItDeclares` asserts exactly that, over every subclass
rather than over a list written out here.

**A read-only view over someone else's structure may declare no constant field.**
`VkBaseOutStructure` deliberately has no `initializeConstantFields`: `FFIStructure class >>
fromHandle:` sends `initialize`, so a constant `sType` here would stamp this class's own type over
the type of whichever structure is being read, and that type is the one thing a chain walker is
there to find out. `testBaseOutStructureViewLeavesTheStructureItReadsAlone` pins it down, and it
caught the real failure in this unit: `VkPhysicalDeviceVulkanMemoryModelFeatures` was writing its
`sType` in the builder rather than in initialization, so the header read zero where the test
expected a type, which is how it came to have an `initializeConstantFields` of its own — now
inherited.

Both chain walkers and the five builders go through accessors:

- `chain:onto:`, `featureChainTypesIn:` and `freeFeatureChain:` read `sType` and `pNext` through
  `VkBaseOutStructure fromHandle:` instead of at offsets 0 and 8. `freeFeatureChain:` still reads
  the successor out of each block before freeing that block, which is the one ordering that
  matters here.
- `buildFeatureChain`, `buildSynchronization2Features`, `buildHalfPrecisionFeatures`,
  `buildCooperativeMatrixFeatures` and `buildVulkanMemoryModelFeatures` fill their structures
  through the generated accessors and answer `getHandle`. Each one leaves the flags this project
  does not ask for alone, because `externalInstance` zeroes the block, and that is what writes
  them off.

**Five size constants became dead and were deleted:** `VkContext class >>
synchronization2FeaturesSize`, `shaderFloat16Int8FeaturesSize`, `storage16BitFeaturesSize`,
`cooperativeMatrixFeaturesSize` and `deviceCreateInfoSize`. A declared structure answers its own
`byteSize`, so a second copy of the number is a copy that can drift. The assertion in
`testDeviceCreateInfoLayoutMatchesTheCLayout` that compared the two went with it.

**A tab that explains a hierarchy needs a companion context method.** The class-side
`inspectorFeatureStructures:` on `VkFeatureStructure` lists each subclass with its structure type
and its flags; `inspectorFeatureStructuresContext:` answers `aContext active: self subclasses
isNotEmpty`, which is the real rule — show the tab where there is a hierarchy to explain — rather
than a comparison against the class name, which Renraku flags and which would not follow a rename.
`testFeatureStructureHierarchyViewShowsOnTheAbstractClassOnly` asks both the abstract class and
every subclass.

Three tests red first — the shared-superclass test, the flag-rows test and the hierarchy-tab test
— on top of the layout and builder tests the structures already had.
`VkCoreTest >> testDeviceCreateInfoChainsTheHalfPrecisionFeatureStructs` is the driver leg: it
reads the chain back out of the create info the driver is given. Examples: one per structure,
`exampleSynchronization2OfThisMachine`, `exampleShaderArithmeticWidthsOfThisMachine`,
`exampleSixteenBitStorageOfThisMachine` and `exampleCooperativeMatrixOfThisMachine`, each querying
the device a plain compute context lands on and copying the answer out of the chain before that
memory is freed; `VkBaseOutStructure class >> exampleHeaderOfAFeatureStructure` reads the header of
a synchronization2 structure; and `VkFeatureStructure class >>
exampleFlagsEveryFeatureStructureDeclares` answers the flags of every declared feature structure
out of zeroed blocks, asking no device at all.

`VkFeatureStructure` keeps five critiques, all one root and all accepted:
`ReMissingSubclassResponsibilityRule` on `sType`, `sType:`, `pNext` and `pNext:` and
`ReSelfSentNotImplementedRule` on `initializeConstantFields`. Those four accessors are generated
by `defineFields` in each concrete subclass from its own offsets; the abstract class declares no
fields and so cannot have them, and the superclass sending `sType:` to a field every subclass
declares is the whole point of putting the constant there. The suite is 352 tests over the nine
concrete test classes.

### 1d — the instance create info, done 13 October 2026

`VkApplicationInfo` (48 bytes, offsets 0, 8, 16, 24, 32, 40 and 44) and `VkInstanceCreateInfo`
(64 bytes, offsets 0, 8, 16, 24, 32, 40, 48 and 56) were declared under defect D and the two
instance paths wrote them as blocks all the same: `initializeCompute` and
`initializeGraphicsWithExtensions:` were near copies of each other, forty-eight and sixty-four
bytes each written field by field at counted offsets, with the graphics path spelling out its own
copy of the C-string array loop as well.

Both now come through one method:

- `buildApplicationInfo` asks for the API version and nothing else. The application and engine
  names are what a driver matches a workaround on, and this project wants none, so they stay the
  null pointers a fresh store gives. `freeApplicationInfo:` is its pair; the structure owns no
  other block precisely because those names were never allocated.
- `VkContext class >> instanceApiVersion` names the version, which is not a free choice: the
  device dispatch table carries `vkQueueSubmit2` only from Vulkan 1.3 on. The comment that fact
  used to sit in has become the constant's comment.
- `buildInstanceCreateInfo:extensions:` fills the create info through the accessors and reuses
  `buildExtensionNameArray:`, the method the device path already had, so the graphics path's
  inline loop over `byteAt:put:` is gone and `allocateCString:` is the one place a Pharo string
  becomes a C string. `freeInstanceCreateInfo:` pairs with it through
  `freeExtensionNameArray:count:` and leaves the application info to the caller that built it.
- `createInstanceFromCreateInfo:` is the one `vkCreateInstance` call.
- `createInstanceWithExtensions:` is the whole sequence with each block freed in an `ensure:` by
  the method paired with the one that built it, so a refused `vkCreateInstance` leaks nothing.
  `VkContext class >> computeInstanceExtensionNames` is the empty list the compute path passes:
  it never presents to a surface. The graphics path passes what SDL names.

`initializeCompute` and `initializeGraphicsWithExtensions:` are five lines each and their
long-method and complexity critiques are gone; `VkContext` now has no critiques at all.

**`pApplicationInfo` is declared `void*` although it is a `VkApplicationInfo*`.** uFFI's getter
for a typed structure pointer answers that structure through `fromHandle:`, which sends
`initialize`, so every read of the field would write this project's constant fields over memory
the driver is about to read. `freeInstanceCreateInfo:` reads the field, so this is not
hypothetical. The declaration is one pointer wide either way and the layout is unchanged.

**`VkInstanceCreateInfo >> initializeConstantFields` was writing fields that are not constant for
the type** — the flags, both counts and both name arrays, as zeros and nulls. A fresh store
already reads as none of each, and anything written in initialization is written again on every
`fromHandle:` read of the structure, which would clear a count the driver was meant to see. It
writes `sType` only now, and `testInstanceCreateInfoInitializesOnlyWhatIsConstantForTheType`
asserts the degenerate state field by field and then asks the method itself which setters it
sends, so the rule cannot drift.

Three tests red first: that test, `VkCoreTest >>
testInstanceCreateInfoCarriesTheApplicationInfoAndTheExtensionsAskedFor`, which reads the struct
`vkCreateInstance` is given, and `testInstanceCreateInfoWithoutExtensionsAsksForNone` for the
degenerate state, where the count must read zero and the array pointer must be null, because a
driver reads the array whenever the count says there is one. The poke test for this unit is
`VkBindingsTest >> testVkContextWritesNoScalarFieldAtAHandCountedOffset`, which bans the scalar
accessors — `unsignedLongAt:`, `unsignedShortAt:`, `unsignedLongLongAt:`, `signedLongAt:` and
their setters — across every method of `VkContext`, rather than only in the methods that mention
one class. Every scalar a Vulkan structure carries is a declared field, so a scalar written at a
counted offset is a write outside a declaration; the pointer, float and byte accessors stay
allowed, because an array of C strings, of priorities or of handles has no field specification
and is walked by a named stride.

Examples: `VkApplicationInfo class >> exampleApiVersionThisProjectAsksFor`, built in object
memory, and `VkInstanceCreateInfo class >> exampleComputeInstanceRequest`, built by the real
builder and copied into object memory before the external blocks go, so the click frees
everything it allocated. Layout and Fields tabs inherited from `VkStructure`; the Fields tab
reports a pointer as set or not set and never follows one, which is what makes it safe on a copy
whose pointers are stale. The suite is 356 tests over the nine concrete test classes.

**Group 1 is complete.** Every structure on the instance and device creation path is declared.

## 2 — Buffers, memory and the small create infos

| Method | Offsets written | Structures |
|---|---|---|
| ~~`VkBuffer >> allocate`~~ | ~~8~~ | done, unit 2a |
| `VkImage >> allocate` | 4 | both memory structures, declared in 2a |
| `VkDescriptorSetLayout >> create` | 5 | `VkDescriptorSetLayoutBinding`, layout create info |
| `VkShaderModule >> initializeFromBytes:` | 5 | `VkShaderModuleCreateInfo` |
| `VkCommandPool class >> on:` and `VkDevice >> createCommandPool:` | 4 each | `VkCommandPoolCreateInfo` |
| `VkCommandPool >> allocateBuffer` | 5 | `VkCommandBufferAllocateInfo` |
| `VkFenceWrapper >> initializeDevice:` | 3 | `VkFenceCreateInfo` |
| `VkSemaphoreWrapper >> initializeDevice:` | 3 | `VkSemaphoreCreateInfo` |

The two command pool create infos are written twice, by two methods, from the same five values;
the unit that declares the structure should leave one writer.

### 2a — the buffer and its memory, done 14 October 2026

Three structures declared and `VkBuffer >> allocate` converted. `VkBufferCreateInfo` is
fifty-six bytes over eight fields at 0/8/16/24/32/36/40/48: `size` is a `VkDeviceSize`, so it is
eight bytes wide and eight byte aligned, which puts four bytes of padding after `flags`, and
`queueFamilyIndexCount` is padded again before the pointer that follows it.
`VkMemoryAllocateInfo` is thirty-two bytes at 0/8/16/24 for the same reason.
`VkMemoryRequirements` is twenty-four bytes at 0/8/16 and has no chain header at all: the driver
writes all three fields, so like `VkBaseOutStructure` the class declares no
`initializeConstantFields`, and `testMemoryRequirementsWritesNothingOfItsOwn` asserts both that
the class does not implement it and that the lookup lands on `VkStructure`.

`allocate` was one method writing eight offsets into three hand-allocated blocks. It is now four:
`allocate` itself, which creates the buffer, backs it and binds the two together; `createHandle`,
which fills the two fields this project chooses — the byte count and the usage mask — and leaves
the rest of the request reading as the degenerate buffer, exclusively owned with no queue family
list; `memoryRequirements`, which hands the driver a declared block and answers
`copyIntoObjectMemory`; and `allocateMemoryFor:`, which asks the physical device for a memory
type that both suits the buffer and is host visible and coherent. The sharing mode's zero is
named by `VkBufferCreateInfo class >> sharingModeExclusive`, and
`sharingModeNameFor:` names that one value and prints any other as the number it is, rather than
vouching for a name the class does not carry.

Seven tests red first in `VkBindingsTest`: a layout test per structure, a constant-field test for
each create info that asserts the degenerate state field by field and then asks
`initializeConstantFields` which setters it sends,
`testMemoryRequirementsWritesNothingOfItsOwn`, and
`testVkBufferWritesNoScalarFieldAtAHandCountedOffset`, the blanket scalar-poke ban over every
method of `VkBuffer` — `map`, `copyToByteArray` and `copyFromByteArray:` send only pointer and
byte accessors, which stay allowed, because a mapped buffer's contents have no field
specification. The driver leg is `VkCoreTest >>
testBufferMemoryRequirementsAnswerWhatTheDriverAsked`, which asserts the driver's answer is a
real one: at least the bytes asked for, a power of two alignment and a non-empty set of memory
types, read after the buffer is destroyed to prove the copy outlives it.

Examples: `VkBufferCreateInfo class >> exampleStorageBufferRequest`, which asks no device,
`VkMemoryRequirements class >> exampleRequirementsOfAStorageBufferOnThisMachine` and
`VkMemoryAllocateInfo class >> exampleAllocationForAStorageBufferOnThisMachine`, both of which
run against this machine and answer object-memory copies. The view is
`VkBufferCreateInfo >> inspectorRequest:`, a Request tab that names what the raw words in the
Fields tab mean: the byte count, the usage mask decoded by `VkBufferUsage nameForFlags:` rather
than restated, the sharing mode named by the class and whether a queue family list is attached.
`testBufferCreateInfoRequestRowsNameTheUsageBitsAndChangeNothing` compares the rows against the
flag constants and the field report before and after reading, so the tab cannot drift and cannot
mutate. The suite is 365 tests over the nine concrete test classes.

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
