/// Bounded local comparison inputs for book candidate evaluation (M7.3.1).
///
/// Correlation-only [itemId]; never transmitted to providers or persisted by
/// the evaluator.
class LocalBookMatchInput {
  const LocalBookMatchInput({
    required this.itemId,
    this.title,
    this.subtitle,
    this.authors = const [],
    this.publicationYear,
    this.publisher,
    this.language,
    this.isbn10Values = const [],
    this.isbn13Values = const [],
    this.series,
    this.volume,
    this.editionMarkers = const [],
    this.filenameStem,
  });

  final String itemId;
  final String? title;
  final String? subtitle;
  final List<String> authors;
  final int? publicationYear;
  final String? publisher;
  final String? language;

  /// Caller-supplied **trusted** local ISBN-10 values for comparison only.
  ///
  /// The matching engine validates format/checksum but does not decide whether
  /// an identifier is catalogue- or user-trusted. Phase 7.3.2 must populate
  /// these fields only after trust is established (explicit user entry or
  /// approved sidecar policy).
  final List<String> isbn10Values;

  /// Caller-supplied **trusted** local ISBN-13 values — same trust boundary as
  /// [isbn10Values].
  final List<String> isbn13Values;
  final String? series;
  final String? volume;
  final List<String> editionMarkers;
  final String? filenameStem;

  bool get hasTrustedIsbn =>
      isbn10Values.isNotEmpty || isbn13Values.isNotEmpty;

  bool get hasUsableTitle =>
      (title?.trim().isNotEmpty ?? false) ||
      (filenameStem?.trim().isNotEmpty ?? false);

  bool get hasUsableAuthor =>
      authors.any((author) => author.trim().isNotEmpty);

  LocalBookMatchInput copyWith({
    String? itemId,
    String? title,
    String? subtitle,
    List<String>? authors,
    int? publicationYear,
    String? publisher,
    String? language,
    List<String>? isbn10Values,
    List<String>? isbn13Values,
    String? series,
    String? volume,
    List<String>? editionMarkers,
    String? filenameStem,
  }) {
    return LocalBookMatchInput(
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      authors: authors ?? this.authors,
      publicationYear: publicationYear ?? this.publicationYear,
      publisher: publisher ?? this.publisher,
      language: language ?? this.language,
      isbn10Values: isbn10Values ?? this.isbn10Values,
      isbn13Values: isbn13Values ?? this.isbn13Values,
      series: series ?? this.series,
      volume: volume ?? this.volume,
      editionMarkers: editionMarkers ?? this.editionMarkers,
      filenameStem: filenameStem ?? this.filenameStem,
    );
  }
}
