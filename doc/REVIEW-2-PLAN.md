# PharoVulkan — second architecture and code review, with the plan that follows from it

Written 2026-11-07, against `98685fb`, from the live image and the checkout, with nothing modified
before the plan was validated.

The first review is `doc/REVIEW-PLAN.md`; all twelve of its points are done. This second review was
asked for because a great deal changed while that plan was executed, and it reads the project as it
stands now rather than as it stood on 2026-11-06.

## Baseline, measured before any diagnosis

The seven non-device test classes were run as one in-image suite:

```
184 ran, 184 passed, 0 skipped, 0 expected failures, 0 failures, 0 errors
```

The device classes were read from the previous commit's forked runs: `VkCoreTest` 68,
`PVComputeTest` 63, `VkImageTest` 8, `PVGraphicsTest` 53, all green. The whole suite is 662 tests
over twelve concrete `TestCase` classes, which is what `CLAUDE.md` claims, so the documentation is
in step with the image.

Every figure below was read from the image, not estimated.

## What the architecture review found: nothing to change

- The dependency rule holds. `PVArchitectureTest class >> allowedDependencies` and
  `BaselineOfPharoVulkan` agree with what the code really references, and the twenty-two
  architecture gates are green.
- The two families extracted at point 8 of the first review are healthy: `PVSpirvKernel` has three
  subclasses and declares four hooks, `PVDeviceRun` has four subclasses and declares four hooks.
- No empty `on:do:` handler anywhere in the project.
- No method source holds an LF; all of them use CR, as the project requires.
- Every numeric literal that carries meaning lives in a named constant method, with four
  exceptions, which are point 6 below.

So the findings of this review are all at the level of the code, and the plan below is a code plan.

## How the plan is executed

The project's own cycle applies to every point: the failing test first when the point is a bug, one
refactoring at a time, the suite re-run after each, `run_critics` on what changed, and an Iceberg
commit at each green step. Pharo's automated refactorings are preferred over editing source by
hand, because they rewrite the senders.

No existing test is changed. Tests are added.

---

## 1. The memory properties block is allocated with a hand-written size and never freed

`VkPhysicalDevice >> fetchMemoryProperties` is:

```smalltalk
fetchMemoryProperties
    memoryProperties := ExternalAddress allocate: 520.
    Vk getPhysicalDeviceMemoryProperties: handle memoryProperties: memoryProperties
```

Three facts make this the first point of the plan:

- `520` is written in the method. No class describes `VkPhysicalDeviceMemoryProperties`, so nothing
  derives that number and no test checks it. It happens to be right — `memoryTypeCount` (4) +
  `memoryTypes[32]` (32 × 8) + `memoryHeapCount` (4) + four bytes of padding + `memoryHeaps[16]`
  (16 × 16) = 520 — but the next person to touch it has nothing to check it against, and a size that
  is too small is silent heap corruption rather than a failure.
- The block goes into the `memoryProperties` slot, which three methods read
  (`memoryTypeCount`, `memoryPropertyFlagsOfType:`, `memoryHeapIndexOfType:`), and
  `VkPhysicalDevice` has no `destroy`. The 520 bytes are never given back.
- Two further sites allocate outside object memory and hand the pointer to their caller without any
  stated rule about who frees it: `VkContext >> queuePriorityArrayOutsideObjectMemory` and
  `VkContext >> buildExtensionNameArray:`.

**Refactoring: Extract Constant**, then give the owner a destroy path, then state the ownership rule
where the code can hold it.

Gain: high — this is a correctness point, not a tidiness one. Risk: medium, because a `free` sent at
the wrong moment takes the image down, so the tests come first and the device classes are re-run
afterwards.

**Decided:** the size becomes a class-side constant on `VkPhysicalDevice` that names the fields it
adds up, with the arithmetic written out rather than the total. The failing test asserts the
constant equals that sum and that it is what `fetchMemoryProperties` asks for. A second test
asserts the block is released when the device is let go. The two `VkContext` sites get a comment
naming their caller as the owner; they are not changed otherwise, because the caller frees them
inside the same device-creation sequence.

## 2. Dead code: around thirty methods and nineteen slots used in one direction only

Scanning every method of `PharoVulkan-*` and `VectorGraphics-*` for sent selectors and for symbols
inside literal arrays leaves 76 selectors that nothing sends. Four groups of those are alive and
must stay:

- the SPIR-V and Vulkan constant vocabulary (26 selectors on `SpvOpcode class`,
  `SpvStorageClass class`, `SpvBuiltIn class`, `SpvMemorySemantics class`,
  `SpvSelectionControl class`, `SpvLoopControl class` and two others) — the project's own rule
  against magic values is what puts them there, and `VectorGraphics-Vulkan` reads part of the table;
- the nineteen methods of `PVBytecodeDecoder`, which is an `InstructionClient` and is driven by
  Pharo's own bytecode scanner;
- `PVOpcodeProbeKernel >> inspectorComparisonContext:`, which Pharo finds by naming convention from
  the `<inspectorPresentationOrder:title:>` view beside it;
- `PVWorkItem >> localZ`, which `PVWorkItem >> kernelSelectors` declares as DSL vocabulary beside
  `localX` and `localY`.

What is left is dead. The largest pieces are in the emitter: `emitSelection:function:condReg:` (56
lines), `emitBytecodeBlock:initialTempDefs:block:` (17 lines), `isVoidMain` and `outputVarIds:`.
Then `PVSelectorTable >> at:receiverType:ifAbsent:`, `PVBytecodeOp >> stackEffect`,
`PVSelectorMapping >> isSpecialForm`, five accessors of `PVBytecodeBlock`,
`PVTypeInferencer >> typeOf:` and `PVTypeInferencer class >> annotation:inferAll:selectorTable:`,
`PVTypeAnnotation >> shaderKind` and `paramTypeFor:`, `PVStructuredCFGRecognizer >> blocks:` and
`blockMap`, `PVCooperativeMatrixKernel class >> leftBinding` and `rightBinding`,
`PVOpcodeProbeKernel >> results`, two accessors of `PVCooperativeMatrixComparison`,
`PVTriangleScene >> pipeline`, `OSSDL2VulkanBackendWindow >> sdl2WindowHandle`, nine accessors
across `SpvFunction`, `SpvBuilder`, `SpvFunctionType`, `SpvPointerType`, `SpvGlobalVariable`,
`SpvTypeRegistry`, `SpvStructType`, `SpvMatrixType` and `SpvValidationError`, and the parsed-but-
unread descriptor fields of the generator (`VkMemberDescriptor >> arrayLen`, `arrayLen:`, `isConst`,
`VkTypeDescriptor >> alias`, `VkCommandDescriptor >> errorCodes`, `successCodes`,
`SpvGrammarParser >> operandKinds`).

Nineteen instance variables are read or written in one direction only, including
`PVBlockSimulator.annotation` and `.selectorTable` (carried from the first review),
`VkDescriptorSet.pool` and `.layout`, `VkSwapchain.surface`, `VkDevice.context` and
`VkQueue.familyIndex`.

**Refactoring: Remove Dead Code**, one selector at a time, each verified with `find_senders` across
the image before it goes.

Gain: high — the emitter alone loses 73 lines and two slots. Risk: low.

**Decided:** `VkDevice >> allocateBuffer:usage:`, `VkDevice >> createShaderModule:` and
`VkCommandPool class >> on:device:queueFamilyIndex:` are judged one by one when the point is
reached, because they read as published API rather than as leftovers; everything else on the list
goes. `VkCooperativeMatrixConfiguration`'s nine never-written slots are not touched: the structure
is filled by the driver through its FFI layout, so the scan cannot see the writer.

## 3. `PVSPIRVEmitter >> emitRegOp:block:` is a 146-line cascade of 34 conditionals

The method tests `op opcode` against `#const`, `#move`, `#self`, `#storeInstVar`, `#send` and
more, and inside the `#send` branch tests `mapping spirvOp` against a second list. It is the
textbook case for replacing a conditional with dispatch, and it is what the first review's point 7
left behind: that pass moved the stateless work out of the emitter, and what remains is the
dispatcher itself.

**Refactoring: Replace Conditional with Polymorphism**, in its table form.

Gain: high. Risk: low — the eighty-six tests of `PVCompilerTest` cover every path through it.

**Decided:** two levels, two moves. `PVSelectorMapping` answers the emitter selector for its own
`spirvOp`, which removes the envy of the emitter reading another object's symbol; and the first
level becomes a symbol-to-selector table on the class side of `PVSPIRVEmitter`, with one short
method per branch. No new class, no visitor hierarchy: the branches stay in the emitter, where they
already touch `module` and `regMap`.

## 4. A decoration is an `Array` with a symbol in slot one

`SpvSerializer >> emitAnnotations` reads `module decorations`, takes `d at: 1` as a tag, compares it
to `#decorate` and `#memberDecorate`, and builds a different instruction in each case. `instr` is
read before it is written, which Renraku reports and which only the `ifNotNil:` makes safe.

**Refactoring: Replace Data Value with Object** — a decoration answers its own `SpvInstruction` —
which deletes the type test with it.

Gain: medium to high; `PharoVulkan-SPIRV` is the most-read package of the project. Risk: low to
medium, depending on how many places build a decoration.

## 5. Two conformance gaps left by recent work

- `PVStructuredNode` declares one hook, but its three subclasses have implemented
  `simulationsWith:selectorTable:` since pass 3b of point 7, and the superclass does not declare it.
  Renraku reports the missing `subclassResponsibility`.
- `SpvMatrixType >> instruction` sits in protocol `emitting` while the ten sibling implementations
  sit in `encoding`.

Both are one-line corrections. Gain: small but real — the first is what tells a reader writing a
fourth node what to implement.

## 6. Four magic values left inline

`SpvSerializer >> serializeModule:` writes `Array new: 256`, `PVOffscreenTarget >> swatchFor:`
divides by `255`, `PVTriangleScene >> putFloat:into:at:` masks with `16rFF` four times and shifts
by 8, 16 and 24, and `VkPhysicalDevice >> fetchMemoryProperties` holds the `520` of point 1.

**Refactoring: Extract Constant.**

## 7. Inspector views are missing on the classes a reader opens

Views per hand-written package: `PharoVulkan-Core` 11 of 17, `PharoVulkan-Compute` 12 of 18,
`PharoVulkan-Compiler` 7 of 24, `PharoVulkan-Graphics` 5 of 17, `PharoVulkan-SPIRV` 4 of 39,
`PharoVulkan-Generator` 0 of 12. Examples are in better shape: 119 `<sampleInstance>` methods over
twenty `<Subject>Examples` classes.

**Decided:** a bounded subset, not forty views. Eight classes get one view each, chosen because a
reader actually inspects them: `SpvSerializer`, `SpvValidator`, `PVKernelCompiler`,
`PVTypeInferencer`, `PVSelectorTable`, `VkSwapchain`, `VkSurface`, `VkGraphicsPipeline`. Each view
takes the presenter builder, never mutates the inspected object, and asks the real rule rather than
restating it. The generator keeps none: it is dev-time code that no one inspects.

## 8. Seventy-four class comments hold LF in the image

Of 327 classes, 74 have a comment containing an LF, while every method source is CR-only. Tonel
normalises both to LF on disk, so nothing is visible in `src/`, and the inconsistency is image-only.

Gain: consistency with the project's own stated rule, nothing more. Risk: none. It is last but one
for that reason.

## What this plan deliberately does not do

- **No Extract Class on `PVSPIRVEmitter`.** It was diagnosed and rejected on evidence at point 7 of
  the first review: every emitting group touches `module` and `regMap`. Point 3 above cuts the worst
  method without adding a class.
- **No single home for the five byte-mask constants.** `VkBuffer class >> byteMask`,
  `PVSpirvValidator class >> byteMask`, `PVOpcodeProbeKernel class >> channelMask`,
  `PVOffscreenTriangleScene class >> fullChannel` and `SpvBuilderExamples class >> byteMaximum` are
  the same number five times, which meets the rule of three — but they live in packages that are
  not allowed to depend on each other, and inventing a shared leaf package for one integer costs
  more than the duplication. They stay local.
- **No deletion of the unsent SPIR-V vocabulary.** See point 2.
- **No renaming of the 37 protocols Renraku wants aligned with Pharo's.** Nineteen of them are
  `PVBytecodeDecoder`'s `instruction client`, which is deliberate and descriptive. The one real
  inconsistency inside the project is in point 5; the rest are banned with a reason, if they are
  touched at all.
- **No split of `VkBindingsTest`.** Its 286 tests are large for one class, but `CLAUDE.md` requires
  one test class per package, and changing that convention is not what this review was asked for.
- **No MuTalk run, and no test for `VkXmlParser >> parseEnums`.** Both are carried debt, recorded
  here so they are not forgotten, and neither is scheduled by this plan.

## Order

1 (the FFI leak, failing test first) → 2 (dead code) → 3 (`emitRegOp:block:`) → 4 (decorations) →
5 (conformance) → 6 (constants) → 8 (LF comments) → 7 (the eight views).

Point 1 is first because it is the only defect; 2 is next because it shrinks the surface every later
point reads. The device classes are run alone and forked after each commit that touches driver code,
which is points 1 and 7.
