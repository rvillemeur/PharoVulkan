# VECTORCANVAS-PLAN — a GPU-capable replacement for the Alexandrie Cairo layer

## 1. Goal and target

Make `VectorGraphics` a drop-in replacement for the Cairo layer that Alexandrie wraps, so that Bloc
renders through it with the same calling API and the same pixels, and so that it can serve as a
failover when `libcairo` is absent or broken.

The target API is `AeCairoContext`, together with `AeCairoSurface` and `AeCairoPattern`.
It is not `AeCanvas`.

`AeCanvas` is Bloc's figure drawer.
It knows about backgrounds, borders, outskirts and the eleven ways those combine, and it exists to
draw a `BlElement` and nothing else.
It is a client of the paint API, not the paint API itself.
Everything it does, it does by sending messages to its `cairoContext`.

So `AeCanvas` is kept, not replaced.
A `VGCanvas` subclass overrides the handful of methods that name a Cairo class, and the rest of
`AeCanvas` runs unchanged on top of our context.
That keeps the one hundred and thirty-five `Bloc-Alexandrie` extension methods, `BARenderer` and the
figure logic as they are, and it reduces the project to the thing that actually has to be written:
a Cairo-equivalent rasteriser.

The work splits in two phases.

Phase 1 is pure Pharo, no Vulkan and no external library.
It delivers Cairo parity for the selectors Bloc and `AeCanvas` really send, and it passes a
conformance corpus rendered against real Cairo.

Phase 2 adds a Vulkan backend behind the same object boundary.
It is an optimisation, never a dependency.
Every phase 2 unit must leave the phase 1 software path working and selectable.

Vulkan cannot be the failover, because acquiring a working device is more fragile than acquiring a
Cairo surface: a missing or broken ICD, a Wayland or X11 mismatch, MoltenVK on macOS, a stale
`vulkan-1.dll` on Windows.
The software path is the failover; the GPU path is the fast path.

## 2. The measured calling surface

All counts below were measured in a live image with Bloc and Alexandrie loaded, by intersecting the
messages sent in the `Bloc*` code packages and in `Alexandrie-Canvas` with the selectors each Cairo
class and its subclasses define.

| Class and subclasses | Selectors defined | Sent by Bloc | Sent by `AeCanvas` | Union to implement |
|---|---|---|---|---|
| `AeCairoContext` | 206 | 44 | 45 | 74 |
| `AeCairoSurface` | 104 | 24 | 17 | 27 |
| `AeCairoPattern` | 79 | 17 | 7 | 20 |

The three unions overlap and a few selectors are declared on both the instance side and the class
side, so the real scope is one hundred and thirteen entries over one hundred and three distinct
selectors, not three hundred and eighty-nine.
`VGCairoInventory` holds that list, with the false positives named and explained, and
`VGCairoInventoryTest` fails if the live image disagrees with it.
Most of the context's share is path building, which is recording, not rasterising.

`AeCanvas` itself defines ninety-seven selectors, fifteen of them `drawFigure*` variants.
None of them need reimplementing.

### 2.1 The creation seams

Only sixteen methods in `Alexandrie-Canvas` name a Cairo class directly, and `VGCanvas` has to
override five of them:

- `AeCanvas class >> extent:` — `^ self newFor: (AeCairoImageSurface extent: aPoint)`
- `AeCanvas >> newCairoSurfaceExtent:` — builds the surface and sets its device scale
- `AeCanvas >> setSourceLinearPatternStops:start:end:`
- `AeCanvas >> setSourceRadialPatternStops:innerCenter:innerRadius:outerCenter:outerRadius:`
- `AeCanvas >> newSurfaceWithGaussianShadow:width:canvasDo:` — also names the blur filter

The remaining eleven name only enumeration and record classes: `AeCairoStrokeCap`,
`AeCairoStrokeJoin`, `AeCairoAntialias`, `AeCairoFontOptions`, `AeCairoHintMetrics`,
`AeCairoHintStyle`, `AeCairoTextExtents`, `AeCairoTextMetrics`.
Those carry integers and plain fields, so our context accepts them as they are.
No subclass and no reimplementation is needed for them.

`AeCanvas >> prepareForSurface:` already takes a surface from outside, which is the seam the host
window path uses.

### 2.2 How the host hands over pixels

This is the requirement that shapes the software backend, and it was not visible from the `AeCanvas`
API alone:

```
BARenderer >> renderWith: aBlock pixels: address stride: stride
              physicalRectangle: physicalRectangle logicalRectangle: logicalRectangle
	aCairoSurface := AeCairoImageSurface
		unownedNewForData: address format: AeCairoSurfaceFormat argb32
		width: physicalRectangle width height: physicalRectangle height stride: stride.
	aCairoSurface
		deviceOffset: physicalRectangle origin negated;
		deviceScaleX: scaleFactor y: scaleFactor.
	aeCanvas prepareForSurface: aCairoSurface.
	…
```

The host window gives a raw pixel address and a stride, and the renderer draws straight into it, in
premultiplied ARGB32, with a device offset and a device scale applied.

The current engine writes into an opaque thirty-two-bit Pharo `Form`, so one of two things must
happen, and unit 1.1 decides which by measuring both:

1. the engine writes into external memory directly, through `byteAt:put:` on the address, or
2. the engine writes into an internal buffer and the frame ends with one bulk copy into the host
   address.

Option 2 is the default, because writing into external memory per pixel from Pharo is both slower
per access and the known way to kill this image.
Option 1 is only worth it if the bulk copy shows up in the profile.

Unit 1.1 measured both, filling a 1024 by 768 ARGB32 surface five times in this image:

| What runs | Total, five frames | Per frame |
|---|---|---|
| Per-pixel writes straight into external memory | 130 ms | 26 ms |
| Per-pixel writes into my own `ByteArray` | 135 ms | 27 ms |
| The same, plus one `LibC memCopy:to:size:` of the three megabytes | 134 ms | 26.8 ms |
| That `memCopy:to:size:` alone, twenty times | 7 ms | 0.35 ms |

The handover is not the cost: the bulk copy is 0.35 ms, around one per cent of a frame, while the
per-pixel loop is 26 ms, or 33 nanoseconds per pixel.
Option 2 therefore stands, and the profiling unit 1.11 has to attack the loop, not the copy.

### 2.3 Text

Text is a context-level API in Cairo, and `AeCanvas` uses it through five selectors:
`scaledFont:`, `appendGlyphsPath:`, `showGlyphs:`, `getGlyphExtentsOf:size:into:` and `fontExtents`.

Those take glyph indices, not characters.
Shaping — the map from a string to positioned glyph indices — is Harfbuzz's job, and Harfbuzz needs
no Cairo, so `Alexandrie-Harfbuzz` can stay loaded and unchanged.
Rasterisation is FreeType's job today, and that is the part we replace: the `TTFontReader` glyph
model is indexed by glyph id before the UTF-8 map is built, which is exactly what
`appendGlyphsPath:` needs.

A `VGScaledFont` therefore wraps a `TTFontDescription` plus a size, and answers metrics and glyph
paths from our own contour data.
If Harfbuzz is absent too, fall back to the font's own `cmap` and kern pairs, which the reader
already parses, and accept that complex scripts will not shape.

### 2.4 The gap list

What `VectorCanvas` does not do today, each item a phase 1 unit of work:

- `geometryTransformation:` is a no-op, because the Cuis `AffineTransformation` it wants is absent.
- The target must be an opaque thirty-two-bit `Form`: there is no premultiplied ARGB32 target, no
  external-memory target, no device offset and no device scale.
- There is no group, no mask and no operator other than source-over, so `paintGroupWith:`,
  `maskGroupWith:`, `maskSurface:x:y:` and `setOperatorClear` have nothing behind them.
- Clipping is rectangular only, through `morphIds`; there is no path clip, no clip stack and no
  `clipPreservingPath`.
- Winding is nonzero only; `useFillRuleEvenOdd` has nothing behind it.
- Caps and joins are round only, implicit in the disc splat; there are no butt or square caps, no
  miter or bevel joins, no miter limit and no dash pattern.
- There is no pattern of any kind, so no gradient, no surface pattern and no image paint.
- There is no blur, and `AeCanvas` asks for one on every shadow.
- There is no surface lifecycle: no `flush`, no `finish`, no `status`, no `asForm` of a
  sub-rectangle, no `writePngTo:`.
- Nothing is wired into a display loop, so nothing renders a real Bloc space yet.

## 3. The three seam rules

These are frozen.
They exist so that phase 2 can be added, and removed, without touching phase 1 code.

### Rule 1 — a retained display list per frame

`VGCairoContext` never rasterises as it records.
It appends to a display list, and the list is drained once per frame by whichever backend is
selected.

A display list is required by both phases, for different reasons.
The software backend wants it so that the dirty rectangle is known before the first pixel is
written.
The GPU backend wants it because a draw call per figure is the one thing that makes a GPU slower
than a CPU.

The list is also what makes failover cheap: when the GPU backend raises, the same list is replayed
on the software backend and the frame still appears.

Cairo's own API is stateful and immediate, so the context must keep the Cairo state machine —
source, matrix, fill rule, stroke parameters, clip stack — and record state as part of each entry.
`fillPreservingPath` and `strokePreservingPath` mean the path outlives the operation, so a path is
an immutable value in the list, not a mutable buffer the next entry overwrites.

### Rule 2 — a frozen paint ABI

A paint is a tag, a block of thirty-two-bit floats holding its coefficients, and, for a gradient, an
optional two-hundred-and-fifty-six-entry stop lookup table.

Nothing above the backend boundary knows whether a paint will be evaluated by a Pharo method or by a
SPIR-V function.
Nothing below it knows what a `BlPaint` or an `AeCairoPattern` is.

The ABI is defined once, in unit 1.5, and tested by a unit test that reads the bytes.
A phase 2 shader and a phase 1 Pharo method read the same block.

### Rule 3 — no Vulkan type above the backend boundary

The backend answers three messages and no more:

- `fillSegments: aSegmentArray paint: aPaint clip: aClip operator: anOperator`
- `blitSurface: aSurface at: aPoint paint: aPaint`
- `drainInto: aTarget`

`PharoVulkan` classes appear only in the Vulkan backend's own package.
A `VGBackendFailure` raised anywhere below the boundary is caught at the boundary and answered by
replaying the list on the software backend.

## 4. Package layout

Phase 1 adds three packages and phase 2 adds two.

| Package | Phase | Contents |
|---|---|---|
| `VectorGraphics-Cairo` | 1 | `VGCairoContext`, `VGCairoImageSurface`, the pattern classes, `VGScaledFont`, the display list, the paint ABI, `VGBackend` and the software backend |
| `VectorGraphics-Cairo-Tests` | 1 | The conformance harness, the corpus and the inventory tests |
| `VectorGraphics-Cairo-Examples` | 1 | One `<Subject>Examples` class per subject, holding the `<sampleInstance>` examples |
| `VectorGraphics-Cairo-Reference` | 1 | The reference generator, the one place allowed to replay a corpus case through Alexandrie and write its PNG |
| `VectorGraphics-Bloc` | 1 | `VGCanvas` (the `AeCanvas` subclass) and `VGRenderer` (the `BARenderer` subclass), nothing else |
| `VectorGraphics-Vulkan` | 2 | The Vulkan backend, the tile binner, the SPIR-V paint and coverage shaders |
| `VectorGraphics-Vulkan-Tests` | 2 | The GPU-versus-software parity tests |

`VectorGraphics-Cairo` may depend on `VectorGraphics`; the reverse is forbidden.
`VectorGraphics-Cairo` must not name a single `Ae*` class, so that it stands alone and so that the
corpus can be run with Alexandrie absent.
`VectorGraphics-Bloc` and `VectorGraphics-Cairo-Reference` are the only packages allowed to name
`Ae*` classes, and both are deliberately thin for that reason: the first wires Bloc to the engine,
the second exists only so that the reference renders can be produced in an image that has Cairo,
and neither is needed to run the corpus.
`VectorGraphics-Vulkan` may depend on `VectorGraphics-Cairo` and on `PharoVulkan-Core`,
`PharoVulkan-Compute` and `PharoVulkan-SPIRV`; nothing may depend on it.

State those edges in a `VGArchitectureTest class >> allowedDependencies` table, the same way
`PVArchitectureTest` does in `PharoVulkan`, and check the table against both the code and the
baseline.

Subclassing `AeCanvas` and `BARenderer` reaches their instance variables, which are private and can
be renamed upstream.
That is the accepted cost of not duplicating the figure logic, and it is paid once: pin the
Alexandrie and Bloc versions in `BaselineOfVectorGraphics`, and let `VGCanvas` have a test that
asserts the five overridden selectors still exist in `AeCanvas`.
That test is what turns an upstream rename into a red test instead of a silent wrong render.

## 5. Which images need what

| Image | Bloc and Alexandrie loaded | `libcairo` present | Used for |
|---|---|---|---|
| Engine image | no | no | Units 1.1 to 1.9, and all of phase 2 |
| Parity image | yes | yes | Unit 1.0 corpus generation, and units 1.10 to 1.11 |
| Failover image | yes | no | The acceptance test for the whole project |

The parity image needs Cairo working, for one reason only: the reference renders.
A conformance corpus is worth nothing unless each case carries the exact pixels Cairo produces for
it.
Generate the corpus once, commit the reference images as PNG files next to the corpus descriptions,
and the engine units then run with nothing loaded.

The failover image is the interesting one, and it is cheaper than the earlier plan assumed.
Alexandrie's classes load without `libcairo`, because the library is only touched when an FFI call
runs.
So the failover image is a normal Bloc image with the library absent or renamed, using `VGRenderer`
instead of `BARenderer`.
Nothing has to be rewritten to be Alexandrie-free; only `VectorGraphics-Cairo` has to be, and rule
four of the package table says it is.

Bloc being loaded in the working image is a help, not a problem: the counts in section 2 came from
it, and every parity test can diff against a live Cairo render instead of against a committed PNG.

## 6. Phase 1 — pure Pharo, Cairo parity

Each unit is one commit.
Each unit follows the project cycle: failing test, smallest code that passes, refactor, class-side
`<sampleInstance>` example in a `-Examples` package, custom inspector view, clean critics.

### 1.0 — the context skeleton and the conformance harness

Create `VGCairoContext`, `VGCairoImageSurface` and the pattern classes, with every one of the one
hundred and three measured selectors present, each either implemented or raising
`VGNotYetImplemented` naming the unit that will implement it.

Create the harness: one corpus case per Cairo primitive, each holding a script that drives the
context and the reference image Cairo produced for it.
Add a test that reads `AeCairoContext`, `AeCairoSurface` and `AeCairoPattern` in the live image, and
fails if they declare a selector Bloc or `AeCanvas` sends that our classes do not answer.
That test is the inventory, so the inventory cannot go stale.

Gate: the harness runs, every case fails with a named unimplemented selector rather than an error,
and the inventory test passes.

**Done.** Ten classes in `VectorGraphics-Cairo`: `VGCairoObject` and its three subclasses
`VGCairoContext`, `VGCairoImageSurface` and `VGCairoPattern`, the four pattern subclasses,
`VGCairoStatus` and `VGNotYetImplemented`, plus `VGCairoInventory`, which holds the frozen
measurement and the unit table.
One hundred skeleton methods, twelve of them class-side, each naming the unit that owes it; the five
unit 1.0 selectors — `new`, `newFor:`, `status`, `autoRelease` and `externallyFree` — are real.

The harness is `VGConformanceCase` and `VGConformanceCorpus`: twenty-nine cases over eight group
methods, filed under units 1.1 to 1.8, each answering, through `blockingFailure`, the first selector
it stops on.
`VGConformanceCase >> newTarget` builds its surface reflectively until unit 1.1 implements
`extent:`, so that a case reports the selector its own drawing asks for.
Reference PNGs are not written yet: they belong to `VectorGraphics-Cairo-Reference`, and the first
unit that renders anything is 1.1.

Eighteen tests pass over four test classes: `VGCairoInventoryTest` (six, three of which skip when
Alexandrie is absent), `VGCairoSkeletonTest` (four), `VGConformanceTest` (five) and
`VGCairoExamplesTest` (three).
Three examples classes in `VectorGraphics-Cairo-Examples` hold five `<sampleInstance>` examples, and
four inspector views read the compiled methods rather than a kept list: `Skeletons` on both sides of
`VGCairoObject`, `Units` on `VGCairoInventory` and `Cases` on `VGConformanceCorpus`.
A view and its gate are two methods in Pharo 13, `inspectorX:` carrying the pragma and
`inspectorXContext:` sending `active:`; one method doing both is never gated.

### 1.1 — the ARGB32 target

Premultiplied ARGB32, device offset, device scale, `flush`, `finish`, `status`, `asForm`,
`colorAt:`, `writePngTo:`, and `unownedNewForData:format:width:height:stride:`.
Measure the two pixel-delivery options from section 2.2 and record the numbers here.

Gate: a corpus case that paints translucent over translucent matches the reference to within one
unit per channel, and a render into an externally supplied address with a stride larger than the
width lands in the right bytes.

**Done.** `VGCairoImageSurface` holds a format, an extent, a stride, a buffer, a device offset, a
device scale, a status and a finished flag, and all twenty-three selectors the unit owes are real;
`VGCairoInventory progressReport` answers 23 of 23.

Pixels go through one path, because both a `ByteArray` and an `ExternalAddress` answer
`uint32AtOffset:` and `uint32AtOffset:put:`.
A surface of my own allocates a `ByteArray`; `unownedNewForData:format:width:height:stride:` keeps
whatever buffer the caller passed, which is how the host window path of section 2.2 is served, and
a stride too small for one row sets the status to `VGCairoStatus invalidStride` rather than
signalling, as Cairo does.
Every write runs row by row and only width pixels wide, so the padding bytes between rows stay as
the host left them.

`VGCairoSurfaceFormat` is new, and it owns the pixel arithmetic: `strideForWidth:` (four-byte
alignment, so an A8 row of seven pixels is eight bytes), `pixelForColor:` and `colorForPixel:`
(premultiply and divide back out, with `Color transparent` for a zero alpha), and
`blendPixel:over:` (source-over, dividing by 255 with rounding).
`normalize:` accepts one of ours, an Alexandrie enum value or a plain integer, so
`VectorGraphics-Cairo` still names no `Ae*` class while a future `VGCanvas` can pass Alexandrie
constants straight through.

Gate, first half: `blendPixel:over:` is compared against a live Cairo render of the same two
translucent colours, painted one over the other, and agrees exactly — `16rBF40007F` — so the
tolerance of one unit per channel is not even needed.
The reference is rendered in the test rather than committed as a PNG, because Alexandrie and
libcairo are both in this image; `VectorGraphics-Cairo-Reference` is still not needed.
The painting verb that would let a corpus case do this belongs to unit 1.5, so the gate is met at
the surface, through `fillPixel:` and `blendPixel:`.
Gate, second half: two tests render into a caller-supplied buffer whose stride is four bytes wider
than its rows, one checking that every pixel lands at the right offset and one checking that all
eight padding bytes still hold what the host wrote.

Twenty-two tests in `VGCairoSurfaceTest`, and forty in the package.
`VGConformanceCase >> newTarget` now builds a real surface through `extent:`, and the corpus cases
that need a second surface do too.
`VGCairoImageSurfaceExamples` holds three `<sampleInstance>` examples — the translucent target, a
host buffer with a padded stride, and an A8 mask — and the surface has two inspector views,
`Picture` (a fresh `asForm`, so looking cannot mutate) and `Layout` (the stride and the padding read
back out of the object).

### 1.2 — the matrix and the state stack

`matrix`, `matrix:`, `setIdentityMatrix`, `translateBy:`, `scaleBy:`, `rotateByRadians:`,
`rotateByRadians:center:`, `transformWith:`, `restoreStateAfter:`, `currentPointInUserSpace`.
Transform at record time, not at splat time, so the engine stays untouched.

Gate: a rotated and sheared rounded rectangle matches the reference; a singular matrix draws nothing
rather than raising; `restoreStateAfter:` restores source, matrix, fill rule and clip together.

**Done.** Ten selectors, all real: `VGCairoInventory progressReport` answers 10 of 10 for this unit.
`currentPointInUserSpace` moved to unit 1.3, because a current point comes from a path and there is
no path until the shape verbs arrive.

`VGCairoMatrix` is new and holds Cairo's six numbers, `sx shy shx sy x y`, in Cairo's own field
order, so `newFrom:` reads an `AeCairoMatrix` through the same six accessors.
It follows Cairo's composition order rather than the obvious one: `translateBy:`, `scaleBy:` and
`rotateByRadians:` pre-multiply, so the new transformation acts first and what the matrix already
holds acts after it, which is what `cairo_matrix_translate` does.
`invert` answers a `VGCairoStatus` — `invalidMatrix`, code 5, the same code Cairo answers — and
`inverted` copies, inverts and sends `ensureIsSuccess`, which is how Alexandrie splits the two.
A determinant of zero, a NaN or an infinity all mean not invertible.

`VGCairoState` holds the four pieces of graphics state together: the matrix, the source, the fill
rule and the clip.
`postCopy` copies the matrix, because a context transforms its matrix in place and a saved state
must not move with it.
`VGCairoContext` keeps one current state and a stack of saved ones; `restoreStateAfter:` saves,
runs the block under `ensure:` and restores, so a painting that raises cannot leave the next frame
transformed.
The state the block worked on is not the object that comes back, which a test pins.

A singular matrix does not signal.
Measured on a live Cairo context: `matrix:` with a singular matrix leaves the context in
`CAIRO_STATUS_INVALID_MATRIX` and a later `paint` writes no pixel at all.
`VGCairoContext` matches that: `matrix:` latches the status, `isInError` answers true afterwards,
and every transformation and the two clearing verbs return without touching anything.
Two tests prove the second half of the gate, one against our own surface and one against a live
Cairo surface whose pixels stay zero.

The first half of the gate is met through the matrix rather than through a shape, because the shape
verbs belong to unit 1.3: the rotated and sheared transformation is built on a `VGCairoMatrix` and
on an `AeCairoMatrix` by the same calls, and the six fields, the mapped corners of the unit square
and the inverse all agree with Cairo to within 1.0e-12.
The three transform cases in `VGConformanceCorpus` moved to unit 1.3 with the shape verbs they need,
and unit 1.2 joins units 1.0 and 1.9 in `VGConformanceTest >> unitsWithoutAPicture`, because a
transformation changes nothing visible on its own.

Thirty tests, fifteen in `VGCairoMatrixTest` and fifteen in `VGCairoContextStateTest`, four of them
comparing against live Alexandrie; seventy-two in the package.
`VGCairoMatrixExamples` holds the rotated and sheared matrix and the singular one;
`VGCairoContextExamples` gained a transformed context with a state pushed underneath it.
Two inspector views: `Mapping` on the matrix, which sends `value:` and `inverted` rather than
restating the arithmetic, and `State stack` on the context, which reads the stack itself so it shows
what `restoreState` will really bring back.

### The Alexandrie experiment corpus

Imported 19 October 2026, between units 1.2 and 1.3, because the image already held a far larger
body of Cairo drawings than this plan was ever going to write by hand: `AlexandrieCairoExperiment`
carries eighty-three class-side `<sampleInstance>` experiments, each a complete script against the
Cairo API.

Nothing is copied. `VGAlexandrieCorpus` derives one method per experiment by substituting our class
names for Alexandrie's — `AeCairo*` becomes `VGCairo*`, longest name first — and dropping the
`<sampleInstance>` pragma, and compiles the result onto `VGAlexandriePortedExperiments class` in a
protocol named `generated - do not edit`.
`VGAlexandrieCorpusTest` then compares every compiled copy against what the substitution writes
today, so an edit to an experiment upstream and a hand edit of a copy both fail the suite; another
test fails if any copy still names a class we have a counterpart for, which would otherwise measure
Alexandrie against itself.
The oracle itself renders the copy and the original and compares the two forms pixel by pixel,
reporting the number of differing pixels and the largest difference in any one channel, with a
tolerance table that is empty for now and whose every future entry must carry its reason.
Every test skips when `AlexandrieCairoExperiment` or `libcairo` is absent, so the failover image
still runs the suite.

Eighty-two of the eighty-three experiments are cases; `getNumberOfGlyph` is excluded by name,
because it measures a font rather than drawing a picture.
Measured on import: no case drifts, and none of them compares yet, because almost every experiment
sets a source colour before it draws.
The cases are waiting on five units — forty on 1.5, thirty on 1.7, five on 1.8, five on 1.12 and
two on 1.4 — and each case answers the unit that unblocks it, which is the latest unit owing a
class it is missing, since it needs all of them, or the unit owing the selector its own render stops
on first.
That is the correction to the earlier estimate in this file: the corpus lights up at unit 1.5, not
at 1.3.

`VGCairoInventory` grew a second table for this, `extendedSelectorUnitTable`: twenty-three selectors
the experiments send that the measured Bloc surface never does, filed under the units that owe them,
with twenty-one new skeletons raising `VGNotYetImplemented`.
Both tables feed `unitForSelector:` and `progressReport`.
`VGConformanceTest >> coveredUnits` now reads both corpora, since the mesh patterns are covered only
by the derived cases, and units 1.10 and 1.11 joined `unitsWithoutAPicture` because neither adds a
drawing verb.
Nine tests over `VGAlexandrieCorpusTest`, eighty-one in the test package.
`VGAlexandrieCorpusExamples` holds three `<sampleInstance>` examples, and the views are `Waiting on`
on the corpus class side, gated on its position in the hierarchy, and `Classes` and `Blocking` on a
single case; all three ask the corpus rather than restating what it knows.

One critics exception is accepted here, and only here: `VGAlexandriePortedExperiments class` trips
`ReExcessiveMethodsRule` and three of its methods trip `ReLongMethodsRule`.
Those methods are generated transcriptions of Alexandrie's own experiments; shortening them would
break the comparison the corpus exists to make.

### 1.3 — path construction

The whole path vocabulary `AeCanvas` and Bloc path blocks send: `moveTo:`, `lineTo:`, `lineToX:y:`,
`lineFrom:to:`, `curveVia:via:to:`, `curveViaX:y:viaX:y:toX:y:`,
`quadraticCurveFromCurrentPoint:via:to:`, `closePath`, `rectangle:`, `rectangleTo:`,
`rectangleX:y:width:height:`, `roundedRectangleLeft:top:right:bottom:tl:tr:br:bl:`,
`circleCenterX:y:radius:`, `ellipseWidth:height:`, the three `arcCenter*` variants,
`circleSectorCenter:from:to:radius:` and
`annulusSectorCenter:from:to:innerRadius:outerRadius:`.

`fill`, `stroke`, `paint`, `fillPreservingPath`, `strokePreservingPath`, `useFillRuleWinding`,
`useFillRuleEvenOdd`, `clearColor:`, `clearTransparent`.

Gate: every path corpus case matches the reference, including the even-odd rule and a self-crossing
path.

**Done.** Thirty-six selectors, all real: `VGCairoInventory progressReport` answers 36 of 36 for
this unit, and no skeleton of unit 1.3 is left in the image.

A path is held in device space, because that is where Cairo holds it: `cairo_move_to` transforms
its point by the matrix of the moment, so a later `translateBy:` cannot move a path already built.
`VGCairoContext` keeps a `VGPathBuilder`, maps every incoming point through `state matrix` as the
verb arrives, and hands the finished `VGPath` to the fill or the stroke.
`newPath` drops the builder, which is what `fill` does after it paints and `fillPreservingPath`
does not.

The corners Cairo rounds off are copied rather than guessed, each one measured against a live
context: `lineTo:` with no current point acts as a move; `relativeLineTo:` with no current point
latches `CAIRO_STATUS_NO_CURRENT_POINT`, code 4, read from the live enumeration;
`currentPointInUserSpace` answers `0.0@0.0` and not nil on a fresh context, while `hasCurrentPoint`
answers false, so the two readers have to be asked together; `cairo_arc` runs in increasing angles
and raises the end angle by whole turns until it is not below the start, `cairo_arc_negative` lowers
it instead, and both join the current point with a line, or move when there is none;
`cairo_rectangle` is a move, three lines and a close, and accepts a negative width or height;
there is no quadratic primitive at all, so `quadraticCurveFromCurrentPoint:via:to:` raises the
quadratic to a cubic with both controls two thirds of the way to the control point.

Stroking is a fill of an outline, as section 1.4 says it will be: `VGStroker` turns each run into
one quadrilateral per segment plus a disc at every interior vertex, all wound the same way, so the
winding rule sees their union rather than a ring of holes.
The vertex count of a disc comes from the flattening tolerance measured in device space, which is
the same rule the curve flattener uses, so a magnified stroke buys vertices instead of showing
facets.
Caps, joins and dashes stay in unit 1.4; until then every cap and join is round, which is what a
disc gives for nothing.

The gate is met against live Cairo rather than against committed PNGs, and the reason is the point
of the whole project: the replacement answers Alexandrie's own selectors, so one conformance draw
block renders on either context unchanged.
`VGConformanceCase` now has `ourForm` and `cairoForm`, which run the same block on a
`VGCairoImageSurface` and on an `AeCairoImageSurface`, and `VGConformanceTest >>
testEveryCaseThatDrawsMatchesCairo` compares the two pictures for every case the implemented units
can draw.
`VGConformanceCase >> referenceFileName` is gone with no senders, and
`VectorGraphics-Cairo-Reference` is still not needed.

Pictures are compared premultiplied, by `VGFormComparison`, which is the one trap in the exercise:
a Pharo `Form` stores a fully transparent pixel as transparent white, so an unpremultiplied diff
reports a distance of 255 between two pixels whose coverage differs by two parts in 255.
The comparison answers three numbers — differing pixels, the largest distance in any one channel,
and the pixels we paint where the reference is untouched — and a case passes only when the third is
zero and the second is within its tolerance.

The tolerance rule is set from measurement, not from taste.
We sample coverage on Cairo's own grid, fifteen sub-rows a pixel, so the two pictures can differ
only in the shade of an antialiased edge.
Measured over the twelve cases that draw: the axis-aligned ones — the two clears, the translated
rectangle, the filled rectangle and the painted target — differ by nothing at all, and the curved or
slanted ones differ on 64 to 154 pixels with a worst channel distance of 4 to 21, the worst being
the filled circle.
`antialiasedCase:unit:draw:` files those cases with a tolerance of 24 and every other case keeps 0,
and the exterior is held exactly in both: no pixel of ours lies outside Cairo's shape in any case,
and the only pixels Cairo makes fully opaque that we do not are the 2 to 8 on an edge.

One hundred and seventeen tests in the test package, thirteen of them the new
`VGCairoDrawingTest`, and two of them meta tests that hold the artefacts of this unit honest:
`VGCairoExamplesTest >> testEveryViewOfAnExampleBuildsAndFillsItsCells` builds every inspector view
of every example and asks every table for every cell it would show, and `testEveryViewHasAGate`
fails on a view with no `…Context:` method.
`VGCairoSkeletonTest >> testNoMethodReferencesAnUndeclaredVariable` was written red and caught what
it was written for: `VGFillEntry >> setSegments:fillRule:` still assigned a slot that had been
removed, so the name had become an undeclared global and the write went nowhere.
It and its unsent constructor are deleted.

Four new example classes — `VGPathExamples`, `VGStrokerExamples`, `VGRasteriserExamples` and
`VGDisplayListExamples` — plus `VGFormComparisonExamples` and `VGBackendExamples`, bring the
`<sampleInstance>` examples to twenty-nine objects over twelve holders.
Twelve new inspector views, each with its gate: `Sub-paths` on `VGPath`, `Points` on `VGSubPath`,
`Building` on `VGPathBuilder`, `Edges` on `VGSegments` (whose winding column computes the direction
the rule counts rather than restating it), `Coverage` on `VGRasteriser`, which draws the real
coverage rows one character a pixel through `coverageRowsDo:`, `Entries` on `VGDisplayList`, `Fill`
on `VGFillEntry`, `Recorded commands` on `VGSoftwareBackend`, `Outline` on `VGStroker`, `Verdict` on
`VGFormComparison`, `Path` on `VGCairoContext`, and a class-side `Boundary` on `VGBackend` which
reads the three frozen messages off its own selectors and asks the subclasses which of them they
answer, gated on being the root of the hierarchy.

### 1.4 — stroke geometry

`strokeSize:`, `strokeCap:`, `strokeJoin:`, `strokeJoinMiterLimit:`,
`strokeDashPattern:offset:`, `strokeDashPattern:size:offset:`, `tolerance:`, `antialias:`, and the
six `useStrokeCapButt`, `useStrokeCapRound`, `useStrokeCapSquare`, `useStrokeJoinBevel`,
`useStrokeJoinMiter`, `useStrokeJoinRound` verbs.
The disc splat gives round caps and joins for free and nothing else, so this unit converts stroking
into a path and fills it.

Gate: a per-cap and per-join corpus case each match the reference; a dash offset larger than the
pattern period wraps.

The gate used to read "a zero-length subpath draws the cap pair rather than nothing", which
measurement disproves: live Cairo paints a zero-length sub-path only under a round cap, and paints
nothing at all under a butt or a square cap.
The case that does paint under a square cap is a zero-length *dash* run, which is a different thing
and is measured below.

**Done.** Fourteen selectors, all real, and no skeleton of unit 1.4 is left in the image.

Every number below was read from a live Cairo context rather than reasoned about, because the
defaults and the degenerate cases are where a reimplementation drifts.
A fresh context answers a line width of 2.0, a tolerance of 0.1, an antialias mode of 0, a miter
limit of 10.0 and no dash pattern.
`tolerance:` clamps a value of zero or less to 0.00390625, which is `CAIRO_TOLERANCE_MINIMUM`, one
part in 256, and leaves the status successful; `VGCairoState class >> minimumTolerance` holds it.
An invalid dash pattern — a negative entry, an all-zero pattern, or a single zero — latches
`CAIRO_STATUS_INVALID_DASH`, code 19, and every later painting verb returns without touching
anything.
An empty pattern is valid and turns dashing off.

Degenerate sub-paths, measured on a line width of 8: `moveTo: p` then `lineTo: p` paints 36 pixels
under a round cap and nothing at all under a butt or a square cap; a lone `moveTo:` paints nothing
under any cap; and `moveTo: p` then `closePath` paints the same 36 pixels under a round cap and
nothing otherwise.
That last one is why `VGPathBuilder >> closePath` keeps a run of one point rather than dropping it.
An 8-wide line from 10@32 to 50@32 paints `(10@28) corner: (50@36)` under a butt cap and
`(6@28) corner: (54@36)` under either of the other two, which is the half-width overhang.

The miter rule is arithmetic, and the arithmetic is confirmed at the pixel: a chevron
10@50 → 32@10 → 54@50 at width 7 paints its top row at row 2 for miter limits of 10 and 2.1, and at
row 8 for limits of 2.0 and 1.0, while our own ratio at that corner is 2.075.
A join is mitered when `(2 / (1 + dot)) sqrt` is within the limit, where `dot` is the dot product of
the two unit directions; the outer side of a corner is chosen by the sign of the cross product, the
outer corner is the vertex offset along the perpendicular by the radius, and the tip is the vertex
offset along the sum of the two perpendiculars by `radius / (1 + dot)`.
Past the limit the quadrilateral becomes the bevel triangle, and a round join stays a disc.

Dashes follow Cairo's own start search rather than a modulo, because the two differ on a pattern
whose first entry has no length:

```
while (offset > 0.0 and: [ offset >= (lengths at: index) ])
```

stops as soon as the offset reaches zero, so a first entry of no length is never stepped over, and
the length left of the entry it stopped on is `(lengths at: index) - offset`.
An odd pattern is the cycle written out twice, so `#(4)` has a period of 8, measured: an offset of 0
and an offset of 8 draw the same picture and an offset of 4 does not.
`VGCairoStrokeStyle >> paintsDashEntryAt:` is the one place that knows a painted entry is an odd
one, and the stroker's walk and the `Dash cycle` inspector view both ask it.

A zero-length dash entry that lands exactly on the end of a run still paints: a pattern of no length
on and twelve off, along 8@32 → 56@32, paints five dots, at distances 0, 12, 24, 36 and 48, the
fifth of them on the end point itself.
A butt cap paints none of them, and a round or a square cap paints all five, which is the measured
fact the corrected gate sentence above refers to.
`VGStroker >> dashTailAt:along:walk:into:` is that last dot, and it is the reason the dash walk
carries its position in a two-element array that each edge leaves where the next must pick it up:
Cairo's pattern runs along the whole path, not along each edge.

Antialiasing is one setting with one effect: only `#none` changes anything, and it means one sample
at the centre of the pixel.
Measured against Cairo on an exact polygon — a five-pointed star — our aliased render differs on
zero pixels.
On a flattened curve it does not, and the reason is not the sampling but the flattening: our vertex
phase differs from Cairo's by a fraction of a pixel, which antialiasing hides inside an edge shade
and aliasing turns into eight whole symmetric pixels on a radius-20 circle.
So the aliased corpus case fills a star and the curved cases keep their antialiased tolerance of 24.
The mode travels to the backend inside the `VGSegments` object, beside the fill rule, because the
backend boundary of rule 3 is frozen and takes no per-fill argument.

A shared conformance block has to speak the API both contexts answer, and the enums are the trap.
Alexandrie's `strokeCap:`, `strokeJoin:` and `antialias:` take uFFI enum objects: handed one of our
symbols, uFFI coerces it silently to zero — the block drew butt and miter with no error and eight
tests failed for one reason — and handed a plain integer it fails with "primitive #instVarAt: in
SmallInteger failed".
So a shared block uses the six `useStroke…` verbs where they exist, and names
`AeCairoStrokeCap round`, `AeCairoStrokeJoin bevel` or `AeCairoAntialias none` where they do not.
Our own symbol spelling stays an accepted extra, normalised by
`VGCairoStrokeStyle class >> nameIn:for:`, which takes one of our symbols, an Alexandrie enum or a
plain integer, and is covered by three tests of its own.
Only the `VectorGraphics-Cairo` package may not name an `Ae*` class; the test package already does.

Twenty-six tests in `VGCairoStrokeTest`, 143 in the test package and 214 in `VectorGraphics`, all
green, and critics clean on everything this unit touched.
`VGStroker` carries the whole geometry and nothing else: slots `path` and `state`, so the stroke
style, the matrix and the tolerance are read off the state rather than copied into the stroker.
The example artefact is the new `VGCairoStrokeStyleExamples`, six styles including the even pattern
and the odd one to compare periods with, and four more on `VGStrokerExamples` — round caps and
joins, a bevelled sharp corner and a dashed line.
The view artefact is `Style` and `Dash cycle` on `VGCairoStrokeStyle`, each gated, and the
seventeen-row `Outline` view on `VGStroker` now reads the real predicate for the first corner's
miter rather than restating the inequality.

### 1.5 — the paint ABI and the patterns

Freeze the ABI from rule 2.
Implement `sourceColor:`, `sourceColorR:g:b:`, `sourceColorR:g:b:a:`, `sourcePattern:`,
`sourceSurface:`, `source`, and the pattern classes: colour, linear gradient, radial gradient and
surface pattern, with `from:to:addStopsFrom:`,
`innerCenter:innerRadius:outerCenter:outerRadius:addStopsFrom:`, `matrix:`, `filter:` and the extend
modes.
Gradients are evaluated in Pharo in this unit.

Gate: a test reads the coefficient block byte by byte and asserts its layout; every gradient corpus
case matches the reference; the two `VGCanvas` pattern overrides from section 2.1 produce the same
pixels as the Alexandrie originals.

### 1.6 — the clip stack

`clip`, `clipPreservingPath`, path clipping with both fill rules, a clip mask stack that
`restoreStateAfter:` unwinds, and the rectangular fast path kept for the common case.

Gate: nested clips, an empty intersection, and the clip that
`BlElement >> aeApplyClippingWithAllParentsOn:` builds.

### 1.7 — groups, masks and operators

`paintGroupWith:`, `paintGroupWith:alpha:`, `paintWithAlpha:`, `maskGroupWith:`,
`maskSurface:x:y:`, `setOperatorClear` and the operator set behind it.

This is the hardest unit in phase 1, and it is what makes outskirts-outside possible: `AeCanvas`
emulates it by stroking at doubled width inside a group, then clearing the inner half.

Gate: the two outskirts-outside figure methods produce the same pixels as the Alexandrie originals,
since that emulation is pixel-sensitive.

### 1.8 — text

`VGScaledFont`, `scaledFont:`, `appendGlyphsPath:`, `showGlyphs:`, `getGlyphExtentsOf:size:into:`,
`fontExtents`, and a glyph atlas keyed by font, size and glyph id, built on the
`contourDataForUtf8` work already done.
Accept `AeCairoTextExtents` and `AeCairoTextMetrics` as the record types, since `AeCanvas` fills
them.

Gate: a shaped string renders identically through the atlas and through the glyph path; the atlas is
built once for a repeated draw, proved by a counter; metrics match FreeType's within the tolerance
the harness states.

### 1.9 — blur and export surfaces

A Gaussian blur equivalent to `AeCairoA8FastGaussianBlurFilter`, plus
`newSimilarImageFormat:width:height:`, `fromForm:`, `extent:to:`, and whichever export surfaces the
exporters need.

Gate: the shadow corpus cases match the reference within the tolerance the harness states for blur,
and the tolerance is justified in a comment.

### 1.10 — renderer wiring

`VGCanvas` overriding the five creation methods, `VGRenderer` overriding the canvas class, and the
guard test that asserts those five selectors still exist upstream.
Run it in the failover image, with `libcairo` renamed away.

Gate: a real Bloc space opens, draws and responds to a mouse event with no `libcairo` present, and
the `Bloc-Alexandrie` extension methods are untouched.

### 1.11 — profiling

Profile a representative Bloc scene and record where the time goes, per stage, next to the Cairo
numbers for the same scene.
Write the numbers down in this file.

Gate: the profile exists, and it names the stage phase 2 must attack first.
Without this number, phase 2 has no target and cannot be judged.

### 1.12 — mesh and Coons patch patterns

`AeCairoMeshPattern` and the Coons patch vocabulary the Alexandrie experiments use: a pattern built
from patches, each patch a closed path of up to four sides with a colour at each corner, plus the
control points that bend its sides.
Cairo evaluates a patch by bilinear interpolation of the corner colours over the Coons surface, so
the software path needs the same evaluation, and the paint ABI of rule 2 needs a tag for it.

This unit exists because the corpus asked for it: five derived cases stop on `AeCairoMeshPattern`
and nothing earlier in the plan owes it.
It comes last in phase 1 because it is the only paint Bloc itself never asks for — no method in
`Alexandrie-Canvas` builds a mesh pattern — so a failover image is complete without it.

Gate: the five mesh cases in the Alexandrie corpus match Cairo within a stated tolerance, and the
tolerance carries its reason.

## 7. Phase 2 — Vulkan as an optimisation

### 2.0 — probe and recovery

`VGBackend preferred` attempts a real dispatch, not a library-presence check: create an instance,
pick a device, allocate a buffer, run a trivial shader, read the result back.
Anything less is not a probe, because a present `libvulkan.so.1` with no working ICD is the common
broken case.
Wrap every backend entry point so that a raise becomes `VGBackendFailure`, caught at the boundary,
and replay the display list on software.

Gate: a deliberately broken backend stub produces a correct frame through the fallback, and the
image survives it.

### 2.1 — the go or no-go gate

Measure three numbers on this machine: buffer upload bandwidth, fill rate for a trivial coverage
shader, and readback latency for a full frame.
Compare the sum against the unit 1.11 profile.

Gate: if a GPU round trip costs more than the software path for a typical Bloc frame, stop here and
record why.
This gate is not a formality.
Readback is the known risk, because section 2.2 shows the frame ends in host window memory, and the
path back from device memory can swallow the whole win.

### 2.2 — tile binning on the CPU

Bin the display list into tiles in Pharo first.
Binning is cheap, it is testable without a GPU, and it decides whether the GPU path is one dispatch
or thousands.

Gate: a binning test over the corpus, and a count of tiles touched per case.

### 2.3 — the tiled fill rasteriser

Fill only, no stroke and no text: strokes are paths after unit 1.4 and text is blits after unit 1.8,
so fill is the whole of the hot work.
One dispatch per frame, coverage accumulated per tile.

Gate: every fill corpus case matches the software backend, which is the oracle, not Cairo.
The software backend already matched Cairo in phase 1, so matching software is both necessary and
sufficient.

### 2.4 — paint evaluation on the GPU

Compile the unit 1.5 paint ABI into SPIR-V, reading the same coefficient block.

Gate: the gradient cases match software; the stop lookup table gives identical bytes on both paths.

### 2.5 — blur on the GPU

A separable two-pass Gaussian.

Gate: matches software within the stated blur tolerance.

### 2.6 — image paint on the GPU

This unit needs `OpTypeImage`, and `SpvImageType` does not exist in `PharoVulkan-SPIRV` today.
Add it there, in `PharoVulkan`, with its own tests, before this unit starts.
Note also that `SpvOpcode class` declares no atomic opcode, so any coverage scheme needing an atomic
must add those opcodes first; unit 2.3 is written to avoid them.

Gate: a surface-pattern case matches software.

## 8. Backend selection at run time

One class-side method answers the backend, and it caches.

```
VGBackend class >> preferred
	^ preferred ifNil: [ preferred := self probeVulkan ifNil: [ VGSoftwareBackend new ] ]
```

A frame that raises `VGBackendFailure` clears the cache, so the next frame goes to software and
stays there.
A user can force either backend, and the forced choice is what the tests use, because a parity test
that silently falls back proves nothing.

`VkLibrary` already declares the three platform names: `libvulkan.so.1` on Unix,
`libMoltenVK.dylib` on macOS and `vulkan-1.dll` on Windows.
macOS and Windows are therefore not excluded by declaration, only untested, and the probe is what
decides on the user's machine.

## 9. Gates that apply to every unit, in both phases

1. The failing test was written and seen to fail before the code.
2. The package suite is green.
3. `run_critics` is clean on every class the unit touched, with one standing exception:
   `ReExcessiveArgumentsRule` and `ReExcessiveMethodsRule` fire on selectors the frozen Cairo
   surface dictates, such as `roundedRectangleLeft:top:right:bottom:tl:tr:br:bl:` and the size of
   `VGCairoContext` itself. Renraku offers no per-method suppression, and renaming a selector would
   break the calling API, which is the whole point of the project. Every other critique is a defect.
4. A class-side `<sampleInstance>` example exists in the `-Examples` package.
5. A custom `<inspectorPresentationOrder:title:>` view exists, and it asks the real rule rather than
   restating it.
6. The software backend still renders the corpus with the GPU backend forced off.
7. `VectorGraphics-Cairo` still names no `Ae*` class.

Rules six and seven are the ones that keep the failover honest.

## 10. Committing this plan without detaching the image

Iceberg reports a repository as detached when the working copy's reference commit differs from git
`HEAD`; that is exactly what `IceAttachedSingleVersionWorkingCopy >> isDetached` computes.
A `git commit` run from a shell advances `HEAD` and leaves the image's reference commit behind, so
every command-line commit in an Iceberg-tracked repository detaches it.

`IceGitIndex >> commitWithMessage:andParents:` writes a tree from the whole on-disk git index, and
`IceGitIndex >> addToGitIndex` only adds Iceberg's own modified paths on top of what is already
staged.
So a file staged with `git add` before an Iceberg commit is included in that commit, and the image's
reference commit advances with it.

The rule for this repository:

- Stage documentation changes with `git add`, and never run `git commit`.
- Commit from the image, with `repo workingCopy commitWithMessage: '…'`, which carries the staged
  documentation and the Pharo code in one commit and leaves the working copy attached.
- For a documentation-only change, where Iceberg's own diff is empty, use
  `commitChanges: repo workingCopyDiff withMessage: '…' force: true`, which skips the
  `IceNothingToCommit` check and still writes the staged index.
- If a command-line commit happens anyway, re-attach with
  `repo workingCopy adoptCommit: repo headCommit`, which sets the reference commit and recalculates
  the dirty packages without reloading any code.

A `pre-commit` hook in `.git/hooks/pre-commit` enforces the first rule, so that a shell commit fails
loudly instead of detaching the image silently.
It refuses every commit unless `ICEBERG_ALLOW_GIT_COMMIT=1` is set, and its message repeats the two
commit expressions above.
Iceberg is unaffected by it, because Iceberg commits through libgit2, which runs no hooks; the hook
sees only commits that come from a shell.
Hooks are not themselves tracked content, so installing it in a second repository means copying the
file and marking it executable there.

Note that the documentation and the code live in different repositories here: this file is in the
`PharoVulkan` repository, and the `VectorGraphics` package is in its own.
Phase 1 commits therefore go to the `VectorGraphics` repository, and only this plan file goes here.
