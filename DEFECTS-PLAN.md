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

## Out of scope, recorded rather than fixed

The hand-written byte offsets inside `VkDescriptorPool >> create:` — 8, 40, 9, 17, 21, 25, 33.
They were the struct-writing style used throughout the bindings where no uFFI structure was
generated. Fixed as defect D above, on its own, with its own layout tests, measured against the
driver the way `VkPhysicalDeviceProperties` was.

`VkDescriptorPool >> allocateSet:` still writes `VkDescriptorSetAllocateInfo` as a byte block
with the offsets 1, 9, 17, 25 and 33 counted by hand, and it carries the `ReLongMethodsRule`
critique that `create:descriptorCount:` just lost. It is the same hazard class as D and the
obvious next unit of work: declare `VkDescriptorSetAllocateInfo` field by field, with its own
layout test, and let the existing device tests be the driver leg.
