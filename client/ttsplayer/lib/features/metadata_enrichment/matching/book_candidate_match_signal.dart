/// Stable signal identifiers for explainable candidate evaluation (M7.3.1).
enum BookCandidateMatchSignalKind {
  titleExact('title_exact', 0.35, false, false),
  titleMainExact('title_main_exact', 0.28, false, false),
  titleStrong('title_strong', 0.22, false, false),
  titlePartial('title_partial', 0.12, false, false),
  titleFilename('filename_fallback', 0.06, false, false),
  subtitleAgree('subtitle_agreement', 0.05, false, false),
  authorPrimaryExact('author_primary_exact', 0.30, false, false),
  authorAnyExact('author_any_exact', 0.20, false, false),
  authorSurname('author_surname', 0.12, false, false),
  yearExact('year_exact', 0.10, false, false),
  yearNear('year_near', 0.07, false, false),
  yearLoose('year_loose', 0.04, false, false),
  publisherAgree('publisher_agreement', 0.05, false, false),
  languageAgree('language_agreement', 0.03, false, false),
  isbnConflict('isbn_conflict', 0.0, true, true),
  authorConflict('author_conflict', -0.25, true, false),
  volumeConflict('volume_conflict', -0.15, true, false),
  editionConflict('edition_conflict', -0.10, true, false),
  formatVariant('format_variant', -0.20, true, false),
  abridgedConflict('abridged_conflict', -0.15, true, false),
  largeYearGap('large_year_gap', -0.15, true, false),
  languageConflict('language_conflict', -0.10, true, false);

  const BookCandidateMatchSignalKind(
    this.id,
    this.defaultContribution,
    this.isPenalty,
    this.disqualifiesAutoLink,
  );

  final String id;
  final double defaultContribution;
  final bool isPenalty;
  final bool disqualifiesAutoLink;
}

/// One weighted or penalty signal contributing to an evaluation.
class BookCandidateMatchSignal {
  const BookCandidateMatchSignal({
    required this.kind,
    required this.contribution,
    this.comparedField,
  });

  final BookCandidateMatchSignalKind kind;
  final double contribution;
  final String? comparedField;

  String get explanationId => kind.id;

  bool get isPenalty => kind.isPenalty;

  bool get disqualifiesAutoLink => kind.disqualifiesAutoLink;
}
