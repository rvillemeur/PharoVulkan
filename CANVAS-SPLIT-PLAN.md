# CANVAS-SPLIT-PLAN — splitting VectorGraphics-Cairo into three packages

## 1. Why

`VectorGraphics-Cairo` holds 71 classes and 1352 methods, and its name says the one thing that is
not true of it: it does not bind Cairo. The package makes no `ffiCall:`, and it names no `Ae*` class
at all — rule 4 of `VECTORCANVAS-PLAN.md` forbids it to, so that the backend stands on its own in an
image where Alexandrie is absent. The native library is reached from `VectorGraphics-Bloc` alone,
which names `AeCairoContext`, `AeCairoImageSurface`, `AeCanvas`, `AeFontManager` and the HarfBuzz
classes, eleven references in all.

What the word *Cairo* means in this package is the *shape of the API*: `VGCairoContext` is the
replacement for `AeCairoContext`, `VGCairoImageSurface` for `AeCairoImageSurface`, and
`VGCairoInventoryTest` holds the list of selectors that correspondence requires. The classes keep
those names for that reason, and because eight packages of this project are absent from the working
image, where an automated rename would leave dead names in their Tonel files.

The package name is what changes, and with it the layering. Three things live in one package today
and want to be read separately:

- the recording canvas API and the device-independent model it records into — the context, the
  display list, the paint ABI, the patterns, the surfaces, the compositing operators, the matrix;
- the software renderer, which must never need a device, a library or a window, because it is the
  failover path and the oracle for the Vulkan backend;
- the scaled-font layer: one face at one size under one transformation, its glyph atlases and the
  text extents the canvas measures with.

The reading that prompted this plan was a question about the FreeType work: the font engine's test
package has to name `VectorGraphics-Cairo` because `VGFontFace` lives there, and that edge reads as
if the font engine depended on Cairo. After the split it names the font layer, and says what it
means.

## 2. The three packages

Measured in the image on 2026-11-20, from `VectorGraphics-Cairo` at commit `6903791`.

| Package | Classes | Tags it takes |
|---|---|---|
| `VectorGraphics-Canvas` | 46 | Context, Display list, Paint, Pattern, Surface, Compositing, Matrix, Export, Inventory, Reflection, Skeleton, Path (less `VGStroker` and `VGSegments`) |
| `VectorGraphics-Canvas-Raster` | 13 | Backend, Rasterising, Blur, plus `VGStroker`, `VGSegments`, `VGMeshRaster`, `VGCoonsPatch`, `VGCairoSurfaceMask` |
| `VectorGraphics-Canvas-Fonts` | 12 | Text |

`VectorGraphics-Canvas-Raster` (13): `VGBackend`, `VGBackendFailure`, `VGSoftwareBackend`,
`VGRasteriser`, `VGSpanScanner`, `VGEdgeIndex`, `VGClip`, `VGA8GaussianBlurFilter`, `VGStroker`,
`VGSegments`, `VGMeshRaster`, `VGCoonsPatch`, `VGCairoSurfaceMask`.

`VectorGraphics-Canvas-Fonts` (12): `VGFontFace`, `VGScaledFont`, `VGGlyph`, `VGGlyphAtlas`,
`VGGlyphMask`, `VGFontExtents`, `VGTextExtents`, `VGFontOptions`, `VGCairoAntialias`,
`VGCairoHintStyle`, `VGCairoHintMetrics`, `VGCairoSubpixelOrder`.

The four enumeration carriers go with the fonts because `VGFontOptions` is the only class in the
whole image that names any of them. `VGSegments`, `VGStroker`, `VGCoonsPatch` and
`VGCairoSurfaceMask` go with the renderer although their tags did not say so, and that placement is
what keeps the split nearly acyclic: see section 4.

`VectorGraphics-Canvas` keeps everything else, which is the 46 remaining classes.

## 3. The mirror packages

Six packages are born from the two that exist, by the rule this project already follows: a test or
examples class goes to the package of its subject.

| Package | From | Classes |
|---|---|---|
| `VectorGraphics-Canvas-Tests` | Cairo-Tests | `VGAlexandrieCorpusTest`, `VGArchitectureTest`, `VGCairoContextStateTest`, `VGCairoDrawingTest`, `VGCairoExamplesTest`, `VGCairoExportSurfaceTest`, `VGCairoInventoryTest`, `VGCairoMatrixTest`, `VGCairoOperatorTest`, `VGCairoPathTest`, `VGCairoSkeletonTest`, `VGCairoSurfaceTest`, `VGConformanceTest`, `VGMeshTest`, `VGPaintTest`, `VGNestedBlockReferenceFixture` |
| `VectorGraphics-Canvas-Raster-Tests` | Cairo-Tests | `VGBackendSelectionTest`, `VGRasteriserTest`, `VGCairoClipTest`, `VGCairoStrokeTest`, `VGBlurTest`, `VGBackendFrameFixture`, `VGBrokenBackendStub`, `VGFailingDrainBackendStub`, `VGCountingMaskStub` |
| `VectorGraphics-Canvas-Fonts-Tests` | Cairo-Tests | `VGCairoTextTest` |
| `VectorGraphics-Canvas-Examples` | Cairo-Examples | `VGArchitectureExamples`, `VGAlexandrieCorpusExamples`, `VGCairoContextExamples`, `VGCairoExportSurfaceExamples`, `VGCairoImageSurfaceExamples`, `VGCairoInventoryExamples`, `VGCairoMatrixExamples`, `VGCairoOperatorExamples`, `VGCairoReferenceScannerExamples`, `VGCairoStrokeStyleExamples`, `VGConformanceCorpusExamples`, `VGDisplayListExamples`, `VGFormComparisonExamples`, `VGMeshExamples`, `VGPaintExamples`, `VGPathExamples` |
| `VectorGraphics-Canvas-Raster-Examples` | Cairo-Examples | `VGA8GaussianBlurFilterExamples`, `VGBackendExamples`, `VGClipExamples`, `VGEdgeIndexExamples`, `VGRasteriserExamples`, `VGSpanScannerExamples`, `VGStrokerExamples` |
| `VectorGraphics-Canvas-Fonts-Examples` | Cairo-Examples | `VGScaledFontExamples`, `VGAlexandrieFontLifetimeExamples` |

`VGArchitectureTest` stays with the canvas, for the reason its own class comment gives: this project
has no aggregate test package, and a package of its own would owe the baseline and the profiling
stage table an entry for one class.

## 4. The edges, measured

Counted by reading the literals of every method of the package, the same scan `VGArchitectureTest`
uses, with the grouping of section 2.

| Edge | References | Where |
|---|---|---|
| Canvas → Canvas-Raster | 14 | `VGCairoContext` (clip, stroking), `VGCairoImageSurface` (backend, flush), `VGMeshPaint`, `VGSegments` callers |
| Canvas → Canvas-Fonts | 6 | `VGCairoContext` only: `defaultScaledFont`, `fontSize:`, `glyphsOf:size:`, `renderedGlyphMaskFor:atPhase:` |
| Canvas-Raster → Canvas | 4, now 0 | `VGRasteriser class`, `VGSegments class`, `VGStroker class` read `VGCairoState antialiasNames` or build a `VGCairoState`; `VGCoonsPatch class >> channelsOf:` reads `VGPaint rgbaOf:`. Section 8 removed all four |
| Canvas-Fonts → either | 0 | the font layer names no class of the other two |

Two facts to keep:

- **The font layer is a leaf.** It names `VectorGraphics-TrueType` and nothing else of this project.
  That is what makes the font engine's dependency honest after the split.
- **The renderer to canvas edge was four references in four methods**, three of them convenience
  constructors reading a default, one a colour conversion. It was a cycle, declared rather than
  hidden while the split was proven, and section 8 removed it: the renderer now names no package of
  this project but itself.

Outside the trio, measured in the image for the loaded packages and by reading the Tonel sources for
the eight that are not loaded:

| Package | Canvas | Raster | Fonts |
|---|---|---|---|
| `VectorGraphics-Bloc` | yes (7 classes) | yes (`VGBackend`) | yes (3 classes) |
| `VectorGraphics-Bloc-Examples` | yes | — | yes |
| `VectorGraphics-Bloc-Tests` | yes | yes | yes |
| `VectorGraphics-Bloc-FontEngine-Tests` | — | — | yes |
| `VectorGraphics-Conformance` | yes | yes | yes |
| `VectorGraphics-Benchmarks` | yes | yes | — |
| `VectorGraphics-Vulkan` and its two packages | yes | yes | — |

The counts for the unloaded packages come from a text scan, which reads comments as well as code.
The table of record is rebuilt from the architecture test's own scan once the packages are loaded,
in unit 4.

## 5. Rules

1. No package of the trio may name an `Ae*` class. This is rule 4 of `VECTORCANVAS-PLAN.md`,
   restated for three packages instead of one, and `VGBackendSelectionTest` already holds it through
   `VGCairoReferenceScanner`.
2. `VectorGraphics-Canvas-Fonts` names no class of `VectorGraphics-Canvas` or of
   `VectorGraphics-Canvas-Raster`. It is a leaf, and a test holds it so.
3. `VectorGraphics-Canvas-Raster` needs no device, no library and no window, as before.
4. Class names do not change. `VGCairo*` says "the replacement for `AeCairo*`", and the eight
   packages absent from the image cannot be rewritten by an automated rename.
5. Tag names travel with their classes, because `VGFrameProfile class >> stageByPackageAndTag` keys
   on `'<package>/<tag>'` and the tag is the unit of the profile.

## 6. Units

Each unit ends green, with the suite re-run, and is committed in Iceberg on its own.

### 6.1 Load the suite and record the baseline — done

The working image held the five code packages and none of the test packages. The groups loaded,
in two passes, were `cairo-tests`, `cairo-examples`, `truetype-tests`, `conformance`,
`fonts-tests`, `bloc-tests`, then `core`, `paths-examples`, `paths-tests`, `engine-examples`,
`engine-tests`, `text-examples`, `text-tests` and `benchmarks`. The `vulkan` groups were left out:
the baseline names no project for them, because PharoVulkan is not published, and this work needs
none of it. The image now holds 26 of the project's packages and 84 test classes.

A forked Metacello load must resume `MetacelloNotification` as well as `Warning`. A load wrapped in
`on: Error do:` alone ends on the first notification Metacello signals, and one wrapped in
`on: Exception do:` reports that notification as a failure; neither loads anything.

Every suite of the paths, engine, truetype, text, cairo, conformance, fonts and bloc layers is
green. Seven tests are red for a reason outside this work, and they are the baseline this split is
judged against — no new red beyond this list:

| Test | Why |
|---|---|
| `VGArchitectureTest >> testEveryPackageOfThisProjectHasADeclaredAllowedSet` | `VectorGraphics-Vulkan-Examples` and `-Vulkan-Tests` are absent from the image |
| `VGArchitectureTest >> testEveryAllowedDependencyNamesAPackageOfThisProject` | the same two packages |
| `VGArchitectureTest >> testEveryAllowedDependencyIsOneThePackageReallyMakes` | the same two packages |
| `VGArchitectureTest >> testVulkanExamplesStayInsideTheirAllowedDependencies` | the same two packages |
| `VGArchitectureTest >> testVulkanTestsStayInsideTheirAllowedDependencies` | the same two packages |
| `VGFrameProfileTest >> testEveryPackageAndTagOfThisProjectHasAStageAndNoOthers` | one stage key, `VectorGraphics-Vulkan-Examples/Examples`, names a package absent from the image |
| `VGArchitectureTest >> testTheMuTalkProjectIsPinnedToATagAndNotToMaster` | `MessageNotUnderstood: MetacelloRepositoriesSpec >> #map`: the test reads a Metacello spec through a selector this Metacello no longer has |

Two tests were red for a reason inside the project, and are fixed in commit `2f247a3`, ahead of the
split: `VGAeCanvasTest >> testPrepareForSurfaceStaysDerivedFromUpstream` and
`VGAeOffscreenTest >> testEnsureReadyStaysDerivedFromUpstream`. Both pin a derived method to
Alexandrie's own, and neither had been updated when the font work added the
`VGFontManager ensureUpstreamHoldsMine` guard to the derived method; each test now drops that
statement before the comparison. `VGAeOffscreen >> ensureReady` also wrote its measuring extent as
`1 @ 1` where upstream writes `1 asPoint`, which the same pin caught.

The last red of the earlier pass, the four tests of `VectorGraphicsDocumentationTest` and of
`VGTrueTypeDocumentationTest` that read `doc/ARCHITECTURE.md` against the image, were red only
because the packages the document names were not loaded yet. Both suites are green with the whole
rasteriser in.

### 6.2 The two new code packages — done

`VectorGraphics-Canvas-Raster` and `VectorGraphics-Canvas-Fonts` were created with the tags of
section 2, the 13 and the 12 classes moved into them, and `VectorGraphics-Cairo` renamed to
`VectorGraphics-Canvas`. No source changed: the 1352 methods are conserved, no protocol was left
unclassified, the one foreign extension method is the legitimate one, and no class of the trio
subclasses a class of another package of the trio, so each of the three loads alone. On disk
`src/VectorGraphics-Cairo` is gone and the three directories are in its place. Iceberg does not
follow an organiser rename: the three names had to be added to the working copy with
`addPackageNamed:` before the commit saw anything. Committed as `2dc4d96`.

### 6.3 The baseline — done

`BaselineOfVectorGraphics` declares `VectorGraphics-Canvas`, `VectorGraphics-Canvas-Raster` and
`VectorGraphics-Canvas-Fonts` in place of `VectorGraphics-Cairo`, and the groups `canvas`,
`canvas-raster` and `canvas-fonts` replace `cairo`. `default` is `core` plus the three, named one
by one so that what it loads is read from the group list and not from a chain of `requires:`.
`fonts` names `canvas` where it named `cairo`. Every `requires:` naming the old package is the
subset of section 4 the code really references.

Two deviations from the unit as written, both recorded in the commit message:

- The examples and the tests of the canvas keep the names `VectorGraphics-Cairo-Examples` and
  `-Cairo-Tests` and the groups `cairo-examples` and `cairo-tests` until 6.6 creates the six
  mirror packages. Declaring the six now would mean guessing their `requires:` before the classes
  are in them; this way every edge in the baseline is one measured against the code.
- `VectorGraphics-Canvas-Raster` declares no `requires:`, because its one edge is back to
  `VectorGraphics-Canvas`, which declares it. A pair declared both ways has no load order, so the
  renderer's half is left out of the baseline and
  `VGArchitectureTest class >> edgesTheBaselineCannotDeclare` holds it, beside the pair the review
  of 2026-11 left there.

A declaration method must be compiled on the instance side. `BaselineOf >> project` builds the
version spec by sending the `<baseline>` method to an instance, so the same four methods compiled
on the class side are never read, and `project version packages` keeps answering the old spec with
no error anywhere.

### 6.4 The architecture table — done

`VGArchitectureTest class >> allowedDependencies` names the three packages and no longer names
`VectorGraphics-Cairo`; every entry was read from the scan the test's own `edgesOf:` makes, and the
three Vulkan entries from the text scan of section 4, which is the only source available in an
image that cannot load them. `testCairoStaysInsideItsAllowedDependencies` became three tests, one
per new package, which is what `testEveryPackageOfThisProjectIsScannedByOneOfMyTests` requires.
Four tests that pinned the old package name were rewritten: the default group test, now
`testTheDefaultGroupLoadsTheRasteriserAndTheCanvasAlone`, the two group scans of the Cairo examples
and tests, and the fonts group test. `VGBackendSelectionTest` is green again, including
`testEveryPackageOfTheProjectIsNamedInTheBaseline`, which 6.3 was what fixed.

Three more readers of the old package name were found by scanning every method of the project for
the string, and each now reads the three packages: `VGCairoSkeletonTest >> packagesUnderTest` and
`>> skeletonMethods`, which made all four skeleton tests error, and
`VGConformanceTest >> unitsWithNoSkeletonLeft`, which is why
`testEveryCaseOfAFinishedUnitDraws` was red in the 6.1 baseline. Both suites are green now, and
no skeleton is left in any of the three packages. Four method comments naming the old package were
rewritten as well.

### 6.5 The profiling stage table — done

`VGFrameProfile class >> stageByPackageAndTag` is re-keyed, and no entry changed stage. A tag name
travels with its classes, so `Path`, `Paint` and `Display list` are a tag of the canvas and a tag
of its renderer both, and each half keeps the stage the one tag had.
`VGFrameProfileTest >> testEveryPackageAndTagOfThisProjectHasAStageAndNoOthers` holds the keys
against the organiser and `testTheStageOfTheRasteriserIsTheCoverageStage` reads one stage off
`VGRasteriser`; both are green.

Units 6.3 to 6.5 are one commit, `54bcbbc`, because the baseline and the table hold each other:
the table's meta tests read the baseline, so neither half is green on its own.

Two packages of the image are dirty for reasons outside this work, and neither may be committed
from this image:

- `VectorGraphics-Vulkan`, because PharoVulkan is not loaded here. The extension methods on
  `PVComputeKernel`, `VkBuffer`, `VkCommandBuffer`, `VkAccess2` and `VkPipelineStage2` have no
  target class in the image, so Iceberg reads them as deletions. The two comments this unit
  rewrote in `VGDisplayListEntry` are in that package, and wait for an image that holds
  PharoVulkan.
- `VectorGraphics-Tests`, where three methods of `VectorGraphicsDocumentationTest` differ from
  disk — `trimBoth` in the image where disk has `trimmed`, and two more — uncommitted work from
  an earlier session that predates this plan.

### 6.6 The six mirror packages — done

The six packages hold what section 3 names: `VectorGraphics-Canvas-Tests` 16 classes,
`VectorGraphics-Canvas-Raster-Tests` 9, `VectorGraphics-Canvas-Fonts-Tests` 1,
`VectorGraphics-Canvas-Examples` 16, `VectorGraphics-Canvas-Raster-Examples` 7 and
`VectorGraphics-Canvas-Fonts-Examples` 2. Every class keeps its name and its tag, so no sender
changed and no source moved. The shared backend stubs — `VGBackendFrameFixture`,
`VGBrokenBackendStub`, `VGFailingDrainBackendStub`, `VGCountingMaskStub` — went to
`VectorGraphics-Canvas-Raster-Tests`, the package of their subject, and the canvas tests that build
a frame name that package.

The baseline declares the six and gains the groups `canvas-examples`, `canvas-tests`,
`canvas-raster-examples`, `canvas-raster-tests`, `canvas-fonts-examples` and `canvas-fonts-tests`
in place of `cairo-examples` and `cairo-tests`. `examples` and `tests` are the union of ten layer
groups now, and `dev` names the three canvas test groups one by one. The baseline holds 34 packages
and 37 groups, and the name `Cairo` occurs in neither.

Four edges are not what a scan of the code alone would state:

- `VectorGraphics-Canvas-Examples -> VectorGraphics-Canvas-Tests`, the cycle the mirrors make,
  which `edgesTheBaselineCannotDeclare` names. It named the renderer's edge back to the canvas
  beside it until section 8 removed that edge, and it is the only entry left.
- `VectorGraphics-Canvas-Raster -> VectorGraphics-Canvas`, the deferred review point of section 8,
  removed there.
- `VectorGraphics-Bloc-Tests -> VectorGraphics-Canvas-Tests` and
  `VectorGraphics-Bloc-FontEngine-Tests -> VectorGraphics-Canvas-Tests`, declared in the baseline
  alone: `VGBlocExamplesTest` and `VGFontEngineExamplesTest` both subclass `VGCairoExamplesTest`,
  and a superclass is named by no method, so the scan cannot see it.

`VGArchitectureTest` gains a dependency row and a scan test per new package, and its two group tests
hold the exact package set of each of the six groups. `VGFrameProfile class >>
stageByPackageAndTag` holds three entries where it held one, 55 keys and no `Cairo`, with no entry
changing stage. `VGCairoSkeletonTest >> packagesUnderTest` reads the nine packages of the canvas
where it read five.

The suites: `VGArchitectureTest` 54 of 60, `VGFrameProfileTest` 15 of 16, `VGCairoSkeletonTest` 5
of 5, `VGConformanceTest` 15 of 15, `VGBackendSelectionTest` 13 of 13. The six reds are the ones
this image has carried since PharoVulkan left it — two packages of the Vulkan layer absent, and
`MetacelloRepositoriesSpec >> #map` missing under the MuTalk pin test. Critics on the four changed
classes report what they reported before: the method count of `VGArchitectureTest`, the complexity
of `declareBackendPackagesOn:` and the `forceLayout` send in `VGFrameProfile >> newScene`.

**The crash, and what it cost.** Running the examples suite with this unit uncommitted killed the
image, which is exactly what the rule against it says. Epicea could not give the work back: the
dead session's `.ombu` stopped hours before the work was written, so `applyCodeChange` had nothing
to replay. The session transcript did — it holds every method source and every script verbatim —
and the recovery was: reload all 28 project packages from the Tonel checkout at `54bcbbc` with a
forked Metacello `tonel://` load, register the clone in Iceberg, then replay the unit from the
transcript and check it against the numbers above.

Three commits, because Iceberg cannot see a package the image does not hold: `8d700c1` adds the six
packages, the baseline and the tables; `b2646e7` removes the classes of the two Cairo mirror
packages, which needed each of them recreated empty in the organiser first so that the diff had an
empty snapshot to compare against; `1debf6f` removes the two `package.st` that outlived them. `src`
now holds 35 directories, one per package of the image.

`VGCairoExamplesTest` is green, 6 of 6, run alone against the committed work. It renders through
every example, which takes minutes and holds the image while it runs: forked above the user
interface priority it looks frozen, and that is what the crash was mistaken for.

### 6.7 The written record — done

Everything on the list is written. Two commits: `f667976` for the image, `56445bd` for the
documents of the repository.

**The package comments.** A Pharo package comment lives on a `PackageManifest` subclass, so the
three packages gained `ManifestVectorGraphicsCanvas`, `ManifestVectorGraphicsCanvasRaster` and
`ManifestVectorGraphicsCanvasFonts`, each in a `Manifest` tag of its own package. That raises the
class counts of the trio to 47, 14 and 13. Each comment says what the package holds, what it may
not do, the tags it is organised in, and the entry points a reader starts from:
`VGCairoImageSurface class >> extent:format:`, `VGCairoContext class >> newFor:` and
`VGBackend >> drainInto:` for the canvas; `VGSoftwareBackend >> drainInto:` and
`VGRasteriser class >> segments:fillRule:clip:` for the renderer;
`VGFontFace class >> newForFile:` and
`VGScaledFont class >> fontFace:fontMatrix:userToDeviceMatrix:options:` for the fonts. The renderer's
comment also names the four references it still makes into the canvas package and points at
section 8, so the deferred point is not lost. The front-page comment of `VectorGraphics` was
rewritten around the trio.

Writing a comment creates a tag, and `VGFrameProfile class >> stageByPackageAndTag` must hold an
entry for every package and tag of the project — `VGFrameProfileTest` says so. Three
`#notInTheFrame` keys were added, one per new `Manifest` tag, which takes that table to 58 keys.

**The documents.** `README.md` now carries three package rows and nine group rows in place of the
Cairo ones, and the paragraph after the load snippet counts what `canvas-tests` really brings:
eleven packages, measured with `VGArchitectureTest class >> packagesLoadedByGroupNamed:`, and
neither the scan-line engine nor the text glue. `doc/USAGE.md` names the canvas in its heading and
its group table. `CLAUDE.md` had been stale since the first split — a ten-package table and a
five-row test table — so both tables were rewritten against the image, and its architecture section
became "The canvas", saying why the class names keep the `VGCairo` prefix. `doc/ARCHITECTURE.md`
describes the rasteriser's four packages only, and now says so: the canvas is described by its
package comments and by this plan. `doc/ARCHITECTURE-PLAN.md` states a live rule about
`VectorGraphics-Canvas-Tests`, so the name in it was changed; `doc/PACKAGE-SPLIT-PLAN.md` gets a
pointer line instead, since its own names are the history of the first split.
`VECTORCANVAS-PLAN.md` has the package table and the rules of its section 4 rewritten in the trio's
names, and `FONT-PLAN.md` a note at the head of its section 4 saying that everything that plan put
in the Cairo package — `VGFontFace`, `VGScaledFont`, `VGGlyphMask`, `VGTextExtents` — is now in
`VectorGraphics-Canvas-Fonts`. `doc/P7-LOAD-PROOF.md`, `doc/REVIEW-PLAN.md` and `doc/DEFECTS.md`
were left alone: they record what was true on the day they were written.

**Verified.** Critics clean on the three manifests; `VGFrameProfile` carries only the pre-existing
`ReBlocDoNotSendForceLayoutRule` critique. The four documentation gates are 15 of 15 each,
`VGFrameProfileTest` 15 of 16 and `VGArchitectureTest` 54 of 60 — the same six reds as before this
unit, all of them from `VectorGraphics-Vulkan-Tests` and `-Vulkan-Examples` being absent from this
image, plus the MuTalk pin test that cannot read `MetacelloRepositoriesSpec`.

No documentation gate was added for the canvas trio. `documentedPackages` is derived from the walk
of concrete `VectorGraphicsDocumentationTest` subclasses, so a gate for the canvas would hold it to
`doc/ARCHITECTURE.md`, which does not describe it. That belongs with a canvas chapter, not here.

### 6.8 The load proof

`doc/CANVAS-LOAD-PROOF.md`, commit `914bd88`, in the shape of `doc/P7-LOAD-PROOF.md`: five steps,
each in its own fresh image, with the packages to expect, the names a load may leave undeclared, and
one snippet per step that works with nothing else in the image. Every expression was run in the
development image first, so each is known to work when its packages are present, and the expected
answers are what it gave there.

| Step | Group | Packages | The claim |
|---|---|---|---|
| 1 | `canvas-raster` | 1 | the renderer needs no canvas API, no font code, no engine, no library and no window |
| 2 | `canvas-fonts` | 3 | a font can be scaled and a glyph outlined with no renderer in the image |
| 3 | `canvas` | 5 | the canvas draws without the scan-line engine and without the text glue |
| 4 | `default` | 8 | what an existing user loads is unchanged in content by the split |
| 5 | the three test groups | 15 | 274 + 84 + 47 = 405 tests, and what skips without a checkout or Alexandrie |

The document also offers `tonel:///home/renaud/devzone/iceberg/rvillemeur/VectorGraphics/src` beside
the GitHub repository, so the proof is runnable the minute a unit is committed and does not wait on
a push — `main` is ahead of `origin` while this plan runs.

Two findings are recorded in the document before it is run, both measured in the development image.
`canvas-raster` alone must leave exactly `VGCairoState` and `VGPaint` undeclared: those are the four
references of section 8, and the step turns that deferred point into something a load shows.
`VGConformanceTest` renders its reference through `AeCairoImageSurface` in three tests with no
availability guard, where `VGAlexandrieCorpusTest` and the four other Cairo comparison classes all
guard themselves, so those three will error rather than skip in an image with no Alexandrie. The
fix is a decision — guard them with `VGAlexandrieCorpus isAvailable`, or declare Alexandrie as a
requirement of the canvas test packages — so the document says to record the result before changing
anything.

**Run, by the user.** A fresh image was built on 2026-11-20 and the project loaded into it from
the checkout: every group came in and the suites behind them pass, which is the claim of the five
steps. The agent could not run them itself — downloading a blank image was refused — so the proof
stands on that load rather than on five separate images, and the two findings recorded in advance
stay as the document states them. The three unguarded `VGConformanceTest` tests are still a
decision to take.

## 7. What this does not do

- No class is renamed and no production behaviour changes. Units 6.1 to 6.8 move no method
  between classes either; section 8 moves three, which is the one place this plan touches code
  rather than package membership.
- `VectorGraphics-Engine`, `VectorGraphics-Paths`, `VectorGraphics-Text` and
  `VectorGraphics-TrueType` are untouched: this plan is about one package, not about the rasteriser
  stack that was split in the review of 2026-11.
- No package is created for a hypothetical reader. The device-independent model stays with the
  canvas API, although a fourth package was considered, because nothing today reads the model
  without the API that records into it.

## 8. Deferred review point — done

The four references from `VectorGraphics-Canvas-Raster` to `VectorGraphics-Canvas` were a cycle
between two packages, declared in the table and left out of the baseline while the split was
proven. They are gone, and `VectorGraphics-Canvas-Raster` now references no package but itself.

What each one really wanted, measured before anything moved:

| Reference | What it wanted |
|---|---|
| `VGRasteriser class >> segments:fillRule:clip:` | `VGCairoState antialiasNames first`, which is the mode a caller who names none gets |
| `VGSegments class >> coordinates:fillRule:` | the same |
| `VGStroker class >> path:matrix:lineWidth:` | a state object. Its only senders were two methods of `VGStrokerExamples`; no production sender existed |
| `VGCoonsPatch class >> channelsOf:` | `VGPaint rgbaOf:`, the quantisation of a Pharo `Color` into four floats |

**Red first.** The edge was removed from `VGArchitectureTest class >> allowedDependencies` and the
pair dropped from `edgesTheBaselineCannotDeclare`, which left
`testCanvasRasterStaysInsideItsAllowedDependencies` failing on exactly those four references. The
baseline needed no change: it never declared the edge.

**Three moves, each with its own test first.**

`VGSegments class >> defaultAntialias` answers `#default`, and the two convenience constructors
send it instead of reading the canvas's list. The name lives with the renderer because the
renderer is what acts on it, and a renderer loaded alone must still know what a caller who named no
mode meant. `VGRasteriserTest >>
testTheDefaultAntialiasOfTheRendererIsTheModeACanvasStateStartsIn` is the one place the two sides
meet: it holds the constant against `VGCairoState antialiasNames first`, so the renderer's default
cannot drift from the state's own first mode.

`VGStroker class >> path:matrix:lineWidth:` is deleted. Its two example senders build the
`VGCairoState` themselves, which `VectorGraphics-Canvas-Raster-Examples` may do — it is allowed to
depend on the canvas. The stroker still reads `matrix`, `lineWidth`, `strokeStyle`, `tolerance` and
`antialias` off whatever state it is given, which is a protocol and not a package edge, and the
class comment now says so.

`Color >> asVGChannels`, an extension method owned by `VectorGraphics-Canvas-Raster`, carries the
conversion and the comment about where quantisation stops. `VGPaint class >> rgbaOf:` keeps its name
and delegates to it, so the canvas's public API is unchanged and one implementation is left.
`VGCoonsPatch class >> channelsOf:` sends it in its non-collection branch. `VGMeshTest >>
testAColourGivesTheSameFourChannelsToAPaintAndToAPatch` holds the paint, the patch and the Color to
the same four floats. An extension on a base class is the mechanism this project allows for a new
method, and the comment names the target class and the reason, as the rules require.

**Verified.** The canvas suites were run one test class per call, because a single call running
twenty of them froze the image for minutes: `VGRasteriserTest` 16, `VGMeshTest` 10, `VGPaintTest` 23,
`VGCairoStrokeTest` 29, `VGBlurTest` 10, `VGCairoClipTest` 17, `VGBackendSelectionTest` 13,
`VGCairoPathTest` 13, `VGCairoOperatorTest` 12, `VGCairoMatrixTest` 16, `VGCairoContextStateTest` 22,
`VGCairoSurfaceTest` 29, `VGCairoExportSurfaceTest` 14 and `VGCairoInventoryTest` 6, all passing,
the two new tests among them. `VGArchitectureTest >>
testCanvasRasterStaysInsideItsAllowedDependencies` passes with the entry at `#()`, and a literal
scan of `VectorGraphics-Canvas-Raster` answers no reference out of the package at all.

`run_critics` is clean on `VGRasteriser`, `VGStroker`, `VGCoonsPatch` and `VGPaint`. `VGSegments`
keeps the one `ReExcessiveArgumentsRule` on `drawOn:paint:clip:operator:into:` it had before this
unit, and `Color` raises nothing for `asVGChannels`: every rule that fires there names a method of
the base image.

Two reds in the image this was run in are the load set and not the work. The image holds the
`canvas-tests` group only, so `VGCairoSkeletonTest >> testNoMethodReferencesAnUndeclaredVariable`
and twenty-four dependency tests of `VGArchitectureTest` fail with `key
'VectorGraphics-…' not found in PackageOrganizer`, naming packages that are not loaded;
`testTheMuTalkProjectIsPinnedToATagAndNotToMaster` fails with `MessageNotUnderstood:
MetacelloRepositoriesSpec >> #map`, which predates the split. `VGCairoDrawingTest` and
`VGCairoExamplesTest` were not run: they open windows, and the run that reached them took the image
down for minutes. They belong to the run the global rules reserve for a committed image with
nothing else touching it.
