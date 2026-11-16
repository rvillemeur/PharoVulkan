# FONT-PLAN — fonts for Bloc without FreeType

## 1. Goal

`VectorGraphics-TrueType` is a font parser written in Pharo: it reads from a font file everything a
renderer needs to know about it. `Alexandrie-FontManager` reads the same things through
`Alexandrie-FreeType` and the native FreeType library, and hands them to Bloc's renderer.

The goal is to give Bloc the same service from the Pharo parser, and to remove every dependency on
FreeType, so that an expensive external native library stops being something this project has to
keep working.

Make Bloc load, choose, measure and draw fonts with the VectorGraphics TrueType stack alone, so that
no `AeFTFace` and no `AeFTLibrary` is created on the text route, and so that
`Alexandrie-FreeType` and `Alexandrie-CairoFreetype` can be unloaded from the image while text still
renders.

**Who draws.** Cairo does, as it does today: every figure, every composition, the whole page. Our
Pharo code supplies font information only — which families exist, their metrics, the glyph
identifiers of a run, and the outlines of each glyph. The target of this plan is therefore the stock
Alexandrie backend and `BARenderer`, not `VGRenderer`. `VGRenderer` inherits the work for nothing,
because it already draws text through `VGFontFace` and `VGScaledFont`, but it is neither the goal
nor the proof.

One boundary inside that, decided in point 2 and measured: the glyph coverage comes from our
rasteriser, as an A8 mask Cairo blits with `cairo_mask_surface`, at 0.42 us a glyph warm.
Handing Cairo the outlines as a path and letting it rasterise each glyph itself costs 50 us a
glyph, 120 times as much, so the path route serves text shadows and text-as-path only (unit 4.4).

**What this does not remove.** Only FreeType goes. The stock backend still calls `libcairo`, by
design, and HarfBuzz is still `libharfbuzz` when Bloc enables it. A text route with no native
library at all exists only on `VGRenderer`, which is outside this plan.
HarfBuzz needs no help from us: `AeFileFaceEntry >> newHbFont` and
`AeMemoryFaceEntry >> newHbFont` build an `AeHbBlob` from a path or from bytes, so shaping never
touched FreeType. It is the FT variants — `AeHbFace class >> unownedNewForFTFaceReferenced:`,
`unownedNewForFTFaceCached:`, `AeHbFont class >> unownedNewFTFaceReferenced:`, `AeHbFont >> lock` —
that become dead code.

**Where the service is not yet the same, and what follows.** FreeType reads font formats our parser
does not, and `AeFontScanner >> shouldIgnoreFile:` filters nothing but dotfiles and `.gz`, so every
one of them is registered today. Counted over the directories the scanner really walks on this
machine — `~/.fonts`, `~/.local/share/fonts`, `/usr/share/fonts`: 362 `ttf`, which we read, against
101 `otf`, 35 Type 1 (`t1` plus `afm`) and 3 `ttc`, which we do not. The families lost are not
marginal: Cantarell, which is Fedora's interface font, Cascadia Code, STIX, the URW Base35 set and
the variable Noto CJK faces, which carry the whole CJK coverage.

Decision 14 takes that cost knowingly. Phases 1 to 7 remove FreeType over the `glyf` subset, and
phase 8 closes the format gap with a CFF/Type 2 parser in Pharo. Nothing else of FreeType is
ported: variable fonts, hinting, colour glyphs (`CBDT`, `sbix`, `SVG`), bitmap strikes, Type 1 and
fontconfig family matching stay out of scope. A font we cannot read is a font we refuse by name,
with the reason recorded, not a font we half-support.

## 2. What the chain does today

Measured in the live image.

`BATextParagraphSpan >> measure` sends `font asAeFTFace`, then
`canvas scaledFontForFace: face size:`, then `cairoScaledFont glyphArrayForString:` and
`canvas metricsFor: glyphs font:`.
`BlFont >> asAeFTFace` goes through `BAFontConverter >> faceFor:`, which asks
`AeFontManager globalInstance detectFamilyName:slant:weight:stretch:ifNone:` and then `faceAt:`.

FreeType enters at exactly two points of that chain.

1. Discovery and naming: `AeFontManager >> registerFacesOnFile:` reads family name, style name,
   `isBold` and `isItalic` through `AeFTLibrary >> fastReadFacesOn:do:`.
2. The face itself: the manager's LRU cache has `anEntry newFaceWith: freetypeLibrary` as its
   factory, which answers an `AeFTFace`.

Cairo then rasterises the glyphs through that FreeType face, which is the third point, upstream of
`AeCanvas` and inside `libcairo`.

Two facts make the replacement small.

`AeCanvas >> scaledFontForFace: aFace size: size` sends `aFace newCairoFontFace` and then
`newScaledFontWithFontMatrix:userToDeviceMatrix:options:`.
Both are messages, not class references, so a face of ours put in the manager makes an unmodified
`AeCanvas` build a `VGScaledFont` with no override at all.

`AeCanvas` sends only five text messages, and four of them go straight to its `cairoContext`:
`drawGlyphs:font:`, `appendGlyphsPath:font:`, `textExtentsFor:scaledFont:do:` and
`metricsFor:font:`, the last built on the third.
So the context, not the canvas, is the place where glyph drawing is decided.

FreeType is confined to `Alexandrie-FreeType`, with four production dependents only:
`Alexandrie-CairoFreetype` (`AeCairoFreetypeFontFace`), `AeCairoScaledFont >> lock`, the FT variants
of `Alexandrie-Harfbuzz`, and `AeFontManager >> reset`.
That is why the proof by absence in phase 6 is two package removals and not a fork of Alexandrie.

Morphic has its own FreeType stack, the `FreeType` package and its `FreeTypeFontProvider`, and Bloc
uses none of it.
The two bind the same library and share nothing else, so removing Alexandrie's two packages leaves
the Morphic user interface untouched; what breaks is test code, and nothing in the running image.
`VGFontFace class >> defaultBytes` reads Pharo's embedded family through `FreeTypeFontProvider`, but
it reads bytes only and makes no FreeType call, and the Bloc route does not need it at all, because
unit 3.6 registers Alexandrie's own embedded font files.

HarfBuzz needs no FreeType either.
`AeFileFaceEntry >> newHbFont` and `AeMemoryFaceEntry >> newHbFont` go through `AeHbBlob
newLocatedAt:` and `newFrom:`, which take a path or bytes.
Bloc does not shape with it today — the HarfBuzz line in `BATextParagraphSpan >> measure` is
commented out and only the Cairo route is live — so shaping stays out of scope here.
The plan keeps the blob route intact all the same, so that enabling HarfBuzz later needs no
FreeType: `AeHbFace class >> unownedNewForFTFaceReferenced:`, `unownedNewForFTFaceCached:`,
`AeHbFont class >> unownedNewFTFaceReferenced:` and `AeHbFont >> lock` are the FT variants, and our
entries must never reach them.

## 2b. The two registries we already have

`VectorGraphics-TrueType` has two consumers today, and they share no object with Alexandrie.

`TTFontDescription`, `TTGlyph`, `TrueTypeFont` and `FontFamily` serve `VectorGraphics-Engine`:
`VectorCanvas >> drawString:from:to:at:font:color:` and
`VectorEngineAbstract >> displayUtf8:at:trueTypeFont:color:scaleX:scaleY:`.
That is the Morphic-shaped API — a point size, a `FormGlyph`, glyphs rasterised into a `Form`.

`VGFontFace >> readBytes:` uses none of those classes.
It sends `TTFontReader new buildTableDirectory: aByteArray offset: 0` and then the table parsers
directly, and keeps contours and advances rather than forms.
That is why the face of the Bloc route is a `VGFontFace`: the Cairo path needs outlines and a
matrix, which `VGScaledFont` and the A8 masks are built on, and `TrueTypeFont` rasterises at a
pixel size with no matrix at all.
`TTFontDescription` stays the model of the `VectorCanvas` route, untouched.

`FontFamily` carries its own registry in three class variables, `AvailableFamilies`,
`DefaultFamilyName` and `DefaultPointSize`, and it has no discovery of its own: the dictionary is
filled by hand through `addFamily:`, from examples and tests.
So the shared discovery of decision 13 has nothing to dismantle.
It fills a registry that is empty by default, and it gives the `VectorCanvas` route a scan it never
had.

## 3. The decisions

Taken in the interview of 2026-11-07, in this order.

1. **Scope**: the stock Cairo backend. Cairo keeps drawing; our code supplies the font information
   it draws from. `VGRenderer` gains the same fonts as a side effect and is not the proof.
2. **How real Cairo gets our glyphs**: A8 masks blitted with `cairo_mask_surface`.
   No `cairo_user_font_face_create`, no `FFICallback`.
   Measured at 0.42 us a glyph warm, which is parity with Cairo plus FreeType, and 50 us cold.
3. **The registry**: a subclass of `AeFontManager`, installed as `globalInstance`, so the thirteen
   packages that send `AeFontManager globalInstance` keep working and no upstream method is
   rewritten.
4. **The face object**: `VGFontFace` itself, which gains `familyName` and `styleName` read from its
   own `name` table, so the `AeFTFace` bridge disappears.
5. **Metadata**: a dedicated metadata-only reader, reading the table directory and then `name`,
   `OS/2` and `head`, leaving `VGFontFace` and its tests untouched.
6. **The hook on the Cairo path**: a context subclass reached by the surface, not a canvas subclass.
7. **The substitution**: one extension method in `VectorGraphics-Bloc` redefines
   `AeCairoSurface >> newContext`, which covers window, composition layers, shadows, exporters and
   offscreen at once, with no uncovered site.
8. **Refused fonts**: ignored at scan time, with the path and the reason kept in a readable
   collection; a text asking for such a family falls back through the `ifNone:` already in place.
9. **The guard**: proof by absence — unload the FreeType packages and check text still draws.
10. **Where that proof runs**: in the working image, there and back, on a committed checkout and a
    saved image, with the Metacello reload script written before the removal.
11. **The criterion for text**: metric invariants, not a pixel comparison against FreeType.
    Glyph identifiers from `cmap`, advances from `hmtx` to the rounding tolerance, run extents that
    enclose the drawn ink, and a Bloc paragraph width equal to the sum of the advances.
12. **The face cache**: permanent, keyed by entry, reset on a session change.
    A full parse costs 200 ms on a 2.2 MB face, so eviction is the thing to avoid.
13. **One discovery for two registries**: the scan and the naming live once, in
    `VectorGraphics-TrueType`, and both registries read from it — `VGFontManager` for the Bloc and
    Cairo route, `FontFamily` for the `VectorCanvas` route.

14. **The format subset is accepted, then closed.** FreeType leaves on the `glyf` subset, and CFF
    becomes phase 8 rather than a prerequisite. The result is demonstrable early, and Alexandrie's
    own `ifNone:` already absorbs a family that is not registered.

## 4. Package layout

The architecture gate carries direct edges only, and `VectorGraphics-Bloc -> VectorGraphics-Cairo`
is the only edge out of the Bloc layer today.
The catalogue of decision 13 belongs in `VectorGraphics-TrueType`, because the `VectorCanvas` route
reads it too and the Engine layer may not name a Cairo class.
So `VectorGraphics-Bloc -> VectorGraphics-TrueType` is declared as a new edge, in
`allowedDependencies` and in the baseline, rather than hidden behind a facade class in the Cairo
layer that would exist only to dodge the table.
The dependency is real: the Bloc manager is an adapter onto the font catalogue.

| Package | What it gains |
|---|---|
| `VectorGraphics-TrueType` | `TTFontMetadata`, `TTFontMetadataReader`, `TTFontCatalogue`, `TTOS2TableParser`, `macStyle` on `TTHeadTableParser`, `buildTableDirectory:offset:` extracted to the class side, `FontFamily class >> addFamiliesFrom:` |
| `VectorGraphics-Cairo` | `VGFontFace >> familyName`, `styleName`, `newCairoFontFace`, A8 mask bytes on `VGGlyphMask` |
| `VectorGraphics-Bloc` | `VGFontManager`, `VGAeTextContext`, `VGAeTextFont` (unit 4.7), `AeFontManager class >> globalInstance:`, `AeCairoScaledFont >> aeTextFont`; the `newContext` override was withdrawn in 4.6 |

`VectorGraphics-Bloc` is already the one package allowed to name an Alexandrie class, so both new
classes and both extensions belong there.

## 5. The units

Every unit runs the project cycle: failing test first, smallest green, refactor, a class-side
`<sampleInstance>` example in the sibling `-Examples` package, an
`<inspectorPresentationOrder:title:>` view taking the presenter builder, then `run_critics`.

### 1.1 — the metadata reader, built on the parsers that exist

The TrueType package already holds what reads a name: `TTFontParser` is the abstract base, its nine
subclasses parse one table each, `TTNameTableParser >> process` answers the eight name strings, and
`TTFontReader >> buildTableDirectory:offset:` builds the directory of `TTFontTableDirEntry` without
touching the font description.
So this unit writes no parser.
It adds `TTFontMetadataReader`, which stops after the directory and the tables it needs, and
`TTFontMetadata`, the value object it answers, holding `familyName`, `styleName` and the length the
directory records for every table.
The reader holds no state: both doors are class-side, and what survives a read is the metadata, so
the Tables view that says which table was read lives there and not on the reader.

What it must not use is `TTFontReader >> readFrom:fromOffset:`, which demands eight tables and
parses `loca`, `cmap`, `glyf` and `hmtx` — the whole cost a scan exists to avoid.
`buildTableDirectory:offset:` is extracted to the class side first, so the reader and the metadata
reader share one directory scan instead of two copies.

`TTFontDescription` is not reused as the metadata object: only `readFrom:fromOffset:` fills it, and
its `emphasis` guesses bold and italic by matching `'*Bold*'` and `'*Italic*'` against
`subfamilyName`, which is the guess unit 1.2 replaces.

The reader has two doors: `readBytes:` for bytes already in memory, `readStream:` for a file on
disk.
The cost of a scan is the reading and not the parsing — the 362 fonts installed on this machine are
262 MB and 4.6 s of disk, against 14 ms to parse all their name tables — so `readStream:` pulls the
offset table, the directory and the name table and nothing else, which is what
`AeFTLibrary >> fastReadFacesOn:do:` does on the FreeType side.
Measured: naming all 362 files costs 98 ms through the stream door, against 27.98 s when each file
is read whole.

Red: the metadata reader answers `'Source Sans Pro'` and `'Regular'` for synthetic sfnt bytes the
test builds itself — an offset table, a one-table directory and a format 0 name table — so the
TrueType test package stays free of Alexandrie and of the FreeType package phase 6 unloads.
The real embedded font is read in unit 2.1, where the Cairo layer is already in scope.
Also red: it builds no `TTGlyph`, no `TTFontDescription` and no `VGFontFace`, asserted structurally
rather than by a timing.
Also red: given a stream over a 500 KB font, the reader pulls fewer than 1024 bytes.

### 1.2 — weight, stretch and slant

Two gaps in the vendored stack, and the only new parsing in this plan.
No `OS/2` parser exists, so `TTOS2TableParser` joins the nine, answering `usWeightClass`,
`usWidthClass` and `fsSelection`.
`TTHeadTableParser >> process` skips `macStyle` by `entry skip: 6`, so it gains that key.

This is not a port of what FreeType gives: FreeType gives upstream none of it.
`AeFaceEntry >> ensureAnalysedAttributes` splits the style name on spaces and
`readStyleFrom:` matches the tokens against word lists, with special cases for `'boldoblique'` and
`'bold.1.1'` and a list of tokens it ignores outright.
Reading `OS/2` and `macStyle` is therefore strictly better information than the chain has today.

The metadata speaks the font format's language, not Alexandrie's: `weightClass` on the OS/2 100 to
1000 scale, `widthClass` on its 1 to 9 scale, `slant` as `#normal`, `#italic` or `#oblique`.
`AeFontWeight value` is already that same scale and `AeFontStretch` numbers the same nine steps from
zero, so unit 3.2 maps a width class by subtracting one; naming the fields for the fields they are
read from is what keeps that off-by-one visible.
A font with no `OS/2` table is classified from `macStyle` alone, which carries one bold bit, one
italic bit and one condensed bit; a font with neither table is the normal face rather than nil,
because a nil weight would reach the font manager as a face that matches nothing.

Red, on synthetic sfnt bytes the test builds: a face stating weight 700, width class 3 and the
italic bit answers those three; the oblique bit beats the italic bit; a font with no `OS/2` table is
read from `macStyle`; a plain face is 400, 5 and `#normal`; a font with neither table is too; a
`usWeightClass` of zero falls back to `macStyle`; and the stream door still pulls under 1024 bytes
of a 500 KB font now that it needs three tables instead of one.

What the installed fonts say, through `TrueTypeExamples styleCountsOfTheInstalledFonts`: ten weight
classes in use (100 to 900, and 350), width classes 2 to 7, 117 italics and two obliques over 362
faces, of which 98 are the plain 400, 5, `#normal` face.

### 1.3 — the refusal

`TTFontMetadata` carries a `rejectionReason`: a symbol, or nil for a face this project can draw.
Five causes, and the first one met answers, in this order: `#notAnSfntFont` for a file too short to
hold an offset table or carrying a version word the reader does not know, `#fontCollection` for a
`ttcf` file, `#noNameTable`, `#noGlyfTable` for the CFF outlines of an OpenType font, and
`#colourFont` for a face carrying `CBDT`, `sbix` or `SVG `.
A rejected face still carries every name and class its file did state, because the catalogue of unit
1.4 must be able to say which font it passed over; a collection and a file that is not a font state
nothing to carry.
Nothing is signalled and nothing is raised, which is where the metadata reader parts company with
`readFrom:fromOffset:` and its `self error: 'Missing required TrueType table: ', tag`.

The detections cost nothing: both doors already hold the whole table directory, since `lengthsFrom:`
records the length of every table, so a tag is known by presence without a byte of disk.

Red, on synthetic sfnt bytes the test builds: an `OTTO` file answers `#noGlyfTable` and still names
its family; a `ttcf` header answers `#fontCollection` and names nothing; a font carrying `glyf` and
`CBDT` answers `#colourFont`; a font with outlines and no name table answers `#noNameTable`; 36
bytes of text answer `#notAnSfntFont`; a font truncated before its directory, and one truncated
inside a table it points at, answer `#notAnSfntFont` rather than raising `SubscriptOutOfBounds`; a
font with outlines and a name is not rejected; and both doors answer the same reason for the same
bytes.

What the installed files say, through `TrueTypeExamples rejectionReasonsOfTheInstalledFonts`: over
the 544 files the font directories hold, 362 are drawable, 101 are `#noGlyfTable` — OpenType files
whose outlines are CFF, which FreeType draws today and this project does not — 3 are
`#fontCollection` and 78 are `#notAnSfntFont`, the metrics and bitmap fonts that live beside the
real ones.
Nothing raised over the 544, which is what lets a scan read a whole directory with no handler:
`metadataOrReasonFor:` and its `on: Error do:` are gone, and with them the `isString` test the
unit 1.2 review had flagged.

Both points of the unit 1.2 design review held for this unit are settled by it: the `name` table is
read only when the directory holds it, so `readNamesInto:fromEntries:` no longer raises
`KeyNotFound` where its sibling tolerated a missing table, and the examples read one answer type
with no handler and no `isString`.

A third point stands on its own, as a unit of its own rather than a side effect of this one:
`TrueTypeExamples class >> defaultFontPath` answers a path under `/home/renaud/Downloads`, which
exists on one machine. It takes a failing test first, like any bug.

### 1.4 — the catalogue, one discovery for two registries

`TTFontCatalogue` in `VectorGraphics-TrueType`: which families exist, where the bytes of each face
are, and the weight, width and slant of 1.2.
It builds no face of either kind.
A full parse costs 200 ms and a name read under 1 ms, so the catalogue stays at the cheap end and
each consumer builds its own face on demand: `VGFontFace` from `entry bytes` for the Cairo and Bloc
route, `TTFontDescription` through `TTFontReader` for the `VectorCanvas` route.

Decided in the interview of 2026-11-11, eight points.

1. **One entry class**, `TTFontCatalogueEntry`, holding a `source` and a `TTFontMetadata`. No
   `index` beside them, as `AeFileFaceEntry` carries: 1.3 refuses a `ttcf` collection, so the face
   index of a readable file is always zero and states nothing.
2. **The source answers for its own bytes.** `entry bytes` is `source fontBytes`, and the two
   sources declare that message themselves: `FileReference >> fontBytes` reads the file,
   `ByteArray >> fontBytes` answers itself. Both are extension methods of this project, classified
   `*VectorGraphics-TrueType` with a line saying why, so no conditional on the kind of source
   appears anywhere.
3. **Two doors, each with its own reader door.** `addFile:` opens a stream and reads the metadata
   through `readStream:`; `addBytes:` reads it through `readBytes:`. A scan therefore never calls
   `fontBytes`: the 362 installed faces are 262 MB and 4.6 s of disk read whole, against 14 ms
   through the stream door.
4. **One list of everything, an index of the drawable.** `entries` holds every file the scan met, in
   the order it met them; `entriesByFamilyName` indexes only the entries whose `rejectionReason` is
   nil. `refusedEntries` is derived from `entries`, so two collections kept by hand cannot drift
   apart, and a family lookup never filters.
5. **The index has the shape of the one upstream.** `familyName asLowercase` to a dictionary from
   `{ slant. weightClass. widthClass }` to an entry, filled with `at:ifAbsentPut:`, so the first
   source met wins, as `AeFontManager >> registerFace:entry:` does with `slantWeightStretch`.
6. **The catalogue carries the directory list and reads no file name.** `defaultFontDirectories`
   holds the five places this platform keeps fonts, `scanDefaultDirectories` walks those that exist,
   and `scanDirectory:` hands every file under it to `addFile:`. No dotfile rule and no extension
   test, unlike `AeFontScanner >> shouldIgnoreFile:`: the refusal of 1.3 says what a file is from
   its content, and one rule is enough. This is decision 13 of §3, and the directory list moves
   out of `TrueTypeExamples class >> fontDirectories`, which then disappears.
7. **The red test scans a `FileSystem memory` directory.** Six synthetic faces over two families,
   one file that is not a font and one truncated inside a table, written into memory and scanned —
   `allChildren` and binary writing both work there. The embedded faces of
   `AeEmbeddedFontFile allSubclasses` are the two families and six faces an earlier draft of this
   unit named, but they are Alexandrie classes and none of the three TrueType packages names one:
   that meeting waits for 2.1, in the Cairo layer. The synthetic builders move out of
   `TTFontMetadataReaderTest` into a fixture class both test classes read.
8. **`defaultFontPath` is fixed after this unit, on the catalogue.** With a catalogue in the image
   the hard-coded path under `/home/renaud/Downloads` becomes the first entry of a scan that is not
   refused, which holds on any machine. Its failing test comes first, like any bug. The first
   drawable entry proved not to be enough: see 1.5.

Not built here: no singleton and no global catalogue, no face of either kind, no duplicate
detection, and no wiring into `VGFontManager` or `FontFamily`, which are units 3.2 and 5.4.

Red: a catalogue that scanned a memory directory of eight files answers two families, eight entries
and two refusals, and `VGFontFace allInstances size` and `TTFontDescription allInstances size` are
both unchanged by the scan.

### 1.5 — the examples find their own font

`TrueTypeExamples class >> defaultFontPath` answered a literal path to a file in one person's
download folder, so the twelve examples that draw text failed on every other machine.
A bug, so its failing test came first: the path the examples draw with must be a font this image
found in the font directories of the machine it runs on.

Point 8 of 1.4 said the fix was the first drawable entry of a scan.
On this machine that is `/home/renaud/.fonts/icons-in-terminal.ttf`, an icon font which maps none of
the letters and digits the examples draw, so `drawString` would trace blanks.
Decided in the interview of 2026-11-12, keeping to Pharo's own habit of naming a few default
families rather than measuring what a face covers.

1. **A preference list, best first.** `preferredFontFamilyNames` answers
   `#( 'Source Sans Pro' 'Source Code Pro' 'DejaVu Sans' 'Liberation Sans' 'Noto Sans' )`. The first
   two are the faces Pharo itself defaults to, through `AeFontManager defaultFontFamilyName` and
   `defaultCodeFontFamilyName`; they ship inside the image rather than in a font directory, so a
   scan finds them only on a machine that installed them as well. Any drawable face of the scan
   when the machine has none of the five, and an error when it has no drawable face at all.
2. **The catalogue gains the two questions this asks of it.** `drawableEntries`, the other side of
   `refusedEntries`, and `entryOfFamilyNamed:`, which takes the name a font states in any case and
   answers the upright, normal weight, normal width face of that family, any face of it otherwise,
   and nil for a family it does not hold. No name matching beyond case: that is 5.4's business.
3. **Found once and kept.** A scan costs some 85 ms and the examples ask a dozen times over a suite
   run, so `DefaultFontPath` holds the answer. A kept path that no longer names a file is found
   again, which covers an uninstalled font and the image file carried to another machine;
   `forgetDefaultFontPath` looks again for any other reason, and `defaultFontPath:` draws with a
   font of the reader's own, which is what the old comment told them to do by overriding the method.
4. **The choice is shown, not explained.** The `defaultFontChoice` example answers the families
   asked for, those installed here, how many drawable faces the scan found, and the path it lands
   on.

The cost is real and is the face, not the scan: the package suite goes from 2.4 s to 6.0 s, because
every example that draws now parses a 760 KB text face at 193 ms rather than a 34 KB display font at
3 ms, some two dozen times over a run.

Not built here: no family-name matching by alias or substring, no coverage test of what a face maps,
and no platform list behind `defaultFontDirectories`, which still names the five places this
platform keeps fonts.

Red: `TrueTypeExamples defaultFontPath` names a file that exists and lies under one of
`TTFontCatalogue defaultFontDirectories`.

### 2.1 — the face names itself

`VGFontFace >> familyName` and `styleName`, read from the face's own `name` table through the reader
of 1.1, so one parser answers for both routes.
Decided in the interview of 2026-11-12.

1. **The face keeps the reader's object, not its strings.** A `metadata` slot holds the
   `TTFontMetadata` that `TTFontMetadataReader readBytes:` builds from the same bytes `readBytes:`
   reads its tables from, and the two accessors delegate to it. The weight, width and slant the
   metadata also carries stay unexposed until 3.2 says what shape the manager wants them in.
2. **The two refusal regimes stay separate.** `readBytes:` keeps its own `requiredTableTags` check,
   which does not ask for a `name` table, and stores what the reader answers whether or not the
   reader would have refused the font. So a font stripped of its `name` table is still a face that
   draws, and only its two names answer nil. Neither refusal is expressed in terms of the other,
   because what the face needs to draw and what the reader needs to name are not the same tables.
3. **The fixture is the face's own bundled bytes.** `VGFontFace defaultBytes`, 293 956 bytes of
   Source Sans Pro, rather than `AeSourceSansPro_Regular` as this section first said. The class
   side already states `defaultFamilyName` and `defaultStyleName` for those bytes, so the test
   confronts the constants with what the reader answers and the two cannot drift apart.
4. **The names go in the view that already exists.** `inspectorFace:` gains a `Family` and a `Style`
   row at its head, which needs no new `inspectorFaceContext:` gate, and the example stays
   `VGScaledFontExamples class >> fontFaceOfASystemFont`, already in
   `VGCairoExamplesTest >> exampleHolders`. No `VGFontFaceExamples` holder and no `inspectorNames:`
   tab for two rows.

The second table-directory walk the reader does over bytes `readBytes:` has already walked costs
nothing worth removing: the whole metadata read is under a millisecond of the 8 ms a face takes, and
the only way to drop it — handing the reader the directory already built — would skip its
`#notAnSfntFont` and `#fontCollection` refusals, which the face does not make itself.

The design review that followed split `readGlyphsAndHorizontalMetricsFrom:count:`, twenty-four lines
and two jobs, into `readHorizontalMetricsFrom:`, `readGlyphRecordsFrom:count:` and
`fillGlyphAdvancesFrom:numHMetrics:` behind a three-send coordinator, and moved the
`requiredTableTags` loop out of `readBytes:` into `refuseIfATableIsMissingFrom:`.
`ReExcessiveVariablesRule` still reports `VGFontFace`, at fourteen slots against a threshold of ten.
It was already over before this unit, and the one coherent cluster left — `glyfEntry`, `glyfStart`
and the three methods that read the glyf table as a byte cursor — would return two slots and keep
the critique, so it waits for a second table that needs a cursor.

Not built here: no `metadata` accessor, no weight, width or slant on the face, and no collapsing of
the metrics slots into `VGFontExtents`, which `VGScaledFont >> computeFontExtents` builds in scaled
space while the face speaks in font units.

Red: a face built from the embedded bytes answers `'Source Sans Pro'` and `'Regular'`, the same
family and style the reader answers for those bytes.
It failed with `MessageNotUnderstood: VGFontFace >> #familyName`.

### 2.2 — the declared edge

`VectorGraphics-Bloc -> VectorGraphics-TrueType` is added to
`VGArchitectureTest class >> allowedDependencies` and to the two baseline declaration methods,
because `VGFontManager` is an adapter onto `TTFontCatalogue` and the dependency is real.
No facade class is added in the Cairo layer to dodge the table.

Red: the architecture gate fails with the manager in place and the edge absent, and passes once the
edge is declared; the test that loads the baseline still loads.

Built inside 3.2, since that is the unit whose `reset` first names `TTFontCatalogue`: one row, and
no edge declared ahead of the class that needs it.

### 2.3 — the face answers for Cairo's two messages

`newCairoFontFace` answers the face itself.
`newScaledFontWithFontMatrix:userToDeviceMatrix:options:` already answers a `VGScaledFont`.

Red: an unmodified `AeCanvas` given one of our faces answers a `VGScaledFont` from
`scaledFontForFace:size:`.

Built on 2026-11-13, interviewed first. Commits `cd861377` and `06445f8c`.

`VGFontFace >> newCairoFontFace` answers the face itself, so Alexandrie's own `AeCanvas` builds one
of our scaled fonts for one of our faces with no class of either backend named in the source. That
and `newScaledFontWithFontMatrix:userToDeviceMatrix:options:` are the two messages the Cairo font
protocol sends a face, which is why they sit together. Nothing in `VGCanvas` was touched: its
`scaledFontForFace:size:` stays as it is, cache bug included, and the decision about its survival
belongs to 5.2.

`VGCanvasTest >> testAnUnmodifiedCanvasAnswersOneOfOurScaledFontsForOneOfOurFaces` is the red, with
four assertions: the canvas is an `AeCanvas` and not one of ours, the answer is a `VGScaledFont`,
its face is the one given, and its font matrix is the size scaled. `VGCanvasExamples class >>
scaledFontAnUnmodifiedCanvasAnswers` shows the object, beside its companion
`scaledFontForTheDefaultFace` which shows the same seam through `VGCanvas`. `VGFontFace >>
inspectorFace:` gained a row that sends `newCairoFontFace` rather than saying what it answers, so it
stops being true the day the method answers something else.

Two real breaks came out from behind the new seam, both fixed here with the failing test first.

1. The canvas hands the scaled font its own `AeCairoFontOptions`, not a `VGFontOptions`, and our
   measurements ask the options record one question it does not answer: `hintsMetrics`. Both
   `VGScaledFont >> fontExtents` and `>> glyphAdvanceOf:` raised
   `MessageNotUnderstood: AeCairoFontOptions >> #hintsMetrics`, so a face reached this way could be
   scaled but never measured. `AeCairoFontOptions >> hintsMetrics` is an extension in
   `VectorGraphics-Bloc`, because Alexandrie's classes are never edited in this project; it reads
   `CAIRO_HINT_METRICS_DEFAULT` as off, the same reading `VGFontOptions` takes of its own default.
   Alexandrie's canvas asks Cairo for hinted metrics, so the ascent and the advance come back
   rounded, which is what the test asserts.
2. Alexandrie's `AeCanvas >> inspectionOfSurface:` answers the surface's `Form` itself. The
   inspector sends `asInspection` to what a view answered, which a `Form` does not understand, and
   that send is outside the handler `StInspectionContext >> newInspectionPresenterOnApplication:`
   wraps the build in: the Surface tab raises for any `AeCanvas`, ours included. `VGCanvas >>
   inspectionOfSurface:` passes the Form through the builder, with `inspectionOfSurfaceContext:` for
   its gate.

The examples gate did not catch either one, because it scanned only the views the project wrote on
a class's own methods. `VGCairoExamplesTest >> viewMethodsAReaderOpensOf:` is the wider set the
build gate now uses: the selector is looked up, so an inherited view counts, and on an object whose
own class is ours a view the replaced stack wrote counts too, by `replacedStackDefines:`. On an
object an example merely answers — a `Form`, a `BlElement` — the views of its own stack stay out,
as Pharo's always were. `viewMethodsOf:` keeps the narrow set, because the project's own rules, the
gate rule among them, apply to the views the project wrote. The build gate also asserts that a view
answers an `SpPresenter`, which is what `asInspection` needs.

Design review of this unit, executed the same day: one refactoring, `0ef6d164`. The examples suite
has two finders of views and the difference between them is a rule, but only one said so in its
name: `viewMethodsOf:` is now `viewMethodsTheProjectWroteOf:`, beside `viewMethodsAReaderOpensOf:`.
Rejected: delegating `VGCanvas >> inspectionOfSurface:` to `VGCairoImageSurface >> inspectorPicture:`
to drop the duplicated `aBuilder newImage image: … asForm`, because a `VGCanvas` can hold a surface
of Alexandrie's, which does not understand `inspectorPicture:` — a one-line duplication traded for a
conditional doesNotUnderstand. Deferred: the hint-metrics value is read as a `Symbol` by
`VGFontOptions` and as an enum by the extension, which is 4.5 and 5.1's decision about the options
record; the rounding rule stands twice in `VGScaledFont`, and two occurrences are a coincidence; and
`VGFontFace`'s variable count is the carried Extract Class.

Carried: the Bloc example that answers a plain `BlElement` cannot show Bloc's own
`inspectionPreview:` tab — `MessageNotUnderstood: VGFontFace >> #tfPointerAddress`. Bloc's own view
on Bloc's own class, so the gate leaves it out; the send is Bloc text drawing through a face of
ours, which is what units 4.1 to 4.5 build.

### 3.1 — the manager without a library

`VGFontManager`, a subclass of `AeFontManager`, redefines `reset`: no `freetypeLibrary`, and a
permanent `Dictionary` from entry to face in place of the LRU.
Decided in the interview of 2026-11-12.

1. **The registry's three doors refuse by name.** `registerFacesOnFile:`,
   `registerFacesOnMemory:` and `scanDefaultDirectories` are overridden to raise through one
   `refuseUntilTheCatalogueRegisters`, rather than left inherited to fail on
   `UndefinedObject >> fastReadFacesOn:do:`. `scanEmbeddedFonts` reaches the registry through
   `registerFacesOnMemory:`, so it refuses with it and needs no override. It is this one method
   that 3.2 deletes.
2. **The cache is a slot here, a reader at 3.4.** `reset` installs the permanent `Dictionary`, and
   `faceAt:` stays inherited, so it reads that dictionary and would signal `KeyNotFound` rather
   than build a face. Unreachable while every door refuses: the registry is always empty, so no
   caller can hold an entry to ask for. 3.4 gives it the reader.
3. **The manager gets its own test and example classes.** `VGFontManagerTest` in
   `VectorGraphics-Bloc-Tests` and `VGFontManagerExamples` in `VectorGraphics-Bloc-Examples`,
   added to `VGBlocExamplesTest >> exampleHolders`, rather than folded into `VGCanvasTest` or an
   existing holder: the manager is a class of its own and the rest of 3.x will add to both.
4. **The view shows the manager's own clean state.** `inspectorState:`, eight rows that each ask
   the real object — the library slot printed, the cache's class and size, the registry counted —
   so a row cannot drift from what `reset` writes. Not `inspectorSubstitution:`, which this unit
   has nothing to put in.

`reset` duplicates four of upstream's six assignments and changes two. `super reset` followed by
two overwrites would remove the duplication and build an `AeFTLibrary newInitialized` to throw
away at once; that `newInitialized` sends `autoRelease`, so an `FT_Done_FreeType` in the
finalisation process, which is the hazard behind the font-handle crash. The image already holds
377 of those instances, one per `AeFontManager new`. The duplication stays, and the comment in
`reset` says why.

The design review that followed changed the refusal's own message, which cited unit 3.2 of this
plan to a reader who has never seen it, and left the plan named once, in the comment of the method
the plan deletes. Critics asked for two things the package's own conventions had: a class tag,
`VectorGraphics-Bloc-Fonts`, and `scanDefaultDirectories` in the `scanning` protocol upstream
classifies it under.

No architecture edge yet: 3.1 names no class of `VectorGraphics-TrueType`, so 2.2's row is still
2.2's, and it is 3.2 that makes it real.

Not built here: no registration, no `rejectedFiles`, no default families, and no
`SessionManager` registration — `checkSession` already resets a manager a new session finds, and
the class-side `globalInstance` a subclass gets is its own.

Red: a fresh `VGFontManager` holds nil in the FreeType slot and answers an empty face cache.
It failed with `TestFailure: 'Assertion failed'`, the inherited `reset` having built an
`AeFTLibrary`. The second red, that every door refuses by name, failed with
`TestFailure: 'Denial failed'` on a `MessageNotUnderstood`.

### 3.2 — registration from metadata

`registerFacesOnFile:` and `registerFacesOnMemory:` add to the catalogue of 1.4, and the catalogue
keys each entry by its lower-case family name and then by `{slant. weightClass. widthClass}`, which
is what the font states in its `OS/2` table. The manager parses nothing itself.
Decided in the interview of 2026-11-12, and 2.2's edge was declared here.

1. **One index, the catalogue's.** `entriesByFamilyName` stays the empty dictionary `reset` writes,
   and the four inherited readers of that slot — `entriesByFamilyName`, `faceEntries`,
   `familyNames`, `includesFamilyName:` — are overridden to read the catalogue. All four read the
   instance variable directly upstream, so overriding the accessor alone would have changed
   nothing. The slot cannot be removed: it is upstream's.
2. **The four doors delegate, and the refusal goes.** `registerFacesOnFile:`,
   `registerFacesOnMemory:`, `scanDirectory:` and `scanDefaultDirectories` each answer what the
   catalogue answers, and `refuseUntilTheCatalogueRegisters` is deleted with the test that pinned
   it. The two register methods answer the entry where upstream answered `self`: nothing read that
   value, and an entry is what a caller wants back.
3. **The vocabularies meet in one method.** `entryForFamilyName:slant:weight:stretch:ifNone:`
   translates the three Alexandrie font category objects into a style key, and
   `detectFamilyName:slant:weight:stretch:ifNone:` is overridden to go through it. The three
   translations are exact, and only in this direction: `AeFontSlant name` is the symbol the
   metadata reader states, `AeFontWeight value` *is* the `OS/2` weight class, and
   `AeFontStretch value + 1` is the width class, since a stretch counts `ultraCondensed` from zero
   where `OS/2` counts it from one.
4. **The Faces view is overridden, and that is the unit's view.** Upstream's `inspectionFaces:`
   sends `slantName`, `weightName` and `stretchName` to each entry and sorts with
   `faceEntriesSortedByFamilySlantWeightStretch`, so it would have failed at the inspector the
   moment the registry held one of our entries — a latent break this unit had to fix anyway. Ours
   shows the style name and the three `OS/2` numbers the key is built from, so a row says why a
   face answers the triple it answers.
5. **The example writes its six keys out.** `managerWithTheEmbeddedFontsRegistered` registers the
   six faces `AeEmbeddedFontFile allSubclasses` carries and is self-contained, rather than reading
   `AeFontManager globalInstance`, which holds whatever the host has installed — 5 families and 14
   entries in this image.
6. **No `AeFTLibrary` in the suite.** Parity with upstream's style-name parser was checked by hand,
   outside the suite, through `AeMemoryFaceEntry`: for all six embedded faces its guessed triple
   and our `OS/2` triple name the same face. A test of that parity would allocate a 378th
   auto-released library, which is the font-handle hazard.
7. **2.2 absorbed.** The architecture gate demanded exactly one new row,
   `VGFontManager >> reset -> VectorGraphics-TrueType`, so only the Bloc row of
   `allowedDependencies` and the Bloc line of `declareBackendPackagesOn:` changed. No facade in the
   Cairo layer, and no speculative edge for the units still to come.

The design review that followed moved two rules the manager was reciting back into the catalogue
that owns them: `TTFontCatalogue >> includesFamilyNamed:` folds the case, and
`entryOfFamilyNamed:styleKey:ifNone:` holds the shape of the key, so the manager keeps only the
vocabulary translation and knows nothing of the index. `TTFontCatalogueEntry` answers `styleName` as
it already answered `familyName`, and the Faces view sorts by `#familyName ascending ,
#styleName ascending` instead of concatenating the two names per comparison. Three points were
diagnosed and left alone: `faceEntries` answering an `Array` where upstream answered a `Set`, the
two register methods' changed return value, and the nineteen-line comment of `reset`, which earns
its length by naming three deliberate departures from upstream.

`ReExcessiveArgumentsRule` fires at five arguments on both lookups and is accepted:
`detectFamilyName:slant:weight:stretch:ifNone:` is upstream's own selector, which carries the same
critique on `AeFontManager`, and the other mirrors it deliberately.

Not built here: `faceAt:` is still inherited, so it reads the permanent cache and signals
`KeyNotFound` for an entry no one has built a face for — 3.4 gives it the reader. No `rejectedFiles`
on the manager, no default families, no `FontFamily` change.

Red: registering the six embedded fonts gives two families and six entries, each found by its
Alexandrie triple. It failed with `MessageNotUnderstood: TTFontCatalogue >> #addBytes:` reaching the
refusal first, then on the family count once the doors delegated. The second red,
`testTheFaceLookupReachesTheCacheRatherThanTheEmptyInheritedIndex`, was written because the
degenerate-state test passed for the wrong reason: the inherited `detectFamilyName:` answered the
absent block by reading the empty slot, so a test that the lookup reaches the cache was needed to
fail, and it did, with `'the entry is there to be found'`.

### 3.3 — refused files are kept, not dropped

`rejectedFiles` answers the catalogue's refused entries, each carrying the reason the reader of 1.3
gave. The list lives once, in the catalogue, which derives it from the entries it kept, and the
manager reads it.
Decided in the interview of 2026-11-12.

1. **The entries themselves, not a second shape.** `rejectedFiles` answers
   `catalogue refusedEntries`, where an entry already carries both its source and its reason, rather
   than associations of a path to a reason: a font registered from bytes has no path, and a reader
   who wants the family name the refused file did state would have to come back to the entry
   anyway. A reader holds a manager, not a catalogue, which is why the delegation is worth a method
   — the four readers of 3.2 set that precedent.
2. **The State view is extended, not doubled.** Two rows, `Files met` and `Files refused`, so the
   three file counts reconcile: every file met is either an entry registered or a file refused —
   544 = 362 + 182 on this machine. No Refusals tab on the manager: `TTFontCatalogue >>
   inspectorRefusals:` already groups the refusals by reason, one dive away, and a second grouped
   table would be duplication between two classes.
3. **The example scans the machine.** `managerThatScannedTheInstalledFonts` sends
   `scanDefaultDirectories`, so the State tab shows 208 families, 544 files met, 362 entries and 182
   refusals — the cost decision 14 takes knowingly, in the numbers of the reader's own machine. It
   runs inside `VGBlocExamplesTest` with the other examples, and the scan was measured at 129 ms for
   those 544 files, which the gate can afford. A deterministic toy directory would only repeat the
   test.
4. **No fixture edge for the OTF case.** The plan's red named a TTF and an OTF, but
   `TTFontFixtures otfFontBytes` lives in `VectorGraphics-TrueType-Tests`, which
   `VectorGraphics-Bloc-Tests` may not name: the table allows one test-to-test edge and it is
   Vulkan's. The scan test uses an embedded font and a text file, `#notAnSfntFont`, and names no
   class of the font packages. `#noGlyfTable` stays covered in `TTFontCatalogueTest`, where the
   fixture lives.

A bug of 3.1 was fixed here, failing test first. The `Families registered` row of
`inspectorState:` read the instance variable `entriesByFamilyName`, which 3.2 leaves empty for
ever, so it answered 0 over six registered faces while `Entries registered`, which went through
`self faceEntries`, answered 6. The row now goes through the reader. It failed with
`Got 0 instead of 2.`

The design review that followed changed nothing, and declined three points, each because the change
would add a method or a layer without simplifying anything today: `inspectorState:` is ten literal
associations over two levels of abstraction, and extracting `sessionRows` and `catalogueRows` to
concatenate them reads worse than the list; `rejectedFiles` and `faceEntries` are the same sentence
twice, which is a second occurrence and so a coincidence, not a rule; and `rejectedFiles` names
files while answering entries, which the plan fixed as the manager's word and the comment explains.

A latent break was checked and is not one: `inspectionFaces:` sorts by `familyName` and `styleName`,
which would fail on a nil name, but `addSource:metadata:` indexes by `familyName asLowercase` and a
font with no `name` table is refused `#noNameTable`, so a drawable entry always has both names.

Not built here: `faceAt:` is still inherited, so no face is built — 3.4. No default families, no
`SessionManager` registration, no architecture edge.

Red: a manager that scanned a directory holding one font and one text file answers one refused file,
reason `#notAnSfntFont`, named `readme.txt`, and a fresh manager refuses none. It failed with
`MessageNotUnderstood: VGFontManager >> #rejectedFiles`.

### 3.4 — the face is ours and parsed once

`faceAt:` answers a `VGFontFace` read from the entry's own bytes and kept in the permanent cache of
1.4. Upstream's answers whatever its `LRUCache` holds, and that cache was given a factory sending
`anEntry newFaceWith: freetypeLibrary`; ours builds the face itself, so the only thing that ever
reads a font is our own reader.
Decided in the interview of 2026-11-12.

1. **The face is built in `faceAt:`, with `ifAbsentPut:`.** One method, and the cache stays a plain
   `Dictionary` a test can read. A `factory:` installed by `reset`, which is upstream's shape, would
   mean going back to `LRUCache` or writing a subclass of `Dictionary` that has one — 1.4 decided
   the permanent cache. A separate `faceForEntry:` would be a second method with a single sender.
   The entry cannot build its own face: `VGFontFace` lives in `VectorGraphics-Cairo` and
   `VectorGraphics-TrueType -> VectorGraphics-Cairo` is not an edge the table allows. That is the
   table deciding, not the interview.
2. **The bytes are read at this point and not before.** A scan reads a few hundred bytes per file to
   say what the file is; the fonts of this machine are 262 MB in all. So `TTFontCatalogueEntry >>
   bytes` is sent when something draws with the face, and the face is kept for the session.
3. **A refused entry is named, not parsed.** `VGFontFace newForBytes:` on bytes that are not a font
   raises `SubscriptOutOfBounds: '13 in #[110 111 116 ...]'`, and since 3.3 a reader holds
   `rejectedFiles` and can hand one of them back. `faceAt:` checks `isRejected` first and signals an
   error naming the source and the reason the reader of 1.3 gave.
4. **Two views, since both facts are worth showing.** The Faces tab gains a `Face built` column read
   from the cache, so the laziness shows where the entries are listed; the Cache tab lists the faces
   built with the glyph count, the em square and the outlines read so far, each row asking the face
   itself. `inspectorCacheContext:` hides the tab until something has drawn.
5. **The example draws with every embedded font.** `managerWithAFaceBuiltForEveryEmbeddedFont`
   starts from `managerWithTheEmbeddedFontsRegistered` and asks for all six faces, so the two
   examples stand side by side: the same manager before anything drew with it, and after. The Cache
   tab shows 1568 and 1972 glyphs, 1000 units per em and no outline read yet.

A test of 3.2 was rewritten here, not refactored away:
`testTheFaceLookupReachesTheCacheRatherThanTheEmptyInheritedIndex` pinned `raise: KeyNotFound`,
which is exactly what this unit removes, so it now asserts that the lookup answers the face the
cache holds. It failed with `Assertion failed` the moment `faceAt:` built anything.

Not built here: the FreeType detour of `VectorGraphics-Bloc` is untouched —
`VGCanvas class >> faceForFreeTypeFace:` still goes through `VGFontFace class >> newForFace:` and
the hand-rolled search of `bytesForFamilyName:styleName:`. It stays unreachable while
`BAFontConverter >> faceFor:` asks `AeFontManager globalInstance`, which is until 3.5 installs ours,
and 5.2 kills the bridge entirely. No default families, no session registration.

Red: two `faceAt:` for one entry answer the identical object and `AeFTFace allInstances size` is
unchanged across both. It failed with
`key a TTFontCatalogueEntry a TTFontMetadata 'Source Sans Pro' 'Regular' from 248132 bytes not found in Dictionary`.
The second red was written twice: the refusal test passed at first for the wrong reason, the cache's
own `KeyNotFound` carrying the file name and the reason in its text already, so it was hardened with
`deny: (error isKindOf: KeyNotFound)` and failed with `Denial failed` before the guard was written.
The view test was written after the two views rather than before, and passed first time: no red.

Design review of 3.4, executed on 2026-11-12. Two points, both applied, commit `077bc6a6`.

1. **Replace Direct Variable Access.** The views and `faceAt:` read `faceByEntryCache`, and the six
   readers of the catalogue read `catalogue`, straight out of the slots. Upstream guards its four
   slots in accessors that send `checkSession` first, so reading a slot walks around the check: a
   manager left over from a dead session answered entries naming bytes nobody in this session had
   read. The `catalogue` accessor now sends `self checkSession` itself, which covers every reader
   and every writer built on it in one place, and `faceAt:` and the three cache views ask
   `self faceByEntryCache`. `inspectorState:` reads nothing out of a slot any more except the
   session it is reporting.
   Red: a manager whose `session` slot is written to a foreign object answers an empty
   `faceEntries`, no family names, no refused files, and a State view saying nought files met and
   nought faces kept. It failed with `Assertion failed`. The cache is asked last in that test on
   purpose — asking it first resets the manager, and every other reader then answers empty whether
   it checks or not, which is how the first draft of the test passed while the bug was still there.
2. **Extract Method.** `refuseFaceFor: anEntry` holds the error the guard signals, so `faceAt:`
   answers a face and the new method states the refusal.
   The review of 3.7 moved it onto the entry, as `signalRefusal:`: the sentence is about the file
   the entry names and uses nothing of the manager.

### 3.5 — installation that survives a session start

`AeFontManager class >> globalInstance:` is a new extension method, a plain setter, so nothing
upstream is rewritten.
`AeFontManager class >> startUp:` nils the slot on every image start, at GUI priority 110, so
`VGFontManager class >> startUp:` registers at a priority above it and re-installs.
Decided in the interview of 2026-11-12, built and committed as `eeacf056`.

1. **The installation is commanded, not automatic.** `installGlobally` and `uninstallGlobally`,
   and `startUp:` only puts back what was posed. Installing unconditionally here would route the
   whole image through our manager before 4.x exists: `BlFont >> asAeFTFace` would answer a
   `VGFontFace`, and `BATextParagraphSpan >> measure`, `BAMockedTextParagraphSpan >> aeDrawOn:`
   and the two Album and Toplo background decorations would break, along with the 22 other senders
   of `globalInstance`. 5.1 turns the installation on; 5.2 deletes the whole mechanism.
2. **The manager posed is `self new`, empty.** It knows no family until something scans or
   registers; the default families are 3.6, and putting them here would move that decision into the
   unit about the mechanism.
3. **One class slot, `installedInstance`, holding the manager posed.** Not a boolean beside a
   manager, which is two pieces of state that can fall out of step, and not a boolean plus a read
   of Alexandrie's slot: `globalInstance` builds a complete FreeType manager when the slot is nil,
   so asking it costs a scan just to answer "nothing". A nil slot of ours means hands off, which is
   what lets `startUp:` run in every image this package loads into.
4. **GUI priority 115.** A category starts its handlers by rising priority (`SessionCategory >>
   prioritizedList` sorts the keys), and the category holds 10 FreeType, 100 the Form and font
   classes, 110 `AeFontManager`'s reset, 120 `AeCanvas initializeFontOptions`, 150 `BAOffscreen`,
   200 `BlHostRegistry`. 115 is after the reset and before the font options. Registering at 110
   would work only while our package happens to load after Alexandrie's, since a priority list
   keeps the order it was registered in.
5. **The tests live in `VGFontManagerInstallationTest`.** Their `setUp` and `tearDown` remember and
   restore both slots, which the 11 tests of `VGFontManagerTest` have no reason to pay for, and
   5.2 deletes the class whole. Upstream's slot is read by reflection there, for the same reason as
   decision 3.
6. **The view is class-side, the example asks the real route.** `VGFontManager class >>
   inspectorInstallation:` shows what was posed and what it knows, reading our slot only.
   `managerBlocAsksToday` answers `AeFontManager globalInstance`, so one click says which reader of
   fonts the image draws with — and accepts that asking builds Alexandrie's manager if nobody has
   asked yet, which is what Bloc would do on its first text.

Not built here: no default families, no scan, so the manager posed draws nothing. The Alexandrie
text route is untouched, because nothing is posed outside a test.

Red: `installGlobally`, then `startUp: true` to both classes in that order, leaves our manager in
`globalInstance`. It failed with
`Could not build slot named 'installedInstance' because the assignated slot was not found in the image`.
The second red states the other half: an image that installed nothing keeps the manager Alexandrie
built, and it failed with `an AeFontManager is not identical to an AeFontManager` once the guard on
a nil slot was taken back out — that guard had been written in the green of the first test, before
a test asked for it. The third red is the view: `Message not understood: VGFontManager class >>
#inspectorInstallation:`.

Two slips, both caught: the `tearDown` of the first run died on
`Message not understood: InstanceVariableSlot >> #write:with:` (the selector is `write:to:`), so it
restored nothing and left our manager posed in the image for one run — the slot was put back by
hand and the lazy getter rebuilt Alexandrie's manager. And the five class-side methods plus the
extension were first compiled with LF line endings through `compile:classified:`, which
`compile_method` would have normalised; the package scan found all six and they were recompiled with
`String cr`.

The class comment was corrected in the same unit: its last paragraph still said `faceAt:` was the
inherited one, pending 3.4.

Design review of 3.5, executed on 2026-11-13, commit `a81aea0c`. Two points.

1. **Remove a duplicate observation.** `inspectorInstallation:` showed the families, the entries and
   the faces built of the posed manager, each behind its own nil test, which is what that manager's
   own State view already says. Two copies of a count can disagree; one cannot. The view now names
   the manager posed and nothing else, and the four nil tests go with the three rows. This was the
   one point that forced a test to change: the view test of this unit asserted the `Families` row,
   which pinned the content of the view rather than the fact of the unit, so that assertion was
   dropped and the rest of the test kept.
2. **Replace Direct Variable Access.** The view reads `self installedInstance`, the rule the review
   of 3.4 set for every reader.

Considered and rejected: `AeFontManager globalInstance:` is sent from `installGlobally`,
`uninstallGlobally` and `startUp:`, three occurrences, but a wrapper around a single message send
simplifies nothing today.

### 3.6 — the default families

The six `AeEmbeddedFontFile` subclasses are registered from their bytes, as upstream does, so a
default text has a family with no FreeType in the image.
Decided in the interview of 2026-11-13, built and committed as `cfaef72c`.

1. **A class-side constructor, `newWithDefaultFaces`, and `installGlobally` builds through it.**
   A test, an example or a consumer can then hold a manager ready to draw without posing it as the
   one the whole image asks. The same work inside `installGlobally` would make every test of this
   unit install and restore; inside the instance-side `initialize` it would peel the empty
   catalogue away from the twelve tests of `VGFontManagerTest` that count on it, and an empty
   manager is a legitimate state — it is what `scanDirectory:` fills.
2. **The six embedded faces, and nothing else.** The same set as upstream, so a default text draws
   the families Alexandrie drew, and the result is the same on every machine: six entries, two
   families, no dependency on the file system. The machine's own fonts stay one
   `scanDefaultDirectories` away — 129 ms and 544 files on this one, which is not a thing to do at
   every image start, and a count no test could state.
3. **The families are named by the embedded font classes.** `AeSourceSansPro_Regular familyName` and
   `AeSourceCodePro_Regular familyName`, asked through
   `detectFamilyName:slant:weight:stretch:ifNone:`, so the path exercised is the one Bloc takes,
   Alexandrie's vocabulary included, and renaming an embedded font leaves no stale string behind.
   An absent family raises an error naming it, where upstream writes `'Shouldn''t happen'`: a
   default face left nil comes back as nil from `BAFontConverter >> faceFor:` and the breakage
   appears in the drawing instead.
4. **Two tests, one per class.** The constructor is stated in `VGFontManagerTest`, which touches no
   global state; what `installGlobally` poses is stated in `VGFontManagerInstallationTest`, and
   asked through upstream's own `AeFontManager defaultFontFamilyName` and
   `defaultCodeFontFamilyName`, which is how the rest of the image asks.
5. **An example, no new view.** `managerReadyToDrawDefaultText` answers
   `VGFontManager newWithDefaultFaces`; the `Default face` and `Default code face` rows of
   `inspectorState:` are the view of this unit, and they showed nothing but nil until today. An
   extra tab for two faces would be the duplication the review of 3.5 just removed.

Not built here: no scan of the machine's fonts. `VGFontFace class >> defaultBytes` and its route
through `FreeTypeFontProvider current families` are untouched; they die at 5.2.

Red: a manager from `newWithDefaultFaces` holds the two embedded families, six entries, a
`VGFontFace` for each default, and leaves `AeFTFace allInstances size` unchanged. It failed with
`Message not understood: VGFontManager class >> #newWithDefaultFaces`. The second red states the
installed half and failed with `receiver of "familyName" is nil`, since `installGlobally` still
posed a bare manager. Measured while deciding: the scan plus the first default face is 15 ms and
the second 12 ms, so nothing here is worth making lazy.

### 3.7 — HarfBuzz keeps working

The premise written here was wrong.
Our manager holds `TTFontCatalogueEntry`, not the upstream `AeFileFaceEntry` and
`AeMemoryFaceEntry`, so `newHbFont` answers for no entry of ours; and `AeFaceEntry >> newHbFont`
has no production sender in the image at all.
So this unit is production code, not a test.
HarfBuzz is also absent from Bloc's text path today: `AeHbBuffer` appears only in Alexandrie's
experiments and tests, and in the two of those we ported, so what this unit pins is the shaping
service, not window drawing.
Decided in the interview of 2026-11-13, built and committed as `1a62baa7`.

1. **`TTFontCatalogueEntry >> newHbFontScaledTo:`, an extension of ours filed in
   `VectorGraphics-Bloc`.** The entry already knows which font it names and whether the reader
   refused it, so shaping is asked of it rather than of a second object built to carry the same
   two facts. The method is filed in the Bloc package, in protocol `*VectorGraphics-Bloc`, because
   `VectorGraphics-TrueType` references no `Ae*` class and must keep it that way.
2. **Nothing new on `AeHbBuffer`.** A consumer builds the buffer as Alexandrie's own experiments
   build it, then sends `shapeWithFont:` and `cairoGlyphArray`. A wrapper of ours would restate
   upstream's own protocol and hide the direction, script and language the caller has to choose
   anyway.
3. **The blob comes from the source itself, polymorphically: `newHbBlob` on `FileReference` and on
   `ByteArray`.** The two kinds of source need two different calls for a reason the catalogue
   entry should not have to know, so the entry sends one message and neither class is type-tested.
   The companions of `fontBytes` and `fontSourceName`, which already split this way.
   - A file goes to `hb_blob_create_from_file`, which opens the file itself: no byte enters
     Pharo's object memory, and nothing has to be pinned or kept alive.
   - Bytes go to `AeHbBlob newFrom:`, which calls `hb_blob_create` in `HB_MEMORY_MODE_READONLY`
     with no destroy callback. HarfBuzz keeps the raw address of the first byte and reads through
     it long after the call returns, so the `ByteArray` pins itself first; an unpinned one can be
     moved by the garbage collector and the blob would then read whatever took its place.
   - A `FileLocator` reaches the `FileReference` extension through its own `doesNotUnderstand:`,
     which forwards any selector the resolved reference responds to.
4. **A refused file is refused here too, with an error naming the file and the reason.** HarfBuzz
   would read it: it parses the font file itself and accepts a collection, which this project's
   reader rejects. The glyph identifiers would then name glyphs of a face no font face of this
   project can draw. The refusal is said by `signalRefusal:`, which `VGFontManager >> faceAt:`
   sends for the same reason about a face.
5. **The scale is `aSize * 64` on both axes, posed by us.** A font built from a blob is unscaled —
   its scale is the units per em of its face — while `AeHbBuffer >> cairoGlyphArray` reads every
   advance and offset as 26.6 fixed point. `hb_ft_font_create_referenced` took this scale from the
   size set on the FreeType face, and nothing poses it on the blob route.
   The face index is 0 because a drawable entry holds exactly one font: a file holding several is a
   collection, which `TTFontMetadataReader class >> offsetTableRejection:inFileOfSize:` refuses
   with `#fontCollection` before the entry is ever drawable.
6. **A new test class, `VGHarfbuzzShapingTest`, with one test per kind of source.** The subject is
   shaping, not the catalogue and not the manager, and the class comment is where the two upstream
   routes and the absence of HarfBuzz from Bloc's text path are written down. It calls
   `libharfbuzz` through uFFI, so its comment also says to commit before running it.
7. **A new class, `VGHarfbuzzShapingExamples`, with one example,
   `glyphArrayShapedWithoutFreeType`.** It answers the `AeCairoGlyphArray` itself, one element a
   glyph, so a reader inspecting it sees the identifiers and the places HarfBuzz chose. Five glyphs
   for `'Pharo'` at 22 pixels: identifiers 17, 35, 28, 45 and 42 at x 0.0, 12.453125, 24.421875,
   35.515625 and 42.9375.
8. **A view, `TTFontCatalogueEntry >> inspectorShaping: aBuilder`, gated on `isRejected not`.**
   It shapes the sample word here and now rather than describing it: the scale is read back off the
   font HarfBuzz answered and the glyphs are the ones it placed, so neither can drift from
   `newHbFontScaledTo:`. The gate is the rule of decision 4 asked of the entry, and the refusal
   itself is already named by the `Source` view.

Not built here: no shaping in the Bloc drawing path. `AeHbBuffer >> cairoGlyphArrayForFace:size:`,
the FreeType route, is untouched, and so are the two ported experiments in
`VectorGraphics-Conformance` that still take it; they die at 5.2.

Red 1: a font this project carries in memory shapes `'Pharo'` into five glyph identifiers, the
font's scale is `22 * 64 @ (22 * 64)`, and `AeFTFace allInstances size` is unchanged across the
shaping. It failed with `Message not understood: TTFontCatalogueEntry >> #newHbFontScaledTo:`.
Red 2: the same through a font on disk, added as the `FileLocator`
`AeFilesystemResources inriaSerifRegularTTF`. It failed with
`Message not understood: FileReference >> #newHbBlob`.
Red 3: a file the reader refused is not shaped at all, and the error names both the source and the
reason.
Red 4: the `Shaping` view answers seven rows for a drawable entry, and the tab is offered on a
drawable entry only.

Two slips worth keeping. The first green answered
`AeHbBlob newFrom: self pinInMemory` and failed with `Instances of True are not indexable`:
`pinInMemory` answers whether the object was already pinned, not the object. The second was a bug
claimed and not real — that `fontBytes` on a `FileReference` would leave an entry holding a
`FileLocator` answering a DNU; the test written for it passed on the first run, and reading
`FileLocator >> doesNotUnderstand:` showed why. The test was deleted rather than kept as a
tautology.

The examples gate also caught two defects left by 3.5, which no run had covered until this unit
added a holder to `VGBlocExamplesTest >> exampleHolders`.
`VGFontManager class >> inspectorInstallation:` was ungated although it reads `installedInstance`,
a class-instance variable every subclass would hold its own always-nil copy of; it now has
`inspectorInstallationContext:`, active where `installGlobally` is defined.
And the example `managerBlocAsksToday` answered `AeFontManager globalInstance`, the same singleton
twice, so it rebuilt nothing; it was deleted, with the sentence a reader needs moved into the
comment of `inspectorInstallation:`.

The new edge is declared twice, as this project's rule asks: `VectorGraphics-Bloc-Examples` and
`VectorGraphics-Bloc-Tests` name `VectorGraphics-TrueType` in
`BaselineOfVectorGraphics >> declareBackendPackagesOn:` and in
`VGArchitectureTest class >> allowedDependencies`.

Design review of this unit, executed the same day. Three refactorings, each committed on green:
`673029b5`, `279602ec` and `61b35759`, plus `c52c82cf`.

1. **Hide Delegate.** Four sites reached through the entry into `source` or `metadata` to name a
   font or say why it was refused. `TTFontCatalogueEntry >> fontSourceName` and `>> rejectionReason`
   answer for the parts, as `isRejected` already did; `source` and `metadata` stay, so no test had
   to change.
2. **Move Method.** `VGFontManager >> refuseFaceFor:` used nothing of the manager and said a
   sentence about the entry's file, which `newHbFontScaledTo:` then said again with a different
   last clause. `TTFontCatalogueEntry >> signalRefusal:` writes the first two clauses once and each
   caller says only what cannot be done; `refuseFaceFor:` is gone.
3. **Extract Method.** `inspectorShaping:` shaped the word, formatted the rows and built the table.
   `shapingRowsAtSize:` answers the rows, and the view builds a table and nothing else; the figures
   can now be asked without a presenter.

Also, `inspectorInstallationContext:` compared the class to `VGFontManager` by name, which Renraku
reads as a class referring to itself and which restates the rule its own comment states. It sends
`includesSelector: #installGlobally` instead.

Left undone on purpose: the `AeHbBuffer` cascade is still written out four times, in the view, the
example and two tests. A method answering a glyph array for a string at a size would freeze the
direction, the script and the language, which is exactly what units 4.1 and 4.2 have to decide for
real text; two of the four occurrences are specimens, and the shape of the real caller is not known
yet. A `TTFontRefusal` exception class was rejected too: nothing catches this `Error` today.

### 4.1 and 4.2 — the substituted context and glyphs drawn as A8 masks

Decided in the interview of 2026-11-13 and built as one unit, because a context that substitutes
nothing draws no text and could only be pinned by a test asserting its own class.

`VGAeTextContext`, a subclass of `AeCairoContext`, plus one extension method redefining
`AeCairoSurface >> newContext` to answer it, with a one-line comment saying why. Every text
selector delegates to `super` when the scaled font it is given is a real `AeCairoScaledFont`, so an
image without our manager behaves exactly as before. `scaledFont:` keeps our scaled font, and
`showGlyphs:size:` blits one mask per glyph with `maskSurface:x:y:`, so the colour comes from the
Cairo source as it does for any other mask.

1. **Cairo rasterises our outlines, and the masks of this route live in their own atlas.** The
   glyph contours come from our reader and the coverage from `cairo_fill` into an
   `AeCairoImageSurface` of format `a8`: this unit owes Bloc the same pixels Alexandrie draws, and
   our own rasteriser is unit 7's subject, not this one's. The surface is externally allocated, as
   every Cairo image surface is, because the garbage collector may move a `ByteArray` while Cairo
   holds the address of its first byte.
2. **A second slot, `cairoMaskAtlas`, beside the existing `atlas`.** The two routes rasterise with
   different code and must be comparable at unit 7; one atlas holding both would key on the route
   as well as on the glyph, phase and matrix, and the keys of the existing atlas would change for
   a reason that has nothing to do with it.
3. **All five text selectors are overridden now, dispatch only.** `scaledFont:`,
   `showGlyphs:size:`, `getGlyphExtentsOf:size:into:`, `appendGlyphsPath:length:` and
   `getFontExtentsInto:` are the sites `AeCanvas` reaches text through, so the context is whole
   from the start and units 4.3 to 4.5 each fill in one answer instead of also having to find its
   site. A test names the three not yet answered, with the receiver and the selector a reader will
   see, so the unit that answers one deletes a line from a list rather than discovering a DNU.
4. **No type test: the font decides, by double dispatch.** Each site sends a message of ours to the
   scaled font it was given — `poseOnAeContext:`, `showGlyphs:size:onAeContext:`,
   `glyphExtentsOf:size:into:onAeContext:`, `appendPathOfGlyphs:length:onAeContext:`,
   `fontExtentsInto:onAeContext:` — and `AeCairoScaledFont` answers each one by sending the context
   back the matching `…ThroughCairo…` escape, which is the superclass's own method under a name an
   override cannot hide. `VGScaledFont` answers with our own drawing. Neither class asks what the
   other is.
5. **The whole font-side half is filed in `VectorGraphics-Bloc`, protocol `*VectorGraphics-Bloc`.**
   `VGScaledFont` lives in `VectorGraphics-Cairo`, a package of the default group, which
   `VGArchitectureTest >> testNoPackageOfTheDefaultGroupNamesAClassOfTheStackItReplaces` forbids
   from naming any Bloc or Alexandrie class. The slot is on the class; every method that mentions
   an `Ae*` class is an extension.
6. **The proof reads the pixels of the drawn surface.** A test asserting that a mask was blitted
   where the pen stood would restate the code; reading the alpha of the drawn surface says that
   Cairo put ink on the page and that it landed inside the extents our own metrics answer. An
   untouched pixel of an ARGB32 surface reads back as `16777215`, transparent white, so ink is the
   alpha byte and never the whole word.
7. **A view of the A8 masks on `VGScaledFont`, `inspectorCairoMasks:`, order 12.** One row per
   glyph of this route's atlas, with the mask as Cairo rasterised it — read back as a `Form`, the
   coverage reads as grey. It reads the variable, not the `cairoMaskAtlas` accessor, because the
   accessor builds the atlas on first use and a view must leave the object it shows alone.

`VGAeTextContext class >> unownedNewFor:` had to be redefined with our own class as the uFFI return
type: `AeCairoContext class >> unownedNewFor:` names `AeCairoContext` in its `ffiCall:`, so without
the override `surface newContext` answered a stock context although the extension was installed.

`cairo_mask_surface` places the mask in user space, so `showGlyphs:size:onAeContext:` sets the
identity matrix inside `saveState`/`restoreState` and passes device coordinates. The pen position
is transformed by the matrix read off the context, the whole-pixel part chooses the blit and the
fractional part is the atlas key's phase, as the existing route already rounds.

Red 1: every surface answers the context that knows our fonts. Red 2: a figure with no text is
pixel for pixel what the stock context draws. Red 3: a glyph run drawn through real Cairo inks
inside its run extents — the ink box is non-nil and lies inside the extents our metrics answer,
expanded by one pixel. Red 4: the three text sites the later units deliver fail naming our own font
and selector. Red 5: a real Cairo font still draws through Cairo itself, and the context keeps no
font of ours.

Two slips worth keeping. The ink test first counted every non-zero word and so found the whole
surface inked, which is the transparent-white reading above. And the delegation test first borrowed
a live FreeType scaled font from `VGCairoTextTest`, which broke
`VGArchitectureTest >> testBlocTestsStayInsideTheirAllowedDependencies`; it uses Cairo's own toy
font instead, which also keeps the suite clear of the FreeType handle-lifetime crash.

The examples are `VGAeTextContextExamples` in `VectorGraphics-Bloc-Examples`:
`textRunDrawnThroughRealCairo` answers the drawn surface, and
`scaledFontWithAWarmCairoMaskAtlas` draws the run twice, the second time shifted one pixel, and
answers the font — `VGAeTextFontExamples class >> textFontWithAWarmCairoMaskAtlas` since 4.7, where
it answers the adapter that holds the atlas — nine masks for ten characters, the two spaces sharing one.

Critics on what changed leave five `ReTrivialCritique` of one kind, "Sends different super
message", one per `…ThroughCairo…` escape. That is the design of decision 4: the escape exists to
reach the superclass's own method under a name the override cannot hide, so the send cannot be
renamed away.

Design review of this unit, executed the same day. Five refactorings, each committed on green:
`e6479191`, `20cd5698`, `e91a4a3c`, `442c74be` and `d5a4a6f4`.

1. **Move Method.** `wholePixelBoxOfContours:` stood on `VGScaledFont` and on `VGCairoContext`,
   body and comment alike. The copy on the font stays, filed in `outlines` since it names no class
   of the replaced stack, and the Cairo context asks its current scaled font for the box.
2. **Move Method.** `deviceContoursOfGlyphAt:underMatrix:at:` is now the one rule, on the font that
   owns the outlines; `VGCairoContext >> deviceContoursOfGlyph:at:` delegates, handing over its own
   matrix without the translation. The two routes can no longer drift apart in the coordinates they
   give the rasteriser, which is what unit 7 compares.
3. **Extract Method, and one transform per mask.** The mask of a glyph,
   `cairoMaskForGlyph:atPhase:underMatrix:onAeContext:`, built its contours twice, once to measure
   the box and once shifted into it, so every miss of the atlas transformed the outline twice.
   The contours are placed once and moved to the box, and
   `cairoMaskSurfaceOfContours:extent:onAeContext:` holds the A8 surface and the fill.
4. **Move Method.** `matrixOfAeContext:` used nothing of the font: it is now the extension
   `AeCairoMatrix >> asVGCairoMatrix`, filed in `VectorGraphics-Bloc`, where units 4.3 to 4.5 can
   ask for it too.
5. **Move Method, to the class side.** `snapped:` and `fixedOf:` use nothing of a path being built.
   They move to `VGPathBuilder class`, the instance method delegates, and neither `VGScaledFont` nor
   `VGCairoContext` builds or holds a path builder to round one point. The rounding rule has one
   home.

Left undone on purpose: the two contour walks, `VGScaledFont >> appendContour:toAeContext:` and
`VGCairoContext >> appendDeviceContour:into:`, stay separate. Unifying them needs an
`AeCairoContext >> quadraticVia:to:` that reads the current point back from Cairo, an FFI round trip
a curve, for two occurrences. The third occurrence is the trigger.
`VGCairoContext >> renderedGlyphMaskFor:atPhase:` still builds its contours twice, as point 3 did;
it is the other route's method and no bug has been seen there, so it waits for a reason of its own.

Critics asked for one more cut after the view learned to tolerate a font with no atlas, commit
`11471568`: the block argument shadowed the `atlas` instance variable and four nil tests in one
method read as complex. `cairoMaskAssociations` answers the rows, still through the variable so that
asking does not build the atlas, and one reader a column says what a row shows where a glyph inks
nothing.

The two gates of `VGRendererTest` that were red before this unit are settled, as their own step,
commit `f6bff11c`. `testNoMethodOfThisProjectNamesACairoClass` is gone:
`VGArchitectureTest >> testNoPackageOfTheDefaultGroupNamesAClassOfTheStackItReplaces` already says
it for the packages it still holds for. `testThisProjectDefinesNoMethodOnABlocOrAlexandrieClass`
moved to `VGArchitectureTest` as
`testNoPackageOfTheDefaultGroupDefinesAMethodOnTheStackItReplaces`, narrowed to the default group,
whose members the baseline's own group list answers. It says what the naming gate does not: an
extension method on a foreign class has no class to go on in an image without that class. The Bloc
packages extend Bloc and Alexandrie by design — that is what phases 3 and 4 are — and what they may
name stays stated by `VGArchitectureTest class >> allowedDependencies`.

### 4.3 — extents that Bloc can measure with

Decided in the interview of 2026-11-13 and built the same day: commits `44bbee21`, `25e3bdad`,
`8f009d08` and `d2f5778c`.

`VGScaledFont >> glyphExtentsOf:size:into:onAeContext:`, on `VGAeTextFont` since 4.7, answers the
measuring site from
`glyphExtentsOf:`, which the font already had: the inked box relative to the origin of the first
glyph, and the advance from that origin to where the next run starts, in user space, as
`cairo_glyph_extents` answers them.

1. **The six numbers are copied by the record they come from.** `VGTextExtents >> writeInto:`
   names no class and sends six setters, so anything that answers them serves: Cairo's call writes
   into a record its caller owns, and `AeCanvas` keeps one such record and reuses it for every run
   it measures.
2. **The context argument is kept, and unused.** The numbers are in user space, so the matrix
   takes no part; the keyword stays because all five text sites dispatch the same way and a test
   pins the selector a missing site has to name.
3. **The red sits where the measured site sits.** `VGCanvasTest`, because the site is
   `AeCanvas >> metricsFor:font:` and that class already gates what a font of ours answers when
   Alexandrie's own canvas asks.
4. **The red builds its font from the bundled bytes.** Measuring must not depend on a FreeType
   face, which is what the canvas route still builds its own faces from; the fixture duplicates
   the one in `VGAeTextContextTest`, and a second duplication is still a coincidence.
5. **What it asserts.** The `AeCairoTextMetrics` the canvas answers carries exactly the six
   numbers of our `glyphExtentsOf:`, and its `advanceX` is the sum of the run's advances. The run
   is `'a b'`, so a glyph that inks nothing sits in the middle and the inked box and the advance
   cannot agree by accident.
6. **The view goes on `VGTextExtents`.** `inspectorGeometry:` draws what the six numbers mean —
   the baseline, the origin, the inked box at the bearing, the advance to the next run — because
   six bare numbers are unreadable, and because that is the object this unit hands to Bloc.
   `VGScaledFontExamples class >> textExtentsOfARun` gives the view its click, and
   `VGCanvasExamples class >> metricsOfARunMeasuredThroughTheCanvas` runs the delivered site.

**The paragraph guard was dropped, because it was green before the unit.** The plan's red was a
Bloc paragraph measured end to end, and it passed with the new method removed from the image. The
reason is that `VGCanvas >> newCairoSurfaceExtent:` answers a `VGCairoImageSurface`, whose context
is `VGCairoContext`, not the substituted `VGAeTextContext`: the live Bloc measuring route has been
answering from our own metrics since phase 3, through
`VGCairoContext >> getGlyphExtentsOf:size:into:`. The site unit 4.3 answers is the other meeting —
a surface Alexandrie made, reached through `AeCairoSurface >> newContext`, with a font of ours on
it — and the narrow red covers exactly that. A test that cannot fail guards nothing, so it went.

Two smaller findings. The record holds doubles, so our exact fractions come back rounded to the
nearest double and the test compares with `closeTo:`. And `writeInto:`, filed in
`*VectorGraphics-Bloc` by the interview's decision, moved to `VectorGraphics-Cairo` as soon as
`VGCairoContext` could use it too: it names no Alexandrie class, and the Cairo package may not
depend on the Bloc one.

The view needed a gate, which `VGCairoExamplesTest >> testEveryViewHasAGate` caught:
`inspectorGeometryContext:` shuts the tab on an empty run. Both it and the view ask
`VGTextExtents >> isEmpty`, and the view still answers a sentence rather than a picture for an
empty run, because the gate that builds every view ignores the activation method.

Design review, agreed before anything was edited. Executed: **Extract Method** on `geometryForm`,
which held the fitting and the drawing at once, into `geometryPlacerInto:` and
`drawGeometryOn:placing:`, with `inkedBox` as the domain accessor both need (`8f009d08`); and the
marks the drawing puts down, six bare numbers, expressed from one named tick (`d2f5778c`).
Deferred: the filling sequence — `glyphsOf:size:`, `glyphExtentsOf:`, `writeInto:` — now appears in
both contexts, which is two occurrences, and the shape of the common factor depends on what units
4.4 and 4.5 ask the context for. Rejected: moving `outline:on:color:` onto `Form`, a kernel class,
for a four-line helper with one sender; drawing the view through a `VGCairoContext` instead of a
`Form`, which is more code for no more clarity; and moving the view off `VGTextExtents`, which
would add a class and simplify nothing today.

### 4.4 — text as a path

Decided in the interview of 2026-11-13 and built the same day.

`VGScaledFont >> appendPathOfGlyphs:length:onAeContext:`, on `VGAeTextFont` since 4.7, answers the
path site: every contour of
every glyph of a run, appended to the path the context is building, which is what a text border, a
text shadow and text-as-path drawing are made of. The consumer is
`BlTextBorderAttribute >> aeDrawOn:span:`, which hands the canvas a path factory that sends
`BATextParagraphSpan >> appendPathOn:`, which sends `AeCanvas >> appendGlyphsPath:font:`.

1. **The contours go on in user space.** A glyph of a `cairo_glyph_t` is positioned in user space
   and `cairo_glyph_path` builds its path there, so ours does too: no `saveState`, no identity
   matrix, no snapping to the device grid. The matrix of the context then takes part when the
   caller fills or strokes, as it does for any other path. The alternative — appending device
   contours under an identity matrix, which is what the mask route of 4.2 does — would buy pixel
   equality with that route and bake the matrix into the shape, so a stroke width or a later
   transform would land on a path already scaled.
2. **One poser for both routes.** `appendContour:toAeContext:`, written for the masks in 4.2,
   takes a contour already placed and never looks at the space it is in; only its comment said
   device space, and the comment was rewritten. Duplicating five lines to keep two comments true
   would be abstracting backwards.
3. **Placement is a named method.** `userSpaceContoursOfGlyphAt:at:` translates the cached
   contours to the position of the glyph, beside `deviceContoursOfGlyphAt:underMatrix:at:` which
   has a linear matrix to apply as well. The site stays three lines and the concept has a name in
   both spaces.
4. **Two levels of red, in two places.**
   `VGAeTextContextTest >> testThePathOfARunEnclosesTheBoxItsExtentsReport` asks Cairo itself, with
   `pathExtentsInUserSpace`, and `VGCanvasTest >> testARunPathAppendedThroughTheCanvasInksOurOwnOutlines`
   fills the figure through `AeCanvas` and reads the pixels, which is the selector Bloc actually
   sends. Extents alone would pass for a path whose curves are posed with the control point and the
   end point exchanged; ink alone would say nothing about the path before it is rasterised.
5. **The degenerate run has its own test.**
   `testARunThatInksNothingAppendsNoSubPath` lays out three spaces and asserts both that the path
   extents are empty and that the context has no current point: Cairo drops a move-to that starts
   no sub-path from the extents it reports, so the extents alone would also pass for a path of
   stray move-tos.
6. **The view is the other route of the same object.** `VGScaledFont >> inspectorGlyphPath:`
   strokes the outlines of a short run thinly on white, beside the `Cairo masks` tab that 4.2 put
   there: a fill would hide where the contours run. The view and its gate both ask
   `contoursOfTheInspectorSample`, which calls the placement method, so neither restates the route.
   `VGScaledFontExamples class >> glyphsPathOfARunOnACairoContext` and
   `VGCanvasExamples class >> runPathFilledThroughTheCanvas` give the two sites their click.

**No paragraph guard, for the reason unit 4.3 found.** `VGRenderer >> renderWith:…` builds a
`VGCairoImageSurface` over the window's pixels, whose context is `VGCairoContext`, and
`VGCairoContext >> appendGlyphsPath:length:` has posed our own contours since phase 3. The live
window route is therefore already ours, and a guard on it would have been green before the unit.
The site 4.4 delivers is the other meeting: an Alexandrie-made surface, reached through
`AeCairoSurface >> newContext`, with a font of ours on it — shadows, composition layers, exporters
and the canvas-level test above.

Two findings worth keeping. The path box and the box our measuring reports are built from the same
points, contour points with their control points among them, so they are the same box and not
merely close ones; the whole of the difference is that Cairo keeps a path point on a grid of two
hundred and fifty sixths of a pixel, and the test allows a quarter of a hundredth for it. And a
canvas drawn by hand needs `setBorderOff` before `drawFigure`: the figure block is chosen by the
border setters, and `drawFigureWithBackgroundAndNoBorder` called directly reads an unset
`clipAfterwards` and dies on `NonBooleanReceiver`.

Design review, agreed before anything was edited: **nothing executed, one point deferred,
three rejected.** Deferred, and now a point of the phase 4 review: `VGScaledFont` carries 45
methods and 8 variables, and 20 of those methods sit in `*VectorGraphics-Bloc` — the font model
and the whole Alexandrie substitution adapter are one class. The refactoring is **Extract Class**,
and it is worth doing once, after unit 4.5 has posed the fifth and last site, rather than twice.
Rejected: factoring the two contour placers together, which is two occurrences and the third would
have to be invented; extracting the surface setup out of `glyphPathFormOfContours:`, fourteen lines
of view code read once; and pulling the duplicated `inkBoxOf:` test helper up, which has no common
test superclass to go to and belongs to the test review in any case.

### 4.5 — font extents

Decided in the interview of 2026-11-14 and built the same day. It poses the fifth and last of the
text sites, so the substitution of phase 4 is complete.

`VGScaledFont >> fontExtentsInto:onAeContext:`, on `VGAeTextFont` since 4.7, answers the font
extents site: ascent, descent, line
height and the widest advance the face allows, written into the record the caller owns. The numbers
are the ones `VGScaledFont >> fontExtents` already computes from `hhea` over the em square through
the font matrix, rounded when the options hint metrics, so the site adds no arithmetic of its own
and, like the measuring site of 4.3, never looks at the context it is handed.

1. **The copy lives on the extents, not on the font.** `VGFontExtents >> writeInto:` poses five
   setters and names no class, as `VGTextExtents >> writeInto:` does for the six numbers of a
   measured run. What a record of extents holds stays knowledge of extents.
2. **The red sits at the context and nowhere else.** The plan's own note for this unit — "Red:
   `metricsFor:font:` answers a negated ascent" — was wrong: `AeCanvas >> metricsFor:font:` sends
   `fontExtents` to the scaled font, never to the context, so that route was green before the unit
   and no site of ours is on it. The failing test is
   `VGAeTextContextTest >> testTheContextAnswersTheFontExtentsOfOurOwnFont`, and it failed with
   `VGScaledFont >> #fontExtentsInto:onAeContext:` not understood, on our own class, as the four
   sites before it did.
3. **The test compares against the font, not against hhea.** The five fields of `context
   fontExtents` against those of `font fontExtents`. The numbers themselves are pinned against live
   Cairo and live FreeType in `VGCairoTextTest`, and copying figures out of the face into
   `VectorGraphics-Bloc-Tests` would only restate them. The record holds five C doubles while our
   own metrics are exact fractions, so the comparison is against the double each one becomes on the
   way in: the first run said `23.616` against `2952/125`.
4. **The list of undelivered sites dies with its last entry.**
   `testTheTextSitesTheLaterUnitsDeliverFailNamingOurOwnFontAndSelector` existed to name the site
   still missing; the list is now empty and the test is deleted, with its helper
   `receiverAndSelectorNotUnderstoodIn:`, which had no other sender. The guard stays with the four
   site tests and `testEverySurfaceAnswersTheContextThatKnowsOurFonts`, itself deleted in 4.6 with
   the decision it asserted.
5. **The view draws real glyphs, so it hangs on the font.** `VGFontExtents` holds five doubles and
   no font, so a witness word cannot come from it. The arithmetic stays there — `drawLinesOn:
   placing:`, over the four rows `horizontalLines` names — and the tab is
   `VGScaledFont >> inspectorLineBox:`, gated by `inspectorLineBoxContext:`, drawing the word from
   the contours the path site of 4.4 puts down, at the font's own size, so the picture cannot drift
   from the route. A face with no line gap puts the bottom of its line box exactly on its descent:
   the line box is drawn first across the whole width and the blue ascent and descent lines short
   over it, so the green part still showing to the right is the line box.
6. **One example, for the site.** `VGScaledFontExamples class >> fontExtentsThroughAnAlexandrieContext`
   answers the `AeCairoFontExtents` our font filled, beside the four examples the earlier sites left.
   Unit 4.6 moved it to `VGAeTextContextExamples class >> fontExtentsFilledIntoAnAlexandrieRecord`.

**The incident the surface test caught.** Alexandrie was reloaded into the image during the unit.
Epicea records, in order, `AeCanvas >> inspectionOfSurface:` rewritten to a newer upstream source,
an `EpProtocolRemoval` on `AeCairoSurface`, and `newContext` back to `^ AeCairoContext newFor: self`
in protocol `instance creation`. `AeCairoSurface >> newContext` is the project's only extension that
*redefines* an Alexandrie selector instead of adding a new one, so it was the only one lost; the
eight others, all new selectors on `AeCairoScaledFont`, `AeCairoFontOptions`, `AeCairoMatrix` and
`AeFontManager`, came through untouched. Every text call then marshalled a `VGScaledFont` into FFI
and died on `VGFontFace >> #tfPointerAddress`, far from the cause —
`testEverySurfaceAnswersTheContextThatKnowsOurFonts` named it in one line instead. The method was
recompiled from the committed Tonel source back into `*VectorGraphics-Bloc`; the checkout had never
been wrong. The lesson was read first as a durability one - a redefining extension is only as durable as the
last load of the package it redefines - and then, in 4.6, as the deeper one: a redefinition cannot
leave the upstream checkout clean at all, so there was never a site to keep in force.

Design review, agreed before anything was edited: **one point executed, one kept as its own unit,
two rejected.** Executed: Extract Method on `VGFontExtents >> drawLinesOn:placing:`, whose nested
associations became `horizontalLines`, four rows of three named fields; the picture is pixel for
pixel the one it was. Kept: the **Extract Class** on `VGScaledFont` that 4.4 deferred, now 49
methods and 8 variables with 24 of the methods in `*VectorGraphics-Bloc` — the font model and the
whole Alexandrie adapter in one class. It is a unit of its own at the end of phase 4, with its own
green steps, not a tail to 4.5: `VGAeTextContext` dispatches through `scaledFontToWorkFrom`, `textFontToWorkFrom` since 4.7, so the
adapter has to be reachable from the font, and twenty-four methods move at once. Rejected:
extracting the surface setup shared by `glyphPathFormOfContours:` and
`lineBoxFormOfTheInspectorSample`, two occurrences with the third still to be invented; and pulling
`writeInto:` up out of `VGTextExtents` and `VGFontExtents`, which have no common superclass and
would need one built for two methods of five lines.

### 4.6 — the substitution site withdrawn

Asked for on 2026-11-14, straight after 4.5: the method `AeCairoSurface >> newContext` is still in
the `Alexandrie-Cairo` package, while it should be in a VectorGraphics package as an extension
method.

In the image the method already belonged to `VectorGraphics-Bloc`, in protocol
`*VectorGraphics-Bloc`. The Alexandrie checkout was dirty all the same, with one diff node on
`src/Alexandrie-Cairo/AeCairoSurface.class.st`, and no reclassification can mend that. A class holds
one method object for a selector, so an extension that *redefines* a selector takes the upstream
package's own method away: Iceberg reads the upstream method as gone, and the next load of
`Alexandrie-Cairo` puts the stock version back and ours away without a word — the incident 4.5
records. An extension that *adds* a selector has none of this. The rule of this project is that code
outside it is never changed except by an extension that adds a selector, so decision 7 of unit 4.1 —
one substitution site, `AeCairoSurface >> newContext`, covering window, composition layers, shadows,
exporters and offscreen at once — is withdrawn, and the stock `^ AeCairoContext newFor: self` was
recompiled into `Alexandrie-Cairo`, protocol `instance creation`. The Alexandrie working copy reports
no diff and no modified package again.

1. **The rule is a test, read off the upstream sources on disk.**
   `VGArchitectureTest >> testNoMethodOfThisProjectRedefinesAMethodOfAnotherProject` walks the
   extension methods of every package of this project, finds through `IceRepository registry` the
   repository that owns the class each one extends, and looks in that package's Tonel file for the
   header `<Class> >> <selector> [`. The helper `tonelFileDefiningTheClassOf:` answers nil for one of
   our own classes, for a registered repository with no location on disk — `pharo` among them — and
   for a package no repository has, as the image's own packages are. The red named
   `AeCairoSurface >> newContext`, the only offender in the project, and it is the guard against the
   next one.
2. **`VGAeTextContext` is built where it is wanted.** `VGAeTextContext newFor: aSurface` in place of
   `aSurface newContext`, at the five site tests of `VGAeTextContextTest`, at the stock-against-ours
   pixel comparison, and at the four examples. Nothing else changes: the class, the five sites and
   their numbers are the ones units 4.1 to 4.5 delivered.
3. **The canvas sites drive `VGCanvas`.** Four places built a stock `AeCanvas` and relied on the
   redefinition to get our fonts into it: two tests of `VGCanvasTest` (the measuring site of 4.3 and
   the path site of 4.4) and the two examples beside them. They now build `VGCanvas`, the canvas of
   this project, which makes a `VGCairoImageSurface` and a `VGCairoContext` of its own and needs no
   substitution. `AeCanvas >> metricsFor:font:` and the path factory are inherited unchanged, so the
   route under test is still the one Bloc calls.
4. **`testEverySurfaceAnswersTheContextThatKnowsOurFonts` is deleted.** It asserted decision 7, which
   is what has just been withdrawn, and the architecture test above now pins the rule that replaced
   it. The behaviour of the five sites stays covered by the tests that name them.
5. **The two examples of 4.4 and 4.5 move to the Bloc examples.** Naming `VGAeTextContext` from
   `VectorGraphics-Cairo-Examples` crosses the layering, which
   `testCairoExamplesStayInsideTheirAllowedDependencies` reported at once.
   `VGScaledFontExamples class >> glyphsPathOfARunOnACairoContext` and
   `fontExtentsThroughAnAlexandrieContext` are therefore
   `VGAeTextContextExamples class >> glyphsPathOfARunOnACairoSurface` and
   `fontExtentsFilledIntoAnAlexandrieRecord`, on the class whose subject they are, reading that
   class's own fixture.
6. **What is left uncovered.** `VGAeTextContext` is now reached from tests and examples only: no
   production sender exists. Alexandrie and Bloc create their surfaces themselves —
   `AeCanvas class >> extent:`, `BAAxisAlignedCompositionLayer >> createSurfaceToBePaintedOn:` and
   `BlGradientShadowEffect >> setUpShadowSurfaceFor:extent:` — and ask them for a context, which is
   stock again, so a `VGScaledFont` reaching one of those contexts still dies on
   `VGFontFace >> #tfPointerAddress`. Phase 5 therefore cannot route Bloc's text through the stock
   canvas; it has to put a canvas of this project in the frame. The honest shape, when phase 5 gets
   there, is a surface class of ours over `cairo_image_surface_create` whose `newContext` answers
   `VGAeTextContext`, created by a canvas of ours — not an extension that redefines anything.
7. **A stage for the tags phase 4 added.** `VGFrameProfileTest` was red on three keys with no stage:
   `VectorGraphics-Bloc/Fonts` and `VectorGraphics-Bloc/Text` are `text`, since a frame enters the
   font manager or the substituted context only to lay out or to draw a run, and
   `VectorGraphics-Bloc-Examples/Text` is `notInTheFrame`.

### 4.7 — the font model stops being the Alexandrie adapter

The end-of-phase-4 unit deferred by the design review of 4.1 to 4.5: `VGScaledFont` carried the whole
Alexandrie route as twenty-four extension methods of `VectorGraphics-Bloc` — more methods than the
twenty-four its own package holds — so the font model was two objects wearing one name. Extract Class
was the named refactoring, and the interview settled one adapter class carrying all twenty-four
rather than one class a concern.

1. **The red.** `VGAeTextFontTest`, in `VectorGraphics-Bloc-Tests`, states three facts: the adapter
   answers each of the five verbs an Alexandrie context sends and `VGScaledFont` understands none of
   them, a font answers one and the same adapter however often it is asked and that adapter answers
   for that font, and a run drawn twice through two contexts rasterises each glyph once. The third is
   why the adapter is kept on the font and not built per pose: each context of a frame poses the font
   again, and a fresh adapter would throw the masks away every time.
2. **`VGAeTextFont`**, package `VectorGraphics-Bloc`, tag `Text`, beside `VGAeTextContext`. Slots
   `scaledFont` and `cairoMaskAtlas`, built by `on:`, with the five text sites in protocol
   `text sites`, the mask machinery in `masks`, `appendContour:toAeContext:` in `private` and the
   three views in `inspector`. Every send that was `self` and meant the font reads `scaledFont`; the
   five sites, the mask machinery and the views are otherwise the methods units 4.1 to 4.5 delivered.
3. **The pivot stays a dispatch.** `VGAeTextContext >> scaledFont:` is
   `^ aScaledFont aeTextFont poseOnAeContext: self`, and `AeCairoScaledFont >> aeTextFont` answers
   `self` — an extension that adds a selector, which 4.6 showed is the only kind this project may
   write. So the route is still chosen by the font answering for itself, with no `isKindOf:` anywhere,
   and the cost is one selector of upstream surface instead of a second façade on the font model.
4. **`VGScaledFont` keeps one selector of that package**, the lazy accessor `aeTextFont`, in a ninth
   slot of the same name; `cairoMaskAtlas` left the font with the methods that read it. The font model
   now names nothing of Alexandrie.
5. **The views and their examples.** The three tabs of the Alexandrie route — Cairo masks, Path, Line
   box — look at what the adapter holds, so they moved with their gates and their six helpers, and
   are numbered 1 to 3 on the class they now sit on. `VGAeTextFontExamples`, in
   `VectorGraphics-Bloc-Examples`, answers the adapter of a font a run was drawn through twice, which
   gives the Cairo masks tab a warm atlas to show; it reads the font and the run from
   `VGAeTextContextExamples`, its sibling in the same package, because the run that warms the atlas is
   drawn through one of their contexts and `VectorGraphics-Bloc-Examples` may not name
   `VectorGraphics-Cairo-Examples`. The class is listed in `VGBlocExamplesTest >> exampleHolders`:
   without that line the two generic gates never see it, and `ReClassNotReferencedRule` is what says
   so.
6. **A backwards dependency closed.** `glyphsOf:size:` sat in `VectorGraphics-Bloc` and was sent three
   times from `VGCairoContext`, so the Cairo backend reached into the Bloc package for a method of its
   own class. It is now in `VectorGraphics-Cairo`, protocol `layout`. No test saw this: the
   architecture gate reads references between packages by the classes a method names, and a send to a
   method of one's own class names nothing.
7. **The context names what it holds.** Pharo's own rename refactorings took the slot `ownScaledFont`
   to `ownTextFont` and the selectors to `ownTextFont`, `ownTextFont:` and `textFontToWorkFrom`,
   rewriting the senders, the one test among them. The class comments of `VGAeTextContext` and
   `VGAeTextContextTest` still claimed the substitution 4.6 withdrew, and were corrected here.

Twenty-three methods moved, in four steps with the suite green and a commit at each: `31aba7a` the
sites and the masks, `209a4b8` the views and the examples, `6dbd856` the renames, and this one the
repackaging and the write-up. `VectorGraphics-Bloc-Tests` is 79, `VectorGraphics-Cairo-Tests` 381,
and both examples gates are green on the new class.

The design review that follows the unit kept three points and rejected the rest. The loop that
appends every contour of a set was written out in four places, which is the rule of three passed, so
`appendContours:toAeContext:` is one method now. The line box view measured the right edge of the run
with a nested `inject:into:` although `VGScaledFont >> wholePixelBoxOfContours:` already answers that
box, so the size of that picture is a method of its own that asks the real rule, and the margin is a
method rather than a literal in two places. The drawing site built the part of the matrix a vector is
mapped by from a copy and two setters: `VGCairoMatrix >> linearPart` answers it under the name the
geometry gives it, pinned by a test that it maps a vector as the whole matrix maps the step between
two points. `676841a` and `3596893`. Rejected, and why: no Extract Class on the masks of
`VGAeTextFont` while nothing else needs them; no key object for a glyph's index, phase and matrix; and
the five `…ThroughCairo…` twins of `VGAeTextContext` stay, because an extension method cannot send
`super` and nothing upstream may be redefined.

### 5.1 — the Bloc route, end to end

A paragraph measured and drawn in an offscreen space, with our manager installed and no FreeType
face anywhere in the frame. Unit 4.6 withdrew the substitution site, so the stock `AeCanvas` cannot
be the canvas of this test any more: it makes a stock surface and asks it for a stock context, which
a `VGScaledFont` cannot enter. The frame is driven through a canvas of this project, and the first
question of the unit was how far up the Bloc route that canvas has to be put. The answer the
interview settled is the whole way: the route Cairo draws and we only feed with fonts gets its own
three sisters beside the all-ours ones, built bottom up with a commit at each green step.

1. **`VGAeCanvas`**, package `VectorGraphics-Bloc`, tag `Text`, with `VGFontCanvas` inserted above
   both canvases. The one override is `prepareForSurface:`, Alexandrie's own method with the send
   `cairoSurface newContext` replaced by `VGAeTextContext unownedNewFor: aeCairoSurface`, and
   `VGAeCanvasTest` holds the rest of the method against the upstream source by parsing both and
   comparing the bodies. The five font methods the two canvases share — `initialize`, `fontOptions`,
   the two quality setters and `scaledFontForFace:size:` — moved up into the new abstract class with
   its three class-side constants, and a `fontFaceFor:` hook parts them: `VGFontCanvas` answers the
   face it was handed, because on this route Bloc's face is already one of ours, and `VGCanvas`
   overrides it with `self class faceForFreeTypeFace: aFace`, the bridge unit 5.2 deletes.
   Reparenting `VGCanvas` in Pharo 13 drops its class-side instance variable, so `faceCache` was
   declared again afterwards.
2. **`VGAeOffscreen`**, same package and tag. Bloc measures a paragraph during layout, before any
   window exists, through a singleton canvas of one pixel, so the route needs its own or a paragraph
   would be laid out against fonts read by Cairo's own FreeType while the frame it belongs to is
   drawn against ours. Like `VGOffscreen`, the single override is Alexandrie's `ensureReady` with
   the canvas class changed, held against the upstream source by a test, and the singleton is its
   own because a class instance variable gives each subclass its own slot.
3. **`VGAeRenderer`**, same package and tag, with `initializeForHostSpace:`, `label` and
   `offscreenMeasureTextParagraph:`. The instance side override is Alexandrie's method with the
   canvas and the offscreen changed, pinned the same way; `renderWith:…` is inherited whole, because
   on this route the surfaces, the paths and the paint are Cairo's own and only the fonts are ours.
   The label is `'VectorGraphics fonts'`, told apart from the other two in a window title and in
   Bloc's own tools.
4. **The gate.** `VGAeRendererTest` opens a real `BlSpace` holding a `BlTextElement` on
   `VGPixelBufferHost`, with our manager installed and this renderer named in
   `BlHostRenderer class >> preferableClass`, and states four facts about the frame it drew: the
   space chose this renderer, pixels reached the buffer the host lent, the span was measured against
   a `VGFontFace` and a `VGScaledFont`, and `AeFTFace allInstances size` did not grow across the
   frame. The fonts are read from the offscreen canvas and not from the frame canvas, because
   `BATextParagraphSpan >> measure` resolves the scaled font while the span is measured and the frame
   canvas is then handed that font to draw with — which is also why the measuring canvas of the route
   had to be its own.
5. **Three inspector tabs serve all the siblings now.** Seams and Backend moved from `VGCanvas` to
   `VGFontCanvas`, and the Seams gate had asked for `AeCanvas` as the direct superclass, which the
   new class in between made false: the tab had gone silent on the reader's screen with nothing
   failing, and a test states it is offered on each of the three canvases. It now asks
   `overridesUpstreamSelector:`, which walks the stretch from the canvas up to Alexandrie's. The
   Backend tab lists `inspectorBackendProperties`, and `VGCanvas` appends the one row the bridge
   fills. Measuring and Renderer could not move up the same way, because the offscreens and the
   renderers of the routes are siblings under Alexandrie's own classes: they are extension methods of
   `VectorGraphics-Bloc` on `BAOffscreen` and `BARenderer`, with `canvas`, and each one asks the
   object which canvas and measurer it holds rather than restating it. That is the only kind of
   change this project may make to a class it does not own, and the precedent is
   `TTFontCatalogueEntry >> inspectorShaping:`.
6. **The examples.** `VGAeCanvasExamples` answers a canvas over a small surface, the scaled font it
   builds for a face of our manager, and the one pixel offscreen of the route;
   `VGAeRendererExamples` answers a renderer prepared for a host space, and a space holding text
   opened and drawn into a buffer of pixels with no window present, which is this unit end to end in
   one click. Both are listed in `VGBlocExamplesTest >> exampleHolders`, without which the two
   generic gates never see them, and both examples that touch a global put the image's own renderer
   and font manager back in an `ensure:`.

Three cycles, three commits: `85a6db9` the canvas, `0aa5b79` the offscreen, `0ace22b` the renderer.
`VectorGraphics-Bloc-Tests` is 95, the architecture gate 48 and the documentation gate 60, all green,
and `run_critics` is clean on everything the unit touched.

The design review that follows the unit kept three points. The stretch of the hierarchy that holds
our overrides is now named once, by `VGFontCanvas class >> ourClassesBelowAlexandrie`, instead of
being computed in both seam methods; `seamRows` scans upstream and scans ours through two methods of
its own; and the two inspector extensions say why they read the slots of the object instead of its
accessors — `BAOffscreen >> canvas` sends `ensureReady`, so a tab that used it would build the
measuring canvas of an object a reader is merely looking at, and `BlHostRenderer` declares
`scaleFactor` with no accessor at all. The review also found a hole: `VGAeRenderer` inherits
`newFormFrom:` and `write:asPngTo:`, whose upstream bodies reach Alexandrie's own canvas, which
cannot draw a `VGScaledFont`, so an element carrying text can be drawn in a frame on this route but
not exported from it. The sister route redefines both. The hole is recorded as a stated fact by
`VGAeRendererTest >> exportSelectorsWithNoOverrideYet`, which fails as soon as one of the two is
covered, and unit 5.3 decides whether this route needs them. The duplication of `ensureReady` and
`initializeForHostSpace:` between the two routes was left alone: two occurrences, and Alexandrie
names the canvas class inline, so even a hook would still leave both methods overridden.
Four commits: `e24b62e` and `bc89100` the two extractions, `bf5ef57` the two comments,
`9a2eeab` the stated hole. `VectorGraphics-Bloc-Tests` is 96 with the hole test in it.

### 5.2 — the bridge dies

Done, in three cycles.

**Cycle 1 — the ported experiments read their font with no FreeType.**
The five experiments of `VGAlexandriePortedExperiments` that picked their font out of the global
`AeFontManager` now read a `TTFontCatalogue` of their own, scanning the directory Alexandrie scans,
or the bytes an embedded font class carries; and they shape from a HarfBuzz blob over the bytes of
the face, because upstream's `AeHbBuffer >> cairoGlyphArrayForFace:size:` sends `charHeight:` to a
FreeType face, which a `VGFontFace` is not. `numberOfGlyphs` became `glyphCount`.
The copies are generated, so the rewrites live in `VGAlexandrieCorpus class` as
`fontLookupRewriteIndentedBy:informing:` and `shapingRewriteIndentedBy:`, each asked for at the two
indentation depths of the copies through the new `source:indentedBy:`. The gate is
`VGConformanceTest >> testTheExperimentsPortedFromAlexandrieReadTheirFontWithNoFreeType`.

The copies read a catalogue rather than `VGFontManager`, which was the first design and had to be
abandoned: `VectorGraphics-Conformance` is loaded by the Cairo example, test and dev groups, which
bring no Bloc package, so naming a class of `VectorGraphics-Bloc` broke three tests of
`VGArchitectureTest`. The new edge is `VectorGraphics-Conformance` → `VectorGraphics-TrueType`,
stated in `VGArchitectureTest class >> allowedDependencies` and in
`BaselineOfVectorGraphics >> declareSupportPackagesOn:`. For the same reason the shaping rule is
written out in the generated copies instead of being sent to
`TTFontCatalogueEntry >> newHbFontScaledTo:`, which is the one place the project states that rule
but is filed in `VectorGraphics-Bloc`. No production method was added.
`VGAlexandrieCorpusTest` stays green, so the ported pictures are still the pictures Alexandrie's
own FreeType experiments draw.

One sibling test lost its subject with the last two senders: `VGCairoTextTest` asserted that every
method of ours handing a face to HarfBuzz keeps it for the session, because
`hb_ft_font_create_referenced` frees it with `FT_Done_Face` from the finalisation process. The rule
now reads the other way round, as `testNoMethodHandsAFreeTypeFaceToHarfbuzz`: no method of this
project sends `cairoGlyphArrayForFace:size:` at all, and the reason stays in the comment.
Two commits: `8b91c71` the experiments, `3ceed0e` the inverted gate.

**Cycle 2 — the bridge itself.**
Gone: `VGFontFace class >> newForFace:` and `bytesForFamilyName:styleName:`,
`VGCanvas class >> faceForFreeTypeFace:` with its `faceCache` class variable and `resetFaceCache`,
both implementations of `fontFaceFor:`, and the `VGCanvas` override of `inspectorBackendProperties`
that counted the cached faces. `VGFontCanvas >> scaledFontForFace:size:` stays, because it also
fixes the upstream cache that never fills, and it now hands the face it is given straight to
`VGScaledFont`: the two canvases part on nothing in the font path any more.
`VGFontFace class >> default` and `defaultBytes` stay — they read the font Pharo embeds and name no
FreeType class.

The gate is `VGCanvasTest >> testNoMethodOfThisProjectRecoversTheBytesBehindAFreeTypeFace`: no
package of this project implements any of those six selectors. It scans the image and then keeps to
our own packages, because upstream implements `newForFace:` too, on its own Cairo font face.
`bytesForFamilyName:styleName:` made the fallback for a family no registry can name, a second time
over; the one that remains is `BAFontConverter >> faceFor:` falling back on the default face of the
manager posed, which `installGlobally` sets, and it is pinned by
`VGFontManagerInstallationTest >> testAFamilyNobodyHoldsFallsBackOnTheDefaultFaceOfTheManagerPosed`.
Three tests of the bridge are deleted, with the two `VGCairoTextTest` fixture helpers only they
used, and the example that built a face from the manager's FreeType face;
`VGCanvasExamples class >> scaledFontForTheDefaultFace` now asks a `VGFontManager` of its own for
the face, since posing one would change the image an example runs in. The test of the scaled font
states that the canvas passes the face through untouched, and the Backend view test no longer looks
for the faces-cached row. The class comments of `VGCanvas` and `VGFontCanvas` say what the font
seam is without the bridge. One commit: `0685b9e`.

**Cycle 3 — the plan.** This section, and the correction to phase 6 below.

`VGAlexandrieFontLifetime class >> freeTypeLibrary` and `roleOf:` name `AeFTLibrary` and are kept,
with their examples: they document the handle lifetime of the stack phase 6 unloads, which is what
makes a reader understand why the project left it. They live in `VectorGraphics-Conformance`, which
loads only in the test, example and dev groups, so phase 6 can run with them in the image — that
package is red during the unload window and green again after the reload, like the seven Alexandrie
test packages.

Counts after the unit: `VectorGraphics-Bloc-Tests` is 95, three bridge tests out and two gates in;
`VGCairoTextTest` is 36; the whole `VectorGraphics-Cairo-Tests` package is 382.

**The mutation reference.** The design review after the unit asked for one figure: that deleting
four tests had not taken coverage with them. The four tested `faceForFreeTypeFace:`, `faceCache`,
`newForFace:` and `bytesForFamilyName:styleName:`, every one of which the same cycle deleted, so no
surviving method lost its only test by construction. The run gives the number the later units are
measured against. MuTalk 3.0.8, loaded through the baseline's `dev` group, mutating
`VGFontCanvas` and `VGFontFace` alone, with the nine test classes that name either of them
(`TTFontMetadataReaderTest`, `VGAeCanvasTest`, `VGAeRendererTest`, `VGAeTextContextTest`,
`VGAeTextFontTest`, `VGCairoTextTest`, `VGCanvasTest`, `VGFontManagerInstallationTest`,
`VGFontManagerTest`): **score 34, 1599 mutants, 547 killed, 1052 alive, 15 min 32 s**. The working
copy held no production change afterwards.

The alive mutants fall in two heaps, and neither is a surprise. The inspector views and `printOn:`
carry most of them, because a view is pinned by one test that it builds and reads, not by a test per
label. The rest sit in the glyph reader that `VGFontFace` grew in phase 2 — `readBytes:`,
`nextSignedByte`, `readComponentWithFlags:`, `contoursOfSimpleGlyph:`, `glyphIndexForCodePoint:` —
where the composite-glyph path and the signed readings survive mutation. That is the coverage to
raise before phase 8 touches the same reader for CFF, and it is a defect of phase 2, not of this
unit: no test of this unit should be written to chase it.

### 5.3 — a window drawn by Cairo — done

One `open…` example is the deliverable: text in a window drawn by `VGAeRenderer`, Cairo
compositing every pixel, with our fonts behind it and no FreeType in the image.
The stock renderer cannot be that renderer, as this unit read it before 5.1 was built: a stock
renderer measures text through `BAOffscreen`, whose stock canvas asks its surface for a stock
context, which a `VGScaledFont` cannot enter. Unit 5.1 built the three sisters that can.
A second `open…` on `VGRenderer` is kept as a sibling, because the same faces serve it, but it
proves nothing about this plan.

**What the window shows.** `VGAeRendererExamples class >> textSceneInTwoSizes` builds the scene:
one line in `Cascadia Code` at 12 and at 36, on a light background that makes the compositing
visible. The family is named rather than left to the default face, so that what a reader sees is a
font found on the disk; Pharo bundles Cascadia Code, so the name holds in any image of it.
`VGRendererExamples class >> textSceneInTwoSizes` is its own scene, word for word the same today.
The two are kept apart on purpose: each example reads on its own, and two occurrences are not yet a
rule.

**What the examples install.** `openWindowWithTextDrawnByCairo` and
`openWindowWithTextDrawnWithoutCairo` save `BlHostRenderer preferableClass` and the
`globalInstance` slot, pose `VGFontManager installGlobally`, scan the directory Pharo ships its
fonts in — the manager's default faces are the two Source families, and Cascadia Code is nowhere
else — choose their renderer, reset the offscreen of their route, and open a space on the host Bloc
prefers. The window has to outlive the method, so nothing is put back in an `ensure:`: a frame
resolves its faces through `AeFontManager globalInstance` again on every repaint, and
`space when: BlSpaceClosedEvent doOnce: [ … ]` puts the renderer, the manager and the offscreen
back when the reader closes the window.

**The gates.** A window blocks the image until a reader closes it, so no test opens one. Each
route gets a test that draws its own scene on `VGPixelBufferHost` instead:
`VGAeRendererTest >> testTheWindowSceneDrawsTextOfTwoSizesInACatalogueFamily` and the same selector
on `VGRendererTest`. Three facts each: the frame reached the pixels the host lent, the scene names
one family in two sizes, and the scaled fonts the frame resolved are `VGFontFace` instances
carrying `Cascadia Code` at 12 and at 36 — which is what tells a silent fallback on the default
face from the font the catalogue found. `VGRendererTest` saves and restores the manager slot in the
test itself, since no other test of that class poses one.

**No new inspector view**, and the unit says so rather than inventing one: no new kind of object
appears here — a scene is a `BlElement`, the result is a window — and the Pixels tab of the renderer
already shows the frame that was drawn. The cycle's fifth artefact is missing on purpose.

Counts after the unit: `VectorGraphics-Bloc-Tests` is 97, two gates in. Critics on the four classes
touched are clean but for the `ReClassNotCategorizedRule` already on the carried defect list.
Commit first and run the two `open…` alone, per the project rule on window and device runs.

**Read on the machine.** Both windows were opened by hand from the browser after the commit, one
after the other: text is drawn in a Bloc window at the small and at the large size, on the Cairo
route and on the route without Cairo. The deliverable of the unit is a window a reader can look at,
so nothing short of looking at it closes the unit.

**The design review.** Two duplications were past the rule of three, and both are now said in one
place.

The slot `AeFontManager` keeps its manager in was read by reflection in nine methods over five
classes, each repeating why `AeFontManager globalInstance` cannot be sent for it: the getter builds
a whole FreeType manager when the slot is nil, which a test or an example that only wants to put
the image back as it found it must not do. `VGFontManager class >> managerUpstreamHolds` and
`>> restoreUpstreamManager:` say it once, and
`VGFontManagerInstallationTest >> testTheUpstreamSlotIsReadAndWrittenWithoutEverBuildingAManager`
states the three facts, the last of them by reading the two methods' own `messages`: neither sends
`globalInstance`. The two assertions that pin the real slot against what `installGlobally` did keep
their reflection on purpose — a reader of those tests must see the slot itself, not a reader of
ours standing in for it.

The variable `scaledFontCache` was reached with `instVarNamed:` in three test methods, which no
rename would follow. `VGFontCanvas >> cachedScaledFontsByFaceAndSize` answers a snapshot of it,
keyed by the face and the size the font was asked for. A snapshot and not the cache: it is an
`LRUCache`, which reading promotes and which a reader could empty under the canvas drawing with it.

Nothing else was changed. The two `textSceneInTwoSizes` and the two pairs of private test helpers
are two occurrences each, which the interview chose deliberately; both renderer test classes descend
straight from `TestCase` and both examples classes from `Object`, so pulling either up would mean
inventing a superclass for a duplication that is not yet a rule. The two new readers got no
`<sampleInstance>` example and no inspector view, and the unit says so rather than inventing them:
they are one-line readers of a class slot on a class that already has its installation view, and
`inspectorInstallation:` deliberately says nothing about what upstream holds. Counts after the
review: `VectorGraphics-Bloc-Tests` is 99.

### 5.4 — `FontFamily` takes its families from the catalogue — done

`FontFamily class >> addFamiliesFrom: aCatalogue` builds one `TrueTypeFontFamily` per family the
catalogue holds and registers it with `addFamily:`. Nothing is parsed on the way: a family keeps
the catalogue entry of each of its faces and reads the outlines behind one when a reader first asks
for a font of that face. A name already registered is left alone, so a family posed by hand — by a
test, by a consumer, by a font loaded on its own — is never replaced by a scan, and a second call
does nothing rather than throw away the fonts the first one built. `AvailableFamilies`,
`familyNamed:` and `defaultFamilyAndPointSize` keep their protocol, so `VectorCanvas` and its tests
see no change in shape — the dictionary is simply no longer empty by default.

This is the other half of decision 13: one scan, two registries, two kinds of face —
`TrueTypeFont` in `Form` for `VectorCanvas`, `VGFontFace` in outlines for Cairo and Bloc.

**Deviation from the plan.** The plan registered each family through `baseTTFontDescription:`, with
the description read lazily. A family built that way knows one face, and cannot say which of its
faces is the bold one until it has parsed them: the emphasis of a face is read from the triple the
catalogue already keys it by — slant, weight class, width class — and not from the description. So
a family keeps the catalogue entry of every face instead, filed by emphasis in the encoding
`StrikeFont` uses and `TrueTypeFont >> emphasis` answers: 1 bold, 2 italic, 3 both, 0 the plain
face. A weight class of 600 is Semibold, the lightest weight a reader is meant to see as bold. The
first face to claim an emphasis keeps it, so a family carrying both Semibold and Black draws with
the one met first. The lazy parse the plan asked for is still there, one face at a time rather than
one family at a time: 82 ms for Cascadia Code, against the 17 s that parsing 210 families eagerly
would cost at the scan.

**A face is an object.** `TTFamilyFace` holds the catalogue entry a scan met and the description a
reader parses out of it at the first ask; `isParsed` answers whether the outlines have been read
without reading them, and `styleName` names the face from whichever end is there. A face built from
a description has no entry behind it, which is how a font posed by hand becomes a face of a family.
The family keeps one dictionary of faces by emphasis, the base face under 0.

**The emphasis comes from the family.** `TrueTypeFont >> emphasized:` asked for a face it holds no
derivative for now asks its family: `fontForEmphasis:pointSize:` parses that one face, builds the
font, wires it to the plain font of that size and files it as its derivative. A family with no face
of that emphasis answers nil, which leaves the old fallbacks in charge — italic or bold in place of
bold italic, the plain font for a bold or an italic nobody holds, and the synthetic derivation for
underline, strike-through, superscript and subscript, none of which a font file carries.
`atPointSize:` hangs only the faces already parsed off the plain font, so asking for the plain font
parses nothing else. `clearCache` throws away the fonts built and keeps the faces: it used to reach
for a description a lazy family does not have and fail on nil.

**The wiring.** `VGFontManager class >> installGlobally` registers its own catalogue with
`FontFamily` and poses the default family and point size the manager can draw with —
`AeSourceSansPro_Regular familyName` and 12 — each one only when the image has not chosen it.
`FontFamily class >> familyNames` and `familyNamed:` read `self availableFamilies` rather than the
class variable, since a pristine image still holds nil there and an installation is the first
reader. The manager is built by `newWithDefaultFaces`, which scans the embedded fonts only, so an
image that wants the machine's fonts sends `scanDefaultDirectories` as before.

**The gates.** The fixtures of `TTFontFixtures` carry a name table and an OS/2 table and no glyph
tables at all, so a parse of one raises `Missing required TrueType table: head`: that is how a test
states that a face was not read, and which face a reader reached for. On that,
`TrueTypeFontFamilyTest` states that a face is filed under the emphasis its style key gives, that a
family keeps the faces it was given and parses none of them, that a font of an emphasis is parsed
only when it is asked for and that an emphasis no face carries answers nil, and that clearing the
cache reads nothing. `TrueTypeFontTest >> testEmphasizedAsksItsFamilyForAFaceItHasNotBuiltYet`
states the same from the font's side. `FontFamilyTest` states that registration gives one lazy
family per catalogue name, keeps every face of a family, and leaves a family posed by hand alone.
`VGFontManagerInstallationTest >> testInstallingRegistersTheCatalogueFamiliesAndPosesADefaultOnlyWhenNoneIsSet`
states the wiring, saving and restoring the three class variables of `FontFamily` the way the class
already saves the two manager slots. Two tests use a font of this machine instead of a fixture,
where the parse succeeds: the plain face is read at the first `atPointSize:` and not before, and a
face posed as a description is parsed from the start.

**The example and the view.** `TrueTypeExamples class >> fontFamilyOfThisMachine` builds, in one
click, the family of the font the examples draw with, taken from this machine's own fonts the way
an installation takes it; `fontFaceOfThisMachine` answers its unread plain face.
`TrueTypeFontFamily >> inspectorFaces:` is one row per emphasis — the emphasis, the style the face
states, parsed or pending — and `TTFamilyFace >> inspectorFace:` says what a face is and where it
comes from. Neither reads a byte, which is what makes them usable on a family nobody has asked
anything of yet; both have a test that builds them through `StInspectionContext` and runs every
column block over every row, on fixtures that would raise if a row parsed.

**Read on the machine.** `VGFontManager installGlobally` takes 15 ms. `Source Sans Pro` at 16 pt
answers 13.27 for the width of `$A` plain, 14.06 bold and 12.44 italic — three real faces, not one
face three times. On `DejaVu Sans` taken from the machine's scan, `atPointSize: 14` leaves bold and
italic pending, `emphasized: 1` parses the bold face alone, and the italic one is still pending
after it.

**The design review.** Two refactorings were agreed and done, one was dropped.

The family kept four slots for one idea — the entry of its base face, its parsed description, a
dictionary of entries by emphasis and a dictionary of descriptions by emphasis — and four methods
asked whether an emphasis was the base one. Extract Class: a face is a `TTFamilyFace`, a family
keeps one dictionary of faces, and `hasParsedEmphasis:`, `styleNameOfEmphasis:` and
`catalogueEntryForEmphasis:` each ask the face. `atPointSize:` keeps the only remaining condition
that earns its place, and the comment says why: a face still pending is not built here, or asking
for the plain font would parse every face of the family.

`TrueTypeFont >> emphasized:` mixed four levels and was long and complex by Renraku's count before
this unit touched it. Extract Method: the body is the sequence of decisions, and the three tails
are `realFontForEmphasis:`, `plainestFontForEmphasis:` and `syntheticFontForEmphasis:`. Both
critics on the method are clean.

Extracting a lazy `ttFontDescriptionForEmphasis:` out of `fontForEmphasis:pointSize:` was dropped:
the extract-class step moved the lazy parse into the face, so the extraction would have added a
level of indirection that simplifies nothing.

Two tests changed before the refactoring and not during it, which is where a test pinning an
implementation detail belongs. One read the slot holding the parsed description through
`instVarNamed:` and now asks `hasParsedEmphasis:`. The other asserted that the catalogue entry of
emphasis 0 is nil, which said only that the plain face is kept apart from the faces filed by
emphasis; the fact that a family has no entry for an emphasis it holds no face for stays, stated on
emphasis 3.

Counts after the review: `VectorGraphics-TrueType-Tests` is 225, `VectorGraphics-Bloc-Tests` is
100, `VGArchitectureTest` is 48. Critics on the classes touched are clean but for the carried
defect list — the two `ReExcessiveArgumentsRule` on `VGFontManager`, the missing class tag on
`VGFontManagerInstallationTest`, `ReRefersToClassRule` on `FontFamily class >> defaultLineSpacing`,
and the long, complex `TrueTypeFont >> glyphAtUtf8Byte1:byte2:byte3:byte4:`, which this unit did
not touch.

### 6 — the proof by absence — done

The route was proved in an image with no FreeType in it at all: `Alexandrie-CairoFreetype-Tests`,
`Alexandrie-CairoFreetype`, `Alexandrie-FreeType-Tests` and `Alexandrie-FreeType` were removed with
`removeFromSystem`, `Smalltalk includesKey: #AeFTFace` went from true to false, and a Bloc text
element was then drawn into a frame by Cairo through faces and scaled fonts of this project alone.
The frame is `font-plan-6-proof.png` next to the image, 320 by 160, and the script that drew it is
`font-plan-6-proof.st` in the same directory.

**Deviation from the plan.** The plan said the only casualties would be test suites. That is wrong,
and the reason is packaging rather than FreeType: `Alexandrie-FreeType` also holds the embedded
font files, `AeEmbeddedFontFile` and the six `AeSourceSansPro_*`/`AeSourceCodePro_*` classes, which
are pure data. `VGFontManager class >> newWithDefaultFaces` names two of them, so
`VGFontManager installGlobally` — our own installation, the thing a consumer sends — cannot run
while the package is out. The proof therefore ran on a font of this machine: a manager built with
`scanDefaultDirectories` (208 families in 66 ms), posed by hand with `AeFontManager globalInstance:`
and `FontFamily addFamiliesFrom:`, with `'DejaVu Sans'` as the default face and `'Liberation Mono'`
as the default code face. That is the stronger statement of the unit, not a weaker one: the route
needs an sfnt file, not FreeType, and not even the fonts the package ships.

**Two more dependencies on `Alexandrie-FreeType`, neither of them FreeType.** `Integer >>
from26Dot6FractionalPoint` is an extension method packaged in `Alexandrie-FreeType`, and its only
senders are in `Alexandrie-Harfbuzz`: `AeHbGlyphPosition >> xAdvanceFrom26Dot6` and its three
siblings, and `AeHbFont >> positionWithFallback:`. So shaping breaks when the package goes, with
`Message not understood: SmallInteger >> #from26Dot6FractionalPoint`, although nothing in the path
touches FreeType. `AeFilesystemResources class >> fontsDirectory` and `>> inriaSerifRegularTTF` are
extensions packaged in `Alexandrie-FreeType-Tests`, and our `VGAeRendererExamples class >>
openWindowWithTextDrawnByCairo` sends the first of them to find Cascadia Code. Both are upstream
packaging defects, and both are for unit 7 to answer, because the answer is not an extension method
of ours: adding a selector upstream already defines would collide the moment the package loads.

**What `removeFromSystem` leaves behind.** It does not rewrite the references of surviving methods,
so a method that names a removed class gets an obsolete binding. Two came out of that, and both
read as a defect in an unrelated place. `AeCairoContextTest class >> resources` answers
`AnObsoleteAeFTLibraryResource`, whose `setUp` fails on the missing `downloadedFontsDirectory` and
whose `tearDown` then raises `receiver of "externallyFree" is nil` **outside** the SUnit harness,
in `TestResource class >> makeAvailable` — so the whole suite of `Alexandrie-Cairo-Tests` dies with
one unreported error instead of failing test by test. And `VGAlexandrieFontLifetime class >>
inspectorKept:` prints each object it keeps, which are now `AnObsoleteAeFTFace` instances, whose
`printOn:` fails on `AnObsoleteAeFTFaceFlag class >> bitFlagNamesAt:`.

**The proof.** It is a throwaway script in `Smalltalk imageDirectory` and belongs to no package,
because nothing of the project may depend on it; the write-up is where it is kept. It checks the
five class names are absent, builds the manager described above, scans the fonts directory of
Alexandrie's own checkout on top (three families more, Cascadia Code among them, which the scene of
unit 5.3 names), opens the scene of that unit on `VGPixelBufferHost` with `VGAeRenderer`, and states
what the 5.1 gate states: the space chose our renderer, the pixels are not all zero, and the faces
and scaled fonts the offscreen canvas cached are `VGFontFace` and `VGScaledFont`. It then writes the
`Form` to `font-plan-6-proof.png` and puts the renderer and the font manager back. Read on the
machine: 211 families scanned, 213 registered with `FontFamily`, two faces and two scaled fonts
(Cascadia Code at 12 and at 36 points), 5436 bytes of PNG. The file was read back, parsed, and run
again from its own text, which answered the same figures.

**The window.** `font-plan-6-window.st`, beside the proof, opens the same scene in a real window of
this machine and puts the renderer and the manager back when the space closes. It was run by hand,
alone, in the image with no FreeType, and the reader saw what the unit promises: the sentence
`Drawn with our own fonts` in a window, small and large. A window example is run by hand by the
project rule, and that rule is why this one is a script and not a gate.

**The red, measured during the window.** Of ours, three packages are untouched —
`VectorGraphics-TrueType-Tests` 225 of 225 green in 7.5 s, `VGArchitectureTest` 48 of 48, and
`VectorGraphics-Tests`, `-Engine-Tests`, `-Paths-Tests` and `-Text-Tests` all green. The rest is
red for the embedded fonts, not for FreeType: `VectorGraphics-Bloc-Tests` 79 of 100, of which
fifteen say `No face registered for the family Source Sans Pro`, three
`SmallInteger >> #from26Dot6FractionalPoint`, one `inriaSerifRegularTTF`;
`VGCairoExamplesTest` two green of six, the four others on
`Attempt to read undeclared variable AeSourceSansPro_Regular`; `VGCairoTextTest` 35 of 36, the
missing one the inspector-view gate printing an obsolete face; `VGCairoSkeletonTest` one failure,
which is the project's own undeclared-variable gate naming the two methods of `VGCairoTextTest` that
read `AeCairoFreetypeFontFace` and `AeSourceSansPro_Regular`; `VGConformanceTest` 14 of 15, the
missing one on `fontsDirectory`. `VGAlexandrieCorpusTest` was not measured, being too slow for one
call. So the plan's claim that `VectorGraphics-Conformance` is the only package of ours to go red
was wrong in both directions: conformance loses one test, and the Bloc layer loses twenty-one.

Of Alexandrie's: `Alexandrie-FontManager-Tests` two green, one failure
(`scanEmbeddedFonts` answers `#()`) and five errors; `Alexandrie-Harfbuzz-Tests` nineteen green, one
failure and twenty-eight errors, every one of them a missing fixture extension;
`Alexandrie-Cairo-Tests` and `Alexandrie-Canvas-Tests` die at the obsolete test resource described
above, with sixteen of the eighteen Cairo classes green when run one by one; `Alexandrie-Blur-Tests`,
`-Base-Tests` and `-NewTools-Tests` unchanged.

**The reload, and green again.** `font-plan-6-reload.st`, written and read back before anything was
removed, puts the four packages back from the local Iceberg clone pinned at
`e9f1ddc719df8a14bd13876ee64802d2b5cbe565` — no network, the very checkout this unit measured — and
raises if a package or `AeFTFace` is still missing; a Metacello form by the same SHA is kept at its
foot as the fallback. It ran in 7.5 s, the five class names answered true again, and no obsolete
class was left in `Smalltalk globals`. Then the two globals the window had used to pin live faces
and hold the manager were dropped and `VGFontManager uninstallGlobally` left upstream's slot nil,
which is the state of an image that never met this project.

Re-run after the reload: `VectorGraphics-TrueType-Tests` 225 of 225, `VectorGraphics-Bloc-Tests` 100
of 100, `VGArchitectureTest` 48 of 48, `VGCairoTextTest` 36 of 36, `VGConformanceTest` 15 of 15 in
36 s, the sixteen other `VectorGraphics-Cairo-Tests` classes green, `VGCairoExamplesTest` 6 of 6,
and Alexandrie's `-FreeType-Tests`, `-CairoFreetype-Tests`, `-FontManager-Tests`, `-Canvas-Tests`,
`-Blur-Tests`, `-Base-Tests`, `-NewTools-Tests`, `-Harfbuzz-Tests` and `-Cairo-Tests` all green. Two figures to keep: `VGCairoExamplesTest`
takes 7 minutes 44 (171 s for `testEveryExampleRebuildsItsObject` alone) and has to be forked with
its result written to a file, because the mesh examples are slow and no MCP call survives it; the
abstract `AePixelMatchTest` answers `subclassResponsibility` when a suite is built from the class
itself, before and after, which is not a regression.

**The image went down** on the first suite started after the reload,
`Alexandrie-Harfbuzz-Tests`, and the dump names the cause exactly: `SIGSEGV` in
`libfreetype FT_Done_Face`, reached from `hb_font_destroy`, `hb_face_destroy` and
`hb_blob_destroy`, in the **finalisation process**, running `FFIExternalResourceExecutor >>
finalize` on an object whose class prints blank in the dump — an obsolete class. So the precaution
this unit took was the right kind and the wrong set: every live `AeFTFace` and `AeFTLibrary` was
pinned in a global so nothing of FreeType's own would finalise during the window, but the Harfbuzz
objects that hold a blob of a FreeType face were not, and the fatal collection came *after* the
reload, when the executors of the obsolete classes were finally mourned and freed a face that no
longer existed. The lesson for any later unload is that the finalisation registry, not the class
table, decides what a package removal can still kill, and that the dangerous moment is the first
garbage collection after the reload.

Nothing was lost — no code had been compiled since the save — but the image came back from a
snapshot taken *during* the window, with the four packages still out and the two globals still
there, so the reload was run a second time on the restarted image: 8.7 s, the five class names true
again, no obsolete class left in `Smalltalk globals`. Iceberg then needed one correction of its own,
the shape the project note on a crash describes: `VectorGraphics-Conformance` read as modified while
`diffToReferenceCommit` was empty, the working copy was attached and its reference commit was the
head, and `adoptCommit:` did not clear the flag — `IcePackage >> beClean` did. The package was
compared with the checkout method by method first, 245 either side, which is what made clearing it
safe rather than hopeful.

The two suites that had not been reached were then run on that image, each forked with its result
written to a file, after the commit: `Alexandrie-Harfbuzz-Tests` 46 of 46, and
`Alexandrie-Cairo-Tests` 149 of 149 over its eighteen classes — including the four `testFormSelector`
errors the baseline carried, which this image does not reproduce.

**What the unit proves.** Bloc draws text through Cairo with the two FreeType packages of Alexandrie
out of the image: the glyphs are read, scaled and shaped by this project from an sfnt file on disk.
What it does not prove, and what unit 7 therefore owes: `VGFontManager installGlobally` still needs
the embedded font bytes of `Alexandrie-FreeType`, and shaping still needs an `Integer` extension
packaged there. No class, test or production method was written for this unit, by the decision taken
at the interview: the artefacts are the three scripts, the PNG, and this write-up.

### 7 — review and write-up — done

The code unit closed with `e5c09d5`, and this section is what the project rule asks for after it: a
design review of the production code the phase touched, the mutation figures that review asked for,
and the corrections this work owes the other plan documents.

**The diagnosis.** Six points, each named against a class or a method, each with the refactoring that
answers it.

- `VGFontManager >> defaultFaceOfFamilyNamed:` lost its last sender in unit 7 — dead code, Remove
  Method.
- `TTFontCatalogue >> refusedEntries` spelled as a refusal what `drawableEntries` and
  `TTFontMetadataReader` call a rejection: one idea, two words — Rename Method.
- `VGCanvas class >> inspectionOfSurface:` and `VGFontManager >> inspectionFaces:` read as names
  describing the implementation rather than the intention — Rename Method, and cancelled below.
- `VGScaledFont >> glyphsOf:size:` and `VGCairoContext >> glyphsOf:size:` held the same unwrapping of
  an opaque glyph array twice — Extract Method, onto the class that owns a glyph.
- `VGScaledFont >> glyphExtentsOf:` mixed two levels of abstraction, merging the inked boxes of a run
  inside the method that converts the merged box to text extents — Extract Method.
- `TTFontCatalogueEntry >> styleKey` carried a domain concept — slant, weight class, width class — as
  a three element array, read in five places and printed as `#(#normal 400 5)`: primitive obsession,
  Extract Class.

**What was executed**, one refactoring at a time with the suite re-run and committed at each green
step. `6dba43a` removes the dead method. `fab04ab` renames `refusedEntries` to `rejectedEntries`
through `ReRenameMethodRefactoring`, which rewrote the seven senders — the MCP `method_rename` tool
does not, and `RBRenameMethodRefactoring` does not exist in this image. `e283395` takes the old word
out of the two prose references left behind, a class comment and a test comment. `ff3be09` moves the
unwrapping to `VGGlyph class >> glyphsOf:size:`, which asks for `#asExternalStructure` rather than
for a class name and so keeps the package free of Alexandrie's names; both canvases now delegate to
it. `7bec0e3` extracts `VGScaledFont >> inkedBoxOfRun:`, which answers nil when nothing in the run is
inked, so `glyphExtentsOf:` reads as the two steps it is.

`5c77e1e` is the Extract Class. `TTFontStyle` holds the three facts a font states about its face,
answers `plainest` from the reader's own `normalWeightClass` and `normalWidthClass` constants, is a
value — `=`, `hash`, `printOn:` as `TTFontStyle(italic 700 3)` — and knows `isPlainest`. It has the
five artefacts the cycle asks for: `TTFontStyleTest` with five tests, the class-side example
`TrueTypeExamples class >> styleOfTheBoldestFaceOfThisMachine`, and `inspectorStyle:` with its gate,
which reads its rows off the class's own instance variables so that a fact added to the class shows
in the view without the view being touched. `TTFontMetadata >> style` builds one,
`TTFontCatalogueEntry >> styleKey` became `style`, and `entryOfFamilyNamed:styleKey:ifNone:` became
`entryOfFamilyNamed:style:ifNone:`. `VGFontManager >> styleForSlant:weight:stretch:` holds the three
translations from Alexandrie's category objects, and
`entryForFamilyName:slant:weight:stretch:ifNone:` keeps its five arguments on purpose: it mirrors
`AeFontManager >> detectFamilyName:slant:weight:stretch:ifNone:`, so the `ReExcessiveArgumentsRule`
it carries is untouchable, like the six arguments of `VGCairoContext` that mirror Cairo's own C API.
No three argument `entryForFamilyName:style:ifNone:` was added, because nothing would send it today.

That last refactoring forced five tests to change, which the rule says to stop and report rather than
absorb: they pinned the array representation rather than the behaviour, and each now states a
`TTFontStyle`. The rewrite was validated before anything was edited.

**P3 was cancelled on evidence.** `inspectionOfSurface:` and `inspectionFaces:` are overrides of
`AeCanvas` and `AeFontManager` selectors, so a rename would not improve a name — it would restore
upstream's tab beside ours in the inspector. Both comments already say so, and nothing was changed.

**The mutation figures.** MuTalk 3.0.8 through the baseline's `dev` group, two runs forked at
priority 46 against a clean checkout, each writing its result beside the image.

Run A replays unit 5.2's reference exactly — `VGFontCanvas` and `VGFontFace` alone, with the same
nine test classes: **score 36, 1495 mutants, 549 killed, 946 alive, 5 min 00 s**, against 5.2's score
34, 1599 mutants, 547 killed, 1052 alive, 15 min 32 s. The score did not drop. The mutant count
differs because units 5.3, 5.4 and 6 changed both classes after that run, and the run is three times
faster, which nothing here measures the cause of. The alive mutants sit where 5.2 said they would:
`readComponentWithFlags:` 163, `readBytes:` 125, `refuseIfATableIsMissingFrom:` 119, then the
inspector views and `printOn:`. That is still the phase 2 coverage defect to raise before phase 8
touches the same reader for CFF.

Run B measures the six classes the refactorings touched — `TTFontStyle`, `TTFontCatalogue`,
`TTFontCatalogueEntry`, `TTFontMetadata`, `VGScaledFont` and `VGGlyph` — with the eight test classes
that name them: **score 48, 1801 mutants, 869 killed, 932 alive, 1 min 35 s**. There is no before to
hold it against, because 5.2's reference covered the other pair of classes, so this figure is the
baseline the next refactor of these classes is held to. The alive mutants are again the inspector
views, `printOn:` and one outlier, `TTFontCatalogueEntry >> signalRefusal:` with 138 — a message
string built for a reader, which no test reads word by word. Of `TTFontStyle` itself, 19 alive
mutants are in the view, 4 in `hash`, 4 in the view's gate and 1 in `=`.

After both runs the working copy diff was empty and `isDetached` false, so no production method was
left mutated.

**Two constats this review recorded, neither a defect of this phase.** Section 6 filed both as owed
to this unit; here is what each one is, exactly.

The suite still needs `Alexandrie-FreeType` in the image, and will keep needing it: the fixtures of
`TTFontMetadataReaderTest`, the manager tests that assert no FreeType library is owned and no
FreeType face is built, the example `VGFontManagerExamples class >> managerWithoutALibrary`, and
`VGAlexandrieFontLifetime`, which documents the handle lifetime of the stack phase 6 unloads. A gate
that asserts the absence of a thing has to be able to name it.

`Integer >> from26Dot6FractionalPoint` is implemented in `Alexandrie-FreeType` and sent only from
`Alexandrie-Harfbuzz`: `AeHbFont >> positionWithFallback:` and the four conversions of
`AeHbGlyphPosition`. Shaping stays Alexandrie's, and `TTFontCatalogueEntry >> shapingRowsAtSize:`
reaches those conversions through `AeHbBuffer >> cairoGlyphArray`, so an image that loads HarfBuzz
without FreeType dies in a `doesNotUnderstand:` on a pure arithmetic conversion. That is an upstream
packaging defect, and it is what keeps `Alexandrie-FreeType` loaded in an image that draws text with
none of it.

**Carried, and not fixed here.** `ReClassNotCategorizedRule` on several classes of the phase.
`VGFontFace` carries `ReExcessiveVariablesRule` for its thirteen tables and
`readComponentWithFlags:` is 32 lines; `TTFontMetadata >> inspectorIdentity:` carries
`ReCyclomaticComplexityRule`; `TrueTypeFont >> glyphAtUtf8Byte1:` and
`FontFamily class >> defaultLineSpacing` are upstream shapes we only extend. `VGFontFace` still mixes
sfnt generic state with `glyf` specific state, which is the seam section 8 will press on: it is not
split now, because the first red of CFF is what should drive the split rather than a guess made
before it.

Two names still carry the old word after `fab04ab`: `TTFontCatalogue >> inspectorRefusals:` and
`TTFontCatalogueEntry >> signalRefusal:`. Extending the rename to them was left outside the validated
scope of this review.

**Where the suite stands.** `VectorGraphics-TrueType-Tests` is 231 and green, six of them written
here — the five of `TTFontStyleTest` and the metadata test for `style`; the two extractions added
none, because the tests that existed already covered the methods they moved.
`VectorGraphics-Bloc-Tests` is 103; `VGCairoTextTest` 36, `VGCanvasTest` 15,
`VGTrueTypeExamplesTest` 10, `VGArchitectureTest` 49. Critics are clean on everything written here,
with the two `VGFontManager` excessive arguments hits and `TTFontMetadata >> inspectorIdentity:`
carried as above.

### 8 — CFF, after FreeType is gone

Decision 14's second half, and the phase that closes the format gap: 101 `otf` files against 362
`ttf` on this machine, and with them Cantarell, Cascadia Code, STIX, URW Base35 and the CJK faces.

What it needs, and nothing more: the CFF header, `INDEX` and `DICT` structures, the charstrings
`INDEX`, the private dictionaries and subroutine indexes, and a Type 2 charstring interpreter
answering the same contours `TTGlyfTableParser` answers for `glyf`.
`CFF2` and the variable-font axes stay out.

It lands behind the same seam as the rest: the metadata reader stops refusing a face whose outlines
live in `CFF`, and the face answers contours from the CFF interpreter instead of from `glyf`.
Nothing above the face changes — not the catalogue, not the manager, not the context, not the masks.
That is the test of the seam this plan builds, and the reason CFF is cheap to add afterwards and
expensive to add first.

Red, first test of the phase: a `.otf` face answers the contours of one glyph, and the metadata
reader no longer records a rejection for it.

## 6. First failing test

`TTFontMetadataReaderTest >> testFamilyAndStyleOfAFont`: the reader answers `'Source Sans Pro'`
and `'Regular'` for sfnt bytes the test builds itself, with no `glyf` table read.
