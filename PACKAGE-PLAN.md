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
| `PharoVulkan-Bindings` | 144 | nothing |
| `PharoVulkan-SPIRV` | 50 | nothing |
| `PharoVulkan-Compiler` | 32 | SPIRV |
| `PharoVulkan-Core` | 16 | Bindings |
| `PharoVulkan-Graphics` | 17 | Bindings, Core, Compiler, SPIRV, Compute |
| `PharoVulkan-Compute` | 15 | Bindings, Core, Compiler, SPIRV |
| `PharoVulkan-Generator` | 13 | Bindings, SPIRV |
| `PharoVulkan-Examples` | 18 | everything |

`Bindings` takes the `Constants` tag with it, because the constants classes have no client outside
the bindings and no life of their own; they stay a tag inside the package.
`Core` takes `VkContext`, `VkCommandBuffer`, `VkQueue`, `VkFenceWrapper` and `VkSemaphoreWrapper`
out of the `Graphics` tag, where they do not belong: the compute path uses all five.
`Vk` leaves the `Graphics` tag too, but for `Bindings` rather than `Core`: see decision D6.
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
Five real problems remain, and each is recorded as a decision below rather than fixed on the way
past: D1 to D3, D5, and D6, which the block-aware reading below turned up.

**The scan reads one level too few, and the table above is short by that much.** A class named
inside a block is a literal of the `CompiledBlock`, not of the method that contains the block, so
`method literals` never sees it. Reading the blocks as well — recursively, since a block may hold a
block — turns up 86 further edges that this table does not count. Most are downward and intended,
and most of the rest are the `Core → Graphics` and `Compute → Graphics` pairs that unit 5 settles by
moving six classes out of the `Graphics` tag. Three are real additions to decision D5, all in the
same shape as the four it already names: `VkFramebufferCreateInfo >> attachmentHandlesSet`,
`VkPhysicalDeviceFeatures2 class >> of:chainedWith:do:` and `VkPhysicalDeviceProperties2 class >>
of:chainedWith:do:` reach from a binding into the `Graphics` tag from inside a block.

Two things follow. The reference counts in the table are a floor rather than a count, which changes
nothing about the unit order they were used to decide. And `PVArchitectureTest` must read blocks
recursively, or it will pass while the edge it exists to forbid sits one level down in an
`ensure:` block — which is where this project puts most of its driver calls.

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

**D5 — the policy constants the structures ask for.** Five report methods in the bindings ask a
resource class for the rule they report against, which is the view rule working as intended — a
report that restates a rule can disagree with it — but it makes `Bindings` depend on `Core` and on
`Graphics`:
`VkRenderPassBeginInfo >> clearColorComponents` and `passRows` read
`VkCommandBuffer clearComponentCount` and `clearComponentByteCount`;
`VkSurfaceCapabilitiesKHR >> surfaceRows` reads `VkSwapchain unlimitedImageCount` and
`VkSwapchain imageCountFor:`;
`VkSurfaceFormatKHR >> formatRows` reads `VkSurface formatRenderedIn`;
`VkSwapchainCreateInfoKHR >> swapchainRows` reads `VkSwapchain presentModeNameFor:` and
`VkSwapchain clipObscuredPixels`;
and `VkFramebufferCreateInfo >> attachmentHandlesSet`, which the first scan missed because the
reference is inside a block, reads `VkFramebuffer attachmentByteCount` for the stride of a run of
handles that carries no field specification.
The recommendation is to move each value down to the layer both sides sit above rather than to
allow the edge: the policy constants to `VkRenderConfig`, which already holds
`sharingModeExclusive` for exactly this reason; the present mode names to a constants class of
their own, since no `VkPresentMode` exists yet and the values currently live on `VkSwapchain`; and
`imageCountFor:` inverted, so that the capabilities structure answers the count it allows and
`VkSwapchain` delegates to it. This was found by the scan after unit 1, when the example methods
stopped hiding it. Take it in unit 8, with `VkSwapchain` and `VkSurface` still answering the same
values through delegation so that nothing outside the bindings changes.

**D6 — where `Vk` lives.** `Vk` is the uFFI command façade: 91 class-side methods, each one a
`vkSomething` call and nothing else. It currently sits in the `Graphics` tag, which is why the
block-aware scan reports `Core → Graphics` from twelve methods, `Compute → Graphics` from six and
`Bindings → Graphics` from the two `of:chainedWith:do:` chain builders: every layer calls the
driver, so every layer reaches it.

This plan first put it in `Core` with the other five classes leaving the `Graphics` tag. That is
wrong, and the two chain builders are the proof: `VkPhysicalDeviceFeatures2` and
`VkPhysicalDeviceProperties2` are bindings, they call `Vk getPhysicalDeviceFeatures2:into:` to fill
themselves, and a bindings package may not depend on `Core`. A declared foreign call belongs beside
the declared structures it passes, so `Vk` goes to `PharoVulkan-Bindings`. `Core` then holds the
five lifecycle classes and depends on `Bindings` for both the structures and the calls, which is
what it already does in fact.

Nothing else moves with it: `VkExtensionCommand` already sits in the `Core` tag and is a lookup of
extension function pointers rather than a declared call, so it stays where it is until unit 5 reads
it again.

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

1. **Examples — done 16 October 2026.** Create `PharoVulkan-Examples` and, inside it, one example
   class per subject — `VkPipelineExamples`, `VkContextExamples`, `PVValidationExamples` and so on —
   each holding as class-side methods the examples of the thing it is named after. Move every
   `<sampleInstance>` method into the example class of its group, dropping the `example` prefix from
   the selector and sending to the subject class where the method used to send to `self`. Move
   `PVGlslTriangleScene`. Decide D4 and move `PVKernelExamples` to the compute side. Two kinds of
   method stay where they are: the twenty `example…` fixture constants, because they are read by
   tests and one of them is a `subclassResponsibility` the scene hierarchy overrides, and
   `renderTriangle`, which `doc/glsl-api-tutorial.md` documents as the method a user writes on their
   own scene.
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
    its allowed set, with the allowed sets declared on the class side so that adding an edge means
    stating it. It must read each method's literals **and** the literals of every block inside it,
    recursively — the scan in this plan read only the method's own literals and so missed 86 edges;
    a test with that blind spot would pass on the driver calls this project writes inside `ensure:`
    blocks. One of its own tests should be that it finds a reference planted inside a nested block.
11. **Documentation.** Replace the package table in `CLAUDE.md` with the one above, say that each
    package's allowed dependencies are enforced by `PVArchitectureTest` rather than by the table,
    and update `doc/architecture.md` and the `README.md` load instructions to name the groups.

## What unit 1 did

Done 16 October 2026.

`PharoVulkan-Examples` created, with a package comment saying that nothing may depend on it, and
seventeen example classes created inside it, each with a class comment that says what the group
covers and what a click actually does:

| Example class | Tag | Examples | Subject |
|---|---|---|---|
| `VkDeviceRequestExamples` | Bindings | 4 | what this project asks of an instance and a device |
| `VkFeatureStructureExamples` | Bindings | 11 | the feature and property structures a driver fills |
| `VkMemoryExamples` | Bindings | 5 | buffer requests, allocations and requirements |
| `VkDescriptorExamples` | Bindings | 6 | pools, layouts, bindings and writes |
| `VkCommandExamples` | Bindings | 8 | one submission, from allocation to fence |
| `VkPipelineExamples` | Bindings | 16 | every structure a pipeline is created from |
| `VkRenderPassExamples` | Bindings | 8 | the offscreen colour pass, attachment outwards |
| `VkSwapchainExamples` | Bindings | 5 | the window path, with no display touched |
| `VkContextExamples` | Core | 7 | what this machine answers about itself |
| `VkResourceExamples` | Compute | 6 | live driver objects a kernel is dispatched through |
| `PVComputeExamples` | Compute | 5 | the compute path at DSL level |
| `PVBenchmarkExamples` | Compute | 6 | the examples that measure rather than demonstrate |
| `PVCooperativeMatrixExamples` | Compute | 6 | the device product and the host twin it is checked against |
| `SpvTypeExamples` | SPIRV | 2 | the SPIR-V types that carry a shape |
| `PVValidationExamples` | Compiler | 10 | `spirv-val` over every kernel this project compiles |
| `PVCompilerExamples` | Compiler | 3 | what the compiler saw and what it made |
| `PVSceneExamples` | Graphics | 2 | the offscreen graphics path, end to end |

110 `<sampleInstance>` methods moved into them. Each move drops the `example` prefix from the
selector and rewrites what was `self` to the subject class, so `VkDeviceCreateInfo class >>
exampleGraphicsDeviceRequest` became `VkDeviceRequestExamples class >> graphicsDeviceRequest`
sending to `VkDeviceCreateInfo`. Thirty-nine senders, all in tests and in other examples, were
rewritten with the same parse-tree rewriter rather than by hand. Three selectors were renamed
further than the prefix drop, because dropping it alone would have collided or read badly inside
the group: `poolForOneSetOfThreeDescriptors`, `allocationForOneSetOfThreeBindings` and
`layoutRequestForTwoStorageBuffers`.

Twenty-one methods stayed on their own classes and were reclassified back out of
`*PharoVulkan-Examples`: the twenty `example…` fixture constants, which tests read and which
`PVTriangleScene class >> exampleExtent` declares as a `subclassResponsibility` with two overrides,
and `PVHelloTriangleScene class >> renderTriangle`. No extension method of
`PharoVulkan-Examples` is left; the package is seventeen classes it defines and nothing else.

`PVGlslTriangleScene` moved to the new package, tag `Graphics` — it is a demonstration scene, and
nothing in the renderer subclasses it or refers to it. Its own `renderTriangle` stayed on it, for
the same documentation reason.

The rest of the scene hierarchy stayed in `PharoVulkan`, which is deliberate: `PVTriangleScene` and
its two concrete scenes are the renderer the tests drive, not demonstrations. Only
`PVGlslTriangleScene`, whose whole content is two overrides showing how a reader writes their own
scene, is a demonstration. That does split the GLSL pair `PVGlslTriangleShaders` names — the window
scene is an example, the offscreen one stays in `Graphics` — and the split stands: the offscreen
twin is the subject of the pixel comparison in `PVGraphicsTest`, and a test should not have to load
the examples to reach its subject. Later units must not tidy this into symmetry.
`PVKernelExamples` moved the other way, from the `Example` tag to `Compute`, which settles decision
D4: twenty production references compile its kernel sources, so it is a kernel library and not an
example. The `Example` tag is gone.

Gates. All 111 examples in the package were run one after another, and every one answered without
raising. Suite after the move: 593 tests, no failures, no errors, over the nine concrete test
classes. Critics on the new package report one rule, `ReClassNotReferencedRule`, against the seven
example classes no test happens to name; `ManifestPharoVulkanExamples` declares that as a false
positive, with the reason that an example class is a click target and a reference from production
code would mean an example had become part of the library. The MCP `run_critics` call reads the
rules rather than the manifest, so it still lists them; the Critics browser does not. One real
critique was fixed: `VkSwapchainExamples class >> requestForAWindowSurface` named its own class
where the sender rewrite had put the class name, and now sends to `self`.

The scan was re-run with each method attributed to the package that now owns it, which is what
turned up decision D5: the layering violations fell from roughly ninety references to seven, and the
seven are D2, D3 and the four report methods of D5. Reading blocks as well — which the scan did not
do, and which the section above now records as its defect — adds a fifth report method to D5 and
turns up decision D6, `Vk` sitting in the `Graphics` tag while every layer calls it. Every `Bindings → Core`, `Bindings → Graphics`,
`Bindings → Compute`, `Bindings → Compiler`, `SPIRV → Core` and `SPIRV → Compute` reference that the
first scan found was an example, and all of them are now `Examples → …` edges, which the layering
allows.

## Rules this plan sets

- **The image moves the class, not the file system.** `cls package: (PackageOrganizer default
  ensurePackage: '…')` and `cls packageTag: …`. Editing `src/` or the `#package:` pragma in a Tonel
  file is not a way to move a class.
- **An example lives in an example class.** The examples of a subject are class-side methods of a
  class named after that subject — `VkPipelineExamples`, `PVBenchmarkExamples` — which lives in
  `PharoVulkan-Examples` under a tag mirroring the package the subject came from. One click from
  the browser still runs an example, and the subject class is left holding only the library. An
  extension method on the subject class is not a way to do this: the package then owns a method the
  class still declares, which is what a reader sees as the class's own protocol.
- **What stays on the subject class.** A constant the tests read, and a method the documentation
  tells a user to write themselves, belong to the class rather than to the examples. The fixture
  constants named `example…` and `renderTriangle` stayed for those two reasons; everything carrying
  `<sampleInstance>` moved.
- **A package's allowed dependencies are declared once.** `PVArchitectureTest` holds the sets, and
  a new edge is added there deliberately or not at all.
- **A shared value gets its own home.** The rule `LAYOUT-PLAN.md` recorded for
  `VkPipelineCreation` is what decisions D1 and D3 apply: when two layers need the same value, it
  belongs below both of them, not in whichever one wrote it first.
- **No cosmetic change rides along.** The split moves classes. The six decisions are the only code
  changes, each with a reason recorded here, and each gets its failing test first.

## Not in this plan

The `PVTmpArrayStructProbe` class in the `Uncategorized` tag is dead and should go, but deleting it
is not part of a package move.
Renaming `PVKernelExamples` to say what D4 concludes it is, dropping the unused `extent:` argument
from `VkGraphicsPipeline >> initializeDevice:renderPass:vertexModule:fragmentModule:extent:`, and
the group 5 structures `LAYOUT-PLAN.md` names are all separate work.
