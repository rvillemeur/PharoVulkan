# VectorCanvas — presenting straight from the device

Not committed to. Scoped at the user's request on 30 October 2026, after unit 3.6 recorded the
verdict (Bloc's default stays Cairo) and asked why a GPU path cannot beat a CPU one on this frame.
Companion to `VECTORCANVAS-PLAN.md`, which this document does not replace or supersede — phases 1-3
of that plan are done, their verdict stands, and nothing here reopens it.

## 1. Why this is a separate document, not phase 4

`VECTORCANVAS-PLAN.md` §1 states the goal as a drop-in replacement for `AeCanvas`, same calling API,
and §3 freezes three seam rules so that the GPU backend can be added or removed without touching the
software path: the backend answers `fillSegments:paint:clip:operator:`, `blitSurface:at:paint:` and
`drainInto: aTarget`, and nothing above the boundary knows a SPIR-V function from a Pharo method.

Presenting straight from the device breaks that shape on purpose. `drainInto: aTarget` today ends in
a CPU buffer the host renderer handed over; a backend that presents a GPU image to a window swapchain
has no CPU target to drain into, and the three messages stop being enough to describe what it does.
That is a different project wearing the same name, not an optimisation of this one, so it gets its
own document rather than a quiet phase 4 that would need to un-freeze §3.

## 2. What unit 3.6 and 3.7 already say about the ceiling

Unit 3.6 measured the reference frame (the real Bloc scene, 88 entries) at 30.222 ms whole-frame
against Cairo's 6.040 ms, 5.0 times slower, and the dispatch alone is already only 2.2 times Cairo
(13.198 ms). Unit 3.7, scoped alongside this document, is the cheap lever on the encode side of that
number and does not touch the device.

Nothing on the device side closes the rest of that gap by working harder: the dispatch already pays
79 ns a pixel on real arithmetic, not idle time, per §12's own measurement. The remaining gap that
*optimisation* can close is bounded by the dispatch figure itself. What is left outside that bound is
not computation — it is the two trips the frame makes across the PCIe bus it does not need to make:
upload (0.156-0.222 ms, cheap) and the one this document is about, read the whole frame back to a
`ByteArray` so Bloc's own renderer protocol can hand it to the window as CPU pixels, every frame,
whether or not anything on screen asks a GPU to redraw it that way. That round trip, and the SDL2
texture lock on the other side of it, is host-side cost no shader can remove, because nothing about
it is arithmetic.

## 3. The idea in one sentence

Render into a GPU image already in the window's own presentable format, and hand that image to the
swapchain directly, instead of reading it back into a `ByteArray` for a software blit to redo the
copy a second time.

## 4. What already exists and would be reused

Confirmed in the image, not assumed:

- `VkSwapchain` (`PharoVulkan-Graphics`) has the full lifecycle already: `acquireNextImage:fence:`,
  `createImageViews`, `present:queue:waitSemaphore:`, `destroy`, and the present-mode and
  image-count queries a real present loop needs.
- `PVHelloTriangleScene` and `PVTriangleScene` are a complete, already-working window-driven render
  loop over that swapchain: `initializeCtx:backendWindow:` builds the surface, swapchain and
  framebuffers over it, and `renderFrame` answers the swapchain index drawn into.
- `PVOffscreenTarget` already renders into an image sharing the swapchain's own colour format without
  presenting, specifically "so a picture rendered offscreen is the picture a [window render]s" (its
  own class comment) — the discipline this document needs (compute kernel writes into that same
  format) is already named and tested there, just not yet pointed at a real swapchain image instead
  of an offscreen one.
- `VectorGraphics`'s own `VGBackend class >> preferred`/rank machinery (§8 of the other plan) is a
  working precedent for probing a device capability once and caching the answer, which a new backend
  here would reuse rather than invent again.

None of this is hypothetical. All of it was built for PharoVulkan's own Phase 6/7 graphics work and
is sitting unused by VectorGraphics today.

## 5. What is confirmed open, not assumed either way

- `BlHostRenderer` is the abstract root and declares `render:` a `subclassResponsibility`;
  `BARenderer` (Cairo) is its only direct subclass and its only implementor of `render:`, and
  `VGRenderer` (ours) is a subclass of `BARenderer` that overrides
  `renderWith:pixels:stride:physicalRectangle:logicalRectangle:` and inherits `render:` unchanged.
  Corrected while answering unit 3.7's step 1, where this hierarchy was read in the image: the point
  the paragraph was making still holds — `render:` is overridable per renderer and nothing above it
  forces a CPU hand-off — but a renderer that never locks a CPU surface has to override `render:`
  itself, not merely the pixel-lending method `VGRenderer` overrides today, because it is
  `BARenderer >> render:` that sends `lockSurfaceFor:scaleFactor:during:`.
- `BlHostSpace` has its own `renderer` instance variable and three known subclasses
  (`BlAbstractMorphicHostSpace`, `BlOSWindowSDL2HostSpace`, and this project's own
  `VGPixelBufferHostSpace`, built for exactly this kind of substitution). Only `BARenderer >> render:`
  sends `lockSurfaceFor:scaleFactor:during:` — the CPU-pixel contract is specific to that one
  implementor, not forced by `BlHostSpace` or `BlHostRenderer` themselves.
  So the seam this document needs — a renderer that does not lock a CPU surface at all — already has
  a place to stand without touching a single Bloc class, which satisfies this project's own rule
  against editing an external package directly.
- What is **not** yet known, and has to be answered before a single Vulkan line is written for this:
  how a real window (not `VGRendererTest`'s stub, not `VGFrameProfile`'s offscreen harness) actually
  chooses which `BlHostRenderer` a given `BlSpace` drives with, whether that choice is already
  late-bound the way `VGBackend preferred` is, and whether anything Bloc draws into a frame besides
  this project's own canvas — chrome, cursors, overlays — shares that same renderer or is composited
  on top of it afterwards. `VGRendererTest` calls `VGRenderer` directly with pixels it made up, which
  proves the renderer's own contract but says nothing about how a live window picks it.

## 6. Proposed first unit — an investigation, not an implementation

Named to match this project's own precedent: unit 2.1 was a go/no-go round trip before anything was
built on top of it; the font handle lifetime defect and the FFI mutation hazard (see memory) are both
cases where a question answered by reading code first would have been cheaper than one answered by
crashing the image. This unit is that question, asked first.

**Question.** Can a `BlSpace` backed by a real OS window be driven by a `BlHostRenderer` that never
locks a CPU surface, end to end for one static triangle, without modifying any class outside
`VectorGraphics` and `PharoVulkan-Graphics`? And does anything else that window would normally draw
in the same frame depend on sharing that renderer's CPU buffer?

**Method.** Read, in order: what actually constructs a `BlHostSpace` and its `renderer` for a live
`BlOSWindowSDL2HostSpace` window (not a test stub); what a `BlSpace`'s frame-pacing loop calls once a
frame, and whether that call site is renderer-polymorphic already or hardcodes `BARenderer`; whether
window chrome, cursor, and overlay drawing in Bloc go through that same renderer or a separate layer
composited after it. Answer each with a file and a selector, the way this unit's own sibling
documents do, not with a guess.

**Gate.** A written yes-or-no on the question above, with the evidence for it, committed to this
document as its own section before any other section of this plan is written. A no closes this
document the way a no closed §12.7 of the other plan: written down so the next reader does not ask
the same question again, and nothing past this unit gets built.

## 7. If the answer is yes — the shape of what comes after, not yet scoped

Sketched only so the investigation unit has something to report against, not committed to:

1. A new `BlHostRenderer` subclass, in a package of its own (`VectorGraphics-Present` or inside
   `PharoVulkan-Graphics`, whichever the investigation unit's findings make the natural owner), whose
   `render:` acquires a swapchain image instead of locking a CPU surface.
2. The compute kernel's target becomes a storage image in the swapchain's own format — the format
   discipline `PVOffscreenTarget` already states — instead of a storage buffer, so there is nothing
   to copy out of after the dispatch, only an image layout transition before `present:`.
3. Pixel-identity gates stay: the existing subset corpus must draw the same pixels through this path
   as through the software backend, read back once for the test's own sake, which does not reintroduce
   the per-frame cost this document exists to remove.
4. Failover: a `VGBackendFailure` here cannot fall back to software mid-frame the way the compute
   backend does, because a swapchain image already acquired cannot quietly become a `ByteArray`; the
   fallback boundary has to move to "which renderer a `BlSpace` is given," decided before the window
   opens, not inside a frame.

## 8. What this is not

Not a phase of `VECTORCANVAS-PLAN.md`, not gated by anything in its §9, and not expected to change
unit 3.6's verdict for the general case — Bloc's default stays Cairo regardless, since this document
is about removing a cost specific to the device path, not about the device becoming cheaper than
Cairo everywhere. It would matter only for whatever a caller specifically wants a Vulkan-presented
window for, which is a product question this document does not answer.

Related: `VECTORCANVAS-PLAN.md` §3 (seam rules), §8 (backend selection), §12 and 3.6/3.7 (the
numbers this document's §2 reads from); `~/workspace/CLAUDE.md` (PharoVulkan package layout and the
graphics-path classes §4 of this document names).
