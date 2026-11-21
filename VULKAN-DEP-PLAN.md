# VULKAN-DEP-PLAN

## 1. What this plan is for

PharoVulkan is published at `https://github.com/rvillemeur/PharoVulkan`. Until now
`BaselineOfVectorGraphics` named it nowhere: the `vulkan` group loaded `VectorGraphics-Vulkan` and
expected PharoVulkan already in the image, loaded by hand. That is a load nobody can reproduce from
the baseline alone, and the README said so in as many words.

This plan declares the dependency, so that `vulkan`, `vulkan-examples`, `vulkan-tests` and the two
project-wide unions above them load from a plain image.

## 2. Decisions

1. **The pin is a branch**: `github://rvillemeur/PharoVulkan:main/src`. PharoVulkan has no release
   tag and is written alongside this project, so a tag cut today is stale a week later. Bloc follows
   `master` for the first of those reasons; MuTalk keeps its tag, because it rewrites production
   methods in the image and the version doing the rewriting is part of this project's setup.
2. **The group asked for is PharoVulkan's `default`**: Bindings, Core, Compute and Graphics, whose
   own requires bring its SPIR-V, compiler and inspector packages. `graphics` resolves to the same
   set; `default` is that project's own answer to what a user of it needs.
3. **`examples` and `tests` stay whole unions.** They already name `vulkan-examples` and
   `vulkan-tests`, and that is what `testTheExamplesAndTestsGroupsAreTheUnionOfTheirLayerGroups`
   holds them to. A machine with no Vulkan driver loads `dev`, which names the eight test groups of
   the default stack and never the Vulkan one.
4. **Scope**: the declaration, the two project tests and the README. The seven reds that are red
   only because `VectorGraphics-Vulkan*` and `VectorGraphics-Benchmarks` are absent from the working
   image stay for a run in an image with a driver.
5. **The pin test is one table of three pins**, not one test per project and not a property check: a
   typo'd repository string is exactly what the test exists to catch.

Measured before deciding: the three `VectorGraphics-Vulkan*` packages name `VkBuffer`, `SpvOpcode`,
`PVVulkanDriver`, `PVComputeKernel`, `PVSpirvValidator`, `PVSPIRVEmitter`, `PVKernelCompiler`,
`PVHelloTriangleScene`, `PVWindowAttributes` and their kin — all inside PharoVulkan's `default`
closure. `PVGraphicsTest` appears only in a class comment, so PharoVulkan's `tests` group is not
needed. `VectorGraphics-Benchmarks` names no PharoVulkan class at all; it reaches the device through
`VGVulkanBackend`.

## 3. The unit

`declareExternalProjectsOn:` gains the project. The three `VectorGraphics-Vulkan*` package
declarations gain `'PharoVulkan'` in their requires; the `vulkan` group itself is unchanged, since
the project arrives through those requires. `VGArchitectureTest` gains the pin table and the
requires test, and loses the MuTalk-only pin test. The README's `vulkan` row stops saying the
project is unpublished.

### Verification

`testEveryExternalProjectIsPinnedWhereThisProjectMeansIt` was written first and ran red, on both
counts at once: no PharoVulkan among the projects, and the old reader. It replaces
`testTheMuTalkProjectIsPinnedToATagAndNotToMaster`, which had been erroring on
`MetacelloRepositoriesSpec >> #map` — that selector is gone from this Pharo, and
`each repositories repositorySpecs collect: [ :one | one description ]` is what answers the pins
now. The table holds all three:

    Bloc        -> github://pharo-graphics/Bloc:master
    MuTalk      -> github://pharo-contributions/mutalk:v3.0.8/src
    PharoVulkan -> github://rvillemeur/PharoVulkan:main/src

`testTheBaselineNamesOnlyBlocMuTalkAndPharoVulkanAsExternalProjects` replaces the two-project test
of the same shape, red before the declaration and green after.

`testTheVulkanLayerRequiresTheExternalPharoVulkanProject` holds the three packages to requiring the
project and every package of the `default` group to not requiring it. It was proved sensitive rather
than assumed: with the edge removed from `VectorGraphics-Vulkan` it fails, with it restored it
passes.

`VGArchitectureTest`: 69 tests, 62 passed, 2 failed, 5 errored. The seven are the load-state set —
the `VectorGraphics-Vulkan*` and `VectorGraphics-Benchmarks` packages are absent from this image, so
the per-package scans raise `key 'VectorGraphics-Vulkan' not found in PackageOrganizer` and the two
table tests see three declared packages that are not loaded. The MuTalk pin error is gone, which is
one red fewer than before this unit. Critics on `BaselineOfVectorGraphics` report only the
pre-existing `ReCyclomaticComplexityRule` on `declareBackendPackagesOn:`.

README: the `vulkan` row now names the repository, the `default` group the three packages require,
and the one thing the machine needs — `libvulkan.so.1` and a driver, which nothing else of the
project asks for.

## 4. The gate

In an image with a Vulkan driver, from a plain Pharo:

```smalltalk
Metacello new
	baseline: 'VectorGraphics';
	repository: 'github://rvillemeur/VectorGraphics:main/src';
	onConflictUseIncoming;
	load: 'vulkan-tests'
```

PharoVulkan must arrive on its own, and `VGArchitectureTest` must then run with no
`key '…' not found in PackageOrganizer` error and with the two table tests green, which is the seven
reds closed.

### Verification

Not yet run.
