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

Phase 1 adds three packages and phase 2 adds three.

| Package | Phase | Contents |
|---|---|---|
| `VectorGraphics-Cairo` | 1 | `VGCairoContext`, `VGCairoImageSurface`, the pattern classes, `VGScaledFont`, the display list, the paint ABI, `VGBackend` and the software backend |
| `VectorGraphics-Cairo-Tests` | 1 | The conformance harness, the corpus and the inventory tests |
| `VectorGraphics-Cairo-Examples` | 1 | One `<Subject>Examples` class per subject, holding the `<sampleInstance>` examples |
| `VectorGraphics-Cairo-Reference` | 1 | The reference generator, the one place allowed to replay a corpus case through Alexandrie and write its PNG |
| `VectorGraphics-Bloc` | 1 | `VGCanvas` (the `AeCanvas` subclass) and `VGRenderer` (the `BARenderer` subclass), nothing else |
| `VectorGraphics-Vulkan` | 2 | The Vulkan backend, the tile binner, the SPIR-V paint and coverage shaders |
| `VectorGraphics-Vulkan-Tests` | 2 | The GPU-versus-software parity tests |
| `VectorGraphics-Vulkan-Examples` | 2 | The `<sampleInstance>` examples of the Vulkan backend, one click each |

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

**Done.** Six source selectors, six pattern classes and six paint classes, and no skeleton of unit
1.5 is left in the image.

The ABI of rule 2 is a method and not a paragraph: `VGPaint class >> blockLayout` names the sixteen
thirty-two-bit floats in order — `matrixSx`, `matrixShy`, `matrixShx`, `matrixSy`, `matrixX`,
`matrixY`, `extendCode`, `filterCode`, then seven fields read according to the tag
(`redOrLineX0OrInnerX`, `greenOrLineY0OrInnerY`, `blueOrLineX1OrInnerRadius`,
`alphaOrLineY1OrOuterX`, `outerY`, `outerRadius`), and `surfaceWidth` and `surfaceHeight` last.
Every paint has the same sixteen-element shape whatever it is, which is the point: a reader takes
the first eight fields without asking what the paint is.
The tag is `cairo_pattern_type_t` itself — solid 0, surface 1, linear 2, radial 3 — and the extend
and filter codes are Cairo's own numbers, so a phase 2 shader reads the block with no translation
table.
`VGGradientPaint class >> stopTableSize` keeps rule 2's two-hundred-and-fifty-six-entry table as a
number for a shader to use, and phase 1 evaluates the stops instead, because a table that quantises
the offset drifts from live Cairo.
The gate's byte-by-byte test reads the block as floats and as thirty-two-bit words against
`blockLayout`, so a field that moves breaks a test rather than a picture.

Quantisation is the discovery of this unit, and it is measured from raw premultiplied words rather
than derived: `surface data getHandle unsignedLongAt: index` reads foreign memory, where
`bytes unsignedLongAt: 1 bigEndian: false` reads the pointer, and `asForm` cannot be used at all
because it unpremultiplies with truncation.
Read that way, Cairo has **two** rules, not one.
A solid colour stores `floor(channel * alpha * 65535) >> 8` a channel, with the alpha byte
`floor(a * 65535) >> 8`, exact on six measured colours including `16r7F3F1F5F`.
A gradient, and every other per-pixel paint, stores `round(channel * alpha * 255)`, exact on nine
pixels of a sixty-four-wide ramp including `16r81420040`.
So the paint owns the choice: `VGPaint >> quantise:in:` asks the format for
`pixelForRgba:`, `VGColorPaint` overrides it to ask for `pixelForRgbaThroughShorts:`, and
`VGCairoSurfaceFormat >> shortByteOf:` is the one place the sixteen-bit rule lives.
Four source cases — flat colour, colour pattern, surface pattern and surface set directly — are now
pixel-exact, zero differing and zero outside.

Interpolation happens in unpremultiplied floats and never through a `Color`.
Live Cairo reads a blue of one hundred and twenty-six half-way along a ramp from transparent blue to
opaque red, which a premultiplied interpolation cannot produce; and a Pharo `Color` keeps ten bits a
channel, so rounding an interpolation through one answers one less than Cairo on a ramp of
two hundred and fifty-five steps.
`Color` stays an input, where it is identical on both sides.

`VGGradientPaint >> extended:` is the four extend modes, each measured on a live gradient from 16@0
to 32@0: `none` leaves pixel zero untouched and answers no paint there, `pad` holds the first stop,
`repeat` wraps the offset into zero to one, and `reflect` folds it into a triangle of period two.
`VGSurfacePaint >> sample:along:` is the same four modes on a pixel index, and answers nothing for a
surface of no extent whatever the mode says.
A radial gradient is the quadratic in `VGRadialGradientPaint >> offsetInPaintSpace:`: Cairo
interpolates a whole circle between the two, centre `c0 + s * (c1 - c0)` and radius
`r0 + s * (r1 - r0)`, and the offset at a point is the largest root whose radius is not negative.
Surface patterns default to `#none` and sample nearest-only; the real filters are unit 1.9's work,
and `filter:` stores its code in the block today.

`sourcePattern:` captures the transformation at the moment the source is set and keeps a reference
to the pattern rather than a copy, both measured: a stop added afterwards is painted, a scale
applied afterwards does not move the pattern.
`source` answers the pattern itself for the same reason.
`VGCairoPattern >> paintForDeviceMatrix:` composes the two at paint time — back through the captured
transformation, then forward through the pattern's own matrix — and answers no paint at all when the
device matrix cannot be inverted.

The conformance harness needed one new rule, for the same reason unit 1.4 needed the `useStroke…`
verbs: Alexandrie's context hands whatever it is given straight to a Cairo call, so a shared draw
block that names one of our pattern classes fails with "Message not understood: VGCairoMatrix >>
#tfPointerAddress".
A shared block therefore names no class of either family and asks
`VGConformanceCorpus class >> classNamed:for:`, which answers the `VGCairo…` or the `AeCairo…` class
by the family of the context it is drawing on.
The two gradient cases are the gate's `VGCanvas` clause:
`AeCanvas >> setSourceLinearPatternStops:start:end:` and
`setSourceRadialPatternStops:innerCenter:innerRadius:outerCenter:outerRadius:` are exactly a
constructor plus `sourcePattern:`, which is what those cases now run on both contexts.

The two gradient cases carry a tolerance of 1, in `gradientInterpolationTolerance`, and the reason
is pixman: it walks the ramp in fixed point where we evaluate in floating point.
On an axis-aligned ramp the two agree byte for byte on all sixty-four pixels, and they part by one
only where the offset lands on a step boundary — sixty-four pixels of a diagonal ramp along the line
where the offset is exactly one half, and thirty-two pixels of a radial ramp on one ring.
Byte-exactness is proven where it can be, by `VGCairoSurfaceTest` and `VGPaintTest` on the two
quantisation rules themselves.

One defect found and fixed test-first in the harness: `VGFormComparison class >> premultiplied:`
multiplied a byte by a *fraction* of an alpha instead of by the alpha byte, which inflated every
reported channel distance by as much as two hundred and fifty-five.
`premultipliedByte:byAlpha:` is now `(aByte * anAlphaByte / 255) rounded`, and with it
`transformationTranslation` became exact and the whole Alexandrie corpus fell to thirty-five or
less.
`VGAlexandrieCorpus class >> toleranceTable` therefore has twenty-five entries at last, each with
its reason: twenty-four at `antialiasedEdgeTolerance`, 36, whose comment names the worst measured
thirty-five on the rim of the yellow-to-red sphere, where 448 of 460 differing pixels of
`radialGradientPattern1` lie on the disc rim; and `fillPaint3` at `nearestSampleTolerance`, 96,
which is our nearest-only sampling of a bitmap scaled to a quarter and is unit 1.9's to fix.

One hundred and seventy-two tests in the test package and 214 in `VectorGraphics`, all green, and
critics clean on everything this unit touched.
The example artefact is `VGPaintExamples` with ten `<sampleInstance>` examples over both families —
a colour, a padded and a repeating linear gradient, a concentric radial gradient, a repeating
surface paint, a surface paint that paints nothing outside its tile, and the four patterns — plus
the `tile` fixture the surface ones share.
The view artefacts are four, each gated: `Block` on `VGPaint`, which tabulates the coefficients
against `blockLayout` field by field with each one's thirty-two-bit word; `Ramp` on
`VGGradientPaint`, which reads `extended:` and `rgbaAtOffset:` from minus one half to one and a
half; `Extend` on `VGSurfacePaint`, which shows which pixel each index outside the tile reads; and
`Paint` on `VGCairoPattern`, which asks the pattern for its own `paintDescription`.

### 1.6 — the clip stack

`clip`, `clipPreservingPath`, path clipping with both fill rules, a clip mask stack that
`restoreStateAfter:` unwinds, and the rectangular fast path kept for the common case.

Gate: nested clips, an empty intersection, and the clip that
`BlElement >> aeApplyClippingWithAllParentsOn:` builds.

**Done.** `clip` and `clipPreservingPath` are the two selectors of the unit, and no skeleton of
unit 1.6 is left in the image.

The discovery of this unit is measured before any clip code was written: Cairo's clip composes
**geometrically**, not as a coverage mask.
A clip of a circle followed by a paint is the same picture, byte for byte, as a fill of that circle,
and repeating the same clip changes nothing; two clips give the same picture as one clip and a fill
of the other.
So an implementation that multiplied a clip coverage by a fill coverage would darken every
antialiased edge twice, and the right unit of work is the **span**: `VGClip >> spanFrom:to:at:do:`
trims a span of the fill to its own bounds and then to every shape it holds, on the same sub-row,
and coverages are never multiplied.

`VGClip` is immutable and holds two things: bounds, and the shapes it cannot express as bounds.
The rectangular fast path is a question asked of the path rather than of the caller:
`VGSegments >> asDeviceRectangle` answers the bounding box when the segments are four axis-aligned
edges whose ends are its corners, and a clip of one of those keeps no shape at all, so a fill
through it needs no second scan conversion.
A clip keeps the fill rule **and** the antialiasing mode in force at the clip verb, for life, which
is why the shape is a `VGSpanScanner` and not a segment array.
`clipExtentsInDeviceSpace` rounds out to whole pixels — a right edge at 20.5 reports 21.0 — while
the clip itself keeps the fraction, which is what pays for half a pixel of coverage.
An empty intersection is normalised to `0@0 corner: 0@0`, because `Rectangle >> #intersect:` answers
a rectangle whose left is past its right and a clip has to read as plainly empty.
Immutability is what makes `restoreStateAfter:` work: the saved state shares the clip object, so
`postCopy` has nothing to do for it.

`VGSpanScanner` is the refactoring the clip forced: the scan conversion now belongs to neither the
rasteriser nor the clip but to a class both ask, and with it the two coverage loops of unit 1.0
collapsed into one `fillCoverage:startingAt:atRow:`.
An aliased shape answers the same whole pixels on every sub-row of a pixel row, so it reaches a
coverage of exactly one through the same loop that antialiases, and the aliased rule itself is one
sample at the pixel centre: a span `[from, to)` becomes the pixels
`[(from - 0.5) ceiling, (to - 0.5) ceiling)`, measured on a live context at 20.25, 20.5 and 20.75.
The pixel row is the floor of the sub-row, so neither the scanner nor the clip is told it twice.
The backend seam moved with it: the `clip:` argument of `fillSegments:paint:clip:operator:` is a
`VGClip` where it was a `Rectangle`.

Three defects were found and each fixed test-first.

Two belong to unit 1.5's quantisation, which was right about the paint and wrong about coverage.
A solid colour's sixteen-bit shorts **round**, they do not truncate: measured with exact doubles,
`#(1.0 0.5 0.25 1.0)` stores `16rFFFF8040`, and the six colours measured in unit 1.5 came through a
ten-bit Pharo `Color` and never landed on a tie, which is why truncation looked right.
Coverage is not folded into the paint's alpha at all: Cairo quantises the paint once and then
applies coverage as an **eight-bit mask on the quantised pixel**, scaling every channel including
the alpha.
The mask is `(coverage * 256) rounded` capped at 255 — measured on a live context, a rectangle
`k / 256` of a pixel wide stores an alpha of exactly `k` for every `k` from 0 to 255 — and a channel
is scaled by `(a * b + 127) // 255`, which is pixman's `MUL_UN8`: a solid `16r7F3F1F5F` at half
coverage is `16r40201030` where folding into the alpha gives `16r3F1F0F2F`.
An `rgb24` target has no alpha byte to carry the mask, so it lerps instead: opaque black at half
coverage over white is `16rFF7F7F7F`.
One measured difference remains at the very bottom of the range: a mask of one over an opaque grey
of `16r80` writes a colour byte of zero on a live context where the rule here writes one.

The third defect is the one the two star cases found, and it is about where a path lives rather than
how it is painted: Cairo stores every path coordinate as a `cairo_fixed_t`, twenty-four bits of
whole number and eight of fraction, so a device coordinate lands on a two hundred and fifty-sixth of
a pixel, and the conversion rounds a half to the **even** neighbour.
Measured: a rectangle one four hundredth of a pixel wide stores an alpha of one, one of three five
hundred and twelfths stores two, and one of exactly one five hundred and twelfth paints nothing at
all, because its width collapses to zero on the grid.
`VGPathBuilder >> fixedOf:` is that grid, and `moveTo:`, `lineTo:`, the control points of
`curveVia:via:to:` and every point the flattener emits now reach it, which is where Cairo's own
spline subdivision starts too.

Even snapped, one pixel at the tip of the star stays ours alone: Cairo steps a polygon edge across a
grid of five hundred and twelfths of a pixel with integer arithmetic where our scan converter is
exact across the pixel, and a near tangential edge leaves us a coverage of a fraction of one step of
alpha where Cairo rounds to none.
The gate therefore learnt to weigh a stray pixel instead of only counting it: `VGFormComparison`
reports `maximumStrayAlpha` beside `extraneousPixelCount`, and both gates hold it to
`VGConformanceCorpus class >> strayAlphaAllowance`, which is 1 — the smallest alpha a pixel can
carry, and invisible, where a shape we got wrong is heavy.

A harness defect of its own came out of the same run: the three test classes that render — the
conformance gate, the Alexandrie oracle and the example and view sweep — each take minutes, where
SUnit allows a test ten seconds.
Every one of them had been ending a package run as a **timeout error** rather than as a verdict, and
said nothing at all about the pictures; each now overrides `defaultTimeLimit` with the reason in its
comment.

The conformance corpus gained `clip-circle`, whose rectangle reaches outside the clip of a circle,
and `clip-preserving-path`, which is pixel-exact.
In the Alexandrie corpus `clip1` and `clip2` draw for the first time, both at
`antialiasedEdgeTolerance` with the measured worst at nine of two hundred and fifty-five, so
`toleranceTable` has twenty-seven entries; the six `maskAndClip` experiments stay blocked on unit
1.7's `mask:` and `maskSurface:x:y:`.

One hundred and ninety-one tests in the test package and 214 in `VectorGraphics`, all green, and
critics clean on everything this unit touched.

The example artefacts are `VGClipExamples`, with one clip of each kind the implementation
distinguishes — the rectangle that keeps no shape, the circle that keeps one, and the empty clip
two disjoint rectangles leave — and `VGSpanScannerExamples`, with a self-crossing star under the
even-odd rule and an aliased triangle.
The view artefacts are two, each gated on having anything to show: `Passed` on `VGClip`, which draws
what a fill through the clip would keep by handing the clip to the real rasteriser, and `Spans` on
`VGSpanScanner`, which lists the spans every sub-row answers so the aliased and antialiased modes
can be compared.

### 1.7 — groups, masks and operators

`paintGroupWith:`, `paintGroupWith:alpha:`, `paintWithAlpha:`, `maskGroupWith:`,
`maskSurface:x:y:`, `setOperatorClear` and the operator set behind it.

This is the hardest unit in phase 1, and it is what makes outskirts-outside possible: `AeCanvas`
emulates it by stroking at doubled width inside a group, then clearing the inner half.

Gate: the two outskirts-outside figure methods produce the same pixels as the Alexandrie originals,
since that emulation is pixel-sensitive.

**Done.** `paintGroupWith:`, `paintGroupWith:alpha:`, `paintWithAlpha:`, `maskGroupWith:`,
`maskSurface:x:y:` and `setOperatorClear` are the six selectors the unit named, `mask:` and
`operator:` came with them, and the inventory counts eight for 1.7 with no skeleton of the unit left
in the image.

A group is an intermediate surface of the target's own format, the size of the target.
Cairo shrinks its own group to the clip extents and carries a device offset to put it back; a group
the size of the target needs no offset at all, so the group's pixels sit at the device coordinates
they were drawn at and nothing has to be moved on the way out.
`pushGroup` saves the state, which is what Cairo's push_group does, and the intermediate shares the
target's backend, because a group of a Vulkan target must be drawn by the same device.
`popGroupAsSurfacePattern` drains the group's own display list first, because what comes back is
read as pixels; it then restores the state `pushGroup` saved and gives the pattern the restored
transformation, since the matrix of a pattern maps a user point into the pattern's space and naming
the transformation in force cancels it again.
An unbalanced pop latches `CAIRO_STATUS_INVALID_POP_GROUP` and the context refuses work from there,
as Cairo's does.

`mask:` splits in two.
A mask of one flat colour is `cairo_paint_with_alpha`, fold route and all, which is measured: a
clear through a solid mask of four tenths leaves the pixel where a paint through four tenths leaves
it.
Every other mask is rendered into an `argb32` intermediate of the target's size under the
transformation in force, so the backend is handed a mask in device space and one message covers a
gradient, a transformed surface and a popped group alike.
That message is the third and last of the backend — `blitSurface:at:paint:clip:operator:`, beside
`fillSegments:paint:clip:operator:` and `drainInto:` — so Rule 3 holds with three messages still.
The intermediate carries an alpha channel whatever the target's format is, because the alpha is the
only thing a mask is read for, and it is rendered without the clip on purpose: the blit applies the
clip, and nothing else reads that surface.
`VGCairoSurfaceMask` stands where `VGSegments` stands for a fill and answers the drawing message
itself, and a pixel outside it is no mask at all, which is Cairo's extend mode of none.

The operator set is twenty-nine instances carrying Cairo's code and the name Alexandrie calls it by,
and the compositing is split the way pixman splits it: twenty-one composite in eight-bit integers,
and the eight whose arithmetic divides composite in floating point from a source of four sixteen-bit
shorts.
`sourceFromPaint:in:atX:y:` asks the paint for the representation the operator wants, so no caller
has to know which half an operator belongs to.
Two questions decide the drawing: `isUnbounded`, true of the four that write where no source covers,
which is why those run over the whole clip and sweep the pixels the shape missed, and
`foldsAnAlphaIntoThePaint`, which says whether an alpha on a solid paint belongs in the paint's
colour or in a mask on the segments.

Two defects came out of the gate, each fixed test-first, and both are about a rim.

The first is a stroke defect older than this unit, which the gate's circle found: Cairo does **not**
join a run whose last point equals its first.
A square traced back to its own corner with four `lineTo`s is capped at both ends and the outer
corner between the caps stays empty, and an open polygon approximating a circle shows the same wedge
gap — but a full `cairo_arc` shows none, because Cairo strokes the spline itself and the spline
arrives with the tangent it left with.
Our stroker flattens an arc into chords, so the first and the last chord each lean half a
step away from the true tangent and leave a wedge of one chord angle, about nine and a half degrees
at a radius of twenty.
The rule is therefore about tangents and not about coincident points: a run carries the path's own
tangents at its two ends, the chords answer when the path has none, and
`VGSubPath >> comesBackToItsStartSmoothly` asks whether the ends meet and the two tangents agree,
within the rounding the grid of two hundred and fifty-sixths allows.
Such a run gets one more join, in the seam wedge, and **keeps its caps**, because Cairo caps both
ends of that run as well; a dashed run is cut into runs of its own, so its seam is left to the
dashes.
`VGPathBuilder >> noteTangentsFrom:to:firstSegment:` is where a flattener hands over the two
tangents of the curve it flattened, and `appendArcCenter:radius:from:to:` is its one caller so far.

The second belongs to the mask route and to the clip: a mask carries no spans, so a clip cannot meet
it span by span the way it meets a fill.
Cairo multiplies the coverage of the clip into the mask instead, and our mask route was visiting the
whole pixels the clip allowed, sampled at the pixel centre, so the rim of a clip came out hard where
Cairo shades it.
`VGClip >> coverageRowsDo:` now answers the part of each pixel the clip allows, by handing the clip
to the real rasteriser with a fill of its own extents — the same construction the `Passed` view
already drew, which now reads it from there — and the mask byte is scaled by it with
`maskByteForCoverage:` and `scaleByte:by:`, the two quantisations unit 1.5 measured.
A pixel the clip allows nothing of is left alone under every operator, unbounded ones included.
That took the six `maskAndClip` experiments from eighty-seven of two hundred and fifty-five down to
sixteen at worst, all of it on the rim of the clip and none of it outside the reference, so they
join `clip1` and `clip2` at `antialiasedEdgeTolerance`, and `toleranceTable` has thirty-three
entries.

The gate is the two figure cases, `figure-outskirts-outside-no-background` and
`figure-outskirts-outside-translucent-background`, and both match live Cairo.
`AeCanvas` cannot drive the replacement yet, because `prepareForSurface:` asks a surface for a
device scale matrix and `setHighQualityOptions` sets font options, which are units 1.9 and 1.8, so
each case is the body of the matching `AeCanvas` method written out message for message, with
`clipAfterwards` false.
The conformance corpus is thirty-three cases over nine groups, five of them groups and masks and two
the figures; the Alexandrie corpus runs seventy-two of its eighty-two experiments, and the ten that
stay blocked wait on six font classes and `AeCairoAntialias` and `AeCairoMeshPattern`.

Two hundred and nineteen tests in the test package and 214 in `VectorGraphics`, all green, and
critics clean on everything this unit touched.

The example artefacts are `VGDisplayListExamples class >> surfaceMaskOfATile` and
`blitEntryOfAMask`, `VGPathExamples class >> subPathComingBackToItsStartSmoothly`, which answers the
one run a full circle builds, and
`VGCairoImageSurfaceExamples class >> surfaceMaskedThroughACircleClip`, whose rim is the shade the
clip carries.
The view artefacts are `Mask` on `VGCairoSurfaceMask`, which samples the alpha it really answers at
four places, `Blit` on `VGBlitEntry`, which asks the operator whether it is unbounded rather than
restating the list, and `Seam` on `VGSubPath`, which asks the predicate itself and says whether
Cairo would join that seam or cap it; `Passed` on `VGClip` says in the same breath that a mask
through the clip is scaled by the coverage it draws.

Three things are left where they are on purpose.
`pushGroupWithContent:` is not implemented, because its only sender is an Alexandrie test and the
content of a group is a choice of format the replacement does not offer yet.
`VGFillEntry >> boundingBox` under-reports under an unbounded operator, where `VGBlitEntry` answers
the whole clip for that case; nothing reads the fill entry's box yet.
A dashed run's seam is left to the dashes, as above.

### 1.8 — text

`VGScaledFont`, `scaledFont:`, `appendGlyphsPath:`, `showGlyphs:`, `getGlyphExtentsOf:size:into:`,
`fontExtents`, and a glyph atlas keyed by font, size and glyph id, built on the
`contourDataForUtf8` work already done.
Accept `AeCairoTextExtents` and `AeCairoTextMetrics` as the record types, since `AeCanvas` fills
them.

Gate: a shaped string renders identically through the atlas and through the glyph path; the atlas is
built once for a repeated draw, proved by a counter; metrics match FreeType's within the tolerance
the harness states.

**Done.** `VGScaledFont`, `scaledFont:`, `appendGlyphsPath:`, `showGlyphs:`,
`getGlyphExtentsOf:size:into:` and `fontExtents` are the selectors the unit named, `fontSize:` came
with them, and the inventory counts six for 1.8.
`showText:`, `textExtentsOf:` and `glyphArrayForString:` are ours rather than Cairo's and are what
the corpus draws through.

The font stack is pure Pharo and reads the font's own bytes.
Ten classes carry it, in the `Text` tag: `VGFontFace` for the tables, `VGScaledFont` for a face at a
size under a matrix with its options, `VGFontOptions`, `VGGlyph` and `VGGlyphOutline` for one glyph
and its contours, `VGGlyphComponent` for a component of a composite, `VGGlyphAtlas` and
`VGGlyphMask` for the cached rasterisation, and `VGFontExtents` and `VGTextExtents` for the records
`AeCanvas` fills.
Two things are read from the tables directly rather than through Pharo's own TrueType parsers,
because those parsers drop them.
`TTGlyfTableParser >> parseCompositeGlyph` keeps the component glyphs of a composite and discards
the offsets and the transformations that place them, so `VGFontFace` reads the component records
itself; and `advanceWidthMax` is not among the fields `TTHheaTableParser` answers, so
`readMaxAdvanceWidthFrom:` reads hhea at offset ten and puts the entry's own offset back, since a
parser reads from where the entry currently stands.
Neither external class is touched, as the standing rule says.

The metrics are exact rationals computed from those tables, and the gate measures them against live
FreeType through Cairo rather than against numbers written down here.
Unhinted, under the identity user-to-device matrix, our font extents, our run extents and our glyph
positions agree with `AeCairoScaledFont` to one part in a million million, which is the width of a
double on these magnitudes and the tolerance the test names.
Two limits are stated in the code because they cannot be measured away.
Cairo's hinted *advances* come from a FreeType face it shares with the hinter, and are not
reproducible from outside it, so the hinted half of the comparison is left out on purpose rather
than loosened; and our hinted rounding of the ascent, the descent, the height and the maximum
advance happens in user space, which agrees with Cairo only when the user-to-device matrix is a
translation or the identity.

A run draws two ways and the two agree byte for byte.
The path route appends the glyph outlines and fills them; the atlas route blits one cached mask per
glyph.
They agree because both rasterise the same snapped coordinates and both quantise once: the fill
route scales the coverage byte by two hundred and fifty-five, and the blit route scales the mask's
own byte by the coverage of a fully covered pixel, which is the pair of quantisations unit 1.5
measured.
The atlas key is the glyph index, the sub-pixel phase and the matrix with its translation taken off,
which is why a whole-pixel move reuses a mask: `VGPathBuilder >> fixedOf:` puts a device coordinate
on Cairo's grid of two hundred and fifty-sixths with ties to even, and that snapping commutes with
adding an integer.
A glyph that inks nothing is cached as nil and never rasterised again, and `renderedGlyphCount`
counts the rasterisations, so the "built once for a repeated draw" half of the gate is a number a
test reads: the same run drawn twice rasterises each distinct glyph once.

`showText:` draws through `showGlyphs:` rather than beside it, because Cairo's toy API is a layer
over `cairo_show_glyphs`, and it leaves the current point where the next glyph would start.
That point is a path coordinate, so it comes back a fraction of a pixel from the exact advance and
the test allows one step of the grid, which the comment says in as many words.
A text verb that has selected no font asks Cairo for its toy default face, and naming a family and
finding a file for it needs the font manager, so `defaultScaledFont` is a skeleton naming unit 1.10
and the inventory's extended table carries that entry.
That skeleton is what made the Alexandrie corpus honest: five experiments — `lineCap`, `linejoin`,
`linejoin2`, `fillPaint1` and `fillPaint2` — label their drawings with `showText:` and no font, and
were counted as drawing when they were in fact leaning on nothing.
The corpus now reports sixty-nine of eighty-two drawing, eight waiting on 1.10 — those five and the
three font-manager cases — and five on 1.12, and the six font classes name 1.10 rather than 1.8,
because 1.8 builds the face, the scaled font, the metrics and the atlas while picking a font by
family name and shaping it with HarfBuzz is what 1.10 brings.

The conformance corpus stays at thirty-three cases over nine groups, but its two text cases draw now
instead of standing empty, and they are the same run drawn both ways.
`text-glyph-path` sits at the ordinary antialiasing tolerance, because Cairo rasterises an appended
glyph path with the same scan converter as any other path.
`text-glyph-run` carries a tolerance of thirty-six and an exterior allowance of sixteen, measured at
thirty-three and at five pixels of alpha thirteen, because Cairo rasterises `cairo_show_glyphs` with
FreeType and a FreeType reference does not have the exterior a scan converter has.
That allowance is now per case: `VGConformanceCase` holds its own `strayAlphaAllowance` and defaults
it to the corpus constant, so one case's rasteriser cannot loosen the other thirty-two.

Twenty-two tests in `VGCairoTextTest`, 241 in the test package and 214 in `VectorGraphics`, all
green, and critics clean on everything this unit touched bar `ReExcessiveVariablesRule` on
`VGFontFace`, which holds thirteen slots of one font's tables and keeps them, as `VGCairoState` and
`VGCairoImageSurface` already do.

The example artefacts are five in `VGScaledFontExamples`, whose class comment says why its font is a
system file: this package names no Alexandrie class, so it searches `/usr/share/fonts` for a known
basename and signals a named error when it finds none.
They are `fontFaceOfASystemFont`, `scaledFontAtAReadableSize`,
`contextWithTextDrawnThroughTheAtlas`, `atlasFilledByARunDrawnTwice`, which answers an atlas of four
cached masks and three rasterisations, and `glyphMaskOfOneLetter`.
The view artefacts are `Face` and `Alphabet` on `VGFontFace`, the second reading the real
`glyphIndexForCodePoint:` and `outlineOfGlyphAt:` for a handful of characters rather than restating
a table; `Metrics` and `Run` on `VGScaledFont`; `Masks` and `Work saved` on `VGGlyphAtlas`, which
counts the keys, the rasterisations and the glyphs cached with no ink; and `Picture` and `Placement`
on `VGGlyphMask`.

### 1.9 — blur and export surfaces

A Gaussian blur equivalent to `AeCairoA8FastGaussianBlurFilter`, plus
`newSimilarImageFormat:width:height:`, `fromForm:`, `extent:to:`, and whichever export surfaces the
exporters need.

Gate: the shadow corpus cases match the reference within the tolerance the harness states for blur,
and the tolerance is justified in a comment.

**Done.** `extent:to:` was the one selector the inventory owed 1.9, and
`newSimilarImageFormat:width:height:` and `fromForm:` came with unit 1.1 and were re-checked here: a
Form goes into a surface and back out bit for bit, and a similar surface can change both its format
and its size.

The blur is `VGA8GaussianBlurFilter`, in the `Blur` tag, and it replaces
`AeCairoA8FastGaussianBlurFilter`, whose superclass `AeCairoA8GaussianBlurFilter` holds all the
arithmetic — the fast subclass defines no method of its own.
Three box passes approximate the Gaussian, the sigma of a shadow radius is the radius over
2.8199568089598754 rounded, and the radii of the three passes come from the `boxesForGauss`
function both implementations share.
Every step is integer and float arithmetic with no hardware behind it, so the filter is not held to
a tolerance at all: `VGBlurTest` seeds a surface deterministically, blurs it through both
implementations and compares every byte, at a width whose rows need no padding and at one where
they do.

Alexandrie's `surface:` takes the walk width from the surface stride rather than from its width, so
the padding bytes at the end of a row take part in the blur and the end of one row bleeds into the
start of the next.
Ours does the same, because an a8 shadow mask is padded whenever its width is not a multiple of
four, and a replacement that blurred only the visible bytes would differ from Cairo on exactly the
shadows Bloc draws.
The class comment says so and `testBlurringAWidthWithStridePaddingAgreesWithAlexandrieToo` holds it.
A radius of zero and a sigma of zero leave every byte alone, which is the degenerate case a shadow
with no blur takes, and the filter draws what the surface still owes before it reads a byte, since
our surface records a frame where Cairo's holds pixels.

Two `ReLongMethodsRule` findings on the two box passes are accepted.
Each pass walks a row, or a column, in three parts — the window growing out of the near edge, the
window wholly inside, and the window running off the far edge — which is what keeps the cost at one
addition and one subtraction per pixel whatever the radius is.
Splitting a part into a helper would pass five temporaries per call inside that loop, and
Alexandrie's own pass is one method for the same reason.

The gate is four shadow cases in the conformance corpus, built by `shadowCaseNamed:geometry:` and a
blur radius, which follows the path `BlGaussianShadowEffect` takes through `AeCanvas`: the geometry
drawn opaque into an a8 surface of the context's own family, blurred, then masked onto the target at
an offset in the shadow colour.
`shadowBlurTolerance` is 4 of 255 and the reason is in the comment: the two curved cases measure 2,
which is the quantisation of a coverage that the unblurred circle of unit 1.3 already differs by 21
on, nothing lands outside the reference at all, and the sharp case and the one blurred by nothing
are held exact, because an axis-aligned edge is the same byte on both sides before the blur and
stays the same byte after.
The corpus is now 37 cases over ten groups, and `VGConformanceTest` passes its ten tests.

The export surfaces are `VGCairoExportSurface` with `VGCairoPDFSurface` and `VGCairoSVGSurface`, in
the `Export` tag, and they are raster pages.
Cairo records the drawing operators sent to one of its export surfaces and emits them as vector
drawing, so a Cairo page is resolution independent; by the time a drawing reaches us it is a display
list of flattened polygons and the curves, the text and the gradients it came from are gone, so a
faithful vector page is not derivable from what we hold.
Each page therefore rasterises itself and embeds the pixels, which is what a reader of the document
sees and what the two exporters that need `extent:to:` — `BAPdfExporter >> newCanvas:` and
`BASvgExporter >> newCanvas:` — hand to a human.
`BAPngExporter` needs only `writePngTo:`, which unit 1.1 delivered, and `AeCairoRecordingSurface` is
used by nothing outside Alexandrie's own tests, so no counterpart is owed.

A page is rasterised at one device pixel to the point.
That is not a quality setting with a better value: the surface protocol answers pixels to `extent`,
Cairo's export surface answers points to the same selector, and the callers the inventory measured
send it, so the two readings have to agree.
`pageExtent` keeps the points, which may be fractional, and the pixels round up.

A PDF page is six indirect objects in a numbering the class states once: the catalogue, the pages,
the page with its `/MediaBox` in points, a content stream that scales the unit square an image
occupies to that box, the pixels as an image in `/DeviceRGB`, and their alpha as a second image in
`/DeviceGray` that the first one names in its `/SMask`, because the format keeps no alpha channel
inside an image.
A cross reference table of the twenty-byte entries the format fixes follows, and `/Length` is stated
last in every stream dictionary, so a reader searching forward from any other key of that dictionary
reaches it.
An SVG page states its size in points and its view box in the same units, and carries the pixels as
one `<image>` holding a Portable Network Graphic in a base64 data URI, with
`preserveAspectRatio="none"` so that a reader does not letterbox the hair a fractional page gains
when its pixels round up.
`finish` writes the document and a second finish writes nothing, which is what Cairo does and what
Bloc's exporters, cascading flush and finish, rely on.
A page of no extent carries no image, since neither format admits one of no width, and is still a
well formed document.

`VGCairoExportSurfaceTest` is fourteen tests and writes every page into a memory file system, so a
test leaves nothing on disk.
It reads each written document back and compares what it carries against the pixels of the surface
itself: the colour stream against the straight-alpha channels, the soft mask against the alphas, the
embedded graphic decoded from its data URI and compared to the page's own Form bit for bit, and each
offset of the cross reference table against the real start of that object.
Both subclasses are also held, reflectively, to the prefix each one declares, so a third container
format added later is covered without a test of its own.
The one check that could be made from outside the image was made: `xmllint` reads a written SVG page
as well formed, and the graphic inside it decodes to a 40 by 30 image.

`VGCairoInventoryTest >> testSurfaceAnswersEverySelectorItsCallersSend` now asks the surface family
rather than `VGCairoImageSurface` alone, which is what the pattern family already did and for the
same reason: a constructor belongs to the class it builds.
The 1.9 skeleton is gone, and `VGCairoContext >> defaultScaledFont` is the only skeleton left in the
package.

The artefacts of the cycle: `VGA8GaussianBlurFilterExamples` builds the point spread of the filter
and a blurred rounded rectangle, `VGCairoExportSurfaceExamples` builds a finished page of each
format in a memory file system, and the views are `Box radii` and `Mask` on the filter and
`Document` on a page, each with its gate.
The `Box radii` table asks the real arithmetic for each radius it shows instead of restating it, and
`Document` builds the document in memory, so looking at a page does not write its file.
Critics are clean on everything the unit touched, bar the two accepted long methods above, and the
test package is 264 tests and passes.

### 1.10 — renderer wiring

`VGCanvas` overriding the five creation methods, `VGRenderer` overriding the canvas class, and the
guard test that asserts those five selectors still exist upstream.
Run it in the failover image, with `libcairo` renamed away.

Gate: a real Bloc space opens, draws and responds to a mouse event with no `libcairo` present, and
the `Bloc-Alexandrie` extension methods are untouched.

**Done.** The seam is eight methods, not five, and the extra three are what made the unit worth
running as its own unit rather than a line in another one.

Five of the eight build a Cairo object by naming its class, and those were the five the plan
expected: `AeCanvas class >> extent:`, `newCairoSurfaceExtent:`,
`setSourceLinearPatternStops:start:end:`,
`setSourceRadialPatternStops:innerCenter:innerRadius:outerCenter:outerRadius:` and
`newSurfaceWithGaussianShadow:width:canvasDo:`.
A sixth, `scaledFontForFace:size:`, reaches Cairo without naming it, through `aFace
newCairoFontFace`, so a scan for class names does not find it and a canvas that overrode only the
five would still build a Cairo font for every piece of text.
The last two are `setHighQualityOptions` and `setLowQualityOptions`, which assign the shared
`AeCairoFontOptions` that `AeCanvas class >> initializeFontOptions` builds; the four field readers
of that record — antialias, hint style, hint metrics and subpixel order — are each a `ffiCall:`, so
reading the options a canvas already holds is a call into the library.
Our canvas holds a `VGFontOptions` instead and answers it through a reader `AeCanvas` does not have,
which is why the record itself did not need overriding.

`AeCanvas class >> startUp:` re-runs `initializeFontOptions` on every image start.
That is Alexandrie's own method and no subclass of ours can reach it, so in an image with no
`libcairo` Alexandrie calls Cairo before any of our code runs.
The honest statement is that the failover replaces Bloc's drawing, not Alexandrie's startup: a
`libcairo`-less image needs `Alexandrie-Canvas` left out of the load, or that one startup action
removed, and this plan does not pretend otherwise.

Two proofs hold the seam, one static and one dynamic, and the dynamic one found a real bug.

The static proof is `VGCairoReferenceScanner`, which reads a method's `allLiterals` — not its
`referencedClasses`, because a full block keeps its own literal frame and a class named inside a
block would be missed — and answers the classes of `Alexandrie-Cairo` that the method names.
It scans every package of this project whose name does not end in `-Tests`, found by prefix rather
than listed, so a package added later is scanned without an edit, and the tests are left out because
the dynamic proof needs a positive control that calls Cairo on purpose.
It answers no offender.
The same scanner, pointed at `Bloc-Alexandrie`, names the four methods of the Bloc backend that
reach Cairo without going through the canvas: `BARenderer >>
renderWith:pixels:stride:physicalRectangle:logicalRectangle:`, which we override, and
`BAAxisAlignedCompositionLayer >> createSurfaceToBePaintedOn:`, `BlGradientShadowEffect >>
setUpShadowSurfaceFor:extent:` and `BASharedCairoMatrix >> default`, which no subclass of the canvas
can reach.
`BASharedCairoMatrix >> default` only allocates an FFI structure and calls nothing, so it is
harmless with the library absent; the other two are a composition layer's surface and a gradient
shadow's surface, and a scene using either draws through Cairo however the canvas is chosen.
A test states that list, so one appearing or disappearing upstream is a failing test rather than a
surprise in a window.

The dynamic proof installs a `MetaLink` on every method of `Alexandrie-Cairo` that sends `ffiCall:`,
draws a frame through our renderer, and asserts that none of them was entered.
Two rules make it work: one link per method node, because a shared link fires for the first node
only, and the methods must be re-resolved live with `each methodClass >> each selector`, because
`package methods` can answer methods a recompile has already replaced.
The links are removed in an `ensure:`, and the test ends with a positive control —
`(AeCairoImageSurface extent: 4@4) newContext rotateByRadians: 0.5` enters three instrumented
methods — so a proof that never fired cannot pass as a proof.
Red on the first run: `AeCairoFontOptions >> antialias`, `hintStyle`, `hintMetrics` and
`subpixelOrder` ran, because the canvas was reading Cairo's record to copy it into ours on every
text run.
That is the bug the three extra seam methods close, and the static scan could never have caught it,
because the method that read them named no Cairo class.

The renderer half is small, as the plan expected.
`VGRenderer` overrides `initializeForHostSpace:`, which upstream builds its frame canvas and its
text measurer with, and `renderWith:pixels:stride:physicalRectangle:logicalRectangle:`, which wraps
the pixels the host window lends in an unowned surface of ours; its class side answers a `label`
Bloc shows in its own tools, and the three form and PNG entry points.
`BlHostRenderer preferableClass:` is a single global setting with no per-space override, so a test
that chooses this renderer has to save and restore it, and a `setUp` that captures it after an
interactive doIt captures the wrong value — which happened here once and left the whole image
drawing through this project.
`newFormFrom:` cannot be inherited: upstream sends `aeAsForm`, which names `AeCanvas` in its own
source and has no seam, so the parent walk it performs lives in `VGCanvas class >> formOfElement:`
and a test parses both methods and compares the trees, with the two names substituted back, so a
change upstream fails a test instead of quietly leaving our form unrotated.
A fractional extent truncates to whole pixels in our surface exactly as it does in Cairo's, which is
what the exporters and that walk rely on.

Bloc's headless host could not be used for the gate.
`BlHeadlessHostSpace >> render:` increments a frame counter and clears the dirty elements without
ever asking the renderer, so a headless space proves nothing about drawing.
`VGPixelBufferHost` and `VGPixelBufferHostSpace` are therefore a host with no window whose space
really draws: the host space lends a `ByteArray` of its own and the stride our ARGB32 format states
for its width, `render:` asks the renderer before the inherited bookkeeping, and `form` answers an
unowned surface over the same bytes as a `Form`, which is what the frame view shows.
One subtlety took a diagnosis: the renderer answered that it was not valid and held no canvas,
because `initializeRenderer` is sent when a window is created and again by `BlSpace >>
validateHostSpaceDrawing` only once the host space `hasResized`, and a headless host space does
neither; our host space sends it from `open`.

The exporter hierarchy of `Bloc-Alexandrie` is backend independent but for `newCanvas:`.
`VGFormExporter` and `VGPngExporter` override that one method, and a test asks the hierarchy which
of its exporters name `AeCanvas` and which of those have a subclass here: `BAJpgExporter`,
`BAPdfExporter` and `BASvgExporter` still have none, which is a stated hole rather than an
oversight — JPEG needs nothing but the canvas, and PDF and SVG need the export surfaces unit 1.9
built — and the test fails as soon as one of them is covered, so the list cannot go stale.

Unit 1.8 left one skeleton behind and named this unit for it: `VGCairoContext >> defaultScaledFont`,
Cairo's toy default face, which a text verb uses when the caller selected no font.
It is implemented, and the package now holds no skeleton at all.
Cairo picks that face through fontconfig; this replacement binds no fontconfig, so the face is the
one Pharo bundles, at Cairo's own default size, matrix and options, with the user to device matrix
in force.
The glyphs are therefore a different typeface, which no tolerance on a channel could honestly cover,
so the three Alexandrie cases that label a drawing with `showText:` and no font — `lineCap`,
`linejoin` and `linejoin2` — are filed in `VGAlexandrieCorpus class >>
casesWithCairosToyDefaultFont` and left out of the oracle, and a second test derives that list from
the ported source of every case that draws, so one that starts or stops selecting a font fails
there rather than failing the oracle with a wall of differing pixels.
`VGCanvas class >> bytesForFamilyName:styleName:` is the bridge to Pharo's font manager and falls
back to the bundled face for a family it cannot find, because a frame in the wrong font beats a
frame that raises inside the renderer.

The gate asked for a space that opens, draws and responds to a mouse event with no `libcairo`
present.
The first two thirds are a test: a space with an element opens on our host, settles, draws pixels
that are not all zero, and `element eventSimulator click` runs its click handler, all with
`BlHostRenderer preferableClass: VGRenderer` — the modern API, since `BlSpace class >>
simulateClickOn:` and `pulseUntilSpaceOpenedAndEmptyTaskQueue:timeout:` are deprecated.
The last third is not a test and cannot be: the running image has `libcairo` loaded, the metalink
proof is what stands in for its absence, and the literal run with the library renamed away belongs
to the parity image this plan's image table already describes, where `Alexandrie-Canvas` has to be
absent from the load for the reason given above.

The artefacts of the cycle: `VGCanvasExamples`, `VGRendererExamples` and
`VGCairoReferenceScannerExamples` hold fourteen `<sampleInstance>` examples — a canvas on a small
surface, a gradient fill, a blurred shadow surface, a scaled font, a renderer prepared for a host
space, a space drawn into a pixel buffer, the form and the PNG of a drawn element, both exporters,
an offscreen text measurer, and the scan of this project and of the Bloc backend — and the views are
`Backend` and the class-side `Seams` on the canvas, `Renderer`, `Measuring`, `Host`, `Frame`,
`Handover`, `Export` on each exporter, and `Scan` and `Offenders` on the scanner, each with a gate.
`Seams` asks `VGCanvas class >> seamRows`, which reads the two classes rather than listing the
seam, so a creation method added upstream appears as a row with nothing overriding it.
`VGBlocExamplesTest` subclasses the Cairo example gate and overrides the holders alone; that gate's
view rule now ignores a view this project did not write, because an example answers a `Form` or a
`ByteArray` as often as one of our objects and Pharo's own views on those are not ours to gate.
The baseline declares the three new packages and the groups `bloc`, `examples` and `tests`, with
`default` loading core, Cairo and Bloc.
`VectorGraphics-Bloc-Tests` is twenty-nine tests over `VGCanvasTest`, `VGRendererTest` and
`VGBlocExamplesTest`, and the two test packages together are two hundred and ninety-eight and pass.
Critics are clean on everything the unit touched bar four accepted critiques, all of them forced by
parity: the argument count of two methods whose selectors are upstream's, and the length of
`formOfElement:` together with the `forceLayout` it sends, because that method is a copy held
against upstream source by a test and splitting it would break the comparison.

### 1.11 — profiling

Profile a representative Bloc scene and record where the time goes, per stage, next to the Cairo
numbers for the same scene.
Write the numbers down in this file.

Gate: the profile exists, and it names the stage phase 2 must attack first.
Without this number, phase 2 has no target and cannot be judged.

**Done.** The profile is `VGFrameProfile`, in the new `Profiling` tag of `VectorGraphics-Bloc`, and
it answers the question the gate asks with one number: the stage to attack first is `pixelAccess`,
the surface and its pixel format, which holds between 59 and 66 per cent of a frame.

The scene is twelve cards on a filled background, each a rounded rectangle with a vertical
gradient, a two pixel stroked border and a text label, laid out in a grid at 800 by 600.
Between them the four things that cost in a software rasteriser are all present: curved edges, a
gradient read per pixel, a stroke outline, and glyphs through the atlas.
Each number is the mean of three frames, and each frame is drawn on a canvas of its own.

A frame of ours is timed in two phases, because a hardware backend would replace them separately.
Drawing the element tree records a display list into the canvas, which is the build phase, and
flushing the surface drains that list into pixels, which is the drain phase.
The same scene is then timed through `AeCanvas`, which draws with Cairo as it is asked rather than
recording, so it has one phase and not two.
`AeCanvas` belongs to Alexandrie's canvas package and not to its Cairo package, so naming it leaves
the rule that no package of this project names a Cairo class intact, and the scanner test of unit
1.10 still passes.

| Mean of three frames, 800 by 600, twelve cards | First run | Second run |
|---|---|---|
| This project, whole frame | 2149.3 ms | 2139.8 ms |
| of which the build phase | 4.8 ms | 8.7 ms |
| of which the drain phase | 2144.5 ms | 2131.0 ms |
| Cairo, whole frame | 2.1 ms | 1.8 ms |

So this project is around a thousand times slower than Cairo on the same scene, and the whole of
that is in the drain: recording a frame costs between 4 and 9 milliseconds, which is 0.2 to 0.4 per
cent of it.
Cairo's own first frame of an image costs 23 ms and its later frames cost under 2 ms, so the number
above it is the warm one; the cold difference is font and pattern setup inside Cairo, not drawing.

Inside the frame the time is attributed per stage by sampling, with `AndreasSystemProfiler`.
A node's own samples are its tally less the tallies of the nodes it called, and the stage travels
down the tree: a node of a class of this project sets the stage for everything it calls, so the
arithmetic a kernel class does is charged to the code of ours that asked for it, and a node above
every class of ours is charged to the scene.
Nothing is left unattributed and the shares sum to one, which `VGFrameProfileTest` holds.
A stage is read from the package and the tag a class is filed under, through
`VGFrameProfile class >> stageByPackageAndTag`, so moving a class between tags moves its stage with
it, and a test holds the keys of that table against the organiser in both directions: every package
and tag of the project has a stage, and no key names a tag that is gone.
The sampled frame is a fourth frame rather than one of the timed ones, because the sampler costs
time of its own.

| Stage | First run | Second run | What is in it |
|---|---|---|---|
| `pixelAccess` | 65.6 % | 58.9 % | the surface and the pixel format: pixels read and written, colours and coverages quantised |
| `paintSource` | 18.5 % | 22.3 % | the colour a paint or a pattern answers at a pixel |
| `coverage` | 12.5 % | 14.4 % | the rasteriser and its span scanner |
| `transforms` | 2.5 % | 3.8 % | the matrices, almost all of them inverted per pixel by a gradient |
| `sceneAndLayout` | 0.3 % | 0.1 % | Bloc walking and laying out the element tree |
| `displayList` | 0.3 % | 0.3 % | recording a frame and draining it |
| `pathAndStroke` | 0.2 % | 0.2 % | flattening curves and building stroke outlines |
| `canvasApi` | 0.1 % | 0.1 % | the drawing verbs and the state they keep |
| `compositing` | 0.0 % | 0.0 % | the operators |
| `text` | 0.0 % | 0.0 % | the glyph atlas and the font stack |

The four stages that run per pixel — `pixelAccess`, `paintSource`, `coverage` and `transforms` —
are between 95 and 99 per cent of the frame together.
`text` does not appear at all: the atlas rasterises each glyph once and the glyph then arrives as a
mask, so its cost is counted in `pixelAccess` with every other pixel.
This agrees with the handover measurement of unit 1.1 recorded in section 2.2 above: the bulk copy
of a 3 MB frame is 0.35 ms, about one per cent of what the per-pixel loop costs even there, so the
boundary between object memory and a device is not the problem and never was.

The hottest methods of one sampled frame, by their own samples, say the same thing more precisely.

| Share of the frame | Method |
|---|---|
| 36.2 % | `VGCairoSurfaceFormat >> maskByteForCoverage:` |
| 12.4 % | `VGRasteriser >> addOverlapFrom:to:into:startingAt:` |
| 8.7 % | `VGCairoSurfaceFormat >> pixelForRgba:` |
| 8.3 % | `VGCairoSurfaceFormat >> shortOf:` |
| 5.7 % | `VGPaint class >> extendFor:` |
| 4.8 % | `VGColorPaint >> quantise:in:` |
| 3.8 % | `VGLinearGradientPaint >> offsetInPaintSpace:` |
| 3.5 % | `VGCairoMatrix >> value:` |
| 2.1 % | `VGCairoSurfaceFormat >> mixPixel:weightedBy:withPixel:weightedBy:` |
| 1.8 % | `VGPaint class >> nameIn:for:` |

More than half of the frame is four methods of one class, `VGCairoSurfaceFormat`, each of them a
few lines of integer arithmetic sent once per pixel.
That is what phase 2 attacks first, and it is also the shape of the work a shader does for nothing:
the mask byte, the quantisation and the blend are per-fragment arithmetic, and the span loop that
calls them is a fragment shader over the covered area.
Two of the ten are lookups rather than arithmetic — `VGPaint class >> extendFor:` and
`nameIn:for:` resolve a name per pixel, 7.5 per cent of the frame between them — and those are
cheap to hoist out of the loop inside phase 1, whenever the loop is touched for another reason.

One finding came out of building the scene, and it belongs to the failover rather than to the
profile.
Bloc measures a text span during layout through `BlHostRenderer preferableClass`, and the span keeps
the scaled font that measurement produced.
A scene laid out while that class is Alexandrie's therefore carries Cairo scaled fonts into
whatever canvas draws it later, and drawing it on ours fails with `atlas` not understood.
So `VGFrameProfile` builds a separate scene for each backend, under that backend's renderer class,
and puts the class back in an `ensure:` block; a test holds that it is put back, because it decides
how the whole image draws.
The same rule applies to an application that switches backends at run time: the scenes laid out
before the switch have to be laid out again.

The artefacts: `VGFrameProfileTest` is fourteen tests, `VGFrameProfileExamples` holds two
`<sampleInstance>` examples of a frame small enough to measure in a fraction of a second, and
`VGFrameProfile` carries four gated inspector views — the stages with their shares, samples and
milliseconds, the two frame times with the ratio divided rather than written down, and both frames
as images, so a scene that drew on one backend and not on the other is visible as such.
`VGFrameProfile class >> reference` is the configuration the numbers above were measured with, and
`report` is the table.
Critics are clean on everything written here except `ReBlocDoNotSendForceLayoutRule` on
`VGFrameProfile >> newScene`, which is accepted: the scene is never attached to a space, and
forcing the layout of a detached element is what `BlElement >> aeAsForm` does as well.
`VectorGraphics-Cairo-Tests` and `VectorGraphics-Bloc-Tests` together are three hundred and twelve
tests and pass.

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

**Done.** The mesh is four classes: `VGCairoMeshPattern` carries Alexandrie's own vocabulary
(`beginPatch`, `moveToX:y:`, `lineToX:y:`, `curveViaX:y:viaX:y:toX:y:`, `cornerAt:putColorRGB:`,
`endPatch`), `VGCoonsPatch` evaluates one patch, `VGMeshPaint` is the paint the backend reads, with
tag four of `cairo_pattern_type_t`, and `VGMeshRaster` is the picture a mesh is rasterised into
before anything composites it.

The unit was not a matter of writing the Coons formula down.
Bilinear colour over the Coons surface is the easy half, and three rules of Cairo's rasteriser had
to be measured from the live library because no formula gives them.

The first is that a mesh has no antialiasing at all.
Cairo walks a patch over a grid of its two parameters and writes a whole pixel for every sample, so
a pixel a patch reaches is opaque and a pixel it does not reach is untouched, whatever fraction of
the pixel the patch really covers.
A sample lands in the pixel whose unit square contains it, which is the truncation of its
coordinates, so the far edge of a patch contributes a row of pixels and the near edge does not: a
four by four square patch on a seven by seven surface paints a five by five block.

The second is which sample a pixel keeps where a patch covers it once.
Cairo subdivides a patch until a piece of it is about a pixel across and writes the colour of the
middle of that piece, so the colour of a pixel is the colour of the surface near the middle of the
pixel, not at its corner and not at the end of a walk.
Measured on that square probe: the pixel at the origin is 223, 55, 4, which is the parameter pair
one eighth, one eighth — the centre of the pixel — and the pixel at the far edge is 0, 224, 31,
which is the first parameter exactly one.

The third is what happens where a patch folds over itself.
Two pieces far apart in the parameters then reach the same pixel, and Cairo draws the lower
parameters first, so the later piece keeps the pixel.
Measured on a patch whose first and third sides are one loop out and back again and whose colours
mirror the fold: forty-nine pixels painted, every one of them greener than red, the column at the
start of the fold 0, 255 and the column at its apex 128, 128.

Our raster implements the second and third together, because they disagree about what to do with
two samples of one piece.
Samples within `VGMeshRaster class >> sameBranchSteps` grid steps in both parameters count as one
piece of Cairo's and are arbitrated by distance to the centre of the pixel; samples further apart
than that are arbitrated by which comes later.
Four steps of a walk whose pitch is half a pixel is two pixels, which is wider than any one pixel
can be reached from.
The boundary walk of the four sides deliberately keeps the grid's step counts rather than its own
finer ones, or an edge sample would present itself as a later piece and take a pixel from the
interior sample that belongs to it.

What is left is the hard edge itself, one pixel wide, and it is a step rather than a shade, so the
two rasterisers disagree about the whole colour of the ring of pixels the edge of a patch grazes
while agreeing closely everywhere else.
A single worst-channel tolerance cannot express that, so the gate of a mesh case is a colour
tolerance of eight with a count of the pixels allowed past it.
`VGFormComparison` therefore keeps the whole distribution of channel distances, a tally of two
hundred and fifty-six slots, and answers `pixelsFartherThan:`; the old maximum test is the same
question with a count of zero, so no verdict held before this unit changed.

Gate, both corpora.
The five mesh cases derived from the Alexandrie experiments —
`CanonicalGradientAllQuadrantPattern`, `CanonicalGradientFirstQuadrantPattern`,
`CoonsPatchMeshPattern`, `GouraudShadingTriangleMesh` and `meshPattern` — all answer
`matchesCairo`, at a tolerance of eight with boundary counts of 1230, 50, 25, none and 18 against
measured 1118, 45, 22, none and 16.
The largest case is classified rather than waved through: of its 1118 pixels, 995 are on the arc the
patches share with the stroked circle beneath them, 48 on the axes the four patches share with each
other, and 10 beside the degenerate corner where all four collapse, the worst of them 19.
Four cases of our own corpus cover the four shapes a patch can take — straight sides, three sides,
curved sides, and sides that fold the patch over itself — and measure 0, 6, 10 and 0 pixels past
eight, allowed 0, 7, 11 and 0, with worst channels of 4 and 2 on the two cases that need no
allowance at all.

The artefacts: `VGMeshTest` is nine tests, `VGMeshExamples` holds five `<sampleInstance>` examples,
and four gated inspector views say what the measurements above say — the patches of a pattern with
their corner and middle colours, the surface of one patch read at a grid of both parameters, what a
compositor reads along the diagonal of a paint, and the raster as a map of the pixels it painted and
those it left alone, which is where the hard edge is visible as such.
`VGFormComparison` gained a fifth view for the distance tally.
The two test packages together are three hundred and twenty-six tests and pass; a count taken from
`testSelectors` alone reports five fewer, because `VGBlocExamplesTest` defines no test of its own
and inherits the five of `VGCairoExamplesTest`.
Critics are clean on everything written here except `ReExcessiveArgumentsRule` on
`cornerAt:putR:g:b:a:` and `curveViaX:y:viaX:y:toX:y:`, which is the same accepted case as every
other parity selector of this shape in `VGCairoContext`: the name is Alexandrie's and a failover
layer may not rename it.

A mesh is slow: the largest Alexandrie case takes seventeen seconds and an ordinary one about four,
against milliseconds for Cairo, because every patch is sampled on a walk of half a pixel in device
space and the samples are written one at a time.
That is a correctness-first implementation and phase 2 is where it is answered; nothing in phase 1
depends on it being fast, because Bloc never asks for a mesh.
The cost is visible in the suite rather than in a drawing, because `VGAlexandrieCase >> ourForm`
renders on every send and is not memoised, so each test that walks the Alexandrie corpus —
`VGCairoExamplesTest >> exampleSubjects` and `VGConformanceTest >> coveredUnits` both rebuild
`VGAlexandrieCorpusExamples class >> casesWaitingOnAUnit` — renders every case again, and those
suites now take minutes per test.
Memoising the form is a design change with its own invalidation question, so it is reported here and
left to a decision rather than slipped into this unit.

### 1.13 — the Alexandrie font facade

Unit 1.8 built the font stack and unit 1.10 wired it into the canvas, so the replacement rasterises
text today: `VGFontFace` reads the font's own tables, `VGScaledFont` answers metrics, glyph outlines
and an atlas of masks, `VGFontOptions` carries Cairo's four rendering options, and `VGCairoContext`
draws a run through `scaledFont:`, `showGlyphs:`, `showText:` and `appendGlyphsPath:`.
Five experiments of the Alexandrie corpus nevertheless do not run — `fillPaint1`, `fillPaint2`,
`textAllGlyphsInFontFace`, `textWithoutHarfbuzzWithFontManager` and
`texWithHarfbuzzWithFontManager` — and what blocks them is naming, not capability.
Each builds its font the way Alexandrie's own API is spelled, and that spelling has no counterpart
here: `AeCairoFontOptions new`, `AeCairoFreetypeFontFace newForFace:` over the face the font manager
answers, `AeCairoScaledFont fontFace:fontMatrix:userToDeviceMatrix:options:` or the
`newScaledFontWithFontMatrix:userToDeviceMatrix:options:` form of the same thing, and the four
enumeration classes `AeCairoAntialias`, `AeCairoHintMetrics`, `AeCairoHintStyle` and
`AeCairoSubpixelOrder`.
`VGAlexandrieCorpus class >> ourNameFor:` maps a class name mechanically, `AeCairoX` to `VGCairoX`,
and the font classes of this package are named for what they are rather than for Cairo, so the map
answers nothing for them and the five cases stay filed as blocked against a unit that is done.

The unit closes that gap and nothing else.

- Four enumeration classes — `VGCairoAntialias`, `VGCairoHintMetrics`, `VGCairoHintStyle` and
  `VGCairoSubpixelOrder` — each answering Cairo's own value names, which is how `VGCairoOperator`,
  `VGCairoStatus` and `VGCairoSurfaceFormat` already name an enumeration of Cairo's. Each reads its
  names from the array `VGFontOptions` already holds, so a name cannot drift between the two, and
  each answers the symbol `VGFontOptions class >> nameFor:in:` accepts; that method already takes a
  symbol of ours, Cairo's integer code or Alexandrie's own value, so no setter changes.
- `VGFontFace class >> newForFace:`, which takes the `AeFTFace` the font manager answers and gives
  back the face for its bytes. The resolution exists already, as `VGCanvas class >>
  faceForFreeTypeFace:` and `bytesForFamilyName:styleName:`: it moves down to `VGFontFace`, where a
  caller holding no canvas can reach it, and the canvas keeps its cache and delegates.
- `VGFontFace >> newScaledFontWithFontMatrix:userToDeviceMatrix:options:`, the form `fillPaint1`
  uses. `VGScaledFont class >> fontFace:fontMatrix:userToDeviceMatrix:options:` is already spelled
  the way Alexandrie spells it, so the class-side form needs nothing.
- An exception table behind `ourNameFor:`, naming `VGFontOptions`, `VGFontFace` and `VGScaledFont`
  for the three Alexandrie classes whose counterpart does not follow the prefix rule.
- `missingClassUnitTable` then has nothing left to say, and the two stale entries go with it: the
  font classes were filed against unit 1.10, which is done, and `AeCairoAntialias` against 1.4.
  `testEveryFiledMissingClassIsReallyMissing` is what forces that, since a filed class whose
  counterpart now exists is a gap the corpus would keep reporting after it closed.

HarfBuzz stays Alexandrie's, as section 2.3 says: shaping needs no Cairo, and `showGlyphs:` already
reads a shaped run through `asExternalStructure` rather than through a class name of Alexandrie's.
The unit adds no drawing verb, so it owes no case of the plan's own corpus and joins 1.0, 1.2, 1.9,
1.10 and 1.11 in `unitsWithoutAPicture`; what it changes is measured by the five experiments that
now draw.

Gate: every one of the eighty-two experiments is portable, the five derived copies compile and run,
and `missingClassUnitTable` is empty.
Each facade method is held against the behaviour it stands for rather than against its existence:
the face built from an `AeFTFace` reads the same bytes as the face built from the manager's entry,
an options object built through the four enumeration classes equals one built from our own symbols,
and the scaled font the face answers equals the one the class-side constructor answers.
Whether a text experiment then matches Cairo pixel for pixel is measured, not assumed.
Cairo rasterises a glyph through FreeType and hints it there, unit 1.8 recorded that its hinted
advances are not reproducible from outside its own face, and `textAllGlyphsInFontFace` asks for
`hintStyle slight` explicitly, so each of the five is measured and then either carries a stated
tolerance, as the antialiased cases do, or is filed with its reason, as the three cases drawn in
Cairo's toy default font are.

**Done.** The facade is four enumeration classes, two methods that resolve a face and one that
builds a scaled font, and an exception table in the corpus; it added no drawing verb and changed no
rasteriser, and it found two defects by running code that had never run.

`VGCairoAntialias`, `VGCairoHintMetrics`, `VGCairoHintStyle` and `VGCairoSubpixelOrder` sit in the
`Text` tag of `VectorGraphics-Cairo` and answer one value per name, each name read from the array
`VGFontOptions` already holds, so `names` cannot drift from the option it describes and a test asks
each class for a value under every name its option knows and allows it no value beyond them.
`VGFontFace class >> newForFace:` and `VGFontFace class >> bytesForFamilyName:styleName:` are
extension methods in `*VectorGraphics-Bloc`, not methods of `VectorGraphics-Cairo`, because they
name `AeFontManager` and `AeMemoryFaceEntry` and the Bloc package is the only one of ours allowed to
name Alexandrie.
`VGCanvas class >> faceForFreeTypeFace:` keeps its cache and delegates, and
`VGCanvas class >> bytesForFamilyName:styleName:` is gone, so there is one resolution and not two.
`VGFontFace >> newScaledFontWithFontMatrix:userToDeviceMatrix:options:` is the instance-side form
`fillPaint1` uses, and it is held against the class-side constructor rather than against its own
existence: the two answer equal scaled fonts.
`VGAlexandrieCorpus class >> ourNameExceptions` names `VGFontOptions`, `VGFontFace` and
`VGScaledFont` for the three Alexandrie classes whose counterpart does not follow the prefix rule,
and with that `missingClassUnitTable` is empty: every one of the eighty-two experiments is portable
and every derived copy compiles and runs.
A derived copy goes stale when the map changes, and the symptom is not a missing class but a call
into Alexandrie that dies inside it, so `regenerate` belongs to any change of `ourNameFor:`;
`driftingCases` is what reports it.
`progressDescription` now reads `draws already: 82` and nothing else, where unit 1.10 left it at
sixty-nine of eighty-two with eight waiting on 1.10 and five on 1.12.

The first defect was in `VGCairoContext >> strokeDashPattern:size:offset:`.
A drawing that hands the dash pattern over as an external array rather than as a Pharo collection
read one element and used it for all of them, which no case of either corpus had ever done.
The failing test came first and names the shape of the call rather than the case that found it.

The second was the cost of a mask, and it is the reason `textAllGlyphsInFontFace` could not be
measured at all before this unit.
`VGSoftwareBackend >> maskWith:paint:clip:operator:into:` walked the whole clip for every recorded
mask, reading the mask's alpha at every pixel of it, because a clip carries spans and a mask does
not, so the coverage of the clip has to be multiplied into the mask pixel by pixel.
Under a bounded operator a mask byte of zero leaves the destination exactly as it was, so every one
of those reads outside the rectangle the mask covers buys nothing; under an unbounded operator the
whole clip must still be walked, because such an operator writes where the mask covers nothing.
`VGClip >> narrowedTo:` answers the clip inside a rectangle — the same shapes, the same coverage,
and no pixel outside it — and the walk is narrowed to the rectangle of the mask whenever the
operator is bounded.
The difference the picture cannot show, because a pixel left as it was is indistinguishable from a
pixel never read, so the test counts the reads through `VGCountingMaskStub`: a mask of four by four
on a surface of two hundred by two hundred is read at exactly sixteen pixels under `over` and at
every pixel of the clip under `in`.
Measured on the corpus: `textAllGlyphsInFontFace`, nineteen hundred glyphs on ten thousand by
eighty-eight, had drained two hundred of its three thousand two hundred and forty-one display-list
entries after forty minutes and now renders in 7.8 seconds; the two paragraph cases fell from 2.35
seconds to 0.49.

The glyph verdict is a tolerance with a count, as a mesh is.
Cairo rasterises a glyph through FreeType, which grid-fits the outline to the pixel grid before
filling it, and this package fills the outline the font carries, so every stem stands a fraction of
a pixel from Cairo's and is a whole shade different down its length — a disagreement about where the
stem is, not about how much of a pixel it covers.
Unit 1.8 already recorded that it cannot be closed from outside Cairo's own face.
The five cases therefore carry `hintedGlyphRunTolerance`, which is the thirty-six the atlas cases of
our own corpus already carry, and a count in `hintedGlyphRunPixelTable`: 522, 205, 1382, 1063 and
38404 against measured 474, 186, 1256, 966 and 34912, each a tenth above its measurement as the mesh
counts are.
That the bound has to be a count and not a distance is visible in the distribution: 94, 26 and 4477
of those pixels are more than a hundred and twenty-eight apart, which is most of a channel.
The stray alpha is nought in all five, so the corpus's own allowance of one step of coverage holds
and only the mesh cases still need their own.
`boundaryPixelAllowanceFor:` reads both tables, which name disjoint experiments because a mesh
carries no text.
Two tests hold the rule rather than the list: one selects the cases whose ported source both selects
a font and sends a text verb and requires exactly those to carry the glyph tolerance and a count,
and the one unit 1.8 left requires every case that draws text without selecting a font to be filed
against Cairo's toy default face instead.

Two examples and two views say what the unit changed.
`VGScaledFontExamples class >> scaledFontBuiltTheWayCairoSpellsIt` builds the scaled font of
`scaledFontAtAReadableSize` the way a drawing written against Alexandrie builds one — the options
named through the four enumeration classes and the font asked of the face — so the facade is one
click away from the browser, and `VGFontOptions >> inspectorNames:` puts each of the four options
beside the class that names its values and the value that class answers for the name the options
hold, asking the real enumeration so that a name this package stops knowing reads as `answers no
such name` rather than as a row that still looks right.
`VGClipExamples class >> maskSizedNarrowingOfACircularClip` narrows the clip of `clipOfACircle` the
way the backend narrows it for a mask the size of a glyph, and `VGClip >> inspectorMaskWalk:`
counts what one mask costs through a clip by walking the real clips rather than by reading their
bounds, so it cannot drift from the backend: the circular clip passes 1600 pixels and the same clip
narrowed to sixteen square passes 256.
The view is gated off for a clip of no area, which passes nothing anywhere and so has no walk to
measure.

The two test packages together are three hundred and thirty-nine tests and pass, thirteen of them
new here; a count taken from `testSelectors` alone still reports five fewer, because
`VGBlocExamplesTest` defines no test of its own and inherits the five of `VGCairoExamplesTest`.
`VGCountingMaskStub` is filed in a new `Fixtures` tag of `VectorGraphics-Cairo-Tests`, which is
where a stub a test builds belongs and what `ReClassNotCategorizedRule` asks for.
Critics are clean on everything written here except `ReExcessiveArgumentsRule`, `ReLongMethodsRule`
and `ReCyclomaticComplexityRule` on `maskWith:paint:clip:operator:into:`, which are the same three
its sibling `rasterise:paint:clip:operator:into:` already carries: the two are the backend's two
composite loops and the arguments are the display list's own entry.
`VGFontFace` carries `ReExcessiveVariablesRule` for the thirteen instance variables unit 1.8 gave
it, one per table it reads; this unit added none of them.

Gate met on both counts.

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

**Done.** Selection and recovery are the seventeen class-side methods of `VGBackend`'s own
`selection` protocol, one exception class, a handler in `VGCairoImageSurface >> flush` and a backend
whose probe really computes; no drawing verb changed and no rasteriser was touched.

`VGBackendFailure` sits in the `Backend` tag of `VectorGraphics-Cairo` and carries the backend that
raised it, because the recovery rejects a backend by class and has to know which one failed.
A backend may raise it while a frame is recorded or while it is drained, never between its first
pixel and its last: a frame half drawn cannot be mended by replaying it elsewhere, and the software
backend already keeps that rule by recording into `commands` during replay and writing pixels only
in `drainInto:`.

Selection is class-side state of `VGBackend` and reflection over its own subclasses, so
`VectorGraphics-Cairo` still names no Vulkan class.
What selection decides is a class, and not an instance.
`candidateClasses` answers the subclasses that declare `isCandidate`, minus the rejected ones,
ordered by the `preferenceRank` each declares — `hardwareRank` is 100 and `softwareRank` is 1000,
which is the highest of the scale, so nothing is probed after the failover.
`preferredClass` answers the first candidate whose `probe` answers an instance and remembers that
class, and a probe below the first that answers is never run, because a probe costs a device and a
dispatch: the Vulkan one measures 72 ms on an idle machine and 8.275 s on a loaded one, which is
reason enough to remember the verdict for the rest of the session.
`preferred` answers `self preferredClass new`, a fresh instance on every send, and the surface that
asked keeps it, because a backend records in itself the frame it is draining and two surfaces may
not share that.
A mask surface and a group surface still take the backend instance of the target they belong to,
which is sharing of another kind: it happens while the target records and never while it drains.
`prefer:`, `clearPreference`, `preferredClassOrNil` and `restorePreference:rejections:` are what a
test and a caller who knows the machine use, and `rejectedClasses` answers a copy: the first version
answered the set itself, a test saved that very set in `setUp`, the rejection it caused was in it
again at `tearDown`, and the Vulkan backend stayed out of selection for the rest of the session.

A failed frame is replayed on `VGBackend failover`, which is the software backend and not whichever
candidate ranks next, because a recovery may not fail in its turn.
Section 8 above sketched the cache being cleared so that the next frame goes to software; with more
than one accelerated candidate that is what it has to mean, and the surface keeps the failover
afterwards, so a frame of its own is never attempted twice on a backend that has already given up.
The display list is reset after the drawing and not before it, which is what lets the same frame be
replayed, and `drawRecordedFrameOn:` is the one place that replays and drains.

The whole-project run found the defect this unit introduced, and it was in the instance.
The first version of `preferred` answered one backend to every surface that asked for one.
Replay and drain look like one uninterrupted go until a paint reads a pixel: reading a pixel of a
surface flushes that surface, so draining one frame starts the drain of another, and two drains
through one instance replayed each other's commands to a stack depth of 9999.
Every frame that reads a surface as a paint source hung — masks, surface patterns, the profiling
scenes and four conformance cases — and `VGRendererTest` sat for eighty-five minutes before the
stacks of the live processes named the recursion.
Two tests came first and were seen red: one requires two surfaces with no backend of their own to
hold different instances of one class, and one draws a surface pattern of one surface onto another
and requires the frame to end, with the pixel it copied in place.

The probe is a real dispatch.
`VGVulkanBackend class >> probe` compiles the compute path's own example kernel through
`PVComputeKernel fromMethod: PVComputeKernel exampleKernelMethod`, allocates its three storage
buffers, hands the same vector of small whole floats to both inputs, dispatches one workgroup and
compares the readback with the sums for equality rather than for closeness, because those values
are exact in a 32-bit float both as terms and as sums.
It answers an instance where that works and nil where it does not, catches every class of fault a
driver can arrive as, and destroys the kernel before the buffers, since a buffer freed under a live
pipeline takes the image with it.
On this machine it answers in 72 ms and the device computes, so the first frame of the session
really is handed to the Vulkan backend, really fails, and really comes back correct on software:
the gate is met by the backend and not only by the stub.
Its three boundary messages raise through `cannotDrawYet` until unit 2.3 gives it pixels to write.
It names classes of `PharoVulkan-Core` and `PharoVulkan-Compute` only, and reaches the compiler and
the SPIR-V builder through them, which is within the edges section 4 states for this package.

`VGCairoReferenceScanner` grew the general form of the scan it already did: `classesNamedBy:
inPackagesNamed:` walks `allLiterals` for variable bindings whose class belongs to any of a set of
packages, `offendersIn:naming:` answers the offending methods of one package, and
`cairoClassesNamedBy:` and `offendersIn:` are those two with the Cairo package named.
`vulkanPackageNames` reads the organiser for every package beginning with `VectorGraphics-Vulkan`
or with `PharoVulkan`, so a package added later is covered without the method being edited.
Two architecture tests hold the rule rather than a list: no package of this project but the Vulkan
family names one of those classes, and every package of this project is named in the baseline.

Three packages are new.
`BaselineOfVectorGraphics` gives them a `vulkan` group and leaves that group out of `default`, so
the engine loads and runs on a machine with no driver, which is rule seven of section 9 read from
the other side.
The baseline does not declare `PharoVulkan` itself: that project is loaded from a local checkout,
and a path in a committed baseline would be wrong everywhere but here, so the `vulkan` group is
loaded after `PharoVulkan` is.
`VGVulkanBackend` is filed in a `Backend` tag of its package and
`VGFrameProfile class >> stageByPackageAndTag` gains the two keys the new packages bring —
`VectorGraphics-Vulkan/Backend` is display-list work and `VectorGraphics-Vulkan-Examples/Examples`
is not in the frame — because a test of unit 1.11 requires every package and tag of this project to
name a stage, and no key beyond them.

The fixtures are three.
`VGBackendFrameFixture`, in the `Fixtures` tag of `VectorGraphics-Cairo-Tests`, holds the one frame
the backend tests draw and answers it as a `Form`, because the selection tests of the engine and the
backend tests of the Vulkan package compare the same picture and it has to be the same picture.
`VGBrokenBackendStub` fails while the frame is recorded and `VGFailingDrainBackendStub` records the
whole frame and fails when it is drained; they are the two halves of the gate, and the second
declares `isCandidate` false, because it inherits from the software backend and selection must never
choose a fixture.

The example and the view both ask the real rule.
`VGBackendExamples class >> selectionOnThisMachine` forgets the preference, probes again and answers
`VGBackend`, whose class-side `Selection` tab lists every backend of the hierarchy with the rank it
declares, whether it stands for selection, whether a failure rejected it and whether it is the one
drawing — all read from the live state, and nothing probed, so opening the tab opens no device.
`VGVulkanBackendExamples` holds the other two: `probedOnThisMachine`, which probes for real, and
`frameRecoveredFromTheVulkanBackend`, which draws a frame through the backend and lets the failover
finish it, putting the selection state back afterwards because the recovery rejects what failed.
`VGVulkanExamplesTest` subclasses `VGCairoExamplesTest` and names only the holders of its own
package, so the five example rules — a comment on the holder, an example that rebuilds its object,
an example that runs and answers something, a gate on every view and a view that builds and fills
its cells — hold here too without being written twice.

Twenty-two tests are new: thirteen on selection and recovery in `VGBackendSelectionTest`, four on
the Vulkan backend in `VGVulkanBackendTest` and the five the example rules give
`VGVulkanExamplesTest` for free.
The gate is met twice over, by the fixtures and by the hardware: with the preference cleared, the
twenty-seven drawing tests of `VGCairoDrawingTest` probed the Vulkan device, took its failure on the
first frame, rejected the class and drew every one of the twenty-seven frames on software, and
`rejectedClasses` holds `VGVulkanBackend` afterwards.
The whole project is green afterwards at 579 tests over forty-eight test classes: 312 in
`VectorGraphics-Cairo-Tests`, 214 in `VectorGraphics`, 44 in `VectorGraphics-Bloc-Tests` and 9 in
`VectorGraphics-Vulkan-Tests`.
Critics are clean on all three new packages, on `VGBackendFailure` and on the tests and the fixture,
except `ReExcessiveArgumentsRule` on `VGVulkanBackend >> blitSurface:at:paint:clip:operator:`, which
is the frozen boundary selector and is accepted on `VGBackend` and `VGSoftwareBackend` for the same
reason.

Gate met.

### 2.1 — the go or no-go gate

Measure three numbers on this machine: buffer upload bandwidth, fill rate for a trivial coverage
shader, and readback latency for a full frame.
Compare the sum against the unit 1.11 profile.

Gate: if a GPU round trip costs more than the software path for a typical Bloc frame, stop here and
record why.
This gate is not a formality.
Readback is the known risk, because section 2.2 shows the frame ends in host window memory, and the
path back from device memory can swallow the whole win.


**Done. Go.** One frame through the device costs 0.93 ms on this machine against 2098 ms for the
same frame on the software path and 1.38 ms for Cairo, so the round trip is not only cheaper than
the path it replaces, it is cheaper than the C library both paths are measured against.

The measurement is a class rather than a script, because a number nobody can re-run is not
evidence.
`VGVulkanRoundTrip` sits in a new `Budget` tag of `VectorGraphics-Vulkan` and holds the three
numbers, the software frame they are compared with, the device they were measured on and the reason
there is none where there is none.
Its extent is asked of `VGFrameProfile referenceExtent` and never written down again, so the two
sides of the comparison are the same 800 by 600 picture by construction, and `reference` builds the
measurement without running it: `run` measures the device, `measureSoftwareFrame` measures the
software frame, and `runGate` does both.
`recordUpload:fill:readback:` is the only way the numbers get in, which is why no test needs a
setter and why a partial measurement cannot exist: `roundTripMilliseconds` answers nil until all
three are known, and `verdict` answers `#unknown` until the software side is known as well.
The three rates — megabytes a second out, megapixels a second filled, megabytes a second back — are
the frame over the time, so they cannot be read the wrong way round, and a test halves the
milliseconds and requires each rate to double.

Each number is the mean of ten passes with one warm-up pass thrown away, read from the microsecond
clock and not from `Time millisecondsToRun:`, because a copy of one frame finishes inside a
millisecond and a step measured as zero would read as infinitely fast.
`VGVulkanCoverageKernel >> coverageOf:out:` is the fill: a `<gpu>` method that writes full coverage
at one work item per pixel, which is the cheapest kernel that still touches every pixel, so the
number is the rate of the write and not of any arithmetic.
The dispatch is sized from the kernel's own `localSize` through `PVTypeAnnotation`, never from a 64
written here, and `PVComputeKernel >> dispatch:y:z:` waits on the queue, so the host clock around it
measures the whole dispatch, including the command buffer it allocates and the submit.
The kernel is destroyed before the buffer, since a buffer freed under a live pipeline takes the
image with it.

The measured numbers, on an Intel Iris Plus Graphics (ICL GT2) with the frame of unit 1.11:

| Step | Time | Rate |
|---|---|---|
| upload, 1.83 MB | 0.242 ms | 7563 MB/s |
| fill, 480 000 pixels | 0.565 ms | 850 Mpixel/s |
| readback, 1.83 MB | 0.122 ms | 14 984 MB/s |
| round trip | 0.929 ms | — |
| software frame | 2403 ms | — |

Three further runs gave 1.014, 0.927 and 1.012 ms, so the total is stable to about a tenth of a
millisecond, and the software frame measured 2098 ms in a second session with Cairo at 1.38 ms.
Readback was the known risk of this unit and it is the cheapest of the three steps here, because the
device is integrated and its memory is host visible: the frame never leaves the memory the window
will read it from.
That is a result about this machine and not about Vulkan.
On a discrete card the readback crosses the bus and section 2.2 would have to be read again with a
staging buffer and an explicit transfer in hand; the gate is therefore recorded with the device
named, and a machine that answers `#noGo` stops at this unit rather than arguing with it.

The copy is made with `LibC memCopy:to:size:` against the mapped block, not with VkBuffer's own
`copyFromByteArray:`.
That method writes the bytes one at a time from Smalltalk and costs 31 ms for this frame against
under a millisecond for the memcpy, so measuring through it would have measured the interpreter
rather than the bus.
Thirty-one milliseconds is still two orders of magnitude under the software frame, so the verdict
holds either way, but a path that pays it every frame would give back a third of the win of unit
2.3 before any pixel is composited: the binding's own copy stays as it is, and the Vulkan backend
uses the memcpy.

Twelve tests are new in `VGVulkanRoundTripTest`, and three of them are the degenerate states: an
unmeasured round trip has no total and no verdict, a round trip with no software frame beside it has
no verdict either, and `VGNoDeviceRoundTripStub` — which overrides `newContext` alone and records
its own reason — proves that a machine with no device answers why and measures nothing.
`testTheRoundTripOnThisMachineIsThreePositiveNumbers` measures this machine for real and passes on a
machine with no driver by requiring the reason instead, because the gate is about the machine and
not about the code.
Every driver fault is caught where the context is opened or where the frame is measured, and the
reason recorded is the error's own text or, where it carries none, its class name.

`VGVulkanRoundTripExamples` gives one click for each: `roundTripOnThisMachine` runs both sides of
the gate and `coverageKernel` answers the kernel class.
The `Budget` tab of a round trip lists every row of the report the verdict is computed from, so it
cannot say go while the numbers say otherwise, and the `Kernel` tab of the kernel class reads the
local size and the parameters from the annotation and the module size from a fresh compilation,
which is why neither tab can drift from the code.
Neither opens a device.
`VGFrameProfile class >> stageByPackageAndTag` gains the `VectorGraphics-Vulkan/Budget` key as
`notInTheFrame`, because the measurement weighs a frame and never appears inside one.

The project is green afterwards at 591 tests over forty-nine test classes, twenty-one of them in
`VectorGraphics-Vulkan-Tests`, and critics are clean on the three Vulkan packages except
`ReExcessiveArgumentsRule` on the frozen boundary selector `blitSurface:at:paint:clip:operator:`,
which is accepted on `VGBackend` and `VGSoftwareBackend` for the same reason.

Gate met. Unit 2.2 proceeds.

### 2.2 — tile binning on the CPU

Bin the display list into tiles in Pharo first.
Binning is cheap, it is testable without a GPU, and it decides whether the GPU path is one dispatch
or thousands.

Gate: a binning test over the corpus, and a count of tiles touched per case.

**Done.** Binning is three classes in a new `Tiles` tag of `VectorGraphics-Vulkan` — `VGTileGrid`,
`VGTileBinning` and `VGTileBinningCensus` with its row — and it reads a recorded frame without
drawing one, so the whole unit runs on a machine with no driver.

A grid is row-major and one based, the last column and the last row are short wherever the extent
does not divide by the tile, and its tiles cover every pixel of the extent exactly once: a pixel in
two tiles would be composited twice and a pixel in none would never be written, so a test walks a
grid of 37 by 23 pixels tile by tile and requires each pixel once.
`indexesIntersecting:` widens a box to whole pixels before it reads it, because a box in device
space carries fractions from a transform and a pixel covered in part is a pixel written; nothing,
a box of no width and a box off the frame touch no tile at all, since a tile touched for one of
those is a dispatch over pixels no entry writes.

A binning asks each entry for its own bounding box and adds the entry to every tile that box
reaches, in the order the entries were drawn, because compositing is not commutative.
It copies the entries out of the display list, because draining a frame resets its list and the
census reads its counts after the frame is drawn — the first version held the list and reported
zero entries for every case.
An entry that spans a boundary is in every tile it spans, so `binnedEntryCount` is larger than the
number of entries drawn; that growth is what the tile size trades against the number of dispatches.

The gate does not read a bounding box at all.
For each frame the census draws the frame on the software path, compares every pixel against a
surface nothing has drawn on, and counts the pixels that changed and lie in no tile the binning
touched; a box that is too small cannot hide from that.
A new ARGB32 surface is not all zero — its pixels read as transparent white — so the comparison is
against a blank form and not against zero: the first version compared against zero and reported
2560 stray pixels for a case whose frame had written nothing outside its rectangle.
Over the 41 conformance cases the count is zero.
It is not zero for want of anything to find: binning the same frames into an empty binning makes the
same scan report 75 234 stray pixels over 40 of the 41 cases, the one exception being
`target-cleared-to-transparent`, which writes nothing visible.
The second half of the gate is the count of tiles touched per case, which is the `Cases` tab of the
census and a test over every row.

The corpus does not decide the tile size, and saying so is the point of `overTheReferenceFrame`.
A conformance case is 64 pixels square and touches 92 % of its own tiles at any size.
The frame unit 1.11 profiles is 800 by 600, drawn through the Bloc renderer with gradients, strokes,
glyphs and blits in it, and it is the frame a tile size is for:

| Tile | Tiles | Entries drawn | Entries binned | Per touched tile | Busiest tile |
|---|---|---|---|---|---|
| 8 by 8 | 7500 | 88 | 14 436 | 1.92 | 5 |
| 16 by 16 | 1900 | 88 | 3 803 | 2.00 | 6 |
| 32 by 32 | 475 | 88 | 1 167 | 2.46 | 8 |

Every tile of that frame is touched at every size, because the scene fills its background.
So the choice is between dispatches and repeated work: eight costs 924k entry-pixels and 7500
dispatches, sixteen costs 973k and 1900, thirty-two costs 1.195M and 475.
`defaultTileExtent` is 16 by 16 — a twentieth more repeated work than eight for a quarter of the
dispatches, and 256 work items, which is a whole multiple of the 64 a workgroup of the coverage
kernel holds. A test holds that last fact against `VGVulkanRoundTrip class >> workItemsPerGroup`,
so a tile can never be chosen that leaves part of a workgroup idle.

One defect was fixed first, with its own failing test in `VGCairoOperatorTest`.
`VGFillEntry >> boundingBox` answered the box of its own edges under every operator, but `in`,
`out`, `destIn` and `destAtop` take the destination away where the shape covers nothing.
A 10 by 10 fill under `in` cleared the pixel at 35 @ 25 of a 40 by 30 frame while the entry claimed
`(5 @ 5) corner: (15 @ 15)`.
Binning reads that box, so those tiles would have gone unwritten.
It now answers the whole clip under an unbounded operator, which is the rule `VGBlitEntry` already
kept, and `VGCairoOperator >> isUnbounded` is asked rather than a list restated.

Two declarations were owed.
`VGFrameProfile class >> stageByPackageAndTag` gains `VectorGraphics-Vulkan/Tiles` as display-list
work, because a test of unit 1.11 requires every package and tag of this project to name a stage.
`BaselineOfVectorGraphics` now has `VectorGraphics-Vulkan` require `VectorGraphics-Bloc` rather than
`VectorGraphics-Cairo`: the dependency has existed since unit 2.1, where the budget reads
`VGFrameProfile referenceExtent`, and the census draws the reference frame through `VGRenderer` and
`VGCanvas`. No package of `VectorGraphics-Bloc` names a Vulkan class, which unit 2.0's architecture
test holds, so the edge is one way.

Thirteen tests are new: twelve in `VGTileBinningTest` and the one in `VGCairoOperatorTest` that
reproduced the bounding box defect.
`VGTileBinningExamples` holds three `<sampleInstance>` examples — the grid of the reference frame,
two distant shapes binned, and the census of the reference frame — and the corpus census stays in
the test, because the corpus is a test package and an examples package may not name one.
Five tabs: `Tiles` on a grid, `Binning` and `Busiest tiles` on a binning, `Cases` and `Census` on a
census, each gated and each reading the live object rather than a stored report.
Critics are clean on the three packages but for the accepted `ReExcessiveArgumentsRule` on
`VGVulkanBackend >> blitSurface:at:paint:clip:operator:`.
The suite is 604 tests over 50 concrete test classes and every one passes: 313 in
`VectorGraphics-Cairo-Tests`, 214 in `VectorGraphics`, 44 in `VectorGraphics-Bloc-Tests` and 33 in
`VectorGraphics-Vulkan-Tests`.
One example was wrong and this unit found it: `VGDisplayListExamples class >> fillEntryOfAStar`
built its entry with the symbol `#over` where the recorded frame carries the operator object, so the
entry's own `Fill` tab raised when the bounding box asked the operator whether it is unbounded.
The example now names `VGCairoOperator over`, and it was the only place in the project passing a
symbol there.

Gate met. Unit 2.3 proceeds.

### 2.3 — the tiled fill rasteriser

Fill only, no stroke and no text: strokes are paths after unit 1.4 and text is blits after unit 1.8,
so fill is the whole of the hot work.
One dispatch per frame, coverage accumulated per tile.

Gate: every fill corpus case matches the software backend, which is the oracle, not Cairo.
The software backend already matched Cairo in phase 1, so matching software is both necessary and
sufficient.

**What the corpus asks for, measured before any code.**
Twenty-two of the forty-one conformance cases are fills of a solid colour under a rectangular clip,
which is the subset this unit draws on the device; the other nineteen carry a gradient, a surface or
a mesh paint, a blit, or a clip cut by a shape, and they belong to units 2.4 to 2.6.
Those twenty-two use three operators — `over`, `source` and `clear` — both fill rules, both
antialiasing modes, one to three entries a frame, at most 216 edges in an entry, and every one of
their clips is a whole-pixel rectangle.
Anything outside that subset raises `VGBackendFailure` and the frame is finished by the software
backend, which is the recovery unit 2.0 built and tested.

**The five steps, in order.**

The kernel is hand-built SPIR-V and not a `<gpu>` method, for the reason `PVTiledMatmulKernel`
already records: the structured control flow recogniser handles one loop per kernel, and a
rasteriser nests four — the entries of a tile, the fifteen sub-rows of a pixel row, the crossings
inside a pixel, and the edges scanned to find the next crossing.
Section 4 names `PharoVulkan-SPIRV` an allowed dependency of this package and calls its contents
the coverage and paint shaders, so this is where such a shader belongs.

1. The algorithm on the CPU, in plain Pharo, over `Float64`: one class walks a tile's pixels, finds
   coverage without sorting and without a scratch array, quantises it as the format does and
   composites with the operator the entry carries. Gate: byte-identical to the software backend on
   all twenty-two cases. This is the step that proves the algorithm rather than the device, and it
   needs no GPU.
2. The frame encoding: the flat buffers the kernel reads — the tile table, one header an entry with
   its source pixel, operator, fill rule, antialiasing mode, alpha byte and clip rectangle, and the
   edges. Gate: the step 1 rasteriser driven from the encoded buffers alone draws the same pixels,
   which is what proves the encoding carries everything.
3. The kernel: the step 1 walk translated instruction by instruction into a hand-built module, one
   workgroup a tile and one invocation a pixel, no atomic anywhere. `SpvOpcode` is missing the
   conversion, shift and bitwise opcodes a rasteriser needs, and `GlslStd450` is missing the minimum
   and maximum; those belong to `PharoVulkan`, with their own tests there, as the note under unit
   2.6 already requires for `OpTypeImage`.
4. The backend: `VGVulkanBackend` records a frame, drains it through the encoding and the dispatch,
   and writes the pixels back; an entry outside the subset fails the frame rather than drawing it
   wrongly, and the software backend finishes it.
5. The gate: every one of the twenty-two cases compared with the software backend on the same frame.
   The device computes in `f32` where the rasteriser computes in `Float64`, so the two agree exactly
   wherever coverage is nothing or everything and may differ in the last place on an antialiased
   edge; the tolerance and the count of pixels allowed past it are measured and stated, as units
   1.12 and 1.13 state theirs.

**Done.** The device draws the subset, and it draws twenty-one of the twenty-two cases byte for
byte as the software backend draws them, the twenty-second differing on one pixel by one in one
channel.
Five classes carry the unit in the `Tiles` tag of `VectorGraphics-Vulkan`: `VGTileCoverage` and
`VGTiledFillRasteriser` are the algorithm, `VGTiledFillEncoding` is the frame written out flat,
`VGSpirvVocabulary` and `VGTiledFillKernel` are the module, and `VGTiledFillDispatch` is one frame
on the device.
`VGTiledFillTest` holds all five steps in thirty-five tests, of which two need a device and the rest
run on any machine.

**Step 1, the algorithm.** `VGTileCoverage` answers the part of one pixel a recorded fill covers
with no sorted array of crossings and no scratch buffer: one scan of the edges for the winding at
the left of the pixel, and one scan more for each run after it.
Its gate is not a picture but a float: it sums the same terms in the same order over the same
fifteen sub-rows `VGRasteriser` samples, so the two answer the same `Float64` and not merely the
same colour, and a test compares them pixel by pixel over the corpus.
`VGTiledFillRasteriser` is the frame around it — bin with `VGTileBinning`, draw each tile on its
own, quantise and composite with the format's and the operator's own methods — so what the step had
to prove was the tiling and the coverage and nothing else.
`supportsEntry:` is the subset in one place: a `VGFillEntry`, a solid paint, a rectangular clip and
an operator of `supportedOperators`, which are `over`, `source` and `clear`.

**Step 2, the encoding.** `VGTiledFillEncoding` writes the frame as five flat buffers — `tileTable`,
`entryRefs` and `headers` of unsigned words, `clips` and `edges` of single floats — and the words
and the floats are kept apart so that no kernel bitcasts one into the other.
The layout is class-side and nowhere else, one method a stride and one method a field, so the writer
here and the kernel of the next step read the same names rather than the same numbers.
It also decodes itself: `entriesOfTileAt:` rebuilds the entries of a tile out of the buffers alone,
and the gate is that `VGTiledFillRasteriser` driven from the buffers draws what it draws from the
display list, which is what proves the encoding carries everything.
Coordinates narrow to single floats here, because that is what the device computes in, and the
frame is encoded for one surface format, which `targetFormat` names.

**Step 3, the kernel.** `VGTiledFillKernel` is the step 1 walk translated instruction by instruction
into one hand-built SPIR-V module of 16 568 bytes, built in a few milliseconds, with one workgroup a
tile, one invocation a pixel, and a flag variable wherever the Pharo answers early.
`VGSpirvVocabulary` is the arithmetic it emits, one selector an instruction, so the emission reads
as the algorithm and not as a list of opcode numbers; a test requires that the vocabulary name
nothing of this rasteriser, so it stays the general layer it claims to be.
Seven tests hold the module without a device: it is valid SPIR-V by `spirv-val`, it names every
buffer and built-in in its interface, it binds one buffer for every buffer it reads, its workgroup
is one tile of the grid, it takes the tile from the workgroup and the pixel from the invocation, it
shares nothing and synchronises nothing, and it refuses an operator with no arithmetic of its own.
`GlslStd450 class >> floor`, `ceil` and `uMin` were missing in `PharoVulkan` and were added there,
with their own example and validator test, as the plan requires of an opcode a unit needs.

**Step 4, the backend.** `VGVulkanBackend` records the frame it is given and draws it when it is
drained. `fillSegments:paint:clip:operator:` builds the entry and keeps it, and an entry the subset
refuses fails the frame there and then, while the surface can still replay the whole of it on the
software backend; a surface blit and a target of another format than the frame is encoded for are
refused the same way, which is three tests and the recovery of unit 2.0 doing the rest.
`VGTiledFillDispatch` is the frame on the device: a storage buffer for every binding the kernel
declares, the bytes of each uploaded, one workgroup for every tile the frame touches, and the target
read back into the bytes it came from.
It reads the words and the floats of an encoding through `basicAt:`, which answers the stored word
of a `WordArray` and the bit pattern of a `Float32Array`, so one method narrows both and neither is
bitcast through a `Float`.
It takes a context and never makes one, and it destroys the kernel before the buffers, because a
buffer freed under a live pipeline takes the image with it.
The pixels are packed row after row for the device and written into the target last of all, so a
driver that faults leaves the target as it was, and a frame that touches no tile is dispatched on no
device at all.

**Step 5, the gate.** Over the twenty-two subset cases, drawn on the device and by the software
backend on the same frame, twenty-one hold byte for byte and `path-filled-rounded-rectangle` differs
on exactly one pixel by one in one channel.
So the stated gate is a channel tolerance of one with no pixel past it, and at most one pixel
differing at all in a case — the two numbers are class-side constants with the measurement named in
their comments, as units 1.12 and 1.13 state theirs.
That the difference is as small as that is the `f32` of the device against the `Float64` of
`VGTileCoverage` on one antialiased edge, which is what the plan predicted this step would find.

The regression run over the whole project found one defect, and it was in a test rather than in the
code.
`VGRendererTest >> testAFrameDrawnThroughOurRendererEntersNoCairoFunction` installs a metalink on
every method of `VectorGraphics-Cairo` that sends `ffiCall:` and requires that a frame drawn through
our renderer fire none of them.
It began to fail about one run in six, and the failure named the two `externallyFree:` methods of
`AeCairoContext class` and `AeCairoSurface class`: the finalisation process was freeing the Cairo
objects of earlier tests while the frame was drawn, and a link fires in whichever process calls.
`TestSuite >> run` shuffles its tests, which is why the batch order could not be blamed and why the
failure came and went.
The link now counts a call only when the process making it is the process drawing the frame, which
is a truthful reading of the proof: our frame is drawn in this process from end to end, so nothing
of it is lost, while a free of another test's surface was never part of it.

The example and the view are `VGTiledFillExamples class >> dispatchOfThreeShapesOnThisMachine`,
which encodes three shapes, dispatches them where a device computes and encodes alone where none
does, and the `Buffers` tab of a dispatch, which lists every binding with its word count and its
first words, gated on a frame having been encoded.
The whole project is green: 645 tests over 51 classes, run in five batches with the Vulkan backend
offered the first frame of every batch.
Critics are clean on the three Vulkan packages and on `VGRendererTest`, but for the accepted
`ReExcessiveArgumentsRule` on `VGVulkanBackend >> blitSurface:at:paint:clip:operator:`, which is the
frozen boundary selector.

Gate met. Unit 2.4 proceeds.

### 2.4 — paint evaluation on the GPU

Compile the unit 1.5 paint ABI into SPIR-V, reading the same coefficient block.

Gate: the gradient cases match software; the stop lookup table gives identical bytes on both paths.

**What the corpus asks for, measured before any code.**
Two of the forty-one conformance cases are gradient fills: `source-linear-gradient`, two stops under
`pad` through a translated pattern matrix, and `source-radial-gradient`, two stops under `pad`
between concentric circles.
They take the subset from twenty-two cases to twenty-four, and the remaining seventeen carry a
surface or a mesh paint, a blit or a clip cut by a shape.
Two cases are thin cover for an evaluator, so the gate of this unit adds synthetic frames for what
the corpus never draws: all four extend modes, more than two stops, two stops at one offset, a
gradient with no stops at all, a line of no length, a radial gradient whose circles leave a pixel
with no acceptable root, and a pattern matrix that is not the identity.

The paint ABI needs no change and no new instruction is owed to `PharoVulkan`.
The sixteen-float block of rule 2 already carries the matrix, the extend code and every geometric
field of both gradients, and `Float32Array` is what a paint keeps it in, so the block uploads as it
stands; only the stops are not in it.
`GlslStd450` already answers `sqrt`, `fClamp`, `fMin`, `fMax` and the `floor` unit 2.3 added, and
`repeat` and `reflect` are built from `floor`, so this unit emits arithmetic it already has.

One measurement decides how the device reads the stops.
`VGGradientPaint >> stopTable` is a lookup table of two hundred and fifty-six entries, and its own
comment says phase 1 never reads it because quantising the offset drifts from live Cairo.
Measured on the two corpus cases, sampling that table instead of evaluating the stops moves 2498 of
the 16 384 channel samples of the linear case and 1548 of the radial case, every one of them by one.
So the device evaluates the stops exactly as `rgbaAtOffset:` does, the gate sentence above is read
as the stops and not as the table, and a test records the drift so that the table cannot be put back
in the path by accident.

**The five steps, in order.**

1. The paint on the CPU: the subset widens to a gradient paint, and the rasteriser of unit 2.3
   evaluates the paint at every pixel instead of once an entry. Gate: byte-identical to the software
   backend on the two corpus cases and on every synthetic frame.
2. The encoding: two buffers more — the paint blocks, sixteen floats an entry copied as the paint
   holds them, and the stops, five floats a stop, an offset and four unpremultiplied channels. The
   header gains the paint tag, the offset of its block, the offset of its stops and their count, and
   a solid fill keeps the source pixel field unit 2.3 gave it. Gate: the rasteriser driven from the
   buffers alone draws the same pixels.
3. The kernel: the evaluation emitted as SPIR-V. The matrix maps the centre of the pixel into paint
   space, a linear gradient projects it on its line, a radial gradient takes the largest root of the
   quadratic whose circle has a radius of its own, the extend mode folds the offset, a loop over the
   stops finds the pair that brackets it, the interpolation is unpremultiplied, and the quantisation
   is the rounded product of the channel, the alpha and two hundred and fifty-five, which is what
   `pixelForRgba:` writes. A paint that lays nothing down leaves the pixel alone, which is a flag
   and not a jump out of the loop.
4. The backend: `supportsEntry:` widens to a gradient paint whose stops a dispatch can carry, and a
   paint it cannot evaluate still fails the frame for the software backend to finish.
5. The gate: the twenty-four cases and the synthetic frames compared with the software backend on
   the same frame. The device computes in `f32` where the evaluator computes in `Float64`, and a
   gradient rounds a product of three floats per channel, so the tolerance and the count of pixels
   allowed past it are measured and stated, as units 1.12, 1.13 and 2.3 state theirs.

**Done.** The device evaluates both gradients, and the twenty-four cases of the widened subset and
the fifteen gradient frames of the fixture hold against the software backend.
No class is new in the code packages but one, `VGTiledFillPixelEmitter`, which is the per-pixel half
of the module pulled out of `VGTiledFillKernel`; the rest of the unit widened what unit 2.3 built.

**Step 1, the paint on the CPU.** `VGTiledFillRasteriser class >> supportsPaint:` is the subset in
one place, and it now answers true for a solid colour and for any `VGGradientPaint`, while a mesh
paint and a surface paint still wait for units 2.5 and 2.6: neither is a coefficient block and a
stop list, which is the only shape this unit can read.
The rasteriser asks the paint for the pixel at the pixel it is drawing rather than once an entry, so
the gradient is evaluated by the same `rgbaAtOffset:` the software backend evaluates, and a solid
paint answers the same pixel as before.
The gate of the step is the one the plan asked for: byte-identical to the software backend on the
two corpus cases and on every frame of the fixture.

`VGGradientFrameFixture`, in the `Fixtures` tag of `VectorGraphics-Vulkan-Tests`, holds the fifteen
frames the corpus never draws — the four extend modes, three stops, two stops at one offset, no
stops at all, a line of no length, concentric and off-centre circles, a radial gradient that leaves
pixels with no acceptable root, a pattern matrix that is not the identity, a gradient under the
source operator, one through a constant alpha and one inside a fractional clip.
Two of them are degenerate and lay down nothing — `linearWithNoStops` and `linearOfNoLength` — and
`degenerateGradientFrameNames` names them, because a test that requires pixels of every frame would
otherwise be satisfied by a blank one.

**Step 2, the encoding.** `VGTiledFillEncoding` writes two buffers more: `paints`, sixteen single
floats an entry copied as `VGPaint` holds them, and `stops`, five floats a stop — an offset and four
unpremultiplied channels.
The header grew to sixteen words, which is the paint tag, the offset of the paint block, the offset
of the first stop and the number of stops added to what unit 2.3 wrote; a solid fill keeps the
source pixel field, so the kernel reads a pixel where the tag says pixel and evaluates where it says
gradient.
The coefficient block is copied and not rebuilt, which is rule 2 doing its work: the block the
device reads is the block the paint already keeps, field for field and in the same order.
The gate is unchanged in form — the rasteriser driven from the buffers alone draws what it draws
from the display list — and it now covers the gradient frames as well as the corpus.

**Step 3, the kernel.** The module is 23 696 bytes, up from the 16 568 of unit 2.3, and the
arithmetic the unit added is the evaluation of a paint at a pixel: fields one to six of the block
map the centre of the pixel into paint space, which is where live Cairo samples and what
`VGPaint >> pixelIn:atX:y:` does on the other path, a linear gradient projects that point on its
line, a radial gradient takes the larger root of its quadratic, the extend mode folds the offset —
`repeat` and `reflect` out of `floor`, `pad` out of a minimum and a maximum, all four emitted and
field seven selecting one — a loop over the stops finds the bracketing pair, the interpolation is
unpremultiplied and the quantisation is the rounded product of the channel, the alpha and two
hundred and fifty-five, which is what `pixelForRgba:` writes.
A pixel a paint does not accept — outside `none`, or a radial point with no root — is left alone
through a flag, not through a jump out of the loop, which is the same discipline unit 2.3 set.
No instruction was owed to `PharoVulkan`: the GLSL instructions the vocabulary sends are `sqrt`,
`floor`, `ceil`, `fMin`, `fMax` and `uMin`, all of them already there, and nothing of `SpvOpcode`
was missing.

The stops are searched and the table of rule 2 is not read, and that is a measurement and not a
preference.
Sampling `VGGradientPaint >> stopTable` instead of evaluating the stops moves 2498 of the 16 384
channel samples of `source-linear-gradient` and 1548 of `source-radial-gradient`, every one of them
by one, because an offset between two of the two hundred and fifty-six entries has to be quantised
to one of them.
`VGPaintTest >> testSamplingTheStopTableIsNotTheBytesTheStopsThemselvesGive` records the same drift
over a sweep of a three-stop ramp — 898 of 4096 channel samples, the farthest by two — so the table
cannot be put back in the path without a test saying so.

**Step 4, the backend.** No code changed here, which the plan did not predict: `supportsEntry:`
reads `supportsPaint:`, so widening the paint in step 1 widened the backend in the same breath.
Two tests hold the two halves of that.
One records a three-stop gradient frame through `VGVulkanBackend` on a `VGCairoImageSurface`, with
the preference and the rejections cleared first, and requires that the backend not be rejected and
that the surface hold pixels a blank surface does not — a gradient is drawn, not refused.
The other fills with a `VGSurfacePaint` inside a rectangular clip under `over` and requires
`VGBackendFailure` naming the backend, so a paint the kernel cannot evaluate still fails the frame
for the software backend to finish.

**Step 5, the gate.** Over the twenty-four cases of the subset and the fifteen gradient frames,
drawn on the device and by the software backend on the same frame, thirty-three are byte for byte
identical and six differ.
One is the single antialiased pixel of `path-filled-rounded-rectangle` that unit 2.3 already
measured. The other five are runs inside a ramp — 128 pixels of `linearUnderRepeat` and of
`linearUnderReflect`, 64 of `source-linear-gradient`, 48 of `linearUnderNone` and of
`linearUnderPad` — and every differing channel of every one of them is one byte out.
So the stated gate is a channel tolerance of one with no pixel past it, and at most 128 pixels
differing at all in a case, both class-side constants of the test with the measurement written into
their comments.

The measurement said something sharper than the gate, and the test asserts that too.
Against a software frame whose stops are narrowed to single floats exactly as the encoding narrows
them, the device agrees byte for byte on every one of the fifteen gradient frames.
The five ramp runs are therefore the quantisation of the narrowed stop and not the arithmetic of the
device: a channel of a stop that is a `Float64` in the software path and an `f32` on the device can
put the midpoint of a ramp on the other side of a rounding boundary, and a whole run of pixels
crosses it at once.
`testEveryGradientFrameOfTheFixtureDrawsOnTheDeviceWhatTheSoftwareBackendDraws` holds both: the
tolerance and the count against the ordinary software frame, and equality of all the bytes against
the single-float one.

**One refactor, proved not to move a byte.** `ReExcessiveMethodsRule` fired on
`VGTiledFillKernel` at seventy-five instance methods, and the natural line through it is the one the
module already has: what the kernel emits once a dispatch, and what it emits per pixel.
`VGTiledFillPixelEmitter` is a `VGSpirvVocabulary` holding its kernel, and it emits into the
kernel's own module through `VGSpirvVocabulary >> shareStateWith:`, which hands it the same builder,
the same GLSL set and the same value table — held and not copied, because a value one of them names
is a value the other reads, the two of them emitting one function.
`scalarBitWidth` moved up to `VGSpirvVocabulary class`, since every vocabulary emitting into one
module must answer the same width.
The kernel is now fifty instance methods and twenty-five class methods, the emitter thirty-one and
three, and the proof that nothing moved is the module itself: the bytes were captured before the
split and compared after it, and the 23 696 are identical.
Three tests hold the split rather than the class list — the emitter shares the builder, the GLSL set
and the value table of its kernel, every composition selector it names is a method of its own, and
an operator with no arithmetic is refused by the emitter.

The same rule then fired on `VGTiledFillTest` at sixty-one methods, and the line through the tests
is the line through the unit: `VGTiledFillKernelTest` holds the ten tests that read the module and
the two classes and draw nothing at all, with the three helpers they use, so it runs on a machine
with no driver and no Cairo frame; `VGTiledFillTest` keeps the thirty-two that compare pixels.

The examples and the views are three and three.
`VGTiledFillExamples class >> encodingOfAGradientAndASolidFill` encodes a three-stop gradient over
the whole frame and a solid rectangle on top of it, and `pixelEmitterOfTheDefaultKernel` answers an
emitter on a kernel that has already built its module.
`VGTiledFillEncoding` gains a `Paints` tab, one row an entry with the decoded paint class, the tag,
the extend mode read through `VGPaint extendFor:`, the stop count, the matrix and the geometric
fields, and a `Stops` tab, one row a stop with its offset, its four channels and the pixel
`targetFormat` makes of it; both gated on the frame having been encoded.
`VGTiledFillPixelEmitter` gains a `Composition` tab, one row an operator of the subset with its
encoded code, the selector that holds its arithmetic and whether that selector is a method of the
emitter, read from `supportedOperators` and from the emitter's own selectors rather than restated.

The whole project is green: 656 tests over 52 classes, run in five batches so that no batch wedges
the image, with the Vulkan backend offered a frame in the batch that holds its own tests.
Critics are clean on the three Vulkan packages and on `VGPaintTest`, but for the accepted
`ReExcessiveArgumentsRule` on `VGVulkanBackend >> blitSurface:at:paint:clip:operator:`, which is the
frozen boundary selector.

Gate met. Unit 2.5 proceeds.

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
- Delete or move every scratch file out of the checkout before committing from the image.
  An image commit writes a tree from the whole working tree and not only from what was staged, so
  the plan commit of unit 1.13 swept in five scratch files and one untracked document beside the
  one file it meant to carry.
  `git reset --soft` is not a commit, so the hook permits it: that is the way to undo such a commit,
  followed by `git rm --cached` on the swept paths, `adoptCommit: repo headCommit` to re-attach, and
  a second commit from the image.

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

## 11. The font lifetime defect

Four segmentation faults killed the image while unit 2.0 was being written: on 21 October 2026 at
20:18:53, at 21:23:39 and at 21:50:10, and on 22 October 2026 at 00:06:05.
All four have one stack.
`FT_Done_Face` is reached from `hb_blob_destroy` through `hb_face_destroy` and `hb_font_destroy`,
called through libffi from `FFIExternalResourceExecutor >> finalize`, inside
`FinalizationProcess class >> finalizationProcess`.
No drawing was in progress in any of them, which is why the crash looked unrelated to the work: a
run had finished minutes earlier and the collector was only now getting to the objects it left.

The cause is three parties disagreeing about who owns a FreeType face.
`hb_ft_font_create_referenced`, which `AeHbFont class >> newForFTFaceReferenced:` wraps, keeps a C
reference to the `FT_Face` and releases it with `FT_Done_Face`.
`cairo_ft_font_face_create_for_ft_face`, behind `VGFontFace newForFace:`, does the same.
`FT_Done_Library` destroys every face its library owns, whatever still points at them.
Nothing ties any of that to the Smalltalk lifetimes, so a library collected before a harfbuzz font
that outlived it leaves `FT_Done_Face` reading freed memory, in the finalisation process, long
after the picture it drew was forgotten.

Two patterns in this project produced exactly that state.
`AeFTLibrary newInitialized` was sent per call in four places, so each call made a library and each
library became garbage as soon as the form was answered.
`AeFontManager resetGlobalInstance` was sent by three of the ported experiments, and a manager holds
the library and the face cache in its own slots, so replacing the global manager made the previous
library and all of its faces garbage while the harfbuzz fonts built from them were still alive.

The fix keeps the objects instead of the handles.
`VGAlexandrieFontLifetime`, in the `Fixtures` tag of `VectorGraphics-Cairo-Tests`, answers one
FreeType library for the whole session from `freeTypeLibrary`, and `retain:` adds any object to the
set it holds and answers it, so an expression can be wrapped where it stands.
It is class-side state on purpose: the lifetime being bought is the session's, not an instance's.

The rule is read off the code rather than listed, so a case written later cannot forget it.
`VGCairoTextTest` gained four tests in a `tests - font lifetime` protocol.
One requires `freeTypeLibrary` to answer the same object twice and to be in the retained set.
One requires that no method of any `VectorGraphics` package sends `newInitialized` except
`VGAlexandrieFontLifetime class >> freeTypeLibrary` itself.
One requires every method of this project that sends `cairoGlyphArrayForFace:size:` to send
`retain:`.
One draws a reference picture through `VGAlexandrieCase >> cairoForm` and requires the font manager
left behind to be retained afterwards, because the reference is drawn by Alexandrie's own
experiments, which this project may not edit.

Five of the ported experiment copies needed the rewrite, and they are generated, not written.
Hand-editing them put them out of step with their own derivation at once, and
`VGAlexandrieCorpusTest >> testEveryDerivedCopyIsWhatTheSubstitutionWritesNow` said so.
So the derivation performs the rewrite: `VGAlexandrieCorpus class >> fontLifetimeSubstitutions`
answers two source substitutions, `VGAlexandrieCase >> portedSource` applies them after the class
name map, and `compilePortedCopy` writes the result back.
`AeFTLibrary newInitialized` becomes `VGAlexandrieFontLifetime freeTypeLibrary`.
`AeFontManager globalInstance` becomes a `retain:` of itself, parenthesised so that the replacement
stands wherever the original expression stood.
The substitution found a fifth case, `textWithoutHarfbuzzWithFontManager`, that the hand edits had
missed, and it covers every copy added from now on for nothing.

`VGAlexandrieFontLifetimeExamples class >> fontObjectsKeptForThisSession` asks for the library and
draws one reference case, and the class-side `Kept` tab lists what is held with the role each
object plays, asked of the object rather than recorded alongside it.

Gate: `VGCairoTextTest` is 32 tests and `VGAlexandrieCorpusTest` is 14, both green, no drift, the
whole project green at 579 tests, and critics clean on the keeper class, the corpus, the case, the
test class and the example holder.
The generated ported class keeps `ReExcessiveMethodsRule` and three `ReLongMethodsRule` critiques,
which are Alexandrie's own methods copied as they stand.
