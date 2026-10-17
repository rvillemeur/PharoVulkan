# VECTORCANVAS-PLAN — a GPU-capable replacement for Alexandrie Canvas

## 1. Goal

Make `VectorGraphics` a drop-in replacement for `AeCanvas`, with the same calling API, matching or
extending the feature set that Bloc gets today from Cairo through Alexandrie.

The work splits in two phases, and the split is the point of the plan.

Phase 1 is pure Pharo, no Vulkan, no external library.
It delivers one-to-one compatibility with the Alexandrie API and passes a conformance corpus.
At the end of phase 1 the package can render Bloc on a machine with no GPU driver, no `libcairo`
and no FFI at all beyond what the base image already uses.

Phase 2 adds a Vulkan backend behind the same facade.
It is an optimisation, never a dependency.
Every phase 2 unit must leave the phase 1 software path working and selectable.

The ordering is deliberate: Vulkan cannot be the failover, because a Vulkan device is more fragile
to acquire than a Cairo surface.
A missing or broken ICD, a Wayland or X11 mismatch, MoltenVK on macOS, a stale `vulkan-1.dll` on
Windows: each of those is a plausible failure on a user's machine.
The software path is the failover, and the GPU path is the fast path.

## 2. What exists today

### 2.1 The `VectorGraphics` package

Seventy-two classes and twenty-four test classes, two hundred and fourteen tests, all green.

| Tag | Classes | Purpose |
|---|---|---|
| `Kernel` | 5 | `VectorCanvas`, `VectorEngineAbstract` and its three subclasses (`Pixel`, `SubPixel`, `WholePixel`) |
| `PathCommands` | 12 | The path command objects the canvas records and the engine walks |
| `TrueType` | 22 | `TTFontReader`, `TTFontDescription`, the table parsers, the glyph and contour model |
| `SVG` | 2 | A minimal SVG path-data reader |
| `Examples` | 2 | `VectorCanvasExample`, `TrueTypeExample` |
| `Tests` | 24 | — |

The engine runs in three stages.
The walk stage flattens each path command into a run of hops.
The splat stage stamps a disc of radius `auxStrokeWidthDilatedHalf` into `alphaMask`, max-combining
seven-bit alpha, and accumulates signed winding deltas into `edgeCounts`.
The blend stage scans the dirty rectangle, running-sums `edgeCounts` to get the interior, consults
`morphIds` for the rectangular clip, writes the destination pixel and zeroes the scratch buffers.

Per-pixel blending is message-send bound, which is what a GPU backend is for.

### 2.2 The Alexandrie calling surface, as audited from source

`AeCanvas` declares ninety selectors.
Bloc sends about thirty-five of them.
`AeCairoContext` declares one hundred and sixty-six selectors; the path-building blocks Bloc passes
to the canvas use about twenty-five of them.
`AeCairoSurface` declares nineteen and `AeCairoPattern` eight.

`Bloc-Alexandrie` is seventy-three files, one `BARenderer` plus roughly sixty extension methods on
Bloc classes.
Those extension methods are the real calling API: they are what a renderer must satisfy, and they
are written against Alexandrie class names, not against an abstract canvas protocol.

`AeCanvas` has an ordering contract, stated in its own class comment:

1. set up the path,
2. set up the background,
3. set up the border and the outskirts,
4. send a variant of `drawFigure*`.

The background must be set before the border.
Eleven private `drawFigureWith*` methods cover the combinations of background present or absent,
opaque or translucent, border present or absent, and outskirts inside, centered or outside.
Outskirts-outside is emulated: the border is stroked at doubled width inside a
`cairoContext paintGroupWith: [ … ]`, then `setOperatorClear` plus a fill removes the inner half.
That emulation is the single most demanding thing in the API, because it needs groups, a clear
operator and a preserved path at once.

`AeCanvas >> preparePath` is `pathBlock value: cairoContext`, so a path arrives as a block that
talks to the Cairo context directly.
Any replacement must accept such a block and answer something that understands the same
twenty-five path selectors.

### 2.3 The gap list

What `VectorCanvas` does not do today, each item a phase 1 unit of work:

- `geometryTransformation:` is a no-op, because the Cuis `AffineTransformation` it wants is absent.
- The target must be an opaque thirty-two-bit `Form`; there is no alpha target, no group, no mask
  and no operator other than source-over.
- Clipping is rectangular only, through `morphIds`; there is no path clip and no clip stack.
- Winding is nonzero only; there is no even-odd rule.
- Caps and joins are round only, implicit in the disc splat; there are no butt or square caps, no
  miter or bevel joins and no dashes.
- There is no gradient, no pattern, no image paint, and therefore no `AeCairoPattern` equivalent.
- There is no text shaping; kern pairs are parsed but indexed by glyph and never applied.
- There is no blur, and Bloc asks for one on shadows.
- There is no surface lifecycle, no device offset and no `asForm` on a sub-rectangle.
- Nothing is wired into a display loop, so nothing renders a real Bloc space yet.

## 3. The three seam rules

These are frozen.
They exist so that phase 2 can be added, and removed, without touching phase 1 code.

### Rule 1 — a retained display list per frame

The facade never rasterises as it records.
It appends to a display list, and the list is drained once per frame by whichever backend is
selected.

A display list is required by both phases for different reasons.
The software backend wants it so that the dirty rectangle is known before the first pixel is
written.
The GPU backend wants it because a draw call per figure is the one thing that makes a GPU slower
than a CPU.

The list is also what makes failover cheap: when the GPU backend raises, the same list is replayed
on the software backend and the frame still appears.

### Rule 2 — a frozen paint ABI

A paint is a tag, a block of thirty-two-bit floats holding its coefficients, and, for a gradient, an
optional two-hundred-and-fifty-six-entry stop lookup table.

Nothing above the backend boundary knows whether a paint will be evaluated by a Pharo method or by a
SPIR-V function.
Nothing below it knows what a `BlPaint` is.

The ABI is defined once, in phase 1.5, and tested by a unit test that reads the bytes.
A phase 2 shader and a phase 1 Pharo method read the same block.

### Rule 3 — no Vulkan type above the backend boundary

The backend answers three messages and no more:

- `fillSegments: aSegmentArray paint: aPaint clip: aClip operator: anOperator`
- `blitForm: aForm at: aPoint paint: aPaint`
- `drainInto: aTarget`

`PharoVulkan` classes appear only in the Vulkan backend's own package.
A `VGBackendFailure` raised anywhere below the boundary is caught at the boundary and answered by
replaying the list on the software backend.

## 4. Package layout

Phase 1 adds two packages and phase 2 adds one.

| Package | Phase | Contents |
|---|---|---|
| `VectorGraphics-Compat` | 1 | `VGAeCanvas` (the facade), `VGPathRecorder`, the display list, the figure table, the paint ABI, `VGBackend` and the software backend |
| `VectorGraphics-Compat-Tests` | 1 | The conformance harness and the corpus runner |
| `VectorGraphics-Vulkan` | 2 | The Vulkan backend, the tile binner, the SPIR-V paint and coverage shaders |
| `VectorGraphics-Vulkan-Tests` | 2 | The GPU-versus-software parity tests |

`VectorGraphics-Compat` may depend on `VectorGraphics`; the reverse is forbidden.
`VectorGraphics-Vulkan` may depend on `VectorGraphics-Compat` and on `PharoVulkan-Core`,
`PharoVulkan-Compute` and `PharoVulkan-SPIRV`; nothing may depend on it.
State those edges in a `VGArchitectureTest class >> allowedDependencies` table, the same way
`PVArchitectureTest` does in `PharoVulkan`, and check the table against both the code and the
baseline.

## 5. Do Bloc and Alexandrie have to be loaded?

Not in one image, and not in all phases.
Three images, with different needs:

| Image | Bloc | Alexandrie | Used for |
|---|---|---|---|
| Engine image | no | no | Phases 1.1 to 1.9, and all of phase 2 |
| Parity image | yes | yes | Phase 1.0 corpus generation, and phases 1.10 to 1.11 |
| Failover image | yes | no | Proving the deliverable: Bloc rendering with no Cairo present |

The parity image needs both, for one reason only: the reference renders.
A conformance corpus is worth nothing unless each case carries the exact pixels Cairo produces for
it, and only a loaded Alexandrie can produce those.
Generate the corpus once, commit the reference `Form`s as PNG files next to the corpus
descriptions, and the engine phases then run with nothing loaded.

Phases 1.10 and 1.11 wire a real renderer and profile it, so they need Bloc, and they need
Alexandrie alongside it for the side-by-side comparison.

The failover image is the acceptance test for the whole project.
It needs a Bloc extension package that talks to `VGAeCanvas` without naming a single Alexandrie
class.
Write that package in phase 1.10 and load it instead of `Bloc-Alexandrie`.
Until it exists, the claim "usable as a failover" is untested.

## 6. Phase 1 — pure Pharo, one-to-one with Alexandrie

Each unit is one commit.
Each unit follows the project cycle: failing test, smallest code that passes, refactor, class-side
`<sampleInstance>` example in a `-Examples` package, custom inspector view, clean critics.

### 1.0 — the facade skeleton and the conformance harness

Create `VGAeCanvas` with all ninety `AeCanvas` selectors, each one either implemented or raising
`VGNotYetImplemented` with the unit number that will implement it.
Create `VGPathRecorder` answering the twenty-five Cairo path selectors a Bloc path block sends.
Create the corpus: one description object per case, holding the drawing script and the reference
PNG.

Seed the corpus with the eleven `drawFigureWith*` combinations, each at opaque and translucent
background, each with the three outskirts, which is thirty-three cases before any geometry varies.

Gate: the harness runs, every case fails with a named unimplemented selector rather than an error,
and the failure report names the unit that will fix it.

### 1.1 — RGBA targets and the operator set

Replace the opaque-`Form` assumption with a premultiplied RGBA target.
Implement source-over, clear, source, and the subset of Porter-Duff operators Bloc actually sends.

Gate: a corpus case that paints translucent over translucent matches the reference to within one
unit per channel.

### 1.2 — affine transforms

Implement the transform stack: `pathTransform:`, `pathTranslate:`, `geometryTransformation:` and the
matrix the Bloc element tree composes.
Transform the path at record time, not at splat time, so the engine stays untouched.

Gate: a rotated and sheared rounded rectangle matches the reference; the degenerate singular matrix
draws nothing rather than raising.

### 1.3 — the figure table

Implement the eleven `drawFigureWith*` combinations as a table, not as a cascade of conditionals,
and make the table the thing the test reads.
This is where the ordering contract is enforced: setting a border before a background is an error,
not a silent reordering.

Gate: all thirty-three seeded cases pass, including outskirts-outside, which needs 1.7 and 1.8 and
is therefore the last to go green in this unit.

### 1.4 — stroke geometry

Butt, square and round caps; miter, bevel and round joins; the miter limit; dash arrays with a dash
offset.
The current disc splat gives round caps and joins for free and nothing else, so this unit converts
stroking into a path and fills it.

Gate: a per-cap and per-join corpus case each match the reference, and a zero-length subpath draws
the cap pair rather than nothing.

### 1.5 — the paint ABI, and gradients in Pharo

Freeze the ABI from rule 2.
Implement solid, linear gradient, radial gradient and the stop lookup table, all evaluated in Pharo.
Implement the three extend modes Cairo offers and Bloc uses.

Gate: a test reads the coefficient block byte by byte and asserts its layout; the gradient corpus
cases match the reference.

### 1.6 — the clip stack

Path clipping, an even-odd and a nonzero rule, a clip mask stack with save and restore, and the
rectangular fast path kept for the common case.

Gate: nested clips, an empty intersection, and `preparePathAndClip` as Bloc sends it.

### 1.7 — groups and masks

`paintGroupWith:`, `restoreContextAfterPaintAlpha:with:`, `paintWithAlpha:`, and the preserved-path
variants `fillPreservingPath` and `strokePreservingPath`.

This unit is what makes outskirts-outside possible, and it is the hardest unit in phase 1.

Gate: the two outskirts-outside figure methods match the reference exactly, since that emulation is
pixel-sensitive.

### 1.8 — text

A glyph atlas keyed by font, size and code point, built on the `contourDataForUtf8` work already
done.
Apply the kern pairs the reader already parses.
`drawString:` blits from the atlas instead of re-walking contours.

Gate: a string renders identically through the atlas and through the direct path; the atlas is built
once for a repeated draw, proved by a counter.

### 1.9 — effects and caches

Gaussian blur for shadows, image paint from a `Form`, and the surface lifecycle: device offset,
`asForm`, `asForm` of a sub-rectangle.

Gate: the shadow corpus cases match the reference within the tolerance the harness states for blur,
and the tolerance is justified in a comment.

### 1.10 — renderer wiring

Write `Bloc-VectorGraphics`: a `BlHostRenderer` subclass and the element-side extension methods,
written against `VGAeCanvas` and naming no Alexandrie class.
Load it in the failover image, with `Bloc-Alexandrie` absent.

Gate: a real Bloc space opens, draws, and responds to a mouse event, with no Cairo loaded.

### 1.11 — profiling

Profile a representative Bloc scene and record where the time goes, per stage.
Write the numbers down in this file.

Gate: the profile exists, and it names the stage phase 2 must attack first.
Without this number, phase 2 has no target and cannot be judged.

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

Measure, on this machine, three numbers: buffer upload bandwidth, fill rate for a trivial coverage
shader, and readback latency for a full frame.
Compare the sum against the phase 1.11 profile.

Gate: if a GPU round trip costs more than the software path for a typical Bloc frame, stop here and
record why.
This gate is not a formality.
Readback is the known risk, because a Bloc frame ends in a `Form` the host window system wants, and
the path back from device memory can swallow the whole win.

### 2.2 — tile binning on the CPU

Bin the display list into tiles in Pharo first.
Binning is cheap, it is testable without a GPU, and it decides whether the GPU path is one dispatch
or thousands.

Gate: a binning test over the corpus, and a count of tiles touched per case.

### 2.3 — the tiled fill rasteriser

Fill only, no stroke, no text: strokes are paths by 1.4 and text is blits by 1.8, so fill is the
whole of the hot work.
One dispatch per frame, coverage accumulated per tile.

Gate: every fill corpus case matches the software backend, which is the oracle, not Cairo.
The software backend already matched Cairo in phase 1, so matching software is both necessary and
sufficient.

### 2.4 — paint evaluation on the GPU

Compile the phase 1.5 paint ABI into SPIR-V, reading the same coefficient block.

Gate: the gradient cases match software; the stop lookup table gives identical bytes on both paths.

### 2.5 — blur on the GPU

A separable two-pass Gaussian.

Gate: matches software within the stated blur tolerance.

### 2.6 — image paint on the GPU

This unit needs `OpTypeImage`, and `SpvImageType` does not exist in `PharoVulkan-SPIRV` today.
Add it there, in `PharoVulkan`, with its own tests, before this unit starts.
Note also that `SpvOpcode class` declares no atomic opcode, so any coverage scheme that needs an
atomic must add those opcodes first; 2.3 is written to avoid them.

Gate: an image-paint case matches software.

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
`libMoltenVK.dylib` on macOS, `vulkan-1.dll` on Windows.
macOS and Windows are therefore not excluded by declaration, only untested, and the probe is what
decides on the user's machine.

## 9. Gates that apply to every unit, in both phases

1. The failing test was written and seen to fail before the code.
2. The package suite is green.
3. `run_critics` is clean on every class the unit touched.
4. A class-side `<sampleInstance>` example exists in the `-Examples` package.
5. A custom `<inspectorPresentationOrder:title:>` view exists, and it asks the real rule rather than
   restating it.
6. The software backend still renders the corpus, with the GPU backend forced off.

Rule six is the one that keeps the failover honest.

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

Note that the documentation and the code live in different repositories here: this file is in the
`PharoVulkan` repository, and the `VectorGraphics` package is in its own.
Phase 1 commits therefore go to the `VectorGraphics` repository, and only this plan file goes here.
