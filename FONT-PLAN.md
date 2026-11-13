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
| `VectorGraphics-Bloc` | `VGFontManager`, `VGAeTextContext`, the `newContext` override, `AeFontManager class >> globalInstance:` |

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

### 3.6 — the default families

The six `AeEmbeddedFontFile` subclasses are registered from their bytes, as upstream does, so a
default text has a family with no FreeType in the image.
`VGFontFace class >> defaultBytes` already reads Pharo's own embedded family without an FT call.

Red: `detectFamilyName:slant:weight:stretch:ifNone:` for Source Sans Pro answers one of our faces
in a fresh manager.

### 3.7 — HarfBuzz keeps working

The entries our manager holds are the upstream `AeFileFaceEntry` and `AeMemoryFaceEntry`, so
`newHbFont` keeps answering through `AeHbBlob`, with no FreeType and no change of ours.
This unit is a test, not code: it pins the one service of the chain that must survive the removal
untouched, because Bloc enables HarfBuzz shaping later.

Red: an entry registered by `VGFontManager` answers an `AeHbFont`, that font shapes a run into glyph
identifiers, and `AeFTFace allInstances size` is unchanged across the shaping.

### 4.1 — the context and its substitution

`VGAeTextContext`, a subclass of `AeCairoContext`, plus one extension method redefining
`AeCairoSurface >> newContext` to answer it, with a one-line comment saying why.
Every text selector delegates to `super` when the scaled font it is given is a real
`AeCairoScaledFont`, so an image without our manager behaves exactly as before.

Red: any surface answers a `VGAeTextContext`, and a figure drawn with no text is pixel-identical to
the one the stock context draws.

### 4.2 — glyphs drawn as A8 masks

`scaledFont:` keeps our scaled font, and `showGlyphs:` blits one mask per glyph with
`maskSurface:x:y:`, so the colour comes from the Cairo source as it does for any other mask.
The masks for this route live in externally allocated A8 surfaces owned by the atlas, never in a
`ByteArray` of object memory: the garbage collector may move a `ByteArray` while Cairo holds its
address.

Red, by the criterion of decision 11: the glyph identifiers come from `cmap`, the pen advances match
`hmtx`, and the drawn ink lies inside the run extents.

### 4.3 — extents that Bloc can measure with

`getGlyphExtentsOf:size:into:` fills the `AeCairoTextExtents` that `AeCanvas >> metricsFor:font:`
reads, from our own metrics.

Red: a Bloc paragraph measured through the stock canvas has the width of the sum of our advances.

### 4.4 — text as a path

`appendGlyphsPath:` appends our outlines to the Cairo path, which is what text shadows and
text-as-path drawing need.

Red: the path extents of a run enclose the same box as the mask route reports.

### 4.5 — font extents

`fontExtents` answers ascent, descent and height from `hhea`, with the signs `AeCanvas` expects.

Red: `metricsFor:font:` answers a negated ascent and a positive descent, as upstream does.

### 5.1 — the Bloc route, end to end

A paragraph measured and drawn in an offscreen space by the stock `AeCanvas`, with our manager
installed and no canvas of ours anywhere in the frame.

Red: the scaled font the context received is a `VGScaledFont`, and `AeFTFace allInstances size` is
unchanged across the whole frame.

### 5.2 — the bridge dies

Delete `VGCanvas class >> faceForFreeTypeFace:`, `VGFontFace class >> newForFace:` and
`VGFontFace class >> bytesForFamilyName:styleName:`.
Those three exist only to recover bytes from an `AeFTFace`, which no longer reaches us.
`VGCanvas >> scaledFontForFace:size:` stays, because it also fixes the upstream cache that never
fills.

`VGAlexandrieFontLifetime class >> freeTypeLibrary` and `roleOf:` name `AeFTLibrary`, and they are
ours, in `VectorGraphics-Conformance`: they document the handle lifetime of a stack we no longer
use, so they are guarded on `Smalltalk includesKey: #AeFTLibrary` or deleted with their examples.
Phase 6 cannot run while a class of ours names a class that phase 6 removes.

Red: the two extension methods are gone from `VectorGraphics-Bloc`, no class of our packages names
an `AeFT*` class, and the VG renderer tests still pass.

### 5.3 — a window drawn by Cairo

One `open…` example that is the deliverable: text in a window drawn by the stock renderer, Cairo
compositing every pixel, with our fonts behind it and no FreeType in the image.
A second `open…` on `VGRenderer` is kept as a sibling, because the same faces serve it, but it
proves nothing about this plan.
Commit first and run them alone, per the project rule on window and device runs.

### 5.4 — `FontFamily` takes its families from the catalogue

`FontFamily class >> addFamiliesFrom: aCatalogue` builds one `TrueTypeFontFamily` per family the
catalogue holds, through `baseTTFontDescription:`, and registers it with `addFamily:`.
The description is read lazily, on the first use of a family, because that is the 200 ms parse.
`AvailableFamilies`, `familyNamed:` and `defaultFamilyAndPointSize` keep their protocol, so
`VectorCanvas` and its tests see no change in shape — the dictionary is simply no longer empty by
default.

This is the other half of decision 13: one scan, two registries, two kinds of face —
`TrueTypeFont` in `Form` for `VectorCanvas`, `VGFontFace` in outlines for Cairo and Bloc.
The cost is this one hook, which is code of ours, and a re-read of the `FontFamily` tests: they
assume a registry filled by hand, and the fixtures that add a family themselves must still work
beside a populated catalogue.

Red: after `addFamiliesFrom:` on a catalogue of the embedded files, `FontFamily familyNamed:
'Source Sans Pro'` answers a family, `availableFamilies` holds the catalogue's two families, and a
family added by hand is still found.

### 6 — the proof by absence

The removal is bounded: Morphic's text stack is a different package and a different binding, so the
image keeps running and the only casualties are test suites.
Preconditions all the same, in order: every repository committed, the image saved, and the reload
script written and read back before anything is removed.

1. Unload `Alexandrie-CairoFreetype`, then `Alexandrie-FreeType`.
   Check `Smalltalk includesKey: #AeFTFace` answers false.
2. Run the 5.1 test and open the 5.3 window; write the Form to a file in `Smalltalk imageDirectory`.
3. Reload both packages with Metacello and re-run the Alexandrie suites that use them.

`AeFontManager >> reset` names `AeFTLibrary`, so the upstream manager is broken while the packages
are out; ours is installed, so the route under test is not.
The test packages that name an `AeFT*` class, and so the suites to expect red during that window,
measured in the image: `Alexandrie-Cairo-Tests`, `Alexandrie-Canvas-Tests`,
`Alexandrie-Harfbuzz-Tests`, `Alexandrie-FreeType-Tests`, `Alexandrie-CairoFreetype-Tests`,
`Alexandrie-FontManager-Tests` and `Alexandrie-Blur-Tests`.
All of them pass again after step 3.

### 7 — review and write-up

Design review of the production code touched, by the project rule: diagnose, prioritise with a named
refactoring, guard against over-engineering, present the plan and wait.
MuTalk on the changed classes only, against a clean checkout, with the score compared before and
after the refactor step.
Then update `VECTORCANVAS-PLAN.md` §1.13, which describes the font facade as it was before this
work, and the memory note on the measured cost of the TrueType route.

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
