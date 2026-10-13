# Incidental defects plan

Three defects recorded in `PHASE7-PLAN.md` §2.7 on 9 October 2026 and left unfixed, because
none of them blocked Phase 7. Phase 7 is now complete, so this plan takes them in order.

Written 10 October 2026. Every claim below was verified against the live image before the plan
was written; the verification is quoted beside each defect so no one has to re-derive it.

The global rules apply unchanged: the failing test comes first, the fix is the smallest thing
that passes it, and the unit is not done until the test, the code, the refactor, a class-side
`<sampleInstance>` example and an `<inspectorPresentationOrder:title:>` view all exist and
`run_critics` is clean on what changed.

Defects A and B touch one class and go in one commit. Defect C is its own unit.

After each unit, run the whole project as a real `TestSuite` over the concrete test classes —
nine of them since `VkImageTest`, 309 tests with all three defects fixed — rather than a
package-level count, which double-counts where an abstract `TestCase` has concrete
subclasses. Then hand over a prose Iceberg commit message.

**All three defects are fixed as of 11 October 2026.** A and B went in one commit, C in the
next. What each one turned out to need is recorded under its own heading below; the one
finding worth reading before touching the descriptor path again is in C, step 1.

**Defect F was added and fixed on 13 October 2026**, after E and on the same day. It converted the
descriptor write, which finishes the descriptor path, and it turned up two uFFI facts that affect
every structure in the image: a pointer field was reported as the size of what it points at, and
reading a field that points at a structure wrote through the pointer. Both are written up under F
and both now have sweeping tests. The inventory of what is left moved to `LAYOUT-PLAN.md`.

**Defect E was added and fixed on 13 October 2026.** It is the hand-counted allocate info D's
write-up had left as the next unit, taken the same way: red tests first, the structure declared
field by field, the long method split, and `VkCoreTest` and `PVComputeTest` as the driver leg.

**Defect D was added and fixed on 12 October 2026.** It is the hand-counted byte layout C's
write-up had left out of scope, and it is the same kind of unit: one failing test per claim, the
structures declared field by field, and the driver leg taken by the device tests that already
exercise the path.

## A — dead dispatch state in `PVComputeKernel`

**Verified.** The slots `workgroupX`, `workgroupY` and `workgroupZ` are written by
`PVComputeKernel >> workgroupX:workgroupY:workgroupZ:`, whose only sender is
`PVComputeKernel class >> on:spirv:`, which passes `1 1 1`. Nothing reads them:
`allReferencesTo: #workgroupX` answers empty. `dispatch:y:z:` uses its own arguments.

The state is not merely unused, it is misleading: a reader of §2.4 of `PHASE7-PLAN.md` would
expect it to be the workgroup size, which lives in `PVTypeAnnotation` instead.

1. **Red.** `PVComputeTest >> testComputeKernelDeclaresNoSlotNothingReads`: reflect over
   `PVComputeKernel slots` and assert each one has a reader among the class's own methods.
   Check the Pharo 13 reflection protocol for slot reads before writing the assertion; if
   neither `Slot` nor `CompiledMethod` answers it directly, walk each method's AST for
   instance-variable *reads*. Stated as the rule rather than as three slot names, the test
   keeps catching dead state added later. It fails today, naming the three slots.
2. **Green.** Delete the three slots and `workgroupX:workgroupY:workgroupZ:`, and drop the
   send from `on:spirv:`.
3. **Refactor and smoke.** `find_senders` on the deleted selector must answer empty. Run
   `PVComputeTest` (46) and the README's vector-add playground snippet on the device.
4. **Example.** `PVComputeKernel class >> exampleVectorAddKernelOnThisMachine`. The class has
   no `<sampleInstance>` today. It compiles `PVKernelExamples >> vectorAdd:a:b:out:`, prepares
   the pipeline, dispatches once and answers the kernel; where no device is available it
   answers an unprepared kernel, as `PVCooperativeMatrixComparison class >>
   exampleComparisonOnThisMachine` does.
5. **View.** `PVComputeKernel >> inspectorPipeline:`. The class has no view today. Show the
   bound buffers with their binding indices, whether `prepare` has run, and the local size
   read back out of the SPIR-V module rather than restated in the view, so it cannot drift
   from the module the kernel will actually dispatch.
6. `run_critics` on `PVComputeKernel`.

## B — the stage flag is written as a literal

**Verified.** `PVComputeKernel >> prepare` sends `addStorageBufferBinding: i stageFlags: 32`.
`VkShaderStage computeBit` already exists and answers 32, so this is the no-magic-values rule
and nothing else. `addStorageBufferBinding:stageFlags:` has exactly one sender.

1. **Red.** `PVComputeTest >> testComputeKernelUsesNoBareStageFlagLiteral`: deny that
   `(PVComputeKernel >> #prepare) literals` includes `VkShaderStage computeBit`.

   A test asserting the *value* the layout binds with would pass before the fix, because 32 is
   `VkShaderStage computeBit`; it would not be red and would prove nothing. The literal scan is
   the honest version of the rule.
2. **Green.** `stageFlags: VkShaderStage computeBit`.
3. No new method, so defect A's example and view cover the artefacts. `run_critics` again.

## C — `VkDescriptorPool` conflates `maxSets` with `descriptorCount`

**Verified.** `VkDescriptorPool >> create: maxSets` writes the same argument into the pool
size's `descriptorCount` (offset 5 of `sizeBuf`) and into the create info's `maxSets`
(offset 21). `PVComputeKernel >> prepare` passes `buffers size`, so a three-buffer kernel asks
for three descriptor *sets* where one is enough, and a kernel with no buffers asks for
`maxSets` 0. The two senders are `PVComputeKernel >> prepare` and
`VkDevice >> createDescriptorPool:`, both project code, so the signature can change freely.

A zero-buffer compute kernel is reachable, not hypothetical: `PVKernelCompiler class >>
computeParamTypes` counts `#workItem` and the `#sharedOf_*` types, so a kernel taking a work
item and a shared tile and no storage buffer is a compute kernel with an empty `buffers`.

1. **Observe first.** Put a kernel with no `bindBuffer:` through `prepare` on the device and
   record what actually happens. Pool creation with `maxSets` 0 may well succeed and fail
   later in `allocateSet:`. The test pins what was observed, not what the specification is
   assumed to say.

   **Observed on the Iris Plus, 11 October 2026.** `VkDescriptorPool on: device maxSets: 0`
   succeeds and answers a live handle, although `maxSets` 0 violates
   VUID-VkDescriptorPoolCreateInfo-maxSets-00301. The failure arrives one call later, out of
   `allocateSet:`, as `-1000069000` — `VK_ERROR_OUT_OF_POOL_MEMORY`, which the bindings did
   not declare, so the message read `VkError: 'Vulkan error: VK_UNKNOWN(-1000069000)'` and
   named neither the kernel nor the missing buffers. A zero-buffer kernel through `prepare`
   fails the same way. So the code under test was never the pool refusing anything: it was
   the pool cheerfully building something useless. `VkResult class >> vkErrorOutOfPoolMemory`
   is now declared, with `VkBindingsTest >> testOutOfPoolMemoryIsADeclaredResultCode`
   covering it, which is the same drift `nameForCode:` was fixed for in G-6.
2. **Red, two tests.**
   - `testDescriptorPoolCountsSetsAndDescriptorsSeparately`: build a pool with one set and
     three storage descriptors, allocate one set against a three-binding layout and update all
     three bindings. Red today by message-not-understood, because the API cannot express the
     two numbers separately.
   - `testComputeKernelWithNoBuffersIsRefusedClearly`: pins whatever step 1 found, as an
     explicit raise rather than a pool built for zero sets.
3. **Green.** Add `create:descriptorCount:` and `VkDescriptorPool class >>
   on:maxSets:descriptorCount:`, and give the pool-size count — the literal `1` at offset 25 —
   a named class-side constant. Update both senders: `VkDevice >>
   createDescriptorPool:descriptorCount:`, and `prepare` passing `maxSets: 1 descriptorCount:
   buffers size` and raising when `buffers isEmpty`. Delete `on:maxSets:` unless a caller still
   wants it.
4. **Example.** `VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers`, following
   `VkBuffer class >> exampleStorageBufferOfFourFloats` for how an example that needs a live
   device handles it.
5. **View.** `VkDescriptorPool >> inspectorPool:`: maxSets, descriptorCount, the descriptor
   type by name, and the sets allocated so far.
6. `run_critics` on `VkDescriptorPool`, `VkDevice` and `PVComputeKernel`.

## D — the descriptor pool create info was a block of hand-counted bytes

Recorded below as out of scope on 11 October 2026, taken as its own unit on 12 October 2026.

`VkDescriptorPool >> create:descriptorCount:` wrote the pool size and the create info as two
`ExternalAddress` blocks with the offsets counted by hand — 1 and 5 in the size, 1, 9, 17, 21, 25
and 33 in the create info. That is the hazard class recorded in `PHASE7-PLAN.md` §5 and the one
that corrupted object memory once already: an offset counted short of the struct writes outside
it, and nothing says so until an unrelated object changes.

**Fixed.** Two structures are declared field by field, so uFFI computes every offset:

- `VkDescriptorPoolSize`, two `uint32` members, eight bytes.
- `VkDescriptorPoolCreateInfo`, forty bytes. uFFI puts the four-byte hole between
  `poolSizeCount` and the eight-byte-aligned `pPoolSizes` by itself, and the compiled offsets
  come out 0, 8, 16, 20, 24, 32 — the C layout the driver reads.

`initialize` on the create info names the structure type and clears the chain pointer.
`FFIStructure class >> fromHandle:` sends `initialize` after setting the store, so an instance
from `VkStructure class >> externalInstance` is as ready as one from `new`; that is observed
behaviour, pinned by a test, and it is why the writing code sets only the two counts and the
pointer. Both stores stay outside object memory, because the create info holds a pointer to the
pool size and a store inside the image could be moved by the garbage collector between that
pointer being written and the driver reading it.

`create:descriptorCount:` is now four short methods — it kept the counts, and
`poolSizeOutsideObjectMemory`, `handleForPoolSize:` and `handleForCreateInfo:` each own one
step and one `ensure:` — which also cleared the `ReLongMethodsRule` critique it used to carry.

Six tests, all red first:

- `testDescriptorPoolSizeLayoutMatchesTheCLayout` and
  `testDescriptorPoolCreateInfoLayoutMatchesTheCLayout` pin the offsets, the widths, the
  alignment of each field and the struct size, read back from the compiled field specification.
  Red by undeclared variable before the classes existed.
- `testDescriptorPoolCreateInfoPointsAtThePoolSizeItWasGiven` reads the pool size back through
  the pointer, so a setter that copied bytes instead of storing an address would fail.
- `testDescriptorPoolCreateInfoCarriesItsOwnStructureType` pins what `new` and
  `externalInstance` each leave in the store, including the zeroed pool size as the degenerate
  case.
- `testDescriptorPoolCreateInfoLayoutRowsReadTheStoreAndLeaveItAlone` asserts the Layout view
  reads this instance's bytes and leaves the store byte-identical.
- `testDescriptorPoolCreateWritesThroughDeclaredFields` finds every `VkDescriptorPool` method
  that mentions either structure and asserts none of them pokes a raw offset, so splitting the
  method further keeps the rule enforced. Red by `#(pointerAt:put: unsignedLongAt:put:)`.

The driver leg is the suite that already existed: `VkCoreTest` builds a pool through this path,
allocates a set against a three-binding layout and updates all three bindings, and stays green,
so the declared layout is accepted by the driver rather than only by uFFI.

`layoutRows`, `inspectorLayout:` and `headOfFieldAt:size:` moved up from
`VkPhysicalDeviceProperties` to `VkStructure`, with `headByteCount` on its class side, because
three classes need them now and every body was already generic. Every structure declared field
by field therefore has a Layout tab read from its own field specification. Examples:
`VkDescriptorPoolSize class >> exampleThreeStorageBufferDescriptors` and
`VkDescriptorPoolCreateInfo class >> exampleForOneSetOfThreeDescriptors`, both built in object
memory so a click frees nothing; the create info example leaves `pPoolSizes` null on purpose,
because an example must not hold a pointer to a store it does not own.

Whole project: 324 tests over the nine concrete test classes, all passing. `run_critics` is
clean on `VkDescriptorPoolSize`, `VkDescriptorPoolCreateInfo`, `VkStructure` and
`VkDescriptorPool`, except the long-method critique on `allocateSet:`, which is the next item.

Committed as 49547ac, "Declare the descriptor pool create info field by field".

## E — the descriptor set allocate info was a block of hand-counted bytes

Recorded as out of scope under D on 12 October 2026, taken as its own unit on 13 October 2026.

`VkDescriptorPool >> allocateSet:` wrote `VkDescriptorSetAllocateInfo` as a forty-byte
`ExternalAddress` block with the offsets 1, 9, 17, 25 and 33 counted by hand, three nested
`ensure:` blocks deep, and it carried the `ReLongMethodsRule` critique `create:descriptorCount:`
had just lost. Same hazard class as D: an offset counted short of the struct writes outside it,
and nothing says so until an unrelated object changes.

**Fixed.** `VkDescriptorSetAllocateInfo` is declared field by field, so uFFI computes every
offset. The compiled layout comes out 0, 8, 16, 24, 32 over forty bytes — the C layout the
driver reads, with the four-byte hole between `descriptorSetCount` and the eight-byte-aligned
`pSetLayouts` put there by uFFI rather than by us. `descriptorPool` is declared
`VkDescriptorPool_H*`, because a Vulkan handle is pointer wide and not a count; declaring it as
a `uint32` would have been the silent short write.

`initialize` names the structure type and clears the chain pointer, as the pool create info
does, so an instance from `externalInstance` arrives ready and the allocating code writes only
the pool, the count and the layout array.

`allocateSet:` is now four short methods, each owning one step and one `ensure:`:

- `allocateSet:` builds the layout handle array and frees it after the driver has read it.
- `layoutArrayOutsideObjectMemory:` builds that array. This is the one block of bytes the pool
  still indexes by hand, because an array of pointers has no field specification for uFFI to
  compute offsets from; it is indexed by `handleByteCount` and sized from
  `setAllocationCount`, so the array and the count the driver is given cannot disagree.
- `setForLayoutArray:layout:` fills the allocate info through the generated accessors and frees
  its store once the driver has read it.
- `setForAllocateInfo:layout:` makes the call, checks the result before reading the handle block,
  and counts the allocation only after the call succeeded.

Two new class-side constants replace the literals that were inline on the allocate path:
`setAllocationCount`, one set per call, and `handleByteCount`, `ExternalAddress wordSize`.
`handleForCreateInfo:`, on the create path, still allocates its handle block from a literal 8;
changing it is cosmetic and this project does not touch image code without a bug behind it, so it
waits for the unit that declares the pool create info's own allocation.

Three tests, all red first:

- `testDescriptorSetAllocateInfoLayoutMatchesTheCLayout` pins the field names, the offsets, the
  struct size, each field's self-alignment and the absence of overlap, all read back from the
  compiled field specification. Red by undeclared variable before the class existed.
- `testDescriptorSetAllocateInfoCarriesItsOwnStructureType` pins what `new` and
  `externalInstance` each leave in the store, with the zero set count as the degenerate case: a
  count left at zero asks the driver for no set at all.
- `testDescriptorPoolCreateWritesThroughDeclaredFields`, the reflective poke test from D, now
  covers all three structures and asserts at least three builder methods. Red while
  `allocateSet:` was still the only method mentioning the allocate info and still poking
  offsets into it. The layout handle array is outside its reach on purpose, because the method
  that writes it names no structure class, which keeps the test about structure fields.

A fourth test, `testDescriptorSetAllocateInfoRequestReportReadsItsFieldsAndLeavesThemAlone`,
came with the view rather than before it: it asserts the Request rows follow the compiled field
specification, maps the structure type row's name back to the constant so a second constant of
the same value cannot make it pass by accident, and asserts the store is byte-identical after
the report is built.

The driver leg is again the suite that already existed: `VkCoreTest` allocates a descriptor set
against a three-binding layout through this path, and `PVComputeTest` dispatches kernels that
bind those sets, so the declared layout is accepted by the driver and not only by uFFI.

Example: `VkDescriptorSetAllocateInfo class >> exampleForOneSetOfThreeBindings`, built in object
memory so a click frees nothing, with the pool handle and the layout array left null on purpose.
View: the Layout tab comes free from `VkStructure`, and `inspectorRequest:` adds a Request tab
that shows what each declared field asks the driver for — the structure type named by asking
`VkStructureType` which constant answers the value in the store, counts as themselves, pointers
as set or not set. Its rows come from `layoutRows` and the generated accessors, so a field added
to `fieldsDesc` appears by itself.

## F — the descriptor write was a block of hand-counted bytes, and two uFFI facts came out of it

Taken as its own unit on 13 October 2026, after an inventory of every method in the project that
still writes a structure as a block of bytes. That inventory is now `LAYOUT-PLAN.md`; this unit
is the one it starts from, and the descriptor path is clean after it.

`VkDescriptorSet >> updateStorageBuffer:atBinding:` wrote `VkDescriptorBufferInfo` as a
twenty-four-byte block and `VkWriteDescriptorSet` as a sixty-four-byte block, with the offsets
1, 9, 17 and 1, 9, 17, 25, 29, 33, 37, 41, 49, 57 counted by hand, two nested `ensure:` blocks
deep. Every compute dispatch in the project goes through it.

**Fixed.** Both structures are declared field by field:

- `VkDescriptorBufferInfo`, twenty-four bytes, offsets 0, 8, 16. The handle is pointer wide and
  both `VkDeviceSize` members are `uint64`, so there is no hole.
- `VkWriteDescriptorSet`, sixty-four bytes, offsets 0, 8, 16, 24, 28, 32, 36, 40, 48, 56. The
  four `uint32` members fill the sixteen bytes between the pointer-wide `dstSet` and the three
  eight-byte-aligned pointer members exactly, so uFFI needs no pad.

`updateStorageBuffer:atBinding:` is now three methods: it builds the buffer info and frees it
after the driver has read both, `bufferInfoOutsideObjectMemoryFor:` names the buffer and the
whole range, and `updateBinding:fromBufferInfo:` fills the write through the generated accessors
and makes the call. The descriptor type comes from `VkDescriptorPool class >> descriptorType`
rather than from a literal, so a write cannot name a type the set was never allocated for, and
the counts and the sentinel became `VkDescriptorSet class >> descriptorsPerWrite`,
`writesPerUpdate`, `copiesPerUpdate`, `firstBinding` and
`VkDescriptorBufferInfo class >> wholeSize`.

Five tests were red first: the two layout tests, the structure-type test for the write with its
zero count and zero binding as the degenerate states, the `VK_WHOLE_SIZE` test, and the
reflective test that no method of `VkDescriptorSet` mentioning either structure pokes a raw
offset. The driver leg is `VkCoreTest` and `PVComputeTest`, which update descriptor sets on
every kernel they dispatch.

### Two uFFI facts the unit uncovered, each with its own failing test first

**A pointer field was reported as the size of what it points at.**
`VkStructure class >> layoutRows` took each field's width from `type externalTypeSize`, and
`FFIExternalStructureType` answers the pointed-to structure's size for that, not a pointer's.
So `pBufferInfo` was reported as twenty-four bytes wide and running over `pTexelBufferView`; the
layout test's overlap assertion caught it. It had been invisible until now only because the one
other struct-pointer field in the image, `pPoolSizes`, points at an eight-byte structure.
`layoutRows` now asks `isPointer` first. The fix is pinned by
`testLayoutRowsReportEveryPointerFieldAsOnePointerWide`, which sweeps every structure in the
image that declares a field specification and asserts no field runs past the end of its struct
or into the next one, so the next structure declared is covered too. The Layout tab and
`headOfFieldAt:size:` read the corrected widths.

**Reading a struct-pointer field wrote through the pointer.**
uFFI's generated getter answers the pointed-to structure through `fromHandle:`, and
`FFIStructure class >> fromHandle:` sends `initialize`. `VkDescriptorBufferInfo >> initialize`
set the range to `VK_WHOLE_SIZE`, so reading `aWrite pBufferInfo` rewrote the range of whatever
buffer info the write pointed at — a real length came back as the sentinel — and the same read
over a null pointer failed in the FFI primitive with `primitive
#integerOfObject:at:put:size:signed: in TFFIBackend failed`. Both are stated by
`testStructPointerFieldReadLeavesThePointeeAlone`.
`VkStructure >> initialize` now guards on a null store and defers to
`initializeConstantFields`, which subclasses override instead of `initialize`; what goes there
must be constant for the type, which `sType` and a cleared `pNext` are. The six structures that
overrode `initialize` — `VkApplicationInfo`, `VkInstanceCreateInfo`,
`VkDescriptorPoolCreateInfo`, `VkDescriptorSetAllocateInfo`, `VkDescriptorBufferInfo` and
`VkWriteDescriptorSet` — were converted, and the buffer info's range moved out of the
initialization into the method that builds one for the driver. A zeroed range is not a legal
descriptor, so that method names it explicitly and the test pins the zero as the degenerate
state.

### Lifted, deleted and accepted

`requestReport`, `describeField:value:` and `inspectorRequest:` moved from
`VkDescriptorSetAllocateInfo` up to `VkStructure` as `fieldReport`, `describeField:value:` and
`inspectorFields:` — a Fields tab beside the Layout tab, for every structure declared field by
field, showing what each field says rather than where it sits: the structure type named by
asking `VkStructureType` which constant answers the value in the store, counts as themselves,
pointers as set or not set. A field whose accessor was never generated is left out rather than
failing. `testFieldReportReadsEveryDeclaredStructureAndLeavesItAlone` sweeps every declared
structure and asserts the store is byte-identical after a report is built, which is what lets a
filled-in structure be inspected while a driver still holds a pointer to it.

`VkDeviceQueueCreateInfo` and `VkTestStruct` were deleted. Both were stubs with a `fieldsDesc`
in a syntax uFFI cannot resolve — `layoutRows` on either answered `Unable to resolve external
type` — no accessors had ever been generated for them, and nothing in the image or the sources
referenced either. `LAYOUT-PLAN.md` §1 declares the queue create info properly.

Two critiques are accepted rather than fixed: `ReExcessiveVariablesRule` on
`VkWriteDescriptorSet`, which is one `OFFSET_` class variable per field and the price of
declaring a ten-field C struct — `VkPhysicalDeviceLimits` carries the same one — and
`ReExcessiveMethodsRule` on `VkBindingsTest`, which follows from this project's one-test-class-
per-package convention. The protocol of `fieldsDesc` on `VkApplicationInfo` and
`VkInstanceCreateInfo` was corrected to `field definition` while their initialization changed,
which cleared the inconsistent-classification critique on both.

Whole project after the unit: 335 tests over the nine concrete test classes, all passing — 55
`VkBindingsTest`, 53 `VkCoreTest`, 57 `PVComputeTest`, 40 `PVGraphicsTest`, 5 `VkImageTest` and
125 over the four compiler and SPIR-V classes. `run_critics` is clean on `VkDescriptorBufferInfo`,
`VkDescriptorSet`, `VkStructure`, `VkApplicationInfo` and `VkInstanceCreateInfo`.

## Out of scope, recorded rather than fixed

The hand-written byte offsets inside `VkDescriptorPool >> create:` — 8, 40, 9, 17, 21, 25, 33.
They were the struct-writing style used throughout the bindings where no uFFI structure was
generated. Fixed as defect D above, on its own, with its own layout tests, measured against the
driver the way `VkPhysicalDeviceProperties` was.

The hand-counted offsets in `VkDescriptorPool >> allocateSet:` — 1, 9, 17, 25 and 33 — and the
long-method critique it carried. Fixed as defect E above, on its own, the same way D was.

The hand-counted bytes in `VkDescriptorSet >> updateStorageBuffer:atBinding:`. Fixed as defect F
above, which also finished the descriptor path.

Every other structure the bindings write as a block of bytes rather than through a declared field
specification: thirty-five methods, inventoried by subsystem in `LAYOUT-PLAN.md` with the shape
each unit should take and the four rules defects D to F established. They are worth taking one at
a time rather than in a sweep, because the layout test is what makes each one safe and a sweep
would land them all untested at once.
