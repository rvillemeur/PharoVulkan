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
