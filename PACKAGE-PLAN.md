# Package split plan

The project is one code package, `PharoVulkan`, with fourteen class tags, plus one test package
and the baseline.
Tags group classes in the browser and nothing more: they do not record which layer may depend on
which, they cannot be loaded separately, and they let a binding reach into the graphics code
without anything saying so.

This plan splits the code into eight packages along the lines the tags already suggest, moves the
examples into a package of their own, splits the tests to match, and then states the layering as a
test rather than as a paragraph in `CLAUDE.md`.

Written 16 October 2026, after `LAYOUT-PLAN.md` was finished and committed (`7c7ad0e`).
The dependency figures below were measured in the live image, not estimated: every method of every
class in `PharoVulkan`, instance side and class side, was read for literal variable bindings whose
value is a class of this project, and each reference was attributed to the target package the class
would move to.

## Why this is worth doing

1. **The layering becomes testable.** The compiler and the SPIR-V builder must not know about
   Vulkan; the compute and graphics code may. Today nothing can state that, because everything
   lives in one package. After the split a single test can read each package's outgoing references
   and fail when a new one crosses a line it should not.
2. **Parts can be loaded on their own.** The Pharo-to-SPIR-V half needs no driver and no SDL2. A
   baseline with real groups lets someone load the compiler without the FFI code, which also makes
   it loadable on a machine with no `libvulkan.so.1`.
3. **The test classes stop being buckets.** `CLAUDE.md` asks for one test class per package named
   `<Package>Test`. Nine concrete test classes currently share `PharoVulkan-Tests`, and
   `VkBindingsTest` alone holds 285 tests and carries an excessive-methods critique. Per-package
   test packages make the division principled instead of arbitrary.
4. **The examples get the home the standards ask for.** Examples belong in a sibling
   `<Project>-Examples` package. There are 130 example methods spread over the code packages, and
   they are the single largest source of dependencies that run the wrong way: a structure's example
   reaches up into the resource class that uses it. Moved out, the base packages stop depending on
   what sits above them.

## Current state

`PharoVulkan`, 291 classes:

| Tag | Classes |
|-----|---------|
| Bindings | 103 |
| SPIRV | 49 |
| Constants | 39 |
| Compiler | 23 |
| Graphics | 18 |
| Compute | 15 |
| Generator | 13 |
| Core | 11 |
| Compiler-Pipeline | 8 |
| SDL2 | 5 |
| Exceptions | 3 |
| Example | 2 |
| Manifest | 1 |
| Uncategorized | 1 |

`PharoVulkan-Tests`, 16 classes: nine concrete test classes and seven stubs, fixtures and the
manifest.

## Target packages

| Package | Classes | Depends on |
|---------|---------|------------|
| `PharoVulkan-Bindings` | 143 | nothing |
| `PharoVulkan-SPIRV` | 50 | nothing |
| `PharoVulkan-Compiler` | 32 | SPIRV |
| `PharoVulkan-Core` | 17 | Bindings |
| `PharoVulkan-Graphics` | 17 | Bindings, Core, Compiler, SPIRV, Compute |
| `PharoVulkan-Compute` | 15 | Bindings, Core, Compiler, SPIRV |
| `PharoVulkan-Generator` | 13 | Bindings, SPIRV |
| `PharoVulkan-Examples` | 2 + 130 extension methods | everything |

`Bindings` takes the `Constants` tag with it, because the constants classes have no client outside
the bindings and no life of their own; they stay a tag inside the package.
`Core` takes `Vk`, `VkContext`, `VkCommandBuffer`, `VkQueue`, `VkFenceWrapper` and
`VkSemaphoreWrapper` out of the `Graphics` tag, where they do not belong: the compute path uses all
six.
`Graphics` takes the five `SDL2` classes, rather than keeping a package of five classes whose only
client is the one window this project opens.
`Generator` takes `SpvBuilderGenerator`, `SpvGrammarParser`, `SpvInstructionDescriptor` and
`SpvOperandDescriptor`, which already sit in the `Generator` tag and must stay separate from the
code they emit.
Each package keeps internal tags where it has more than one obvious grouping, so the browser loses
nothing: `Bindings` keeps `Constants`, `Compiler` keeps `Compiler-Pipeline`, `Graphics` keeps
`SDL2`.

Test packages, one per code package that has tests: `PharoVulkan-Tests-Bindings`,
`-Tests-SPIRV`, `-Tests-Compiler`, `-Tests-Core`, `-Tests-Compute`, `-Tests-Graphics`.
Each stub and fixture goes with the test class that uses it.
`PharoVulkan-Tests` survives as a package of one class, `PVArchitectureTest`, because a rule about
how packages may depend on each other belongs to no single package.

## What the scan found

Edges between target packages, by number of referring methods:

| Edge | References | Verdict |
|------|-----------:|---------|
| Compiler → SPIRV | 118 | intended |
| Core → Bindings | 72 | intended |
| Graphics → Bindings | 62 | intended |
| Compute → SPIRV | 46 | intended |
| Bindings → Graphics | 28 | examples only |
| Bindings → Core | 28 | examples only |
| Compute → Compiler | 27 | intended |
| Graphics → Core | 22 | intended |
| Compute → Core | 22 | intended |
| Compute → Bindings | 21 | intended |
| Graphics → SPIRV | 17 | intended |
| Compiler → Examples | 10 | examples, plus one real use |
| Compute → Examples | 8 | real: see decision D4 |
| Bindings → Compute | 7 | examples only |
| Core → Compiler | 3 | `PVTypeError`: see decision D1 |
| Compiler → Compute | 3 | two examples, one real: see decision D3 |
| Graphics → Compiler | 2 | intended |
| Graphics → Examples | 2 | real: see decision D4 |
| Generator → Bindings | 2 | intended |
| Examples → Graphics | 2 | intended |
| Core → Compute | 1 | dead method: see decision D2 |
| Generator → SPIRV | 1 | intended |
| Graphics → Compute | 1 | intended |
| SPIRV → Compute | 1 | example only |
| SPIRV → Core | 1 | example only |
| Bindings → Compiler | 1 | example only |

Eighty-two of the ninety-odd references that break the intended layering are example methods, and
they stop breaking it the moment the examples move.
Four real problems remain, and each is recorded as a decision below rather than fixed on the way
past.

## Decisions to take before the moves they affect

**D1 — where `PVTypeError` lives.** `VkBuffer >> elementsAs:`, `VkBuffer >> put:as:` and
`VkBuffer class >> storageBuffer:of:on:` raise it, and so does the compiler's type inference. It is
an empty `Error` subclass with no methods of its own, so it is a signal rather than behaviour.
Putting it in `Compiler` makes `Core` depend on the compiler; putting it in `Core` or `Bindings`
makes the compiler depend on Vulkan. The recommendation is `PharoVulkan-SPIRV`, which is the only
layer both sides already sit above, together with an added `Core → SPIRV` edge in the allowed set.

**D2 — `VkDevice >> createDescriptorPool:descriptorCount:`.** It answers a `VkDescriptorPool`,
which makes `Core` depend on `Compute`, and it has no senders anywhere in the image or the tests.
The recommendation is to delete it: it is dead, and its only effect is to tie two layers together.
Check `find_senders` again at the time, not from this note.

**D3 — `PVSPIRVEmitter class >> cooperativeMatrixOrder`.** It answers
`PVCooperativeMatrixKernel matrixOrder`, so the emitter reads a constant out of a compute kernel,
and its comment says why: the hand-built kernel and a compiled one must take their shape from one
place. The shape itself is a SPIR-V level fact that `SpvCooperativeMatrixShape` already models.
The recommendation is to give the canonical order one home on the SPIR-V side and have both the
kernel and the emitter read it, in the way `VkPipelineCreation` was given one home for the values
both pipeline kinds asked for. The existing test that checks the order against what the device
reports must stay green, and is what proves the move.

**D4 — what `PVKernelExamples` actually is.** It sits in the `Example` tag, but twenty references
to it come from production code: `PVBenchmark class >> kernelMethodFor:` and `elementTypes`,
`PVSubgroupDotProduct class >> kernelMethod`, `PVTiledMatmulComparison`,
`PVCooperativeMatrixComparison`, `PVPrecisionComparison class >> on:order:repeats:`,
`PVComputeKernel class >> exampleKernelMethod`, and both of
`PVGlslTriangleShaders class >> vertexShaderBytes` and `fragmentShaderBytes`.
It is therefore a library of kernel sources that examples and benchmarks alike compile, not an
example itself. The recommendation is that it goes to `PharoVulkan-Compute` and only
`PVGlslTriangleScene` goes to `PharoVulkan-Examples`. Its name should then say what it is, but
renaming it is a separate unit and not part of the split.

## What a unit looks like

One package, moved whole:

1. Create the target package in the image, with the tags it keeps.
2. Move its classes with `ClassDescription >> package:` and `packageTag:` — in the image, never by
   moving files on disk. Nothing in a moved class changes, so there is no red-green step for the
   move itself; the decisions above are the only code changes in the whole plan, and each one gets
   its failing test first in the ordinary way.
3. Run the suite. The nine concrete test classes are the gate: 593 tests, and a move that changes
   behaviour means something was depending on a package name.
4. `run_critics` on the moved classes, because a package change can surface a manifest or
   classification critique that was hidden.
5. Save the image, then commit that one package through Iceberg.

One package per commit, not one commit for the split.
Every `.class.st` file in a moved package changes directory, so a single commit would be an
unreadable diff over 300 files; per package it stays reviewable, and git follows the renames so
blame survives either way.

## Order of the units

Leaf first, so each commit moves classes whose dependents are already where they will stay.

1. **Examples.** Create `PharoVulkan-Examples`. Move the 130 example and `open…` methods to the
   protocol `*PharoVulkan-Examples` on the classes that own them, which makes them extension
   methods of the new package without moving a class. Move `PVGlslTriangleScene`. Decide D4 and
   move `PVKernelExamples` to the compute side. Twenty of the moved methods are helper constants
   named `example…` that the examples read — `exampleExtent`, `exampleElementCount` and the like —
   and they move with the examples that use them unless a test or production method reads them,
   which must be checked per method.
2. **Generator.** Thirteen classes, two outgoing edges, nothing depends on it.
3. **SPIRV.** Fifty classes. Take D1 here if the recommendation stands, because `PVTypeError`
   lands in this package.
4. **Compiler.** Thirty-two classes, including the `Compiler-Pipeline` tag. Take D3 here.
5. **Core.** Seventeen classes, including the six taken out of the `Graphics` tag. Take D2 here.
6. **Compute.** Fifteen classes.
7. **Graphics.** Seventeen classes, including the `SDL2` tag.
8. **Bindings.** Whatever is left in `PharoVulkan` is the bindings and the constants, so this unit
   is a package rename rather than a move. Check how Iceberg records a package rename before doing
   it; if it records it badly, create `PharoVulkan-Bindings` and move the 143 classes like every
   other unit.
9. **Tests.** Create the six test packages, move each test class with the stubs and fixtures it
   uses, and leave `PharoVulkan-Tests` holding only the architecture test. Rename each test class
   to `<Package>Test` where its name does not already say which package it covers. Splitting
   `VkBindingsTest` further is not part of this unit: it is one test class for one package, which
   is what the convention asks for, and the excessive-methods critique on it is a separate
   question.
10. **Baseline and architecture test.** Rewrite `BaselineOfPharoVulkan` with the eight code
    packages, the six test packages, real `requires:` edges matching the table above, and groups:
    `bindings`, `spirv`, `compiler` (SPIR-V plus compiler, no driver code), `compute`, `graphics`,
    `default` (everything but the generator and the examples), `examples`, `tests`. Write
    `PVArchitectureTest`: one test per package asserting that its outgoing references stay inside
    its allowed set, read from the image the way the scan in this plan read them, with the allowed
    sets declared on the class side so that adding an edge means stating it.
11. **Documentation.** Replace the package table in `CLAUDE.md` with the one above, say that each
    package's allowed dependencies are enforced by `PVArchitectureTest` rather than by the table,
    and update `doc/architecture.md` and the `README.md` load instructions to name the groups.

## Rules this plan sets

- **The image moves the class, not the file system.** `cls package: (PackageOrganizer default
  ensurePackage: '…')` and `cls packageTag: …`. Editing `src/` or the `#package:` pragma in a Tonel
  file is not a way to move a class.
- **An example is an extension method of the examples package.** Moving an example out of the
  class it demonstrates would break the one click the standards ask for, so the method stays on the
  class and changes protocol to `*PharoVulkan-Examples`. The package owns it; the class still
  answers it.
- **A package's allowed dependencies are declared once.** `PVArchitectureTest` holds the sets, and
  a new edge is added there deliberately or not at all.
- **A shared value gets its own home.** The rule `LAYOUT-PLAN.md` recorded for
  `VkPipelineCreation` is what decisions D1 and D3 apply: when two layers need the same value, it
  belongs below both of them, not in whichever one wrote it first.
- **No cosmetic change rides along.** The split moves classes. The four decisions are the only code
  changes, each with a reason recorded here, and each gets its failing test first.

## Not in this plan

The `PVTmpArrayStructProbe` class in the `Uncategorized` tag is dead and should go, but deleting it
is not part of a package move.
Renaming `PVKernelExamples` to say what D4 concludes it is, dropping the unused `extent:` argument
from `VkGraphicsPipeline >> initializeDevice:renderPass:vertexModule:fragmentModule:extent:`, and
the group 5 structures `LAYOUT-PLAN.md` names are all separate work.
