# PharoVulkan — architecture and code review, with the plan that follows from it

Written 2026-11-06, against `93484e1`, from the live image and the checkout, with nothing modified.

## Baseline, measured before any diagnosis

The whole test suite was run forked at priority 45, one class at a time, every concrete `TestCase`
of every `PharoVulkan-*-Tests` package:

```
635 ran, 634 passed, 0 skipped, 0 expected failures, 1 failure, 0 errors
```

`CLAUDE.md` says the suite is 621 tests and passes. Both halves of that sentence are now wrong: the
count has grown by fourteen and one test is red. Correcting the sentence belongs to this plan, at
the end, when the number is stable again.

Every figure below — line counts, method counts, sender counts — was read from the image, not
estimated.

## How the plan is meant to be executed

The project's own cycle applies to every step: one refactoring at a time, the suite re-run after
each, an Iceberg commit at each green step, and prefer Pharo's automated refactorings (rename,
extract, move) over editing source by hand, because they rewrite the senders.

No test is changed during the refactoring phase. Step 1 is the exception and it is deliberate: it
is a bug *in* a test, which is why it is step 1 and not part of the refactoring sequence.

The checkout currently holds three untracked markdown files (`P7-LOAD-PROOF.md`,
`PACKAGE-SPLIT-PLAN.md`, `VECTORGRAPHICS-REVIEW.md`). An Iceberg commit from the image sweeps
every untracked file in the working copy, so they must be committed, moved or ignored before the
first commit of this plan.

---

## P0 — broken, or forbidden by the project's own rules

### 1. The red test: `VkBindingsTest >> testSwapchainCreationWritesNoScalarFieldAtAHandCountedOffset`

The test asserts that the set of `VkSwapchain` methods reaching for a counted byte offset is
exactly a list of five selectors, written out as strings. The image answers:

```
'VkSwapchain >> acquireNextImage:fence:timeout:'   "actual"
'VkSwapchain >> acquireNextImage:fence:'           "expected"
```

The other four entries match. The method gained a `timeout:` keyword and the pinned list did not
follow, so the test fails for a reason that has nothing to do with the fact it is defending. The
fact itself still holds.

**Refactoring: Replace Hard-Coded List with Computed Expectation.** The test's own comment already
states the rule it means to enforce — "what is left is named, and none of it is a structure". Assert
that rule instead of the five strings: check that every offender is one of the named roles (the out
parameter a creation answers through, the image index an acquire is given, the count and run of
image handles, the two runs of one entry), so that renaming a method cannot turn the gate red and
adding a new raw-offset method still can.

Gain: high — a green suite is the precondition for everything else here. Risk: none; one test
changes and no production code does.

**Done.** The test now reads the memory instead of the selectors: a method may reach a counted
offset only if it allocates the block itself, through `ExternalAddress`, and names no declared
structure while doing so. Both halves were proved by planting a violation of each — a poke into a
`VkSwapchainCreateInfoKHR` it allocated, and a poke into a handle it was given — and each one alone
turns the test red. It also denies an empty scan, so a mistyped ban list cannot pass in silence.

Twenty-six sibling tests in `VkBindingsTest` carry their own copy of the same twelve-selector ban
list. Five of them pin the allowed selectors as strings (`equals: #( 'VkSurface >> ...' )`) and are
a rename away from the same false red: `testSurfaceQueriesReadNoFieldAtAHandCountedOffset`,
`testImageCreationWritesNoScalarFieldAtAHandCountedOffset`,
`testRenderPassCreationWritesNoScalarFieldAtAHandCountedOffset`,
`testComputePipelineCreationWritesNoFieldAtAHandCountedOffset` and
`testNoOffsetIsCountedInTheGraphicsPipelineAnyMore`. Two more look a method up by selector
(`VkImage >> #createView`), which errors rather than fails when the selector moves. Converting them
is not part of this point; the test above is the shape to follow.

### 2. Two class-side methods named after a reflection selector

The global standard forbids this outright: a class-side constant named after a selector Pharo's own
tools send hides that selector, and the breakage shows up in the browser and in Renraku rather than
in a test.

- `PVKernelCompiler class >> compile:` (`^ self new method: aCompiledMethod; compile`) hides
  `Behavior >> compile:`. Verified in the image: `PVKernelCompiler class lookupSelector: #compile:`
  resolves to the project's override. 63 senders in the project.
- `SpvMemorySemantics class >> release` (`^ 16r4`) hides `release`. 1 sender.

**Refactoring: Rename Method**, with Pharo's automated rename so the senders are rewritten:
`compileMethod:` and `releaseSemantics` (or `semanticsRelease`, to keep the family prefix of its
siblings — read them before choosing).

Gain: high. Risk: low — mechanical, and the suite covers both call paths.

**Done.** `compileMethod:` and `releaseSemantics`, each carrying a comment naming the reflection
selector it must not be called after. The rename was done by hand rather than with Pharo's
automated rename: that refactoring rewrites every sender of the old selector in the image, and
`Behavior >> compile:` has senders all over Pharo that have nothing to do with this project. All 64
senders were rewritten — 63 here, and one in VectorGraphics (`VGVulkanCoverageKernel class >>
inspectorKernel:`), committed in that repository separately. `PVKernelCompiler`'s own class comment
claimed nine stages, an SSA stage and an entry point `compile:forDevice:` that does not exist; it
now lists the seven real ones. Commit `8107398`.

### 3. Twelve `on:do:` handlers that swallow the error

The standard treats a swallowing handler as always a bug. The three in `PVKernelCompiler >> compile`
are the worst of them:

```smalltalk
on: PVTypeError do: [ :e | typeMap := typeInf typeMap ]
```

A type error in the DSL is discarded and compilation continues with whatever partial type map the
inference had reached. A kernel that should have been refused is emitted instead, and the symptom
appears later as a `spirv-val` failure or a wrong result on the GPU.

**Refactoring: Replace Swallowed Exception with Named Failure.** Either let `PVTypeError` through,
or catch it and signal something that says what was lost. Write the failing test first: a kernel
whose types cannot be inferred must not compile.

Gain: high. Risk: medium — some currently-green tests may be passing *because* of the swallow, and
each one that turns red has to be read rather than patched.

**Done, for the three in `PVKernelCompiler >> compile`.** They are gone and the inference stage is
called plainly. The failing test came first: a kernel with a parameter no `<param:>` pragma declares
failed with `KeyNotFound: key 5 not found in Dictionary` from inside the emitter, where the
inferencer had already said `Cannot infer type for recv of +`. `PVUninferableTypeFixture` now holds
the kernels whose types cannot be inferred, as `PVCfgShapeFixture` holds the CFG shapes, and
`PVCompilerTest` pins both verdicts. No test was passing because of the swallow: 137 green in the
compiler and SPIR-V suites, 445 in the rest, 53 in the graphics suite. Renraku's
`ReTempsReadBeforeWrittenRule` on `typeMap` went away with the handlers. Commit `847bd5c`.

**Triage of the rest.** Eleven of them read `on: VkError do: [ :error | nil ]` in the `*Examples`
classes and in `VkPhysicalDevice >> memoryTypeRows`. Each catches one named condition — a machine
with no device, or no memory type matching the allocator's requirement — and the caller tests the
nil on the next line. They are narrow and handled, and they stay.

**Debt, deliberately not fixed: `VkXmlParser >> parseEnums`.** Its `on: Error do: [ :e | 0 ]` turns
a value of `vk.xml` it cannot read into the constant 0, so a wrong Vulkan enum would reach the
generated bindings in silence. It is dev-time code with one sender, `VkBindingGenerator >>
generateAll:`, and `PharoVulkan-Generator` has no test package at all: fixing it red-first means a
new `PharoVulkan-Generator-Tests` package, an entry for it in `PVArchitectureTest class >>
allowedDependencies` and a group in `BaselineOfPharoVulkan`. That is a unit of work of its own, not
a line in this point, and it is recorded here so the next regeneration of the bindings knows.

---

## P1 — the structure says something the code does not do

### 4. A dead SSA stage, and three documents that claim it runs

`PVSSAConstructor`, `PVSSAVar` and `PVPhiNode` have no sender outside their own tests. Meanwhile:

- the `PharoVulkan-Compiler` package comment lists eight pipeline stages including
  `PVSSAConstructor`, and states that the compiler "puts the registers into SSA form";
- `CLAUDE.md` says nine stages;
- `CLAUDE.md`'s frozen-decisions table pins "SSA algorithm: Braun et al. (on-the-fly)".

And in `PVKernelCompiler >> compile` the stage is called and its result thrown away:

```smalltalk
blocks size = 1 ifTrue: [
  | cfg ssaCFG |
  cfg := PVCFGBuilder buildFrom: regOps.
  ssaCFG := PVSSAConstructor construct: cfg.
  ^ PVSPIRVEmitter compileKernel: regOps typeMap: typeMap annotation: annotation
      selectorTable: st name: method selector ]
```

Neither temporary reaches the emitter. The work is done on every single-block kernel and discarded.

**Refactoring: Remove Dead Code**, plus a correction to the package comment and to `CLAUDE.md`.

This is the one point in the plan that needs a decision rather than an edit, because the two ways
out are opposite: delete the stage and say the compiler does not use SSA, or keep it and wire it
into the emitter. Deleting is cheap and honest; wiring it in is a feature, not a refactoring, and
belongs in its own phase with its own tests.

Gain: high — a plan document that lies about the pipeline is worse than no document. Risk: low if
the stage is deleted; the suite's SSA tests go with it.

**Done, by deleting the stage.** `PVSSAConstructor`, `PVSSAVar`, `PVPhiNode`,
`PVControlFlowGraph`, `PVBasicBlock` and `PVCFGBuilder class >> buildFrom:` are gone, with the two
tests that were their only senders. `PVSSAConstructor >> construct:` answered its argument
unchanged, so no emitted module can differ. The tag `SSA` was renamed `Registers`, and the
documents that claimed the stage runs were corrected: the `PharoVulkan-Compiler` package comment,
`CLAUDE.md` (stage count and the frozen-decisions row, which now reads that there is no SSA
algorithm and that `PVSPIRVEmitter` writes `OpPhi` by saving and restoring its register map),
`README.md`, `doc/architecture.md` and `doc/compute-tutorial.md`. `prompt.md`, `design-notes.md` and
`PACKAGE-PLAN.md` were left alone as the historical record. Commit `8de4299`.

### 5. `PVKernelCompiler >> compile` mixes three levels of abstraction

54 lines. The prologue that builds the register operations is written three times over, and the
dispatch on node kind is a type test:

```smalltalk
node isKindOf: PVSelectionNode
node isKindOf: PVLoopNode
```

**Refactoring: Extract Method** on the triplicated prologue first (it is what makes the method
unreadable), then **Replace Conditional with Polymorphism**: `PVSelectionNode >> emitWith:` and
`PVLoopNode >> emitWith:`, each sending to the emitter what it needs. Do these as two commits, not
one.

Gain: high. Risk: medium — the extraction is safe; the polymorphic dispatch moves code across
classes and wants the suite between each move.

**Done, in the two commits the point asks for.**

First, Extract Method. `decode` runs stages one to four once and keeps its four results in slots,
and each target reads them: `compileVertexShader`, `compileFragmentShader`, `compileComputeKernel`
and `compileGenericKernel`. `recognizedNodeOr:` refuses the recogniser's nil answer in one place
instead of four. `compileComputeBlocks:regOps:typeMap:selectorTable:` is gone — its four arguments
were the slots the caller had just filled. `compile` is eleven lines at one level of abstraction,
and `run_critics` on the class went from a long method and a high cyclomatic complexity to empty.

Second, Replace Conditional with Polymorphism. The seven `isKindOf:` tests are gone. A target now
sends `emitKernelWith:`, `emitComputeKernelWith:` or `emitShaderWith:executionModel:` to the node
the recogniser matched. This needed the step the point does not name: the three node classes each
subclassed `Object`, so a refusal had no single home and a shape with no emitter for the target in
hand would have reached a doesNotUnderstand. **Extract Superclass** `PVStructuredNode` holds the
three refusals and `coveredBlocks` as `subclassResponsibility`; `PVSelectionNode` overrides all
three emitters, `PVLoopNode` two, `PVNestedLoopNode` only the compute one. Adding a shape now means
adding a subclass with the emitters it has, not a branch in four cascades.

The refusal text changed, deliberately: a shader path said `Unsupported CFG in vertex shader: X`
and now says `Unrecognized control flow node: X in a shader`. No test and no document quotes it;
`Unrecognized CFG shape`, which the tutorial and the README do quote, is the recogniser's nil
answer and is untouched.

Three tests hold the result. `PVCompilerTest >>
testCompilerAsksTheNodeToEmitInsteadOfTestingItsClass` reads every `PVKernelCompiler` method's AST
and fails on an `isKindOf:` send. `testNodeShapeWithNoEmitterBehindItIsRefusedByName` pins the
refusal naming the shape, over `PVCfgShapeFixture >> nestedLoops:`. `PVStructuredNode >>
targetRows`, the `Targets` inspector tab and
`testTargetRowsOfANodeReadTheOverridesAndNotAList` read which targets emit a shape by reflecting
over the node's own class — `classHoldingTheRefusals` asks which class implements `refuseFor:`
rather than naming it — so the tab cannot drift from the dispatch.
`PVCompilerExamples class >> selectionOfAClampKernel` gives the one click beside the nested-loop
example already there.

### 6. Magic values, against the project's own "No magic values" rule

The SPIR-V module prologue is written out ten times, with the numbers inline:

```smalltalk
mod addCapability: 1.
mod setAddressingModel: 0 memoryModel: 1.
…
operands: { mergeBlkSpv id. 0 }
```

`CLAUDE.md` names exactly this case as wrong, and names capabilities, addressing models and
SPIR-V word counts among the constants that must be declared.

**Refactoring: Extract Method** to one `SpvModule class >> newShaderModule` (or an instance-side
`beShaderModule`), with named constants behind it — `SpvCapability shader`,
`SpvAddressingModel logical`, `SpvMemoryModel glsl450`, and a named selection-control constant for
the trailing `0`. The constant classes already exist in `PharoVulkan-SPIRV`; check there before
adding any.

Gain: high — ten call sites collapse to one, and the rule the project wrote down starts holding.
Risk: low.

**Done**, in two steps, each one red test first.

`SpvModule >> beShaderModule` now writes the prologue, over `SpvModule class >> shaderCapability`
and the `logicalAddressingModel` and `glsl450MemoryModel` constants that already existed.
`SpvBuilder >> beShaderModule` delegates to it, so a caller holding a builder never reaches past it
to the module. Seventeen call sites lost their numbers: ten `PVSPIRVEmitter class` compile methods,
`PVTriangleScene >> buildVertexShader` and `buildFragmentShader`, `SpvEmitterTest` and
`SpvBuilderTest >> buildVectorAddModule`, `PVComputeTest >> buildVectorAddSpirv`, and two more
`SpvBuilderTest` tests. `SpvCapability`, `SpvAddressingModel` and `SpvMemoryModel` do not exist: the
package's convention is a constant on `SpvModule class`, so the capability was added there.

The trailing `0` of a merge instruction was written inline at five sites, and `PVSPIRVEmitter class`
held its own `selectionControlNone` and `loopControlNone` beside the `SpvSelectionControl none` and
`SpvLoopControl none` that `SpvBuilder` and `PVTiledMatmulKernel` already use. One number, two
names.
The two emitter constants are deleted and all nine sites now ask the SPIR-V constant classes.

`PVArchitectureTest >> testNoProjectMethodWritesTheModulePrologueAsANumber` holds it: it reads every
project method's AST and fails on a numeric literal passed to `addCapability:`,
`setAddressingModel:memoryModel:` or `setMemoryModel:memoryModel:`. A capability named by its own
symbol, `#Shader`, is the specification's name rather than a number and stays allowed. The test also
denies that the scan found nothing, so a mistyped selector cannot make it pass in silence.

`SpvModule >> headerRows` and the `Header` inspector tab read the module beside the prologue's own
constants, `SpvBuilderExamples class >> shaderModulePrologue` gives the one click, and
`SpvBuilderTest >> testHeaderRowsOfAModuleShowItsOwnValuesBesideTheShaderPrologue` proves the tab
reads the module and not a copy of the numbers.

---

## P2 — duplication

### 7. `PVSPIRVEmitter` is a god class

1950 lines, 131 methods, slots `{ #annotation . #regMap . #outputVarIds . #isVoidMain .
#demandBuiltIns . #sharedVariables }`. Forty-eight of the methods are class-side drivers that build
an instance and then steer it from outside:

```smalltalk
em := self new initialize.
…
em regMap copy
em regMap: condRegMapSave copy
```

`compileSelection:annotation:typeMap:selectorTable:` alone declares 23 temporaries, and reads the
simulator's answer positionally — `condSim first`, `second`, `third`, `fourth`.

Three smells, in the order they should be addressed:

- **Data clump.** `annotation:`, `typeMap:` and `selectorTable:` travel together through the whole
  class side. **Introduce Parameter Object**: a `PVCompilationContext` holding the three, built
  once by `PVKernelCompiler`.
- **Feature envy on its own instance.** The 48 class-side drivers manipulate `em`'s state from
  outside. **Move Method**: each becomes an instance method, and the class side keeps only the
  entry points.
- **God class.** Once the first two are done, the stages inside the emitter become visible and can
  be split by **Extract Class**. Not before: an extraction built on today's guess about the
  boundaries would have to be unpicked.

Also replace the positional `first/second/third/fourth` read of the simulator result with an object
that names its four parts (**Replace Data Value with Object**) — it is the cheapest piece of this
point and can be done first, on its own.

Gain: high. **Risk: high.** This is the last point of the plan, deliberately. One refactoring per
commit, suite between each, and stop at the first test that a refactoring forces to change.

### 8. Two families of classes with no common superclass

- Three hand-built kernel builders each define their own `spirv` and
  `newBufferVariableOfType:binding:`.
- Four benchmark and comparison runners each define their own `run` and `reportRows`.

Inside each family the methods are the same shape with different constants — three occurrences, so
the rule for extracting an abstraction is met.

**Refactoring: Extract Superclass**, then **Pull Up Method** for the shared bodies, leaving each
subclass only what differs.

Gain: medium. Risk: low.

**Plan as validated** (interviewed 2026-11-06; nothing edited before this was agreed).

Family 1 — `PVSpirvKernel`, an `Object` subclass with slots `spirv builder`, in
`PharoVulkan-Compute` tag `Kernels`, with a class comment. Abstract, so it gets no
`<sampleInstance>` example and no inspector view: an abstract class cannot be instantiated, and the
pulled-up bodies keep the coverage the three subclasses' tests already give them.

1. Rename `PVCooperativeMatrixKernel >> newBufferVariableOfPointerType:binding:` to
   `newBufferVariableOfType:binding:`, through Pharo's own rename refactoring so the senders are
   rewritten. The three bodies then agree and can be pulled up.
2. Create `PVSpirvKernel`, reparent `PVCooperativeMatrixKernel`, `PVOpcodeProbeKernel` and
   `PVTiledMatmulKernel` under it, and take `spirv` and `builder` out of each.
3. Pull up `spirv` (the lazy memo, identical three times) and `newBufferVariableOfType:binding:`
   (identical three times); delete the six copies.
4. Pull up `buildSpirv` as a template method:

   ```smalltalk
   builder := SpvBuilder new.
   builder addCapability: self class shaderCapability.
   self declareModule.
   self emitMain.
   ^ builder module serialize
   ```

   `SpvBuilder >> addCapability:` forwards to `module addCapability:`, so the capability line means
   what each of the three bodies means today. Each subclass keeps the rest as `declareModule`:
   `declareCapabilities` and `declareBuffers` for the cooperative matrix kernel, whose
   `declareCapabilities` loses its first line because the template now adds the shader capability;
   `ids := Dictionary new`, `declareTypes` and `declareBuffers` for the opcode probe;
   `declareBuiltIns`, `declareBuffers` and `declareSharedTiles` for the tiled matmul.
5. Declare `declareModule`, `emitMain` and class-side `shaderCapability` as `subclassResponsibility`
   on `PVSpirvKernel` — exactly what the pulled-up code sends, and no more.

Family 2 — `PVDeviceRun`, an `Object` subclass with slot `context`, in `PharoVulkan-Compute` tag
`Benchmarks`, with a class comment. Abstract, same consequence as above.

6. Create `PVDeviceRun` and reparent `PVBenchmark`, `PVSubgroupDotProduct` and
   `PVTiledMatmulComparison`, taking `context` out of each. `PVNoSubgroupArithmeticStub`, the
   graphics-free fixture, follows under `PVSubgroupDotProduct`.
7. Pull up `run` — allocate the buffers, run, destroy them in an `ensure:`. `PVSubgroupDotProduct`
   keeps an override: its availability guard, then `^ super run`. Delete the other two copies.
8. Declare `newBuffers` and `runWithBuffers:` as `subclassResponsibility` on `PVDeviceRun`.

Deliberately left alone. `PVCooperativeMatrixComparison` stays outside family 2: its `run` allocates
no buffer, so it would not follow the template and would inherit three hooks it has to switch off,
which would make the superclass a shared slot rather than a shared shape. `reportRows` is not pulled
up: its three bodies differ and no method of either superclass sends it. Nor are `groupCount`, the
`setContext:…` setters and `on:…` constructors of different arities, `voidType` (two occurrences),
`newBuffers`, `inputMatrixWithOffset:`, `order` and `repeats` of `PVBenchmark` and
`PVTiledMatmulComparison` (two occurrences), or `add:to:`, which names addition of floats in one
class and of unsigned integers in the other — a common name there would hide the difference. Two
occurrences are a coincidence; the rule needs three.

Verification. `PVComputeTest` (63 tests) after every step, and no test changed during the
refactoring: if a refactoring forces a test to change, stop and report it. `run_critics` on the five
touched classes and the two new ones. The whole suite at the end, with `PVGraphicsTest` forked.
`PVArchitectureTest class >> allowedDependencies` and `BaselineOfPharoVulkan` need no edit: no new
package and no new edge, since `PharoVulkan-Compute` may already reference `PharoVulkan-SPIRV`,
where `SpvBuilder` lives.

**Done, as validated.** `PVSpirvKernel` and `PVDeviceRun` exist, each abstract, each with a class
comment and neither with an example or a view.

`PVSpirvKernel` holds `spirv` and `builder` and, for `PVCooperativeMatrixKernel`,
`PVOpcodeProbeKernel` and `PVTiledMatmulKernel`: `spirv`, the lazy memo that was written three
times; `newBufferVariableOfType:binding:`, which was written three times once the cooperative matrix
kernel's `newBufferVariableOfPointerType:binding:` was renamed; and `buildSpirv` as the template,
which opens the builder, adds `self class shaderCapability` and then sends `declareModule` and
`emitMain`. Each subclass keeps its own `declareModule` with what the template does not do, and the
cooperative matrix kernel's `declareCapabilities` lost the shader capability line the template now
adds first — `SpvBuilder >> addCapability:` forwards to `module addCapability:`, so the three
modules are byte-for-byte what they were, which
`testCooperativeMatrixKernelFromPharoSourceMatchesTheHandBuiltOne` pins.

`PVDeviceRun` holds `context` and `run` for `PVBenchmark`, `PVSubgroupDotProduct` and
`PVTiledMatmulComparison`. `PVSubgroupDotProduct >> run` is now its availability guard and
`^ super run`, which `PVNoSubgroupArithmeticStub` still exercises. `PVCooperativeMatrixComparison`
stayed outside, as decided.

Two things the plan did not foresee. First, Renraku's `ReMissingSubclassResponsibilityRule` asks for
a `subclassResponsibility` on every selector all the subclasses define, not only on what the
pulled-up code sends: `PVSpirvKernel` therefore also declares `declareBuffers`, `interfaceVariables`
and class-side `entryPointName`, and `PVDeviceRun` also declares `groupCount` and `reportRows` —
declarations of the protocol, no body pulled up. Second,
`ReInconsistentMethodClassificationRule` then fired, because the subclasses had classified the same
selector under three different protocols: `run` is `running`, `runWithBuffers:` and `newBuffers` are
`private`, `reportRows` is `reporting`, `groupCount` is `accessing`, and `interfaceVariables` is
`building`, with four subclass methods reclassified to agree. Critics are clean on the eight
classes.

A trap for the next rename: the MCP `method_rename` tool removed
`newBufferVariableOfPointerType:binding:` without installing the renamed method and without
rewriting the one sender, and said so only as a hint ("Use find_senders to update callers"). The
body was recovered from Epicea through `e content methodRemoved sourceCode` on the newest
`EpMethodRemoval`. Check `allImplementorsOf:` after any rename through that tool.

No test was changed. The suite is 647 tests over eleven test classes and passes: 594 counted in one
run of the ten non-graphics classes, `PVGraphicsTest` (53) forked on its own, after the commit.
`allowedDependencies` and the baseline needed no edit.

### 9. The inspector-row infrastructure, duplicated nine times over three conventions

```smalltalk
rowNamed: aString value: aValueString
	^ Dictionary newFrom: { (#name -> aString). (#value -> aValueString) }
```

Nine identical copies of that method across nine classes. 62 `*Rows` methods feeding it. 61
two-column inspector views whose bodies are identical apart from the title and the row source. And
three competing conventions for what a row *is* — a `Dictionary` with `#name`/`#value`, a
two-element `Array`, and an `Association`.

A row carried as a dictionary is primitive obsession: the concept has a name in the domain and no
class.

**Refactoring: Replace Data Value with Object.** One `PVFactRow` with `name` and `value`, one
builder method that turns a collection of them into the table presenter, and the 61 view bodies
become one line each. Then the three conventions collapse into one.

This is the only new class the plan proposes. It pays for itself today: it deletes nine method
copies and 61 duplicated view bodies, and it removes the need to remember which of three
conventions a given class uses.

Gain: high. Risk: low — the views are covered by the builder-argument gate, and each converted view
can be checked by building it through `StInspectionContext`.

**Done.** `PVFactRow` holds `name` and `value`, converts both with `asString` so a view can pass a
number, a boolean or nil straight from the object it describes, and is `beReadOnlyObject` by
construction, which is the guarantee the dictionaries used to carry. Its class side holds the one
declaration of the two-column fact table this project shows,
`tableOf:nameColumn:valueColumn:in:`, and sixty-five views now answer that and nothing else:
thirty-four in Bindings, thirteen in Core, nine in Compute, four in Compiler, two in Graphics, two
in SPIRV, and `PVFactRow`'s own `Row` tab. No view declares a column any more.

The class has no layer, so it has no home in the existing eight packages: `allowedDependencies`
grants Bindings and SPIRV no outgoing edges, and putting the row in either of them would drag that
package into every group the other packages load. It lives in a new leaf package,
`PharoVulkan-Inspector`, with an empty allowed set. Bindings, SPIRV, Compiler, Core, Compute,
Graphics, Examples, `PharoVulkan-Bindings-Tests` and the aggregate `PharoVulkan-Tests` each gained
the single edge to it, in the table and in `BaselineOfPharoVulkan >> baseline:`;
`PVArchitectureTest >> testTheInspectorPackageStaysInsideItsAllowedDependencies` holds the new
package to its own empty set. The package is in no baseline group, because every group that loads a
package which builds rows requires it transitively.

The nine `rowNamed:value:` copies are deleted. Eighty-one row constructions in twelve store methods
now answer `PVFactRow` directly — `PVBenchmark`, `PVComputeKernel` (three stores),
`PVCooperativeMatrixComparison`, `PVCooperativeMatrixKernel`, `PVCooperativeMatrixSurvey`,
`PVFloat16`, `PVSubgroupDotProduct`, `PVTiledMatmulComparison`, `PVTiledMatmulKernel` and
`VkDescriptorPool` — so those ten views are one send with no `collect:` in front of it.
`PVPrecisionComparison` was left alone: its rows carry five keys and its tab is not a fact table.

Two things were deliberately not converted. The keyed `*Rows` stores of `PharoVulkan-Bindings` stay
dictionaries: a hundred and twenty-four test methods in `PharoVulkan-Bindings-Tests` read them by
key, and rewriting those tests buys no behaviour. Their views therefore still build the rows at the
view, from the store's own keys, rather than reading rows the store already holds. And
`VkBindingsTest >> testNoBindingReachesAnotherPharoVulkanPackage` gained one exception, written into
the test with its reason: the row reaches nothing itself, so it sits below the bindings rather than
above them.

Two consequences worth knowing. A hundred and eighty-four redundant `printString` sends went away,
because `PVFactRow` converts: `Object >> asString` is `^ self printString`, so only `String` and
`Symbol` values change, and they now read without quotes — which also removes the inconsistency
between tabs that quoted a string and tabs that did not. Thirty-two test methods changed because
they pinned the row representation rather than the fact: `at: #name` and `at: #value` became `name`
and `value`, `each second` became `each value`, and the `valueOfRowNamed:in:` helper of
`PVComputeTest` and of `VkCoreTest` reads the row's own messages. That is reported here rather than
passed over in silence, as the refactor step asks.

One trap, for the next mechanical rewrite of this kind. The script that converted the fifty-three
remaining views emitted the arguments unparenthesised, so
`PVFactRow name: each at: #name value: each at: #value` compiled as one send of
`name:at:value:at:` and fifteen views failed with a doesNotUnderstand at the first draw. A send
whose argument is itself a keyword message has to be parenthesised, and the check is cheap: read
every method's AST back and fail on a selector that begins with `name:` and is not `name:value:`.

`PVFactRow` carries the five tests of `PVFactRowTest`, the `<sampleInstance>` example
`PVFactRowExamples class >> wordCountRow` in the Examples package's new `Inspector` tag, and the
`inspectorRow:` tab that draws the row through the same declaration the other sixty-four views use.
`run_critics` is clean on the class. The suite is 647 tests over eleven test classes and passes.

---

## P3 — the rest, smallest gain last

### 10. Eight classes with no sender, and two type systems for one DSL

Eight classes are referenced from nowhere but their own tests (over and above the three SSA classes
of point 4). Separately, the DSL carries a type twice: once as a `Symbol` (`#f32`, `#vec3`) and once
as a token class. `PVVec3` is sixteen lines whose only method says it is "not callable from Pharo;
present to satisfy the linter" — a class that exists to quiet a tool.

**Refactoring: Remove Dead Code**, one class per commit, each with a `find_senders` check first.
The symbol-versus-token duplication is a design decision, not a cleanup: if the token classes are
the intended future of the DSL's type system, they need a sender; if the symbols are, the token
classes go.

Gain: medium. Risk: low, with the sender check. Needs your call on which of the two type
representations survives.

### 11. The architecture suite has no gate on views, examples or documents

`PVArchitectureTest` holds twenty tests and all twenty are about package dependencies. There is no
gate asserting that each of the project's 85 inspector views takes the presenter builder, that each
example lives in `PharoVulkan-Examples`, or that `doc/architecture.md` still describes the packages
that exist. VectorGraphics has those gates; this project does not, and the drift found at points 4
and 12 is what their absence looks like.

**Refactoring: none — new tests.** Three generic gates, modelled on the VectorGraphics ones, and
they must skip rather than fail when there is no Iceberg checkout, so a Metacello-loaded image
stays green.

Gain: medium, and it is the gain that keeps the rest of this plan from being undone. Risk: low.

### 12. One example outside `PharoVulkan-Examples`, and it opens a window

`PVHelloTriangleScene class >> renderTriangle` is an example by every test in the standard, living
on the subject class.

**Refactoring: Move Method** to `PVHelloTriangleSceneExamples class >> openRenderTriangle` — the
`example` prefix dropped, the `open…` prefix added because it opens a window, and `self` rewritten
to the subject class.

Because it drives the GPU through uFFI and opens a window, run it alone, against a committed
checkout.

Gain: low. Risk: low.

**Plan as validated** (interviewed 2026-11-06), and it is not the move this point first described.

The point was written against the standard's rule that an example lives in the `-Examples` package.
Two facts found before editing say the body cannot follow that rule literally. First,
`PVSceneExamples`'s own class comment already records the opposite decision: "The scene classes keep
`renderTriangle` themselves, because `doc/glsl-api-tutorial.md` documents it as the method a user
writes on their own scene" — which is the standard's own exemption for a method the documentation
tells a user to write. The tutorial does exactly that at its lines 252 and 335 to 357, and
`PVGlslTriangleScene`'s class comment names `PVGlslTriangleScene renderTriangle` as the entry point.
Second, a `renderTriangle` left behind to delegate to the examples class would be an edge from
`PharoVulkan-Graphics` to `PharoVulkan-Examples`, which the dependency table does not declare and
will not.

So the pragma moves and the body stays:

1. `PVSceneExamples class >> openRenderTriangle` and its `openGlslRenderTriangle`, each a one-line
   `<sampleInstance>` answering `PVHelloTriangleScene renderTriangle` and
   `PVGlslTriangleScene renderTriangle`. The `open…` prefix because they open a window.
2. Take `<sampleInstance>` off `PVHelloTriangleScene class >> renderTriangle`; the method and its
   comment stay, with a line saying why it is not in the examples package.
3. Delete `PVGlslTriangleScene class >> renderTriangle` outright. Its body was `^ super
   renderTriangle` and it existed only so the pragma would give that class a button of its own;
   inheritance already answers `PVGlslTriangleScene renderTriangle`, so the tutorial stays true
   without an edit.

Every clickable example then lives in `PharoVulkan-Examples`, the documented method stays where the
tutorial shows it, and no new dependency appears: `PharoVulkan-Examples` may already reference
`PharoVulkan-Graphics`, which is how `PVGlslTriangleScene` subclasses `PVHelloTriangleScene`.

`exampleFrameCount`, read by that method alone, and `exampleExtent`, read by five tests and ten
examples, both stay on the scene class with the body.

Verification: `run_critics` on the three classes, and `PVGraphicsTest` (53) run forked and alone
against a committed checkout, because the two new examples drive the GPU and open a window.

**Done, as validated.** `PVSceneExamples class >> openRenderTriangle` and `openGlslRenderTriangle`
are the two `<sampleInstance>` examples that open a window, one send each.
`PVHelloTriangleScene class >> renderTriangle` kept its body and lost the pragma, and its comment
now says why it is not in the examples package. `PVGlslTriangleScene class >> renderTriangle` is
gone: `PVGlslTriangleScene class lookupSelector: #renderTriangle` answers the inherited method, so
`PVGlslTriangleScene renderTriangle` in the tutorial and in that class's comment still works.

A scan of every method of every `PharoVulkan*` package counts 118 `<sampleInstance>` pragmas, none
of them outside `PharoVulkan-Examples`, where before there was one. The only senders of
`renderTriangle` are the two new examples. 594 tests over the ten non-graphics classes pass;
`PVGraphicsTest` (53) is run forked and alone after this commit, as the point requires.
`PVSceneExamples`'s class comment gained the paragraph about the two window openers, and
`doc/architecture.md` now states the rule and this one exception to where the documented method
lives.

Noticed on the way, and left alone: 74 class comments in `PharoVulkan*` packages hold LF rather
than CR in the image, `PVSceneExamples`'s among them before this change. It is invisible on disk —
Tonel writes LF for every line of all 366 exported files, and `grep -rlU $'\r' src/` finds none —
so the CR rule bites on method source, not on what Tonel normalises. A sweep would touch 74
comments for no change to the repository and is not part of this point.

---

## Order

```
1 → 2 → 3 → 4 → 6 → 5 → 9 → 8 → 12 → 11 → 10 → 7
```

The reasoning: get the suite green and the forbidden names gone first, because they are mechanical
and safe and everything after depends on a trustworthy suite. Then the swallowed errors and the
dead stage, which are about the code telling the truth. Then the duplication that pays immediately
(the row object, the two superclasses). Then the small moves and the new gates, which protect what
was just done. The god class last, when commits are small, the suite is reliable, and the
boundaries inside the emitter have become visible.

Points that need a decision from you before they can start, rather than an edit:

- **4** — delete the SSA stage, or wire it into the emitter?
- **10** — do the DSL's token classes survive, or the symbols?
- **3** — how far to go if removing a swallow turns other tests red.

## What is deliberately not in this plan

- No new layer, no new indirection and no design pattern for a need that has not appeared. The only
  class the plan adds is `PVFactRow` (point 9), and it is justified by what it deletes today.
- No change to the frozen design decisions in `CLAUDE.md`'s table.
- No touching the generated packages' content (`PharoVulkan-Bindings`, `PharoVulkan-SPIRV`) beyond
  named constants, because regeneration must not destroy edits.
- No mutation testing yet. MuTalk is the right check on point 1 and on any test that is factored
  together later, but it rewrites methods in the image, so it waits for a clean checkout and for the
  suite to be green.
