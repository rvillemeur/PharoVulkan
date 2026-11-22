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

## 6a. The answer: yes, with one window-level condition the question did not anticipate

Read in the image on 30 October 2026, each answer with its class and selector. Nothing was built.

**How a live window picks its renderer.** `BlOSWindowSDL2Host >> newHostSpaceFor:` builds the host
space and sends it `renderer: self newHostRenderer`; `BlHost >> newHostRenderer` is
`^ BlHostRenderer preferableClass new`. The choice is late-bound exactly the way `VGBackend class >>
preferred` is, and `BlHostRenderer class >> preferableClass:` sets it for the whole image.
`VGRendererTest >> testTheRendererIsAHostRendererBlocCanChoose` already holds that fact. Two
details worth carrying forward: `availableClasses` is `self allSubclasses`, and an unset
`preferableClass` is `availableClasses anyOne`, so adding a third renderer subclass makes the
unset default arbitrary; and `preferableClass` is one global for every space, not a per-space
choice, which is where §7's failover boundary has to live.

**What the frame loop calls, and whether it is polymorphic.** `BlSpaceFrameDrawingPhase >> runOn:`
sends `aSpace render`; `BlSpace >> render` sends `aHostSpace render: self`; `BlHostSpace >> render:`
is `self renderer render: self`, which `BlOSWindowSDL2HostSpace >> render:` overrides only to wrap
the same send in `OSWindowRenderThread uniqueInstance critical:`. No class in that chain names
`BARenderer`. `BlHostRenderer >> render:` is a `subclassResponsibility`, `BARenderer >> render:` is
its only implementor, and it is also the **only sender in the image** of
`lockSurfaceFor:scaleFactor:during:` — now held by
`VGRendererTest >> testTheCpuSurfaceLockIsSentByTheFrameMethodAlone`, which fails if a second
sender ever appears. A renderer that overrides `render:` therefore escapes the CPU-pixel contract
without touching a Bloc class.

**What else the window draws in the same frame.** Nothing that needs those pixels. The cursor is
the OS cursor: `BlOSWindowSDL2HostSpace >> cursor:` is `window setMouseCursor: aCursor`. The chrome
is the OS window's own, reached through `title:`, `borderless:`, `fullscreen:` and friends on the
host space, never drawn into the canvas. Overlays are ordinary elements — `BlOverlayElement` is a
`BlElement` — and so are composition layers, both drawn through the one `aeFullDrawOn:` the
renderer already drives. The SDL renderer's other hooks are empty: `BlOSWindowSDL2Renderer >>
exposed`, `>> resized` and `>> present` have no body and `>> updateAll` is `shouldNotImplement`, so
no second path redraws or re-presents the window between frames.

**The condition the question did not anticipate, and the real reason this is not renderer-only.**
`BlOSWindowSDL2HostSpace >> lockSurfaceFor:scaleFactor:during:` does not merely lend pixels: it
locks an `SDL_TEXTUREACCESS_STREAMING` texture created in `>> initializeRenderer`, and after the
renderer has filled it, it runs `sdlRenderer copy: texture; present`. That `sdlRenderer` is created
unconditionally, one step earlier, by `BlOSWindowSDL2HostSpace >> initializeWithAttributes:` sending
`window newBlocRenderer`, which is `OSSDL2BackendWindow >> newBlocRenderer` →
`BlOSWindowSDL2Renderer for:` → `sdl2Window createAcceleratedRenderer`. A window that presents a
Vulkan swapchain cannot also own an SDL accelerated renderer on the same handle, and
`BlOSWindowSDL2Host >> newAttributesFor:` builds a plain `OSWindowAttributes` with `glAttributes`
and no `vulkanAttributes`, so the window is not created with `SDL_WINDOW_VULKAN` either.
So the substitution is three subclasses, not one: a renderer overriding `render:`, a host space
overriding `initializeWithAttributes:` (create the window through `PVWindowAttributes` carrying
`vulkanAttributes`, and do not send `newBlocRenderer`) and answering whatever present hook the new
renderer sends in place of `lockSurfaceFor:scaleFactor:during:`, and a host overriding
`newAttributesFor:` and `newHostSpaceFor:`. All three are subclasses in this project's own
packages, which is what the question asked: no class outside `VectorGraphics` and
`PharoVulkan-Graphics` is modified. `PVVulkanDriver >> createWindowWithAttributes:osWindow:` already
creates exactly that window — `SDL2Vulkan sdlWindowVulkan` in the flags, an
`OSSDL2VulkanBackendWindow` as the result — and falls through to `super` for attributes that carry
no `vulkanAttributes`, so the existing driver serves both kinds of window.

**One hazard found while reading, which is a defect in this project and not in Bloc.**
`BlOSWindowSDL2Host class >> isSupported` is `OSWindowDriver current className = #OSSDL2Driver`, a
literal class-name test, and `PVVulkanDriver` is a *subclass* of `OSSDL2Driver`, so installing it
makes Bloc's SDL2 host unsupported: `BlHostRegistry default availableHostClasses` in this image is
`#(BlMorphicWindowHost BlHeadlessHost)` and `BlOSWindowSDL2Host isSupported` is `false`. The image
is in that state now, which means `PVVulkanDriver class >> install` was used in some session rather
than `installDuring:`, exactly the hazard that method's own comment warns about. A Vulkan-presenting
host class must not copy that test, and the stray installation should be undone
(`PVVulkanDriver uninstall`) or made deliberate before any window work starts.
Both were done on 30 October 2026, as the unit §6b records.

**Verdict: yes.** The seam exists and is reachable by subclassing alone. Nothing else in a frame
depends on the CPU buffer. The cost is one more subclass than §6 assumed, at the host and host-space
level rather than the renderer alone, because the CPU round trip this document exists to remove is
created by the SDL streaming texture the host space builds, not by the renderer that fills it.
That does not reopen §1: this is still a different shape from `VECTORCANVAS-PLAN.md`'s three seam
rules, and §7 of this document stays unscoped until it is committed to.

## 6b. The hazard, undone and held: `VGVulkanDriverSdl2Host`

Done on 30 October 2026, as the first unit after the §6a investigation, because every window unit
after it would have been built in an image where Bloc could not open a window at all.

**The stray installation.** `OSWindowDriver current className` answered `'PVVulkanDriver'` in the
working image and again in the image as it was saved on disk, so some session had called
`PVVulkanDriver class >> install` rather than `installDuring:`. `PVVulkanDriver uninstall` puts the
stock driver back; `BlHostRegistry default refreshAvailableHosts` then answers
`#(BlOSWindowSDL2Host BlMorphicWindowHost BlHeadlessHost)` again.

**Why undoing it is not the whole fix.** The hazard is not the stray call, it is that nothing says
when it bites. `BlOSWindowSDL2Host class >> isSupported` is `OSWindowDriver current className =
#OSSDL2Driver`, so *any* correct use of the driver — `installDuring:` around a window, which is
what `PVHelloTriangleScene` and four `PVGraphicsTest` tests already do — takes Bloc's SDL2 host away
for the duration and hands any space opened in that window the Morphic host instead, with no error.
The driver has to be a subclass of `OSSDL2Driver`: it exists to add `SDL_WINDOW_VULKAN` to the flags
and answer an `OSSDL2VulkanBackendWindow`, and it falls through to `super` for every other window.

**The fix: one subclass, in this project, that answers for exactly that case.**
`VGVulkanDriverSdl2Host`, in `VectorGraphics-Vulkan` under the `Backend` tag, is a subclass of
`BlOSWindowSDL2Host` that adds one class-side method:

```smalltalk
isSupported
	^ OSWindowDriver current isKindOf: PVVulkanDriver
```

Nothing else is overridden, so the attributes, the host space and the renderer it builds are Bloc's
own. The two cases partition: under the stock driver Bloc's host answers supported and this one does
not; under PharoVulkan's driver the reverse. That matters because `BlHostRegistry >> registerHost:`
sorts by `order` alone and both classes answer 10, so two supported SDL2 hosts would make the
registry's choice between them arbitrary.

Package placement follows the dependency table: `VectorGraphics-Vulkan` is the one family allowed to
name a PharoVulkan class, and the host names `PVVulkanDriver`. Bloc is not edited, which §6a required
of any host class; the rule it states — *a Vulkan-presenting host class must not copy Bloc's
class-name test* — is now held by a test rather than by a sentence in this document.

**Why the trait is declared again on the subclass.** `BlHostRegistry >> refreshAvailableHosts`
registers the singleton of each class in `TBlSingletonHost users`, and `users` holds the classes that
use the trait, not their subclasses — `VGPixelBufferHost`, a subclass of `BlHeadlessHost`, is absent
from it. Without `traits: { TBlSingletonHost }` the new host would never be offered by a registry.
The cost is that Renraku reports the trait's nine class-side copies — `default`, `cleanUp`, `start`,
`stop`, `label`, `isRunning`, `pulseProcess`, `uiProcessDo:`, `universe` — as equivalently defined in
the superclass, which also uses the trait. They are copies of one trait, not code written here, and
Tonel does not write them out. Excluding them from the composition — `TBlSingletonHost - #( … )` —
leaves the copies in the method dictionary and changes nothing, so the class is defined plainly and
the reason is in its comment.

**What holds it.** `VGVulkanDriverSdl2HostTest`, five tests:

| Test | Fact |
|---|---|
| `testBlocsOwnSdl2HostIsLostWhileTheVulkanDriverIsInstalled` | Bloc's own host answers not supported under the Vulkan driver — the reason the subject exists, and the canary that lets it be deleted if Bloc ever asks a kind-of question |
| `testTheHostIsSupportedWhileTheVulkanDriverIsInstalled` | the subject answers supported then |
| `testTheHostIsNotSupportedWhileTheStockDriverIsInstalled` | and not under the stock driver |
| `testExactlyOneSdl2HostIsSupportedUnderEitherDriver` | the two cases partition, under either driver |
| `testAnSdl2HostIsAvailableWhileTheVulkanDriverIsInstalled` | a registry built while the driver is installed offers a kind of `BlOSWindowSDL2Host`, which is the whole point |

The tests swap drivers through `PVVulkanDriver class >> installDuring:` and, for the stock driver it
cannot install, through `withDriverClass:during:`, which restores the previous driver in an `ensure:`
exactly as `installDuring:` does. They build `BlHostRegistry new` rather than refreshing the image's
own, because `refreshAvailableHosts` sends `stop` to each host it prunes; `tearDown` sends
`VGVulkanDriverSdl2Host cleanUp`, because `BlOSWindowSDL2Host class >> default` registers each
singleton it builds in the image's registry as well.

The example is `VGVulkanDriverSdl2HostExamples class >> hostOfferedWhileTheVulkanDriverIsInstalled`:
one click answers the host a fresh registry offers while the driver is installed, and puts the
driver, the registry and the singleton back. The view is `VGVulkanDriverSdl2Host >> inspectorHost:`,
a six-row table — the driver it answers to, the driver installed, whether each of the two SDL2 hosts
is supported now, the host a space would be given, and the spaces open on it — every row asking the
live predicate, none of them writing anything. `VGVulkanExamplesTest >> exampleHolders` names the new
holder, so the four example gates cover it.

## 7. Scoped: the frame presented from the device

Scoped on 1 November 2026 at the user's request, after §6a answered yes and §6b removed the window
hazard. Everything below was read in the image before it was written; where it contradicts the
sketch this section replaces, the sketch's own wording is kept and the correction is stated, because
the sketch is what the §6 investigation reported against.

### 7a. What reading the image changed about the sketch

The sketch had four points. Two stand, one is wrong in a way that makes this phase much smaller, and
one gains a condition.

**Point 1 stands.** A `BlHostRenderer` subclass whose `render:` acquires a swapchain image instead of
locking a CPU surface is the shape. `BlHost >> newHostRenderer` is
`BlHostRenderer preferableClass new`, a single global choice, but `BlOSWindowSDL2Host >>
newHostSpaceFor:` sends `renderer: self newHostRenderer` as one keyword of the cascade that builds
the host space, so a host subclass overriding `newHostSpaceFor:` names its own renderer without
touching `preferableClass` and without disturbing which renderer every other window in the image
gets. `VGRenderer` keeps `preferableClass` for the software path.

**Point 2 is wrong, and the correction is the main saving of this phase.** The sketch said the
compute kernel's target becomes a storage image in the swapchain's format, "so there is nothing to
copy out of after the dispatch". It does not have to. The kernel writes a storage buffer of packed
pixels, and `vkCmdCopyBufferToImage` moves that buffer into the acquired swapchain image on the
device, with no CPU trip and no SPIR-V change at all. The reasons to prefer it:

- The format already matches, by measurement rather than by luck: `VkRenderConfig formatRenderedIn`
  is 44, `VK_FORMAT_B8G8R8A8_UNORM`, whose bytes in memory are B, G, R, A — which on a little-endian
  machine is exactly what Cairo calls `ARGB32` and exactly what the kernel already writes.
  `VkSurface class >> formatPreferredFrom:` already asks the surface for that format first.
- Unit 3.9's kernel, its workgroup shape and its 65712 SPIR-V bytes stay untouched, so the pixel
  identity the subset corpus holds is preserved by construction rather than re-established.
- The seam `VGTiledFillDispatch >> draw:into:readBack:` already exists for exactly this case — its
  own comment says "a frame that ends on the device has no use for it: the pixels stay in the target
  buffer, which the next frame of the same dispatch reads as its own destination". That method was
  written in unit 3.4 for the measurement harness; this phase is its first real caller.

A storage image remains the right answer if a later unit wants the kernel to sample the destination
with image operations rather than index it as words. Nothing here forecloses it.

**Point 3 stands.** Pixel identity against the software backend stays the gate, and the test reads
the image back for its own sake. A readback inside a test is not the per-frame cost this document
exists to remove.

**Point 4 gains a condition.** Failover moves to "which renderer a `BlSpace` is given", decided
before the window opens, as the sketch says. The condition the sketch did not see: the choice is a
host choice, and `BlHostRegistry >> registerHost:` sorts by `order` alone, where every SDL2 host in
this image answers 10. §6b already partitioned two hosts on the installed driver. A third host makes
that partition three ways, so it has to be exact, and `VGVulkanDriverSdl2Host class >> isSupported`
has to be narrowed in the same unit that adds the new host.

### 7b. What the trips cost today, so the phase has a number to beat

Per frame of the reference frame, from §2 and from unit 3.0's stage figures:

| Trip | Where | Cost |
|---|---|---|
| read the target's own pixels into a packed `ByteArray` | `VGVulkanBackend >> pixelsOf:` | one 1.83 MB CPU copy |
| that `ByteArray` into the host-visible buffer | `VGTiledFillDispatch >> packBlocksOf:target:` | inside `writeBuffers` |
| the buffer across the bus | `>> upload` | 0.156-0.222 ms |
| the frame back across the bus | `>> readbackInto:` | 0.201-0.604 ms |
| the `ByteArray` into the target's rows | `VGVulkanBackend >> write:into:` | one 1.83 MB CPU copy |
| the target into an SDL streaming texture | `BlOSWindowSDL2HostSpace >> lockSurfaceFor:scaleFactor:during:` | one 1.83 MB write to write-combined memory, then `sdlRenderer copy:` |

Six movements of one frame, of which this phase removes five and replaces the sixth with a
device-local `vkCmdCopyBufferToImage`. The two bus figures are the only ones measured; the four
copies are not, and measuring them on the three benchmark frames is unit 7.6's job rather than an
assumption made here. Nothing in this table is arithmetic, which is why §2 says no shader removes
it, and nothing in it closes the gap to Cairo on its own, which is why §8 stands.

### 7c. The division of labour, following Bloc's own

Bloc's window host space owns the window and the SDL texture; its renderer owns the drawing and is
handed the pixels inside a bracket the host space controls. This phase keeps that shape exactly, and
substitutes at each of the three levels:

| Level | Class | What it does differently |
|---|---|---|
| host | `VGVulkanPresentHost` | builds `PVWindowAttributes` carrying `vulkanAttributes`, so `PVVulkanDriver` creates an `OSSDL2VulkanBackendWindow`; answers its own host space and its own renderer from `newHostSpaceFor:` |
| host space | `VGVulkanPresentHostSpace` | creates the window without sending `newBlocRenderer`, so no SDL accelerated renderer and no streaming texture exist on the handle; owns the `VkSurface` and the `VkSwapchain`; answers `presentFrameFor:scaleFactor:during:`, the bracket that replaces `lockSurfaceFor:scaleFactor:during:` |
| renderer | `VGVulkanPresentRenderer` | overrides `render:`, because it is `BARenderer >> render:` that sends the CPU-surface bracket; inside the new bracket it drives `space aeFullDrawOn:` over a canvas whose backend ends on the device |

The bracket is named for what it does and mirrors the method it replaces: the host space acquires an
image, evaluates the block, and presents. The renderer never sees a swapchain index or a queue, the
host space never sees a canvas, and `OSWindowRenderThread uniqueInstance critical:` keeps wrapping
the frame, as `BlOSWindowSDL2HostSpace >> render:` does today, because queue submission has the same
one-thread discipline the SDL renderer had.

### 7d. Decisions frozen for this phase

| Decision | Choice | Reason |
|---|---|---|
| what the kernel writes into | the storage buffer it writes today | §7a point 2: the format already matches and the SPIR-V does not change |
| how the frame reaches the swapchain image | `vkCmdCopyBufferToImage`, device-local | no bus trip, no CPU copy, no kernel change |
| where the previous frame lives | the device target buffer, across frames | it already does, per `draw:into:readBack:`; this is what lets the upload go too |
| damage rectangles | kept | the backend composites over the destination, and a frame that redraws everything would cost more dispatch than the trips it saves |
| failover | before the window opens, at host selection | a swapchain image already acquired cannot become a `ByteArray` mid-frame |
| opt-in | yes, explicit | §8: Bloc's default stays Cairo, so a presenting host answers supported only when something asks for it |

### 7e. The units

Each is a full cycle — failing test first, smallest code, refactor, `<sampleInstance>` example,
inspector view, `run_critics` — and each is independently runnable, as this project's phases are.

**7.1 The window with no SDL renderer.** `VGVulkanPresentHost`, `VGVulkanPresentHostSpace` and a
`VGVulkanPresentRenderer` whose `render:` only counts the frame and clears the dirty elements. No
Vulkan object is created yet. Gate: under `PVVulkanDriver` a `BlSpace` opens on this host, pulses,
and closes; the backend window is an `OSSDL2VulkanBackendWindow`; its `renderer` is nil, so no SDL
accelerated renderer was built; `lockSurfaceFor:scaleFactor:during:` is never sent, which the host
space holds by implementing it as `shouldNotImplement`; the three SDL2 hosts partition exactly, under
either driver and whether or not presenting is enabled.

**7.2 The swapchain, cleared and presented.** The host space builds `VkSurface` and `VkSwapchain`
over its window, and `presentFrameFor:scaleFactor:during:` acquires an image, evaluates the block,
and presents. The block does nothing yet beyond a clear. Gate: a visible window presents thirty
frames in sequence, the image index cycles through `imageCount`, the swapchain's `format` is
`VkRenderConfig formatRenderedIn` on this machine and the unit refuses loudly when it is not, a
resize recreates the swapchain at the new `vulkanDrawableExtent`, and closing the space destroys
swapchain, surface and semaphores in reverse order with nothing left on the device.

**7.3a One device for compute and presentation.** The session's context and the host space's context
become one: a context built for presentation is chosen and built by the compute path, so the kernels
keep every feature they ask for, and its instance carries the surface extensions the window system
names. Gate: the host space and the session answer the same context object, the compute-only context
is released when the first presentation request arrives, a session that cannot present is refused at
host selection, and the surface extensions are read before any window has been opened.

**7.3b The frame that ends on the device.** `VGTiledFillDispatch` gains the device-local copy: the
target buffer into a given `VkImage` by `vkCmdCopyBufferToImage`, with the layout transitions around
it, and `VGVulkanBackend` gains the path that asks for it instead of `drainInto:`. Gate: the subset
corpus draws the same pixels through the copy as the software backend draws, read back once inside
the test; the frame records no `readback` stage; `pixelsOf:` and `write:into:` are not sent.

**7.4 The real frame in the real window.** `VGVulkanPresentRenderer >> render:` drives the canvas
over a backend bound to the acquired image. Gate: each of the three benchmark frames appears in a
real window, and the pixels read back from the presented image equal the software backend's, tested
offscreen against the same corpus rather than by screenshot.

**7.5 The upload removed as well.** The target buffer already holds the previous frame for the same
extent, so `packBlocksOf:target:` stops packing the destination pixels when the dispatch can prove
it owns them — same extent, same buffer, no release since. Gate: identical pixels on a frame drawn
twice, the `writeBuffers` stage smaller by the frame's own size, and a correct first frame after a
release, which is the degenerate state this gate exists for.

**7.6 The measurement and the verdict.** Alternating same-state comparison against the readback path
on all three frames, three rounds, the way unit 3.9 measured: same session, same window, the two
renderers swapped between runs. Written verdict in this document either way, including what the four
unmeasured copies of §7b turn out to cost.

### 7f. Stop rule

The same shape as the other plan's: if 7.6 measures the presented path no faster than the readback
path on the reference frame, the verdict is written and the code stays behind its opt-in rather than
being tuned. What this phase removes is host cost, not arithmetic, so a null result would mean the
frame was never spending time there — which is worth knowing, and is the one thing §2 asserts
without having measured it.

### 7.1 as built, 1 November 2026

Three classes in `VectorGraphics-Vulkan` under a new `Present` tag, and one narrowing of §6b's host.
No Vulkan object is created in this unit: the subject is the window that has room for one.

**The opt-in is a flag, not a configuration.** `VGVulkanPresentHost class >> isEnabled` reads a
class-side variable that only `enableDuring:` sets, and `isSupported` is `self
respondsToVulkanDriver and: [ self isEnabled ]`. §6b's host is narrowed to `self
respondsToVulkanDriver and: [ VGVulkanPresentHost isEnabled not ]`, and the shared half moves to
`VGVulkanDriverSdl2Host class >> respondsToVulkanDriver`, so the three-way partition is written once
in each direction rather than twice in one. The `isKindOf:` test for the driver stays as §6b wrote
it, because `PVVulkanDriver` is a subclass of the driver Bloc's own host names by class name.

**The window with no SDL renderer.** `BlOSWindowSDL2HostSpace >> initializeWithAttributes:` ends
with `window newBlocRenderer`, which is where the SDL accelerated renderer and the streaming texture
are built; `VGVulkanPresentHostSpace` repeats that method without the last line. The cost of that is
one inherited method that no longer works: `OSBackendWindow >> canvasExtent` answers `renderer
canvasExtent`, so `physicalSize` fails with `receiver of "canvasExtent" is nil` and is overridden to
ask `OSSDL2VulkanBackendWindow >> vulkanDrawableExtent`, which is `SDL_Vulkan_GetDrawableSize` and
is the right question for a swapchain anyway. `lockSurfaceFor:scaleFactor:during:` answers `self
shouldNotImplement`: the seam §6 found is held open by refusing the CPU route out loud rather than
by a comment saying nobody takes it.

**The renderer falls back rather than failing.** `VGVulkanPresentRenderer >> render:` counts the
frame only for a `VGVulkanPresentHostSpace` and sends `super render:` for anything else. The reason
is `BlHostRenderer preferableClass`, a single global choice: a renderer class that assumed its host
space presented would break every other window in the image the moment it became preferable, and
§7c's division of labour puts the window's kind on the host space, which is the object that knows.

**What holds it.** `VGVulkanPresentHostTest`, eight tests:

| Test | Fact |
|---|---|
| `testThePresentHostIsSupportedOnlyWhileEnabledUnderTheVulkanDriver` | the flag and the driver are both required |
| `testExactlyOneSdl2HostIsSupportedInEveryCombination` | the three hosts partition in all four driver-by-flag combinations |
| `testTheWindowOfMyHostSpaceIsAVulkanWindow` | the backend window is an `OSSDL2VulkanBackendWindow`, so `SDL_WINDOW_VULKAN` is in its flags |
| `testMyWindowOwnsNoSdlAcceleratedRenderer` | its `renderer` is nil — the point of the unit |
| `testTheCpuSurfaceLockIsRefusedByMyHostSpace` | the lock raises `ShouldNotImplement` |
| `testThePhysicalSizeOfMyHostSpaceComesFromTheVulkanDrawable` | `physicalSize` equals `vulkanDrawableExtent` |
| `testAFrameOfMySpaceReachesMyRendererAndNotTheSurfaceLock` | a frame of a real space on this host arrives at the new renderer |
| `testMyRendererDrawsTheCpuFrameForAHostSpaceThatDoesNotPresent` | with the new renderer preferable, a `VGPixelBufferHost` space still draws its pixels, and the frame count stays 0 |

The helper that swaps in a driver Bloc can install moved to `VGVulkanDriverSdl2HostTest class >>
withDriverClass:during:` so both test classes use the one implementation, with the instance-side
method delegating to it.

One test of §6 had to be widened. `VGRendererTest >>
testTheCpuSurfaceLockIsSentByTheFrameMethodAlone` counts the senders of
`lockSurfaceFor:scaleFactor:during:` and expected `BARenderer >> render:` alone, excluding itself
for naming the selector to ask the question. This unit's test names it too, so the exclusion is now
every `TestCase` subclass: a test that names the selector is asking about the seam, which is the
opposite of a frame taking the CPU route through it. The fact the test holds is unchanged — one
production sender, and it is the method a renderer subclass overrides.

The example is `VGVulkanPresentHostExamples class >> hostOfferedWhileThePresentHostIsEnabled`: one
click answers the host a fresh registry offers with the driver installed and the flag set, and puts
the driver, the flag and the singleton back. The view is `VGVulkanPresentHost >>
inspectorPresentHost:`, an eight-row table naming the installed driver, the flag, which of the three
SDL2 hosts is supported now, the host a space would be given, the renderer this host builds and the
spaces open on it — every row asking the live predicate. `run_critics` on the five new classes
reports only the nine class-side trait copies §6b documents.

### 7.2 as built, 4 November 2026

Two halves: a class that owns the chain of Vulkan objects over one window, and the host space that
keeps one such chain per drawable extent and presents a frame through it.

#### `VGVulkanPresentChain`, in `VectorGraphics-Vulkan` under the `Present` tag

One object owns, in this order, the `VkSurface` over the backend window, the `VkSwapchain` at the
window's `vulkanDrawableExtent`, the colour `VkRenderPass`, one `VkFramebuffer` per swapchain image
view, the command pool and its one buffer, the two semaphores and the in-flight fence. It is handed
a `VkContext` and destroys none of it.

The order is stated once, in `partsInCreationOrder`, and `partsInDestructionOrder` answers that list
reversed, which is what `destroy` walks. A framebuffer references an image view of the swapchain and
the swapchain references the surface, so destroying forwards would hand the driver objects whose
dependencies are already gone; writing the order out twice would let the two copies drift. The test
holds the one list against the other rather than a hand-written sequence.

`onContext:backendWindow:` builds the chain inside an `ifCurtailed:` that destroys it, for the
reason `PVHelloTriangleScene class >> prepare:backendWindow:` gives: a raise part way through
initialisation would otherwise strand the Vulkan objects already created on an instance no caller
ever receives.

**Two refusals, both as soon as the driver has answered.** `verifyFormat:` refuses a swapchain whose
format is not `VkRenderConfig formatRenderedIn`: the kernel writes `b8g8r8a8Unorm` words, a presented
frame has to be the same bytes an offscreen frame is, and a frame drawn in swapped channels is worse
than a window that says why it cannot open. `verifySurface:presentsOnQueueFamily:` refuses a queue
family the surface does not accept: presenting on such a queue is invalid use that nothing reports
with the validation layers off — the frame goes nowhere and the next acquire waits for an image the
presentation engine never gives back. The first is arithmetic and is tested without a device; the
second is tested against `VGNonPresentingSurfaceStub`, because no working window system offers a
surface no family can present on.

**Every wait of a frame is bounded.** `frameTimeoutNanoseconds` is one second, and both the fence
wait and the image acquire take it. A Vulkan wait happens inside a plain uFFI call, so the virtual
machine sits in the driver until it returns, the user interface with it, and no Pharo process can
interrupt it; a frame loop that waits without a bound therefore has no way back from a presentation
engine that stops answering. Past the bound the driver answers `VK_TIMEOUT`, which `Vk checkResult:`
raises on, so a stall becomes a failing test instead of a dead image.
`testEveryWaitOfAPresentedFrameIsBounded` holds the bound and reads the method for the selectors it
sends, because the next person to copy the hello-triangle loop would copy `Vk noTimeout` with it.

PharoVulkan needed one change for that: `VkSwapchain >> acquireNextImage:fence:timeout:` is now the
acquire that reaches the driver, and `acquireNextImage:fence:` delegates to it with `Vk noTimeout`,
so every existing sender keeps the behaviour it had. `PVGraphicsTest` holds the delegation.

**The frame.** `presentFrameDuring:` waits for the previous frame's fence, resets it, acquires an
image, evaluates the block with that image — which is where unit 7.4 draws — clears the image in a
render pass, submits, presents, records the index in `presentedIndexes` and answers it. The clear is
a render pass because the pass this chain builds is the one that leaves the image in `presentSrcKHR`,
and the pass is closed explicitly: `VkCommandBuffer >> end` does not close an open pass, which is
also why `PVHelloTriangleScene >> renderFrame` leaves one open. `presentedIndexes` outlives `destroy`,
so an example can close its window and still hand back what it did.

#### The host space half

`VGVulkanPresentHostSpace` gained `presentContext`, `presentChain` and
`presentFrameFor:scaleFactor:during:`, which is the method that stands where
`lockSurfaceFor:scaleFactor:during:` stands on the CPU path and which 7.4 will have the renderer send.

The context is the host space's own, built on first use from `requiredInstanceExtensions`. It is not
`VGVulkanDeviceSession`'s: the session's context is created for compute and carries none of the
instance extensions a surface needs. Unit 7.3 is where the two become one, and `presentContext` is
the only method that has to change for it. (Superseded by 7.3a, which did exactly that: the host
space holds no context of its own any more.)

`presentChain` keeps one chain per drawable extent: it answers the chain it holds while
`matchesDrawable` is true, and otherwise destroys it and builds the next one. A swapchain is created
for one extent and is not valid for another, so a resized window needs a new one — and an unresized
window must not pay for a new one every frame. The test resizes a real window through
`windowExtent:`, waits, bounded, until SDL answers the new drawable extent, and then asserts the
chain is a different one, the old one is destroyed, and the new one is at the new extent.

`close` destroys chain, then context, then sends `super close`, which closes the window: the reverse
of the order they were acquired in, because the surface inside the chain belongs to the instance the
context holds. It tolerates a second close, as the inherited method does.

`VGFrameProfile class >> stageByPackageAndTag` gained `'VectorGraphics-Vulkan/Present' -> #handover`,
which is the entry the `Present` tag has been missing since 7.1, so
`VGFrameProfileTest >> testEveryPackageAndTagOfThisProjectHasAStageAndNoOthers` is green again.

#### The two tabs

`frameReport` answers ten rows, each asking the live chain: whether it is destroyed, how many parts
it still holds, the format and extent the driver gave, the image count, how many frames it presented
and which indexes they went into, whether those covered every image of the swapchain, the frame wait
bound, and whether it still matches the drawable. Every row answers after `destroy` as well, because
the swapchain is gone by the time an example hands a chain back and `presentedIndexes` is what is
left to read.

`inspectorFrames:` is a table over that report, so the tab cannot drift from what the chain answers,
and its gate is active always — after destruction it is the only tab that says anything. `inspectorParts:`
numbers each part by the step of `destroy` that reaches it, reading `partsInDestructionOrder` rather
than a list written in the view, so a part added to the chain appears in the tab untouched; its gate
closes on a destroyed chain, which holds no part. Both are held by device-free tests that build the
presenter on a bare `VGVulkanPresentChain new` and pull each cell by hand, since a table column's
block only runs for a drawn row.

Renraku reports `ReExcessiveVariablesRule` on the chain and it is right about the count: one slot per
Vulkan object owned is the point of the class, and splitting them across helpers would move the
destruction order out of the single list that states it. The class comment says so rather than the
rule being silenced.

#### The example, and the gate that must not run it

`VGVulkanPresentChainExamples class >> openWindowAndPresentFrames` is the one-click example: a real,
visible Vulkan window, thirty frames presented through a chain of its own, and the chain answered
with window, context and driver already released, each by its own `ensure:`. Presenting to a hidden
window would prove nothing about the presentation engine, so the window is visible, and the example
answers nil on a machine with no Vulkan device, as every device example of this project does.

An example suite must not run it, and this unit is where the shared gate learned that.
`VGCairoExamplesTest` ran every `<sampleInstance>` example four times in one pass — once for
`testEveryExampleRunsAndAnswersSomething`, twice for `testEveryExampleRebuildsItsObject`, and again
through `exampleSubjects` for each view gate — which for a window-and-device example means four
windows opened and four devices driven inside one test run. So `allExampleMethods` is now the whole
set, `windowExampleMethods` selects the ones whose selector begins with `open`, and `exampleMethods`
— what every running gate takes — is the rest. `testAnExampleThatOpensAWindowIsNamedForItAndNoGateRunsIt`
holds what is left of the rule structurally: a window example is class-side, pragma-tagged,
argument-free, named `open…`, and absent from the set the gates run. It is run by hand, alone, after
committing, which is what §7f and `~/.claude` memory already say about anything that can take the
image down.

**What the three stalls of 4 November actually were.** Every suite call that opens windows or drives
the device ran past the MCP client's request timeout, which is about a minute, while the image kept
working; the call was abandoned, not the image. Two of them had the whole example suite behind them,
so they were never going to answer in time. The session was then lost for a different reason: a
debugger opened on a failed Epicea write and the image was killed to clear it, which cost the
uncommitted half of this unit and had it replayed from disk HEAD. The lesson for the rest of §7 is
the mechanical one — commit first, then run a long or window-opening suite forked at priority 60 with
its result written to a file in `Smalltalk imageDirectory`, and poll that file in calls short enough
to answer.

### 7.3a as built, 22 November 2026

The grill split unit 7.3 in two. 7.3a is one device for compute and presentation; 7.3b is the frame
that ends on the device, which keeps the gate §7e states for 7.3 and is next. Everything below is
7.3a, and it changes no pixel: it removes the second device the presenting path used to open.

#### One context, chosen by the compute path

`VkContext` gained a `surfaceExtensionNames` slot and
`VkContext class >> presentingContextForExtensions:`, which is the only new way in. The instance it
creates carries the extensions the window system named, and the device is then chosen and built by
the compute path: `initializePresentingForExtensions:` stores the names and calls the existing
`initializeComputeRequiring: #( #supportsGraphicsAndComputeOnOneQueue #supportsSwapchain )`. Going
through the compute path rather than the graphics one is what keeps the kernels working — the
graphics path enables `buildSynchronization2Features`, and the compute path enables
`buildFeatureChain`, which is a superset of it. The device requirement is a pair of unary predicates
because device selection asks its requirements by `perform:`; `VkPhysicalDevice >> supportsSwapchain`
is the new one, reading the name from `VkPhysicalDevice class >> swapchainExtensionName`.

Two methods became conditional on the new slot rather than duplicated:
`instanceExtensionNames` answers the surface names when a presenting context asked for them and
`computeInstanceExtensionNames` — which is empty — otherwise, and
`enabledDeviceExtensionNames` adds `graphicsExtensionNames` only for a presenting context, since a
device that was not required to report the swapchain extension must not be asked for it.
`VkContext class >> graphicsExtensionNames` now names `VkPhysicalDevice swapchainExtensionName`
instead of repeating the string, which is where selection reads it.

The queue family has to do graphics and compute both, because this context creates one queue and
dispatches and presents on it. `supportsGraphicsAndComputeOnOneQueue` already existed for
`offscreenGraphicsContext`, so nothing new was needed for that half.

#### The session owns the one device

`VGVulkanDeviceSession` gained a `contextKind` slot and `openContextOfKind:with:`, which is the one
place that opens a context, records the kind, stamps the image run and turns a failure into
`unavailableReason`. `contextOrNil` opens the compute context through it, and
`presentableContextOrNil` opens the presenting one: a session already presenting answers what it
holds, a session holding a compute-only context releases it first — its instance carries none of the
surface extensions a window needs, so nothing of it can be kept — and a machine whose window system
names no surface extension answers nil. `canPresent` is `presentableContextOrNil notNil`.
`isPresenting` is the one reader of the kind's value, so no caller restates the symbol.
`releaseDevice` clears the kind with the context, and moved to the `initialize-release` protocol,
which is what it does and what keeps Renraku quiet about a unary accessor with no return.

#### SDL will not name the surface extensions until its loader is loaded

The read of the instance extensions answered nil in a fresh image and the names in an image that had
already shown a window, which was the one real surprise of the unit. SDL loads the Vulkan loader
when the first `SDL_WINDOW_VULKAN` window is created, and until it is loaded
`SDL_Vulkan_GetInstanceExtensions` answers false and writes nothing — so host selection, which asks
before any window exists, was told this machine cannot present. `SDL_WasInit(SDL_INIT_VIDEO)`
answering 32 is not enough, and a null window argument is accepted but does not load the loader.

`VGSdl2VulkanLoader` declares `SDL_Vulkan_LoadLibrary`, the one SDL function this project needs and
PharoVulkan does not, and `surfaceInstanceExtensionNames` asks for the loader before reading the
names. The call is reference counted inside SDL and nothing here unloads it, because the loader is
wanted for the rest of the image run. The failing test came first and is kept: with a Vulkan device
present, the names are read before any window has been opened. On this machine they are
`#( 'VK_KHR_surface' 'VK_KHR_xlib_surface' )`.

#### The host space stopped owning a context

`VGVulkanPresentHostSpace >> presentContext` answers `VGVulkanDeviceSession default
presentableContextOrNil` and caches nothing — the session holds the context and may release and
rebuild it, so a copy kept in the host space would outlive the handles it names. The
`presentContext` slot is gone. `close` destroys the chain and no longer destroys the context: it is
the session's one device, which compute frames draw on whether a window exists or not, so a host
space that destroyed it would take the next frame of any kind down with it.
`testClosingMyHostSpaceDestroysItsChainAndItsContext` asserted the opposite and was replaced by
`testClosingMyHostSpaceDestroysItsChainAndKeepsTheSessionsDevice`, which states the fact that now
holds. The paragraph in the 7.2 record saying the context is the host space's own is superseded here.

#### The failover is decided before the window opens

`VGVulkanPresentHost class >> isSupported` now reads
`self isSupportedWithSession: VGVulkanDeviceSession default`, and `isSupportedWithSession:` is the
driver, the opt-in and `aSession canPresent` together. Taking the session as an argument is what
lets a test hold the refusal on a machine that can in fact present:
`VGNoSurfaceExtensionSessionStub` is a session whose window system names no surface extension, by
construction. This is §7d's frozen decision — a swapchain image already acquired cannot turn back
into a `ByteArray` halfway through a frame, so the choice is made at host selection or not at all.

#### The example and the tab

`VGVulkanDeviceSessionExamples class >> sessionThatPresentsAndComputesOnOneDevice` asks a fresh
session for presentation first and for compute after, and draws two frames of the three-shape
encoding. The Lifetime tab names what the context was built for and the Residency tab names the
buffers those frames kept on that very device, so the two tabs together are the fact the unit is
about: no second device was opened for the drawing. `lifetimeRows` gained the `Context built for`
row; `canPresent` is deliberately not a row, because answering it would build the presenting device
rather than report one.

#### Verified

On this machine — Intel Iris Plus Graphics (ICL GT2), queue family 0 — the presenting context asks
the device for `#( 'VK_KHR_shader_float16_int8' 'VK_KHR_16bit_storage' 'VK_KHR_swapchain' )`, the
session's compute context is released and rebuilt on the first presentation request, and the host
space and the session answer the same object. Green, each class run on its own: 13 in
`VGVulkanPresentHostTest`, 16 in `VGVulkanDeviceSessionTest`, 12 in `VGVulkanPresentChainTest`, 13 in
`VGVulkanBackendTest`, 5 in `VGVulkanDriverSdl2HostTest`, 6 in `VGVulkanExamplesTest`, and on the
PharoVulkan side 72 in `VkCoreTest`, 61 in `PVGraphicsTest` and 8 in `VkImageTest`. Renraku is clean
on every class the unit touched.

#### The window suites run in a second image, not in the one being worked in

The image went down three times while this unit was built, every time in a suite that opens a
window: once a hard crash, twice a wedge where the image still accepted a TCP connection but served
no answer, which takes the MCP session down with it and loses whatever was not committed. The cause
is still not diagnosed. What removes the cost of it is running those suites in a child image instead:

```
"<vm>" "<image>" st --quit --no-source "<script>.st"
```

started from the working image with `LibC system:` and a trailing `&`, with the script writing
`aTestClass suite run printString` into a file under `Smalltalk imageDirectory` — the agent
scratchpad is not writable from the image, and `ensureCreateFile` has to come first because
`isWritable` is false for a file that does not exist. The child reads the saved image, so the work
has to be committed and the image saved before it is started, which is the discipline those three
incidents were asking for anyway. The child's own Morphic world fails to start under `st`
(`OSSDL2FormRenderer >> outputExtent` is nil, printed repeatedly on stderr) and the suites run green
regardless, since they build their own host and window. All the counts above were taken that way for
the five window-opening classes, and in the working image for the rest.

One thing is known and not fixed here. `OSSDL2VulkanBackendWindow >> requiredInstanceExtensions`
tests `result = 0` on a value the uFFI call answers as a Boolean, so both of its `Error signal:`
paths are dead code; the bug workflow for it comes next, failing test first.

### 7.3b as built, 22 November 2026

The frame that ends on the device. Nothing of a frame crosses to the host any more on this path: the
target buffer is copied into a `VkImage` by `vkCmdCopyBufferToImage`, and the two host copies a
drained frame paid — reading the surface into packed bytes and writing them back — are gone from it.

#### The copy

`VGTiledFillDispatch >> draw:into:endingIn:` runs the frame with `readBack: false` and then sends
`copyTargetInto:`, which allocates a command buffer from a command pool of its own, transitions the
image to `VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL`, records the copy of the `#target` buffer into it
with the region `VkCommandBuffer class >> regionForExtent:` builds, and submits it with a wait. The
caller owns the image and the layout it wants it in afterwards. A frame that touches no tile
dispatches nothing and copies nothing, and answers the image untouched.

The pool is the dispatch's own (`copyCommandPool`, released and nilled by `releaseDevice`) rather
than the kernel's, because the kernel's pool belongs to the dispatch it records compute work in.
The target buffer is now created with `VkBufferUsage transferSrcBit` beside the storage bit — a
buffer a copy reads has to carry it — which is `VGTiledFillDispatch class >> bufferUsage`.

`stageNames` gained `#copy` beside `#readback`, and the comment says what the pair means: one frame
pays one of the two and never both. A new `Stages` tab on a dispatch shows every stage the table
names with what it cost or `not reached`, read off `stageNames` so a stage cannot appear there under
a name no report uses. That tab is how the kind of a frame is read by eye.

#### The backend

`VGVulkanBackend >> drawFrameInto:` is the path a presenting window takes: it encodes the frame it
has recorded for the extent of the image it is given and dispatches it with the copy, where
`drainInto:` would have encoded for a surface and drained. The device trip the two share was
extracted as `dispatchOf:during:` — the session lookup, the refusal when no device computes, and
the handler that releases the session and refuses when one fails — so `dispatch:into:` and
`dispatch:into:endingIn:` differ by the block that says where the frame ends and by nothing else.

#### The gate

`VGTiledImageCopyTest`, six tests, green against the device on this machine:

- every one of the 37 cases of the conformance subset drawn into an image through the copy holds
  what the software backend draws for the same case, within the tolerance of `VGTiledFrameTestCase`;
- the image a frame ends in holds the pixels the same frame read back holds;
- a frame that ends in an image records the `copy` stage and no `readback` stage;
- a frame drawn through `VGHostPixelRefusingBackendStub`, whose `pixelsOf:` and `write:into:` raise,
  reaches neither and still lays pixels down — which is the fact the unit is about;
- a frame with nothing recorded leaves the image as it was;
- the backend draws its recorded frame straight into an image.

The stub answers `false` to `isCandidate`. It has to: `VGBackend class >> candidateClasses` finds
candidates by reflection over subclasses, so a backend fixture that does not refuse is ranked ahead
of the real one and chosen for every surface in the image. `VGFailingDrainBackendStub` already
refuses the same way; the new stub now reads like it.

`VGTiledFillExamples class >> frameEndedInAnImageOnThisMachine` is the example: a frame of one shape
left in a Vulkan image, whose `Image` tab shows the layout a copy writes into over a live handle.
It answers an image that was never created where no device computes.

#### Verified

Green in the working image: 6 in `VGTiledImageCopyTest`, 49 in `VGTiledFillTest`, 13 in
`VGVulkanBackendTest`, 12 in `VGVulkanRoundTripTest`, 16 in `VGVulkanDeviceSessionTest`, and 293 in
`VkBindingsTest` on the PharoVulkan side. `VGVulkanExamplesTest` ran in a child image, the way §7.3a
records. Renraku is clean on `VGTiledFillDispatch`, `VGTiledImageCopyTest`,
`VGHostPixelRefusingBackendStub` and `VkBufferUsage`; the one critique on `VGVulkanBackend` is
`ReExcessiveArgumentsRule` on `blitSurface:at:paint:clip:operator:`, which this unit did not touch.

Commits: `718db16` on PharoVulkan (the transfer-source bit and the decoder entry it was missing),
`93ee8b1` on VectorGraphics (the copy, the backend path and the gate).

#### The image went down once more

Running `VGVulkanExamplesTest` through MCP in the working image wedged it a fourth time, and the
whole of 7.3b was replayed from the dead session's Epicea log afterwards. Two class additions did
not replay — `applyCodeChange` raised nothing and created nothing — so both classes were recreated
by hand from the `EpBehaviorCommentChange` entries, and their methods replayed after that. The rule
stands and is now the only way these suites are run: a window-opening or example-walking class goes
to a child image, never to the working one.

## 8. What this is not

Not a phase of `VECTORCANVAS-PLAN.md`, not gated by anything in its §9, and not expected to change
unit 3.6's verdict for the general case — Bloc's default stays Cairo regardless, since this document
is about removing a cost specific to the device path, not about the device becoming cheaper than
Cairo everywhere. It would matter only for whatever a caller specifically wants a Vulkan-presented
window for, which is a product question this document does not answer.

Related: `VECTORCANVAS-PLAN.md` §3 (seam rules), §8 (backend selection), §12 and 3.6/3.7 (the
numbers this document's §2 reads from); `~/workspace/CLAUDE.md` (PharoVulkan package layout and the
graphics-path classes §4 of this document names).
