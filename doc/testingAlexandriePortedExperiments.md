❯ how can I try the various drawing example from BookletGraphics >> AlexandrieCairoExperiment clas with the new VGAlexandrie ?

  Called pharo 13 times (ctrl+o to expand)

● Three ways, cheapest first.

  1. One drawing, ours only. Each experiment is ported one-to-one to a class-side method of the same name:

  VGAlexandriePortedExperiments meshPattern inspect.
  VGAlexandriePortedExperiments ContextPathWithArcCircle asMorph openInWindow.

  82 selectors there, same names as AlexandrieCairoExperiment class. VGAlexandrieCorpus experimentSelectors lists them.

  2. One drawing, ours against Cairo, with the verdict. This is the real harness:

  | case |
  case := VGAlexandrieCase for: #meshPattern.
  case ourForm.              "drawn by VectorGraphics"
  case cairoForm.            "drawn live by Alexandrie"
  case matchesCairo.         "true"
  case comparisonWithCairo inspect   "VGFormComparison: five views, incl. the channel-distance tally"

  case tolerance = 8, case boundaryPixelAllowance = 18 for that one.

  3. Whole corpus. VGAlexandrieCorpus inspect → Progress tab; VGAlexandrieCorpus cases is 82 VGAlexandrieCase, each with Blocking and
  Classes tabs. Examples under VGAlexandrieCorpusExamples: corpus, casesWaitingOnAUnit, oneCaseWaitingOnAUnit.

  Caveats:

  - 77 of 82 draw. 5 still blocked, all on font classes with no port: fillPaint1, fillPaint2, texWithHarfbuzzWithFontManager,
    textAllGlyphsInFontFace, textWithoutHarfbuzzWithFontManager — missing AeCairoFontOptions, AeCairoFreetypeFontFace, AeCairoScaledFont
    (plus the hint/antialias enums). blockingUnit says 1.10 for all five, and 1.10 is marked done, so either those classes are owed by a
    later unit or the table attribution is wrong. Same staleness as the AeCairoAntialias / 1.4 entry already on the punch list.
  - getNumberOfGlyph answers a number, not a picture (nonPictureSelectors).
  - Add or edit an experiment in AlexandrieCairoExperiment → VGAlexandrieCorpus regenerate re-ports the source. VGAlexandrieCorpus
    driftingCases is 0 now, so the ported copies match.
  - Mesh cases are slow: ~4 s each, 17 s for CanonicalGradientAllQuadrantPattern. ourForm is not memoised, so each send redraws.


