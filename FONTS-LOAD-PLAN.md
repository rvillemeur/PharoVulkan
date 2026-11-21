# FONTS-LOAD-PLAN

## 1. What this plan is for

Someone who wants the TrueType engine on cairo — a `.ttf` read by this project, rasterised by the
real cairo library through Alexandrie, posed in Bloc in place of its FreeType font engine — must be
able to load exactly that. Today the `fonts` group hands them the whole software canvas as well:
`VectorGraphics-Canvas`, `VectorGraphics-Canvas-Raster` and the half of `VectorGraphics-Bloc` that
draws scan lines in Pharo. None of it is on their route. It is thirty-odd classes of distraction,
and it drags the rasteriser stack into an image that will never call it.

The goal of this plan is one sentence: after it, `fonts` loads the TrueType-on-cairo route and no
package of the software canvas.

Three couplings stand in the way, and all three are small.

- `VGAeTextFont` builds its glyph outlines through `VGPathBuilder`, which lives in
  `VectorGraphics-Canvas` together with `VGPath` and `VGSubPath`. The three are pure geometry. The
  only reference any of them makes to the rest of the project is two convenience methods on
  `VGPath`, `segmentsWithFillRule:` and `segmentsWithFillRule:antialias:`, which name
  `VGSegments` in `VectorGraphics-Canvas-Raster`.
- `VGFontCanvas class >> upstreamCairoRows` names `VGCairoReferenceScanner`, also in
  `VectorGraphics-Canvas`. It feeds `seamRows`, which feeds the inspector view
  `VGFontCanvas class >> inspectorSeams:` — production, not a test helper.
- `VectorGraphics-Bloc` holds both renderers in one package. `VGFontCanvas` is the superclass of
  `VGAeCanvas`, the cairo route, and of `VGCanvas`, the software route, so the package cannot be
  loaded by one route without the other.

## 2. Decisions

These were settled in the interview of 2026-11-20 and are not to be revisited without amending this
section.

| # | Decision | Reason |
|---|---|---|
| 1 | The eight cairo-route classes of `VectorGraphics-Bloc` move into `VectorGraphics-Bloc-FontEngine`, joining `VGFontEngine`. `VectorGraphics-Bloc` keeps the software route and gains a requires on `VectorGraphics-Bloc-FontEngine` | No new package name, and the route someone loads for fonts is one package. The new edge is honest: the software canvas really does inherit from a font canvas |
| 2 | `VGPath`, `VGSubPath` and `VGPathBuilder` move to a new leaf package `VectorGraphics-Canvas-Paths`. `VGPath >> segmentsWithFillRule:` and `segmentsWithFillRule:antialias:` become extension methods owned by `*VectorGraphics-Canvas-Raster` | The geometry is wanted by both routes and names nothing once the two convenience methods are owned by the package whose class they build. Same pattern as `Color >> asVGChannels` in unit 8 of the canvas split |
| 3 | `VGCairoReferenceScanner` moves to a new leaf package `VectorGraphics-Reflection` | It has twenty-five methods and no dependency on any package of this project, so it can be required by every package that wants it. `VectorGraphics-Canvas` and its test group are held to naming no Bloc class, so the scanner cannot move to the Bloc side instead |
| 4 | Both new packages get their full mirror pair. `VGPathExamples` moves to `VectorGraphics-Canvas-Paths-Examples`, `VGCairoPathTest` to `VectorGraphics-Canvas-Paths-Tests`, `VGCairoReferenceScannerExamples` to `VectorGraphics-Reflection-Examples` | The split's rule is that every production package has its own examples and tests package. The scanner's assertions live in four other test classes and stay where they are, because each of those classes is about its own subject |
| 5 | The `fonts` group keeps its name. Its contents become `truetype`, `VectorGraphics-Canvas-Fonts`, `VectorGraphics-Canvas-Paths`, `VectorGraphics-Reflection` and `VectorGraphics-Bloc-FontEngine` | Anyone who loads `fonts` today gets the same route, with the canvas gone. A second name for one route would be two entries to hold in step |
| 6 | Four units, each green and committed on its own, then a fresh-image gate | A red is placeable, and the closing proof is a load, not an argument |

Amendments, each recorded in the unit that made it. Decision 1 is superseded: the eight classes
went to a package of their own, `VectorGraphics-Bloc-Text`, and `VectorGraphics-Bloc-FontEngine`
kept `VGFontEngine` and the install hook alone, because a package carrying that hook cannot be
required by `VectorGraphics-Bloc` without posing the cairo renderer on every image that loads the
software canvas — see section 5. In decisions 2, 4 and 5 the new leaf package is named
`VectorGraphics-Canvas-Geometry`, not `-Canvas-Paths`, and `VGCairoMatrix` moved into it as well —
see section 3. Package count therefore goes from thirty-four to forty-two: three production
packages and five mirrors are added, and none is removed.

Not in scope. No class is renamed and no production behaviour changes. The three unguarded
`VGConformanceTest` cases and `testTheMuTalkProjectIsPinnedToATagAndNotToMaster` stay as they are,
on the user's instruction of 2026-11-20. Nothing on the Vulkan side is touched.

## 3. Unit 1 — `VectorGraphics-Canvas-Paths`

`VGPath`, `VGSubPath` and `VGPathBuilder` move out of `VectorGraphics-Canvas` into a leaf package,
and the two methods that make `VGPath` name the rasteriser become extensions owned by
`VectorGraphics-Canvas-Raster`. `VGPathExamples` and `VGCairoPathTest` move to the mirrors.

The first failing test is the dependency table: `'VectorGraphics-Canvas-Paths' -> #( )` in
`VGArchitectureTest class >> allowedDependencies`, with the per-package test beside the sixteen that
are there. Before the package exists it errors with
`key 'VectorGraphics-Canvas-Paths' not found in PackageOrganizer`, which is the red to see first.

`VectorGraphics-Canvas` gains `VectorGraphics-Canvas-Paths` in its allowed dependencies. The
rasteriser's own entry stays empty, which is the point of owning the two methods: the table reads
the classes a method names, not the class it is installed on, so an extension on `VGPath` creates no
edge. The baseline still has to declare `VectorGraphics-Canvas-Raster requires
VectorGraphics-Canvas-Paths`, because an extension method cannot load before the class it extends.
That asymmetry is now stated in the comment of `declareBackendPackagesOn:` and in the package
comment of the rasteriser.

### Verification

Done on 2026-11-20, in the image.

The three geometry classes are in `VectorGraphics-Canvas-Paths` under a `Path` tag,
`VGPathExamples` in `VectorGraphics-Canvas-Paths-Examples` and `VGCairoPathTest` in
`VectorGraphics-Canvas-Paths-Tests`. `VGPath >> segmentsWithFillRule:` and
`segmentsWithFillRule:antialias:` carry the protocol `*VectorGraphics-Canvas-Raster`, so the
rasteriser owns them, as `Color >> asVGChannels` is owned.

The dependency table gained three entries and three per-package scan tests; the baseline gained the
three packages, the `canvas-paths`, `canvas-paths-examples` and `canvas-paths-tests` groups, and
`canvas-paths` in `default`, `canvas-paths-tests` in `dev` and in `tests`, `canvas-paths-examples`
in `examples`. Four group assertions were recompiled for the new package: the `default` group test,
the `dev` group test, the union-of-layers test and the test that holds the canvas example and test
groups to naming no Bloc class.

`VGArchitectureTest`: 63 ran, 51 passed, 2 failures, 10 errors — the same two failures
(`testEveryAllowedDependencyNamesAPackageOfThisProject`,
`testEveryPackageOfThisProjectHasADeclaredAllowedSet`) and the same ten `KeyNotFound` errors as
before the unit, all of them the load-set reds the user deferred on 2026-11-20.

Every suite the move could touch is green, run class by class:

| Suite | Tests |
|---|---|
| `VGCairoPathTest` | 13 |
| `VGCairoStrokeTest` | 29 |
| `VGRasteriserTest` | 16 |
| `VGCairoClipTest` | 17 |
| `VGBlurTest` | 10 |
| `VGBackendSelectionTest` | 13 |
| `VGCairoSkeletonTest` | 5 |
| `VGCairoInventoryTest` | 6 |
| `VGCairoContextStateTest` | 22 |
| `VGMeshTest` | 10 |
| `VGPaintTest` | 23 |
| `VGCairoMatrixTest` | 16 |
| `VGCairoOperatorTest` | 12 |
| `VGCairoSurfaceTest` | 29 |
| `VGCairoExportSurfaceTest` | 14 |
| `VGCairoTextTest` | 47 |
| `VGPathsDocumentationTest` | 15 |
| `VGEngineDocumentationTest` | 15 |
| `VGTextDocumentationTest` | 15 |
| `VGTrueTypeDocumentationTest` | 15 |
| `VGPathsExamplesTest` | 5 |
| `VGEngineExamplesTest` | 5 |
| `VGTextExamplesTest` | 5 |
| `VGTrueTypeExamplesTest` | 10 |
| `VGConformanceTest` | 15 |

382 tests, no failure and no error. `VGCairoDrawingTest` and `VGCairoExamplesTest` were not run:
both open windows, and the one earlier attempt held the image for about twelve minutes. Neither
reads a package name — `VGCairoExamplesTest class >> exampleHolders` lists the example classes
themselves and `projectDefines:` tests the `VectorGraphics-` prefix — so the move is invisible to
them.

`run_critics` on the three new packages: `VectorGraphics-Canvas-Paths-Examples` and
`-Tests` clean, `VectorGraphics-Canvas-Paths` reports only
`ReExcessiveArgumentsRule` on `VGPathBuilder >> flattenCubicFrom:via:via:to:depth:` and
`VGArchitectureTest` only `ReExcessiveMethodsRule`; both predate this unit and neither method or
class was touched by it.

Three package comments were written or corrected: the new one for `VectorGraphics-Canvas-Paths`,
the `Path` tag line dropped from `VectorGraphics-Canvas` with the new package named in its closing
paragraph, and the stale paragraph of `VectorGraphics-Canvas-Raster` replaced — it still claimed
four methods read a class of `VectorGraphics-Canvas` and that section 8 of `CANVAS-SPLIT-PLAN.md`
was the plan to remove them, which that section has since done.

## 4. Unit 2 — `VectorGraphics-Reflection`

`VGCairoReferenceScanner` moves to a leaf package with its mirrors, and
`VGCairoReferenceScannerExamples` moves with it. The packages that name the scanner —
`VectorGraphics-Bloc` through `VGFrameProfile` and `VGFontCanvas`, and four test packages — each
gain the entry.

The first failing test is the same shape as unit 1's: the table entry
`'VectorGraphics-Reflection' -> #( )` and its per-package test, erroring on the missing package.

### Verification

Done on 2026-11-20, in the image.

The red came first, as planned: both new per-package tests errored with
`KeyNotFound: key 'VectorGraphics-Reflection' not found in PackageOrganizer`.

`VGCairoReferenceScanner` is in `VectorGraphics-Reflection` under a `Reflection` tag and
`VGCairoReferenceScannerExamples` in `VectorGraphics-Reflection-Examples` under `Examples`. The
scan was measured rather than assumed: `VGCairoReferenceScanner allCallsOn` answers eleven methods,
in `VectorGraphics-Bloc` (`VGFontCanvas class >> upstreamCairoRows`, `VGFrameProfile class >>
packageAndTagKeys`), `VectorGraphics-Canvas-Fonts-Tests`, `VectorGraphics-Canvas-Raster-Tests`,
`VectorGraphics-Canvas-Tests` and the two example methods that moved with it. `VectorGraphics-Canvas`
itself names the scanner nowhere, so its own entry did not change — the canvas held the class
without using it, which is why the move cost it nothing.

`VectorGraphics-Reflection-Tests` was **not** created, and this departs from decision 4. No test
class has the scanner as its subject: the eleven references are the gate, the backend selection and
the text tests reading it as a tool, and decision 4 says those stay where they are, each class being
about its own subject. A tests package with nothing in it would be a Tonel directory, a table entry
and a group no test justifies, so the mirror pair of this package is the examples package alone. The
one test whose subject really is the scan, `VGArchitectureTest >>
testTheScanReadsAReferencePlantedInsideANestedBlock`, stayed in the architecture suite with its
fixture; moving it is a change to the suites, not to the load units, and it is the user's call.

The table gained `'VectorGraphics-Reflection' -> #( )`,
`'VectorGraphics-Reflection-Examples' -> #( 'VectorGraphics-Reflection' )` and their two
per-package tests, and the entries of `VectorGraphics-Bloc`,
`VectorGraphics-Canvas-Fonts-Tests` and `VectorGraphics-Canvas-Raster-Tests` gained the scan.
`VectorGraphics-Canvas-Tests` gained both it and the examples mirror, because
`VGCairoExamplesTest class >> exampleHolders` names `VGCairoReferenceScannerExamples`.

The baseline declares both packages in `declareSupportPackagesOn:`, beside the corpus and the
benchmark harness: all three hold neither a layer nor a suite. `declareGroupsOn:` gained
`reflection` and `reflection-examples`, and `examples` gained the latter. `reflection` is in no
group above it — every package that reads the scan requires it, so it arrives with whichever of
them is asked for, and it stays out of `default`, which no longer holds a package that names it.

`VGArchitectureTest`: 65 ran, 53 passed, 2 failures, 10 errors — the two new tests included, and
the same deferred failures and errors as before the unit.

The suites the move could touch are green: `VGBackendSelectionTest` 13, `VGCairoTextTest` 47,
`VGCairoInventoryTest` 6, the four documentation gates 15 each, `VGPathsExamplesTest` 5,
`VGEngineExamplesTest` 5, `VGTextExamplesTest` 5, `VGTrueTypeExamplesTest` 10,
`VGConformanceTest` 15 — 221 tests, no failure and no error. `VGCairoExamplesTest` names the
scanner's examples class and was again not run, because it opens windows; the architecture suite
holds the same reference through its own gate and passes.

`run_critics` on `VectorGraphics-Reflection` and `VectorGraphics-Reflection-Examples`: clean. The
production package has its comment and its two tags, the examples mirror has neither comment nor
manifest, as every other mirror of this project. The `Reflection` tag line left the comment of
`VectorGraphics-Canvas`, which now says where the scan went and why.

## 5. Unit 3 — the Bloc split

The cairo text route leaves `VectorGraphics-Bloc`. Eight classes move: `VGAeCanvas`,
`VGAeOffscreen`, `VGAeRenderer`, `VGAeTextContext`, `VGAeTextFont`, `VGFontCanvas`, `VGFontManager`
and `VGFontManagerHasNoUsableFamily`, with the ten extension methods on the classes of Alexandrie
that serve them. Their package tags come with them, so the new package holds `Backend`, `Fonts` and
`Text`. `VectorGraphics-Bloc` keeps `VGCanvas`, `VGRenderer`, `VGOffscreen`, `VGPixelBufferHost`,
`VGPixelBufferHostSpace`, `VGFormExporter`, `VGPngExporter` and `VGFrameProfile`.

The test and example classes of the moved classes move to the mirror packages of the new package.
Those mirror packages are not loaded in a `dev` image, because `dev` excludes the `bloc-tests` and
`fonts-tests` groups, so this unit begins by loading both groups. Each such load has taken about
ten minutes and leaves the image unresponsive, so it runs on its own.

### Amendment — the installer is a package of its own

The plan above put the eight classes into `VectorGraphics-Bloc-FontEngine`, which already held
`VGFontEngine` and the `postLoadDoIt: #installTheFontEngine` of the baseline. That cannot work.
`VGCanvas` is a subclass of `VGFontCanvas`, so `VectorGraphics-Bloc` has to require whatever
package holds `VGFontCanvas`; had that package carried the install hook, every image that loaded
the `bloc` group would have posed our font manager and `VGAeRenderer` over the renderer the user
asked for. Reparenting `VGCanvas` was ruled out: `VGFontCanvas >> scaledFontForFace:size:` was
pulled up deliberately in unit 5.1 of `FONT-PLAN.md` and both canvases share it.

Two decisions settled it. The route becomes a package of its own, named
`VectorGraphics-Bloc-Text`, and `VectorGraphics-Bloc-FontEngine` keeps only `VGFontEngine` and the
hook. So the split is three ways: eight classes to `VectorGraphics-Bloc-Text` with its two mirror
packages, one class left in `VectorGraphics-Bloc-FontEngine`, and the hook left with it. Loading
the route poses nothing; posing it is the one thing the font engine package does.

### Verification

The image holds the packages the amendment names. `VectorGraphics-Bloc-Text` has eight classes and
120 methods, its examples mirror five classes and its tests mirror nine, seven of them test classes
and two fixtures. `VectorGraphics-Bloc-FontEngine` has one class and five methods.
`VectorGraphics-Bloc` has eight classes left.

The measured edges are the point of the unit. `VectorGraphics-Bloc-Text` names
`VectorGraphics-Canvas-Fonts`, `VectorGraphics-Canvas-Geometry`, `VectorGraphics-Reflection` and
`VectorGraphics-TrueType`, and no canvas and no rasteriser. `VectorGraphics-Bloc` names the canvas,
the rasteriser and the reference scan, and nothing of the route; it requires the route in the
baseline for the superclass of `VGCanvas` alone, an edge the dependency table cannot state, because
a superclass is not a reference a method makes. `VectorGraphics-Bloc-FontEngine` names the route
and nothing else.

`VGArchitectureTest class >> allowedDependencies` holds 42 entries, and a run of
`edgesOf:` against it reports no mismatch for any loaded package. Six per-package scan tests were
added or renamed: three for `VectorGraphics-Canvas-Geometry` and its mirrors, three for
`VectorGraphics-Bloc-Text` and its mirrors. The baseline declares the six packages of the route and
the engine with their requires, and `declareGroupsOn:` gains `bloc-text`, `bloc-text-examples` and
`bloc-text-tests`, the last two inside the project-wide `examples` and `tests` unions.

What the groups load now, read back from the baseline:

- `bloc-text` alone: the route, the font layer, the geometry, the reference scan, the reader and
  the two pure Pharo packages below them. No canvas, no rasteriser.
- `bloc`: all of the above plus the canvas and the rasteriser, and **not**
  `VectorGraphics-Bloc-FontEngine`. A `bloc` user gets the renderer they asked for and nothing is
  posed.
- `fonts`: unchanged by this unit, and still pulling the canvas through `VectorGraphics-Bloc`.
  Unit 4 rewrites it.

`VGFrameProfile class >> stageByPackageAndTag` was re-keyed for all three units of this plan: the
geometry, the reference scan and the route each took their tags to a new package, and no stage
changed. `VGFrameProfileTest` had been failing on the stale keys of units 1 and 2 as well.

Suites: `VectorGraphics-Bloc-Text-Tests` 48 of 48, `VectorGraphics-Bloc-FontEngine-Tests` 17 of 17,
`VectorGraphics-Canvas-Geometry-Tests` 29 of 29, `VectorGraphicsDocumentationTest` 60 of 60,
`VGArchitectureTest` 60 of 68 and `VectorGraphics-Bloc-Tests` 54 of 55. Every red in the last two
is the deferred one: the `VectorGraphics-Vulkan` and `VectorGraphics-Benchmarks` packages are not
in this image, so the table entries naming them, the four scan tests over them, the stage keys of
their tags and the MuTalk pin test stay red until the PharoVulkan project is loaded again.

`run_critics`: nothing new. `VectorGraphics-Bloc-Text` reports only the critiques of the Alexandrie
classes it extends, which the package critic walks whole, plus the five `super` sends and the one
classification of `VGAeTextContext` and `VGAeOffscreen` that stood before the move.
`VectorGraphics-Bloc-FontEngine` is clean. `VectorGraphics-Canvas-Geometry` reports the three
six-argument matrix and curve selectors it always had. `VGArchitectureTest` and
`BaselineOfVectorGraphics` report the method count and the complexity of their own tables.

Left behind for a later unit: `VectorGraphics-Bloc`, `VectorGraphics-Bloc-Text` and
`VectorGraphics-Bloc-FontEngine` carry no manifest class comment, which every production package
below them has. The gap predates this unit.

## 6. Unit 4 — the baseline, the table and the README

`BaselineOfVectorGraphics >> declareBackendPackagesOn:` gains the two new packages and their
mirrors, and the requires of the packages whose edges changed. `declareGroupsOn:` gains
`canvas-geometry` and `reflection` groups with their test and example groups, and `fonts` is
rewritten to decision 5. `dev` and `default` keep their meaning: `default` still loads the canvas,
because it is the project's own renderer.

`VGArchitectureTest` gains the per-package scan tests for the new packages and the group assertions
for `fonts`. The README's package table gains six rows, and the section on the `fonts` group is
rewritten to say what it now loads and what it deliberately leaves out.

### Verification

The `fonts` group names five entries — `truetype`, `VectorGraphics-Canvas-Fonts`,
`VectorGraphics-Canvas-Geometry`, `VectorGraphics-Reflection` and
`VectorGraphics-Bloc-FontEngine` — and `packagesLoadedByGroupNamed: 'fonts'` resolves them to seven
packages:

    VectorGraphics-Bloc-FontEngine  VectorGraphics-Bloc-Text  VectorGraphics-Canvas-Fonts
    VectorGraphics-Canvas-Geometry  VectorGraphics-Paths      VectorGraphics-Reflection
    VectorGraphics-TrueType

`VectorGraphics-Canvas`, `VectorGraphics-Canvas-Raster`, `VectorGraphics-Engine` and
`VectorGraphics-Text` are all absent, which is the point of the plan. The route itself arrives
through the requires of the engine package, not through a canvas group; `bloc-text` alone resolves
to the same set less the engine package, six packages.

`reflection` and `reflection-examples` are declared, since unit 2 left the scan a package with no
group to ask for it by name. The comment of `declareGroupsOn:` gained a paragraph naming what
`fonts` is and why it names no canvas group.

`testTheFontsGroupLoadsTheCairoRouteAndNoCanvas` was written red, then green: it names the seven
packages one by one rather than asserting package by package, so the group cannot grow a layer back
unnoticed. It replaced `testTheFontsGroupLoadsTheRouteItInstallsAndNothingElse` of unit 3.7, which
asserted the canvas was part of the route; keeping both would have left two overlapping claims, so
the old one was deleted. `testTheExamplesAndTestsGroupsAreTheUnionOfTheirLayerGroups` now counts
thirteen example groups — the twelve layers and the reference scan — and twelve test groups.
`testTheCanvasExampleAndTestGroupsNameNoBlocClass` was widened to the measured
`canvas-geometry-tests` set.

`VGArchitectureTest`: 68 tests, 60 passed, 2 failed, 6 errored. The eight are exactly the deferred
set — the `VectorGraphics-Vulkan` and `VectorGraphics-Benchmarks` packages that are absent from this
image, and the MuTalk pin test, which fails on `MetacelloRepositoriesSpec >> #map`. The four
documentation suites: 60 tests, 60 passed. Critics on the three classes this unit touched report
only their pre-existing shapes: `ReExcessiveMethodsRule` on `VGArchitectureTest`,
`ReCyclomaticComplexityRule` on `declareBackendPackagesOn:`, and `ReBlocDoNotSendForceLayoutRule` on
`VGFrameProfile >> newScene`.

The README gained rows for `VectorGraphics-Canvas-Geometry`, `VectorGraphics-Reflection` and
`VectorGraphics-Bloc-Text` with their examples and suites, and group rows for `canvas-geometry`,
`bloc-text`, `reflection` and their mirrors. The `fonts` row, the `default` row and the section on
replacing Bloc's font engine were rewritten to the measured sets, and the counts in the text were
corrected against the image: `canvas-tests` brings fifteen packages, not eleven; `dev` names eight
test groups, not seven.

Two commits: `d574dde` for the image work through Iceberg, `1e79471` for the README. The README is
outside `src/`, so Iceberg does not carry it and git commits it directly, which moved HEAD behind
Iceberg's back and made the next `commitWithMessage:` raise `IceWorkingCopyDesyncronized`.
`workingCopy adoptCommit: repo head commit` cleared it. Commit the image work first next time.

Left behind for a later unit: `fonts-tests` still brings the canvas and the conformance corpus,
because `VectorGraphics-Bloc-FontEngine-Tests` requires `VectorGraphics-Canvas-Tests`. The route's
own suite, `bloc-text-tests`, is what a reader of the route should run; `fonts-tests` covers the
engine, whose tests were written against the canvas suite's fixtures.

## 7. The gate

The user builds a fresh image and loads the `fonts` group alone:

```smalltalk
Metacello new
	baseline: 'VectorGraphics';
	repository: 'tonel:///home/renaud/devzone/iceberg/rvillemeur/VectorGraphics/src';
	onConflictUseIncoming;
	load: 'fonts'
```

The plan is proved when no package whose name begins `VectorGraphics-Canvas` other than
`VectorGraphics-Canvas-Fonts` and `VectorGraphics-Canvas-Geometry` is in the image, `VGFontEngine` poses
its font manager, and a glyph renders.

### Verification

Not yet run.
