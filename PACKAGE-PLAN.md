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
| `PharoVulkan-SPIRV` | 51 | nothing |
| `PharoVulkan-Compiler` | 31 | SPIRV |
| `PharoVulkan-Core` | 17 | Bindings, SPIRV |
| `PharoVulkan-Graphics` | 17 | Bindings, Core, Compiler, SPIRV, Compute |
| `PharoVulkan-Compute` | 15 | Bindings, Core, Compiler, SPIRV |
| `PharoVulkan-Generator` | 13 | Bindings, SPIRV |
| `PharoVulkan-Examples` | 18 | everything |

`Bindings` takes the `Constants` tag with it, because the constants classes have no client outside
the bindings and no life of their own; they stay a tag inside the package.
`Core` takes `VkContext`, `VkCommandBuffer`, `VkQueue`, `VkFenceWrapper` and `VkSemaphoreWrapper`
out of the `Graphics` tag, where they do not belong: the compute path uses all five. It also takes
`VkPipelineLayout` out of the `Compute` tag by decision D7, because both pipeline kinds are created
from one; that is why the row says seventeen classes rather than sixteen, and why it names SPIRV as
well — `VkBuffer` raises `PVTypeError`, which D1 put there.
`Vk` leaves the `Graphics` tag too, but for `Bindings` rather than `Core`: see decision D6.
`Graphics` takes the five `SDL2` classes, rather than keeping a package of five classes whose only
client is the one window this project opens.
`Generator` takes `SpvBuilderGenerator`, `SpvGrammarParser`, `SpvInstructionDescriptor` and
`SpvOperandDescriptor`, which already sit in the `Generator` tag and must stay separate from the
code they emit.
Each package keeps internal tags where it has more than one obvious grouping, so the browser loses
nothing: `Bindings` keeps `Constants`, `Compiler` keeps `Compiler-Pipeline`, `Graphics` keeps
`SDL2`.

Test packages, one per code package that has tests, each named for the package it covers and
ending in `-Tests`: `PharoVulkan-Bindings-Tests`, `PharoVulkan-SPIRV-Tests`,
`PharoVulkan-Compiler-Tests`, `PharoVulkan-Core-Tests`, `PharoVulkan-Compute-Tests`,
`PharoVulkan-Graphics-Tests`. The suffix is decision D9: Pharo's own convention, which Renraku
checks, is that a package holding test classes ends in `-Tests`.
Each stub and fixture goes with the test class that uses it, under a `Fixtures` tag, so that the
`Tests` tag of a test package holds test classes and nothing else.
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

**D7 — where `VkPipelineLayout` lives.** Taken in unit 7, after unit 6's scan showed that the
whole allowed `Graphics → Compute` edge rested on two references. A pipeline layout is descriptor
set layouts and push constant ranges; both a compute pipeline and a graphics pipeline are created
from one, and its set layouts arrive as arguments, so it names no descriptor class and reaches
nothing above the bindings. It therefore belongs in `PharoVulkan-Core`, below both readers, in the
way `VkPipelineCreation` already holds the values both pipeline kinds ask for. The second reference
stays: `PVGlslTriangleShaders` compiles two methods out of `PVKernelExamples`, which is a library
of kernel sources rather than compute behaviour, and moving methods out of it belongs to the rename
D4 asks for.

**D8 — whether a test package may depend on another test package.** One edge exists among the test
classes, and it is the only one: `PVComputeTest` runs two of the kernels declared by
`PVCfgShapeFixture`, which lives with the compiler tests. The fixture is a set of kernels with
known control-flow shapes, written to pin the boundary of what `PVStructuredCFGRecognizer` accepts,
so it belongs with the tests of the recogniser. Running two of those kernels on a real device is
how the compute tests show that the acceptance is real rather than a claim about bytes, so the
reference is the point of the test rather than an accident. The decision is therefore to allow the
one edge and to declare it: `PharoVulkan-Compute-Tests` requires `PharoVulkan-Compiler-Tests` in
the baseline, and `PVArchitectureTest` will state the same edge. Taken in unit 9.

**D9 — how a test package is named.** The plan first wrote the test packages as
`PharoVulkan-Tests-<Name>`, following the table that was already in `CLAUDE.md`. Renraku's
`ReTestClassNotInPackageWithTestEndingNameRule` wants the name to **end** in `-Tests`, so the
prefix form put one critique on each of the nine test classes the moment they left
`PharoVulkan-Tests`, which does end in it. The decision is to follow the convention:
`PharoVulkan-<Name>-Tests`. It clears all nine critiques, and it sorts each test package beside
the code package it covers in the browser. `PharoVulkan-Tests` keeps its name, which already ends
in the suffix. Taken in unit 9, after the six packages existed and before they were committed, so
no `src/` directory had to be renamed on disk.

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
2. **Generator — done 16 October 2026.** Thirteen classes, two outgoing edges, nothing depends on it.
3. **SPIRV — done 16 October 2026.** Fifty-one classes. D1 taken here, because `PVTypeError`
   lands in this package.
4. **Compiler — done 16 October 2026.** Thirty-one classes, including the `Compiler-Pipeline` tag.
   D3 taken here.
5. **Core — done 16 October 2026.** Sixteen classes, including the five taken out of the
   `Graphics` tag. D2 taken here.
6. **Compute — done 16 October 2026.** Sixteen classes: fifteen, plus the `PVKernelExamples` that
   unit 1 moved here by D4. No decision was due.
7. **Graphics — done 16 October 2026.** Seventeen classes, including the `SDL2` tag. D7 taken
   here: `VkPipelineLayout` moves down to `PharoVulkan-Core`, below both pipeline kinds.
8. **Bindings — done 16 October 2026.** A package rename rather than a move: the organiser renames
   `PharoVulkan` to `PharoVulkan-Bindings` with its classes, tags and manifest in one step, and git
   records the 146 Tonel files as renames. D5 taken here.
9. **Tests — done 16 October 2026.** Create the six test packages, move each test class with the
   stubs and fixtures it uses, and leave `PharoVulkan-Tests` holding only the architecture test.
   D8 and D9 taken here. No test class was renamed: each of the nine names already says either the
   package it covers or the subject it is about. Splitting `VkBindingsTest` further is not part of
   this unit: it is one test class for one package, which is what the convention asks for, and the
   excessive-methods critique on it is a separate question.
10. **Baseline and architecture test.** The baseline is no longer rewritten once at the end: each
    unit declares the package it creates as part of that unit, so the image on disk is loadable at
    every commit rather than only at the last one. What is left here is the final shape —
    `BaselineOfPharoVulkan` holding the eight code packages, the six test packages, real
    `requires:` edges matching the table above, and groups: `bindings`, `spirv`, `compiler`
    (SPIR-V plus compiler, no driver code), `compute`, `graphics`, `default` (everything but the
    generator and the examples), `examples`, `tests` — and the architecture test. Write
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

## What unit 2 did

Done 16 October 2026.

`PharoVulkan-Generator` created with a package comment and the thirteen classes of the `Generator`
tag moved into it, under two tags rather than one: `Vulkan` holds the XML reader `PVXmlParser` and
`PVXmlElement`, the five descriptors it answers and `VkBindingGenerator`; `SPIRV` holds
`SpvGrammarParser`, its two descriptors and `SpvBuilderGenerator`. The `Generator` tag in
`PharoVulkan` is gone, and that package is down to 277 classes.

The block-aware scan of the thirteen classes before the move: one incoming reference, from
`VkBindingsTest >> testGeneratorIsIdempotent`, and three outgoing — `SpvBuilder` in `SPIRV`,
`VkHandle` and `VkStructure` in `Bindings`, and `Vk`, which decision D6 moves to `Bindings` as well.
So the package depends on `Bindings` and `SPIRV` and nothing depends on it, which is what the target
table says.

Suite 593, no failures, no errors. Critics on the new package report long methods and high
cyclomatic complexity on the parsers and the emitters, and three classes no sender names; all of it
is code-level and none of it can be affected by which package a class sits in, so it is what the
same classes reported before the move. A hand-written XML parser and a source emitter are long by
nature, and splitting them is not what this plan is for.

Found on the way past, for unit 8 rather than now: `VkBindingGenerator >> generateHandle:`,
`generateEnum:` and `generateStruct:` install into the literal package name
`'PharoVulkan-Bindings'`, which does not exist yet — the bindings are in `PharoVulkan`. Nothing
installs there today because every generate method answers early when the class already exists, so
the literal has never been reached in anger; unit 8 makes it true, and should assert that it is.
`VkBindingsTest >> vkXmlPath` names the directory `'PharoVulkan'` for `vk.xml`, which is a path on
disk rather than a package and is unaffected.

## What unit 3 did

Done 16 October 2026.

`PharoVulkan-SPIRV` created with a package comment, holding fifty-one classes: the forty-nine of the
`SPIRV` tag, plus `PVTypeError` by decision D1 and `SpvValidationError`, which the plan's count of
fifty had missed. The package is flat no longer — Renraku reports a class with no tag, and fifty-one
untagged classes is fifty-one critiques — so it carries seven tags: `Builder` (8: `SpvBuilder`,
`SpvModule`, `SpvFunction`, `SpvBlock`, `SpvInstruction`, `SpvGlobalVariable`, `SpvConstantPool`,
`SpvTypeRegistry`), `Types` (14: `SpvType` and its subclasses, with `SpvCooperativeMatrixShape`),
`IR` (13: `SpvIRNode` and its subclasses), `Emitter` (2: `SpvModuleEmitter`, `SpvSerializer`),
`Validator` (1: `SpvValidator`), `Constants` (11: the specification enumerations and `GlslStd450`)
and `Exceptions` (2: `PVTypeError`, `SpvValidationError`).

**D1 is settled, as recommended.** Every raiser of `PVTypeError` was read first: `VkBuffer >>
elementsAs:`, `put:as:` and `VkBuffer class >> storageBuffer:of:on:` in `Core`; `PVBenchmark`,
`PVCooperativeMatrix`, `PVSubgroupDotProduct`, `PVTiledMatmulComparison`, `PVPrecisionComparison`,
`PVCooperativeMatrixKernel` and `PVKernelExamples` in `Compute`; `PVKernelCompiler`,
`PVSPIRVEmitter` and `PVTypeInferencer` in `Compiler-Pipeline`. Three layers raise it, so it belongs
below all three, which is this package. `SpvValidationError` is raised by `SpvValidator` alone and
so has no decision to take. `VkError` stays in `Bindings`, and the `Exceptions` tag there now holds
only it. The block-aware scan of the fifty-one classes found **no outgoing reference into any other
PharoVulkan package**: the package is the leaf the target table says it is.

`cls package:` leaves the class in the old package's tag. After the move, `PharoVulkan` still
reported `Exceptions=3` and 228 defined classes rather than 226, because the two exceptions had been
moved out of the package while the tag object kept its own list. `PackageTag >> removeClass:` on the
old tag fixes it. Any later unit that moves a class out of a tag it shares with classes that stay
must check the old tag afterwards, not just the new package.

The baseline was rewritten here rather than at unit 10, as the three packages that exist now had to
be loadable: `PharoVulkan-SPIRV` requiring nothing, `PharoVulkan` requiring it,
`PharoVulkan-Generator` requiring both, `PharoVulkan-Examples` requiring `PharoVulkan`, and
`PharoVulkan-Tests` requiring `PharoVulkan`, the examples and the generator, with groups `spirv`,
`default`, `generator`, `examples` and `tests` — the examples are in `tests` because the test
classes read them, and out of `default` because a user of the bindings needs neither them nor the
generator.

**A real bug the critics gate found.** `ReClassNotReferencedRule` did not report on `SpvDecoration`;
it raised `'Instance of SmallInteger did not understand #isReferenced'`. The cause was ours:
`SpvDecoration class >> binding` answered the decoration number 33, which hid `Class >> binding`,
so asking that class for its binding answered an integer instead of the global variable holding the
class. Every tool that reads a class reflectively failed on that one class. Fixed in the order the
standards ask: `SpvBuilderTest >> testEveryClassOfTheSpirvPackageAnswersItsOwnBinding` was written
first and seen to fail, the constant was renamed to `bindingDecoration` with a comment saying why it
cannot carry the decoration's own name, the six senders were rewritten, and the test went green. The
test asks every class of the package, so the next constant named after a reflection selector is
caught by it. A sweep of all `PharoVulkan` packages for class-side methods that hide a `Class`,
`Behavior` or `Object` selector found five others: `Vk class >> ffiLibrary` and `SDL2Vulkan class >>
ffiLibrary` and `VkTypes class >> initialize` are the hooks uFFI and Pharo ask for, so they are
right; `PVKernelCompiler class >> compile:` and `SpvMemorySemantics class >> release` hide
`Behavior >> compile:` and `Object >> release` and are recorded below rather than changed here,
because nothing is broken by them today.

Suite 594, no failures, no errors — the 593 of the nine test classes plus the new one. Critics on the
package: nineteen critiques, all code-level and none of them caused by the move — fourteen
inconsistent method classifications on the `instruction` and `key` methods of the type lattice, two
classes no sender names (`SpvIRBranch` and `SpvIRReturnValue`, which the block-aware scan confirms
nothing in the image or the tests references at all), excessive methods on `SpvOpcode class`, which
is a table of opcodes, excessive instance variables on `SpvModule`, and a temp read before written
in `SpvSerializer >> emitAnnotations`, which relies on a block temp being nil and is not a bug.

Found on the way past, for later rather than now: `SpvIRBranch` and `SpvIRReturnValue` are complete,
commented, and reachable from nothing — the IR has two node kinds the compiler never builds.

## What unit 4 did

Done 16 October 2026.

`PharoVulkan-Compiler` created with a package comment, holding the thirty-one classes of the
`Compiler` and `Compiler-Pipeline` tags — the plan said thirty-two, which was one too many. The
`Compiler-Pipeline` tag becomes `Pipeline` inside the new package, and the twenty-three classes that
had no tag of their own are grouped rather than left uncategorised: `Pipeline` (8: the stage classes
in the order they run, `PVBytecodeDecoder`, `PVStackSimulator`, `PVCFGBuilder`,
`PVStructuredCFGRecognizer`, `PVSSAConstructor`, `PVTypeInferencer`, `PVSPIRVEmitter` and the
`PVKernelCompiler` that drives them), `Bytecode` (2), `SSA` (4), `Graph` (5), `Annotations` (3),
`Selectors` (2), `Types` (6: the host-side type tokens and `PVWorkItem`) and `Validation` (1).
`PharoVulkan` is down to 195 classes, and both old tags are gone.

**D3 is settled, in the shape the plan recommended.** The block-aware scan of the thirty-one classes
found one outgoing reference that was not to `PharoVulkan-SPIRV`: `PVSPIRVEmitter class >>
cooperativeMatrixOrder` read `PVCooperativeMatrixKernel matrixOrder`, so the compiler depended on
the compute package for a number. `SpvCooperativeMatrixShape class >> canonicalOrder` now holds the
value, below both readers, and the emitter and the kernel both delegate to it —
`PVCompilerTest >> testCooperativeMatrixOrderHasOneHomeBelowBothReaders` was written first, failed
with a doesNotUnderstand on the new selector, and passes now. The device-reported-shape tests in
`PVComputeTest` stayed green. After the move the package's outgoing edges are to
`PharoVulkan-SPIRV` and nothing else, which is what the target table says; incoming references come
from Compute, Graphics, the tests and the examples, all of which the table allows.

`PVWorkItem` had no class comment. One was written before the move, saying what a kernel asks a work
item and why the same object serves the device and the host reference run. No other class in the
package was missing one.

The baseline now declares `PharoVulkan-Compiler` requiring `PharoVulkan-SPIRV` alone, `PharoVulkan`
requiring both, and a `compiler` group of SPIRV plus Compiler — the group that loads the whole
Pharo-to-SPIR-V path with no driver code in the image.

Suite 595, no failures, no errors. One run reported an error in
`VkBindingsTest >> testOnlyOneMethodPresentsASwapchain`, which passes alone and passed again when
the suite was run with nothing else going on: that test reads `allSendersOf:` and a reflective scan
was running in another expression at the same time. **Do not run a reflective scan while the forked
suite is running.** Critics on the package: sixty critiques, every one code-level and none of them
caused by the move — nineteen inconsistent classifications, thirteen long methods and eight
cyclomatic complexity on the emitter and the recogniser, nine excessive-argument methods, a
read-before-written temp in `PVKernelCompiler >> compile`, two variables referenced once in
`PVBlockSimulator`, and seven classes no sender names.

Found on the way past, for later rather than now: those seven classes are referenced by nothing at
all, not even in a comment or as a symbol — `PVPhiNode`, `PVSSAVar`, `PVVec2`, `PVVec3`, `PVVec4`,
`PVBVec3` and `PVMat4`. The phi nodes and SSA variables the pipeline actually builds are
`PVRegisterOp` instructions and plain associations, and the type tokens are symbols, so the classes
and their comments describing what builds them are stale.

## What unit 5 did

Done 16 October 2026.

`PharoVulkan-Core` created with a package comment, holding sixteen classes under four tags:
`Device` (4: `VkContext`, `VkPhysicalDevice`, `VkDevice`, `VkExtensionCommand`), `Commands`
(5: `VkQueue`, `VkCommandPool`, `VkCommandBuffer`, `VkFenceWrapper`, `VkSemaphoreWrapper`),
`Resources` (3: `VkBuffer`, `VkShaderModule`, `PVFloat16`) and `CooperativeMatrix`
(4: `PVCooperativeMatrixSurvey`, `VkCooperativeMatrixConfiguration`, `VkComponentType`, `VkScope`).
Eleven came from the `Core` tag and five from the `Graphics` tag — `VkContext`, `VkQueue`,
`VkCommandBuffer`, `VkFenceWrapper` and `VkSemaphoreWrapper`. The plan said seventeen classes and
six from `Graphics`, counting `Vk` among them; D6 had already concluded that `Vk` belongs with the
declared structures it passes, so this unit moved it to the `Bindings` tag of `PharoVulkan` instead,
where unit 8 will rename the package around it. `Bindings` is now 104 classes and the `Graphics` tag
is down to 12. No class in the new package was missing a class comment.

**D2 is settled by deletion, as recommended.** `find_senders` was asked again rather than trusted
from the note: `VkDevice >> createDescriptorPool:descriptorCount:` had no senders anywhere, in the
image or the tests, and `VkDevice` was its only implementor. The failing test came first —
`VkCoreTest >> testNoCoreMethodBuildsADescriptorPool` reads every method of the package, blocks
included, and asserts that none of them names `VkDescriptorPool`; it failed on that one method, and
passes with the method gone. The test is worth more than the deletion it justified: it is the one
edge from `Core` up into `Compute` that the block-aware scan found, so the test now holds the layer
boundary open for inspection rather than leaving it to a future scan.

After the deletion the package's outgoing references are to the bindings and the constants — `Vk`
from 52 methods, `VkError` from 11, and the declared structures — and to `PharoVulkan-SPIRV` for the
`PVTypeError` that three of `VkBuffer`'s methods raise, which is the edge D1 added deliberately.
Incoming references come from Bindings, Compute, Graphics, the examples and the tests, all allowed
by the target table.

**A trap worth naming: `cls package: 'PharoVulkan-Core'` does not mean what it reads as.** Pharo
parses the string as the package `PharoVulkan` with the tag `Core`, so classes moved that way were
added to a `Core` tag inside the old package, and `packageTag:` afterwards re-homed the class
without emptying that tag. `PharoVulkan` reported five classes it no longer defined until every
class was removed from the stray tag, which then disappeared with its last member. Move a class with
`cls package: (PackageOrganizer default ensurePackage: '…')`, and check the old package's
`definedClasses size` after every unit. `PharoVulkan` is down to 179 classes.

The baseline declares `PharoVulkan-Core` requiring `PharoVulkan` and `PharoVulkan-SPIRV`, a `core`
group, and `default` as `PharoVulkan` plus `PharoVulkan-Core` — a user of this project opens a
device, so the lifecycle is part of the default load. `PharoVulkan-Examples` and
`PharoVulkan-Tests` now require `PharoVulkan-Core` rather than `PharoVulkan`, which is what they
actually read.

Suite 596 with the new test, no failures, no errors. The first run reported one error in
`PVGraphicsTest >> testSurfaceReportsWhatItAllowsAndWhatItOffersOnThisMachine`, which passed alone
and passed again in a run with nothing else touching the image: the poll that watched the run had
asked for `Process allSubInstances` and for package membership while the surface test was running.
This is the second unit in which a reflective query run beside the suite has failed a test — poll
only `Smalltalk at: #Run`, and nothing else, while a forked suite is going.

Critics on the package: one critique, and not one the move caused —
`ReUnaryAccessingMethodWithoutReturnRule` on `VkPhysicalDevice >> fetchQueueFamilyProperties`, a
method classified as accessing that fills an instance variable instead of answering. It is one of
the two hand-counted readers `LAYOUT-PLAN.md` names as group 5, writing `propSize := 24` and
stepping through the driver's array by that stride, so it is to be rewritten there rather than
reclassified here.

## What unit 6 did

Done 16 October 2026.

`PharoVulkan-Compute` created with a package comment, holding sixteen classes under five tags:
`Descriptors` (3: `VkDescriptorPool`, `VkDescriptorSet`, `VkDescriptorSetLayout`), `Pipeline`
(2: `VkPipelineLayout`, `VkComputePipeline`), `Kernels` (3: `PVComputeKernel`, `PVKernelExamples`,
`PVTiledMatmulKernel`), `CooperativeMatrix` (3: `PVCooperativeMatrix`,
`PVCooperativeMatrixKernel`, `PVCooperativeMatrixComparison`) and `Benchmarks` (5: `PVBenchmark`,
`PVBenchmarkResult`, `PVPrecisionComparison`, `PVTiledMatmulComparison`, `PVSubgroupDotProduct`).
The plan said fifteen; it is sixteen because unit 1 moved `PVKernelExamples` here by decision D4.
`PVSubgroupDotProduct` sits under `Benchmarks` rather than in a tag of its own: it runs a kernel on
a device and reports the result against the host sum, which is the shape of the comparisons beside
it. `PharoVulkan` is down to 163 classes and the `Compute` tag is gone.

No decision was due in this unit, and the block-aware scan found nothing to take one about. The
package's outgoing references are exactly the four packages the target table allows: the bindings
and their constants (`Vk` from 11 methods, fourteen declared structures, `VkDescriptorType`,
`VkShaderStage`, `VkPipelineCreation`, `VkError`), `PharoVulkan-Core` (`VkBuffer`, `VkShaderModule`,
`VkContext`, `VkCommandPool`, `VkScope`), `PharoVulkan-Compiler` (`PVSPIRVEmitter` from 12 methods,
`PVKernelCompiler`, `PVSpirvValidator`, `PVTypeAnnotation`) and `PharoVulkan-SPIRV` (`PVTypeError`
from 12 methods, the specification constants, the builder and the cooperative matrix types). There
is no edge to `Graphics` at all.

`PVBenchmarkResult` had no class comment. One was written before the move, saying that the rate is
derived rather than stored and why `gigaflopsPerSecond` answers nil for a dispatch quicker than the
host clock. `PVKernelExamples` had a comment calling itself a set of examples, which is what D4
concluded it is not: it now says it is a library of kernel sources that the benchmarks, the
comparisons and the GLSL triangle shaders compile out of, and names D4 for the reason it lives here.

The baseline declares `PharoVulkan-Compute` requiring the bindings, `PharoVulkan-Core`,
`PharoVulkan-Compiler` and `PharoVulkan-SPIRV`, adds a `compute` group, and extends `default` to
the bindings plus the lifecycle plus compute — a user of this project opens a device and runs
something on it. `PharoVulkan-Examples` and `PharoVulkan-Tests` now require `PharoVulkan-Compute`
rather than `PharoVulkan-Core`, which is what they read.

Critics on the package: eight critiques, every one code-level and none caused by the move — three
excessive-argument methods and two long methods in `PVKernelExamples`, where a kernel takes each
buffer it touches as a parameter because the DSL has no structures, long `create` on
`VkPipelineLayout` and `destroy` on `PVComputeKernel`, and excessive variables on `PVComputeKernel`,
which holds the whole dispatch.

Found on the way past, for unit 7 to settle rather than now: the whole `Graphics → Compute` edge
the target table allows rests on two references. `VkGraphicsPipeline` reads `VkPipelineLayout`,
which is a pipeline layout rather than a compute one, and `PVGlslTriangleShaders` compiles two
methods out of `PVKernelExamples`. Neither is compute-specific, so unit 7 should ask whether the
edge is wanted or whether `VkPipelineLayout` belongs below both pipeline kinds, the way
`VkPipelineCreation` already holds the values both of them ask for.

## What unit 7 did

Done 16 October 2026.

`PharoVulkan-Graphics` created with a package comment, holding seventeen classes under six tags:
`Pipeline` (2: `VkRenderPass`, `VkGraphicsPipeline`), `Presentation` (2: `VkSurface`,
`VkSwapchain`), `Targets` (3: `VkImage`, `VkFramebuffer`, `PVOffscreenTarget`), `Scenes`
(4: `PVTriangleScene` and its three subclasses), `Shaders` (1: `PVGlslTriangleShaders`) and `SDL2`
(5: `SDL2Vulkan`, `PVVulkanDriver`, `PVWindowAttributes`, `OSVulkanAttributes`,
`OSSDL2VulkanBackendWindow`), which the plan said to keep as a tag rather than make a package of
five classes whose only client is the one window this project opens. Every class already had a class
comment. `PharoVulkan` is down to 146 defined classes: the 104 of `Bindings`, the 39 of `Constants`,
`VkError`, the manifest and the dead `PVTmpArrayStructProbe`.

**The question unit 6 left is settled, as decision D7: `VkPipelineLayout` moves down to
`PharoVulkan-Core`.** A pipeline layout is descriptor set layouts and push constant ranges, which
both pipeline kinds are created from, and it had no business being compute's to lend. It can live
below both because it reaches nothing above the bindings — the set layouts arrive as arguments, so
it names no descriptor class at all. `VkCoreTest >>
testPipelineLayoutLivesBelowBothPipelineKinds` was written first and failed on the package name; it
passes now, and it also asserts that the class's own references, blocks included, stay inside the
bindings, so the move cannot be undone quietly. `PharoVulkan-Compute` is fifteen classes, and its
`Pipeline` tag now holds `VkComputePipeline` alone.

The other half of the question is answered differently: `PVGlslTriangleShaders` compiles two methods
out of `PVKernelExamples`, and that edge stays. The kernel sources are a library both the benchmarks
and the shaders compile from, the target table allows `Graphics → Compute`, and moving two methods
out of that library is part of the rename D4 asks for rather than part of a package move. So this
package's outgoing references are the bindings and their constants (`Vk` from 25 methods, 34
declared structures, `VkRenderConfig` from 7), `PharoVulkan-Core` (`VkContext`, `VkCommandPool`,
`VkFenceWrapper`, `VkSemaphoreWrapper`, `VkShaderModule`, `VkBuffer`, and now `VkPipelineLayout`),
`PharoVulkan-Compute` (`PVKernelExamples` alone), `PharoVulkan-Compiler` (`PVKernelCompiler`) and
`PharoVulkan-SPIRV` (the builder and the specification constants) — the full allowed set, and
nothing else inside this project.

The baseline declares `PharoVulkan-Graphics` requiring all five, adds a `graphics` group, and
extends `default` to the bindings, the lifecycle, compute and graphics: a user of this project opens
a device, runs something on it and draws. `PharoVulkan-Examples` and `PharoVulkan-Tests` now require
`PharoVulkan-Graphics`.

Critics on the package: eight critiques, every one code-level and none caused by the move — two
excessive-argument methods on `VkGraphicsPipeline` (one of them the `extent:` the plan already
records as unused), long methods and high complexity on `PVVulkanDriver >>
createWindowWithAttributes:osWindow:`, which mirrors the driver method it overrides, long `destroy`,
`buildVertexShader` and `buildFragmentShader` on `PVTriangleScene`, and a read-before-written
temporary in the driver method that is a false positive: `aBackendWindow` is assigned inside the
`WindowMapMutex critical:` block and read after it.

The tag residue trap bit again, in a new shape. After the moves the old package still reported the
five SDL2 classes among its `definedClasses`, and they were listed under a tag named `Graphics`
rather than under the `SDL2` tag they came from, which had disappeared. So the residue is not
reliably in the tag a class was taken out of: clear it by removing each stray from every tag of the
old package, and check `definedClasses` for classes whose `package` is no longer that package.

## What unit 8 did

Done 16 October 2026.

`PharoVulkan` renamed to `PharoVulkan-Bindings`, with the 146 classes, the five tags and every
reference carried over by the organiser: `PackageOrganizer default renamePackage: to:` does the
whole rename in one step, so there was no move and no tag residue to clear this time. Iceberg sees
it as the directory `src/PharoVulkan` replaced by `src/PharoVulkan-Bindings`, which git records as
renames of the 146 Tonel files. The manifest class was renamed with it, to
`ManifestPharoVulkanBindings`, and the package comment — still the Pharo placeholder text, because
this package was never created by this plan — was replaced with a real one: what the four tags hold,
that the package is the bottom of the stack, and the uFFI rules a structure here must obey.

**D5 is settled, as recommended, with one deviation.** Six references reached up out of the
bindings, all of them from report methods, and each one moved down to the class that owns the value
with the old holder left delegating, so that nothing outside the bindings changed:

| Value | Now owned by | Delegating |
|---|---|---|
| `clearComponentCount`, `clearComponentByteCount` | `VkRenderPassBeginInfo class` | `VkCommandBuffer class` |
| `subpassContents` | `VkRenderConfig class` | `VkCommandBuffer class` |
| `unlimitedImageCount` | `VkSurfaceCapabilitiesKHR class` | `VkSwapchain class` |
| `swapchainImagesBeyondMinimum` | `VkRenderConfig class` | `VkSwapchain class >> imagesBeyondMinimum` |
| the image-count rule, as `swapchainImageCount` | `VkSurfaceCapabilitiesKHR` | `VkSwapchain class >> imageCountFor:` |
| `formatRenderedIn` | `VkRenderConfig class` | `VkSurface class` |
| `clipObscuredPixels`, `presentModeNameFor:` | `VkRenderConfig class` | `VkSwapchain class` |
| `attachmentByteCount` | `VkFramebufferCreateInfo class` | `VkFramebuffer class` |

Two of these are more than a constant moving house. The image-count rule reads nothing but fields of
the capabilities structure, so the rule itself moved into `VkSurfaceCapabilitiesKHR >>
swapchainImageCount` and the swapchain asks; the report row now asks the same rule the creation code
asks, instead of restating it. The stride of an attachment entry moved to the structure that
declares the pointer, which is where this project already puts a stride for a run uFFI cannot
declare.

The deviation is `presentModeNameFor:`. The plan suggested a `VkPresentMode` constants class, like
the other enumerations. There is one present mode constant in this project, and the lookup already
worked by reflecting over the selectors of `VkRenderConfig class` that begin `presentMode`, so a new
class would have held one value and the lookup would have had to find it anyway. The method moved to
`VkRenderConfig class` beside the constant instead. Moving it there exposed something the old home
hid: the lookup now matches its own selector by prefix, so it selects on `numArgs isZero` as well,
which is stated in the comment.

`VkBindingsTest >> testNoBindingReachesAnotherPharoVulkanPackage` was written first and failed on
all six. It reads every method of both sides of every class of the package the bindings are in,
blocks included, and asserts that no referenced class lives in another `PharoVulkan` package. It
asks `VkRenderConfig package` for that package rather than naming it, so the rename did not touch
it. `VkBindingsTest >> testGeneratorInstallsIntoThePackageTheBindingsAreIn` states the other fact
unit 4 found: the three generate methods install into the literal `'PharoVulkan-Bindings'`, which
until this unit was a package that did not exist. The test reads the literal out of the three
methods and asserts it names a package in the image and is the package the declared structures are
in.

The baseline now declares `PharoVulkan-Bindings` requiring nothing at all — the examples that used
to make it depend on SPIRV and the compiler left in unit 1, and D5 removed the last edges — adds a
`bindings` group, and names it in `default` and in every `requires:` that used to say
`'PharoVulkan'`. Every other package's edges are unchanged.

**A real bug the rename exposed, which unit 7 had introduced.** `PVGraphicsTest class >>
projectPackageName` answered `#PharoVulkan`, and `graphicsClasses` was the classes of that package
whose tag was named `Graphics`. Unit 7 moved all seventeen of them out, so from that commit onwards
`graphicsClasses` was empty and `testEveryGraphicsClassIsExercisedOnADeviceOrSaysWhyNot` — the test
whose whole point is that a new graphics class with no device path fails — passed because it
compared two empty collections. The rename turned the silence into an error, because
`packageNamed: #PharoVulkan` now raises. The fix makes the test ask packages rather than tags:
`projectPackageNames` is every package whose name begins `PharoVulkan` except the test package, so
the walk stays project code across all eight code packages and a ninth is covered the day it is
created, and `graphicsClasses` is the classes of `PharoVulkan-Graphics`, less the package manifest,
which carries the package comment and the critic settings and which no test can put on a device. The
test now checks seventeen classes against 245 reachable ones, and passes.

Critics on the package: 63 critiques, and not one of them is caused by the rename. They are of three
kinds. The generated structures report excessive variables and excessive methods, which is what a
declared Vulkan structure with sixty fields is. The package's extension methods on
`SequenceableCollection` and `Number` make Renraku report those base classes whole, so their own
critiques — excessive methods, uncategorized class, redundant class name in selector — are counted
here although nothing in this project can fix them. The rest is the dead `PVTmpArrayStructProbe`,
which this plan already records as a follow-up, four inconsistent classifications, two shadowed
`layout` temporaries in generated `Vk class` calls, and `VkHandle >> finalize`, which Renraku says
is equivalent to its superclass method.

Suite: 599 tests over the nine concrete test classes, all passing. Getting to that number took
three runs and a correction to how this project diagnoses a window test. The first run reported two
errors: the coverage test described above, which was the real bug, and
`testPresentRequestForARealSwapchainCarriesItsHandleAndIndex`, which passed on its own. The second
reported one, `testRenderFrameCyclesThroughTheSwapchainImages`, which also passed on its own —
five times in a row, then nine frames acquiring all four swapchain images. The third run was
instrumented: every case run under `on: Exception do:` that records the exception class, its message
and fourteen frames of its stack, with the case name written to a global before it runs. It raised
nothing, 599 for 599.

So the two window errors were intermittent and neither was caused by this unit. The one value this
unit could have changed is the requested image count, and it is the same rule as before —
`minImageCount + 1` clamped to `maxImageCount`, with zero read as no maximum — while the count the
cycle test compares against is not the request at all: `VkSwapchain >> imageCount` answers the
images the driver gave back. What makes a window test fail under suite load and pass alone is still
unknown, and it belongs on the follow-up list rather than inside this plan.

Two lessons about diagnosing them, both paid for in wall-clock time. A diagnostic fork must publish
progress as it goes: a fork that writes its log only when it finishes is indistinguishable from a
hung image for as long as it runs, because `evaluate_pharo` times out while a window test holds the
VM. And the handler must be as careful as the code it watches — a handler that called the
non-existent `Context >> stack:` raised a `MessageNotUnderstood` of its own, which opened a debugger
that suspended the fork and stranded a live window for twenty minutes of apparent hang. Writing the
log to a file is no help here either: the image runs on the host filesystem, so a file it writes is
not a file this session can read.

## What unit 9 did

The six test packages exist, each named for the code package it covers and ending in `-Tests` by
decision D9, and `PharoVulkan-Tests` is down to its manifest, waiting for the architecture test
unit 10 writes. Every class moved with `cls package: pkgObject tag: tagName`, which leaves no tag
residue, and each package carries a `Tests` tag holding test classes and a `Fixtures` tag holding
the stubs and fixtures those tests build, so a reader can tell the two apart in the browser:

| Package | Tests | Fixtures |
|---------|-------|----------|
| `PharoVulkan-Bindings-Tests` | `VkBindingsTest` (287) | — |
| `PharoVulkan-SPIRV-Tests` | `SpvBuilderTest` (16), `SpvEmitterTest` (2) | — |
| `PharoVulkan-Compiler-Tests` | `PVCompilerTest` (79), `PVSpirvValidatorTest` (30) | `PVCfgShapeFixture`, `PVMissingToolValidatorStub` |
| `PharoVulkan-Core-Tests` | `VkCoreTest` (67) | `PVQueueFamilyStub` |
| `PharoVulkan-Compute-Tests` | `PVComputeTest` (59) | `PVNoSubgroupArithmeticStub` |
| `PharoVulkan-Graphics-Tests` | `PVGraphicsTest` (52), `VkImageTest` (8) | `PVFailingTriangleSceneStub`, `PVRecordingContextStub` |
| `PharoVulkan-Tests` | `PVArchitectureTest`, in unit 10 | — |

No test class was renamed. The convention asks for `<Package>Test`, and the nine names already
satisfy what the convention is for: five say the package (`VkBindingsTest`, `VkCoreTest`,
`PVComputeTest`, `PVCompilerTest`, `PVGraphicsTest`) and four say the subject they are about
(`SpvBuilderTest`, `SpvEmitterTest`, `PVSpirvValidatorTest`, `VkImageTest`), which is the better
name for a second test class in a package that already has one.

The baseline names all fifteen packages, with one `requires:` set per test package written from a
scan of what each one's classes actually reference: `-Bindings-Tests` on Bindings, Core, Compute,
Graphics, Generator and Examples; `-SPIRV-Tests` on SPIRV, Core and Compute; `-Compiler-Tests` on
Compiler, SPIRV, Compute and Examples; `-Core-Tests` on Core, Bindings, Compute, SPIRV and
Examples; `-Compute-Tests` on Compute, Bindings, Core, Compiler, SPIRV, Examples and
`-Compiler-Tests` (decision D8); `-Graphics-Tests` on Graphics, Bindings, Core, Compute, Compiler
and Examples; and `PharoVulkan-Tests` on the six. Most of them require the examples because the
test classes read the `<sampleInstance>` examples unit 1 created. The `tests` group loads
`default`, the examples, the generator and `PharoVulkan-Tests`, which pulls the six in through its
own `requires:`. A check of the baseline against the organiser reports no package declared that
does not exist and none in the image that is not declared.

Unit 7's silent coverage hole was closed here rather than left to the architecture test.
`PVGraphicsTest class` had asked the organiser for one package by name; it now derives both
populations from the organiser, by the prefix `'PharoVulkan'` and the suffix `'-Tests'`
(`projectPackageNamePrefix`, `testPackageNameSuffix`, `testPackageNames`, `projectPackageNames`),
so a package added to either side is read the day it is created. The new instance-side test
`testTheCoveragePopulationsAreNotEmpty` states that the three populations the coverage tests walk
are not empty, which is the assertion whose absence let unit 7's hole stay green for a commit.
It was seen green, then red after the classes moved, then green again after the derivation was
fixed — the sequence the standing cycle asks for.

Two fixture classes had no class comment, which the critics on the new packages surfaced:
`PVFailingTriangleSceneStub`, whose initialisation always raises so that
`PVHelloTriangleScene class >> prepare:backendWindow:` can be shown to destroy a half-initialised
scene, and `PVRecordingContextStub`, which answers itself for `computeQueue` and `device` and
counts `waitIdle`. Both now say what they are and why they count on the class side.
`PVFailingTriangleSceneStub >> destroy` was reclassified to `releasing`, which is where its
superclass puts it.

Critics on the seven packages are clean except for what was already there before the split:
`ReExcessiveMethodsRule` on the four large test classes, `ReLongMethodsRule` on three module
builders, `ReCyclomaticComplexityRule` on the two layering tests, and one
`ReTempsReadBeforeWrittenRule`. The nine `ReTestClassNotInPackageWithTestEndingNameRule` critiques
the prefix naming introduced are gone with D9.

The suite is 600 tests over the nine classes — 599 plus the new guard test — and it passed twice:
once before the D9 rename and once after it, both times in a forked instrumented run that records
every exception rather than trusting the package-level count. The six package-reading tests were
also run one at a time after the rename, because they are the only tests the rename could break.
The image was saved before and after the rename. One warning for the next unit: during the first
of the two runs the image stopped answering `evaluate_pharo` entirely, including `1 + 1`, for
about fifteen minutes while the graphics tests held the VM inside a driver call. That is not a
hang to debug — the suite finished and reported 600 run, 0 failed — so the right response is to
wait and keep polling the one global.

## Rules this plan sets

- **The image moves the class, not the file system.** `cls package: (PackageOrganizer default
  ensurePackage: '…')` and `cls packageTag: …`. Editing `src/` or the `#package:` pragma in a Tonel
  file is not a way to move a class. Pass the package, never its name: `cls package: 'A-B'` is
  parsed as the package `A` with the tag `B`, which silently builds a tag in the package the class
  is leaving. After every unit, check that the old package's `definedClasses size` fell by exactly
  the number of classes moved, and that no stray tag is left holding them.
- **While a forked suite runs, poll `Smalltalk at: #Run` and nothing else.** Two units have had a
  test fail only in a run that was being watched: a reflective query asked beside the suite —
  `allSendersOf:`, `Process allSubInstances`, package membership — races the tests that read the
  same system state.
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
- **The baseline names the package in the same unit that creates it.** A unit that creates a
  package and leaves `BaselineOfPharoVulkan` naming only the old one leaves a repository that
  cannot be loaded, because the new package's directory is not in the baseline. The `requires:`
  edges are written from the scan that unit did, not guessed.
- **A class-side constant may not be named after a reflection selector.** `Class >> binding`,
  `Behavior >> compile:` and the rest are how tools read a class; a constant of the same name
  hides them and breaks the tools rather than the code that reads the constant. See what unit 3
  found.
- **A test that reads one package name goes quiet when the package splits.** Unit 7 moved the
  graphics classes out of the package `PVGraphicsTest` asked for them by name, and the coverage
  test went green by comparing two empty collections for a whole commit. A test that states a fact
  about a population must either assert that the population is not empty or derive it by prefix
  from the organiser, so that moving a class cannot silence it. Unit 8 found this one only because
  the rename turned the silence into an error.
- **A diagnostic fork publishes progress, and its handler is as careful as the code it watches.**
  `evaluate_pharo` times out while a window test holds the VM, so a fork that writes its result only
  at the end looks exactly like a hung image. Write the case name to a global before each step. A
  file is not an alternative: the image runs on the host filesystem, which this session cannot read.
  An exception handler that itself raises — `Context >> stack:` does not exist — opens a debugger,
  suspends the fork and strands a live window and `VkInstance`; terminate that process so its
  `ensure:` blocks release them.
- **Rename a package with the organiser, not by moving its classes.**
  `PackageOrganizer default renamePackage: aPackage to: aName` carries the classes, the tags, the
  manifest and the package comment across in one step, leaves no tag residue, and gives Iceberg a
  directory rename that git records as renames of the files rather than as deletions and additions.
- **A test package is named `<Package>-Tests`.** Pharo's tools and Renraku's
  `ReTestClassNotInPackageWithTestEndingNameRule` read the end of the name, not the start, so the
  prefix form `PharoVulkan-Tests-<Name>` puts a critique on every test class in it. See decision D9.
- **A silent image is not always a stuck image.** A graphics test holds the VM inside a driver
  call, and while it does, `evaluate_pharo` cannot answer anything at all. Judge a forked run by
  the global it publishes once it answers again, not by the timeouts.
- **No cosmetic change rides along.** The split moves classes. The six decisions are the only code
  changes, each with a reason recorded here, and each gets its failing test first.

## Not in this plan

The `PVTmpArrayStructProbe` class in the `Uncategorized` tag is dead and should go, but deleting it
is not part of a package move.
Renaming `PVKernelExamples` to say what D4 concludes it is, dropping the unused `extent:` argument
from `VkGraphicsPipeline >> initializeDevice:renderPass:vertexModule:fragmentModule:extent:`, and
the group 5 structures `LAYOUT-PLAN.md` names are all separate work.
So are the two unreachable IR node classes `SpvIRBranch` and `SpvIRReturnValue`, the seven
unreachable compiler classes `PVPhiNode`, `PVSSAVar`, `PVVec2`, `PVVec3`, `PVVec4`, `PVBVec3` and
`PVMat4`, and the two class-side selectors that hide a system one without breaking anything today,
`PVKernelCompiler class >> compile:` and `SpvMemorySemantics class >> release`.
