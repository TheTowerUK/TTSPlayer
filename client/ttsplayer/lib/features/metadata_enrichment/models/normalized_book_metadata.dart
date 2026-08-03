import 'provider_attribution.dart';

/// Provider-neutral normalized book metadata (M7.2).
///
/// Does not retain raw provider JSON, cover bytes, ratings, or purchase links.
/// [coverArtworkId] is a stable provider image identifier only — never a URL.
class NormalizedBookMetadata {
  const NormalizedBookMetadata({
    required this.providerId,
    required this.providerRecordId,
    required this.canonicalTitle,
    required this.fetchedAt,
    this.editionId,
    this.workId,
    this.subtitle,
    this.authors = const [],
    this.description,
    this.publishers = const [],
    this.publicationDate,
    this.publicationYear,
    this.languages = const [],
    this.subjects = const [],
    this.isbn10Values = const [],
    this.isbn13Values = const [],
    this.recordUrl,
    this.coverArtworkId,
    this.attribution,
  });

  final String providerId;
  final String providerRecordId;
  final String? editionId;
  final String? workId;
  final String canonicalTitle;
  final String? subtitle;
  final List<String> authors;
  final String? description;
  final List<String> publishers;
  final String? publicationDate;
  final int? publicationYear;
  final List<String> languages;
  final List<String> subjects;
  final List<String> isbn10Values;
  final List<String> isbn13Values;
  final String? recordUrl;
  final String? coverArtworkId;
  final DateTime fetchedAt;
  final ProviderAttribution? attribution;

  bool get hasExactIsbnMatch =>
      isbn10Values.isNotEmpty || isbn13Values.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is NormalizedBookMetadata &&
        other.providerId == providerId &&
        other.providerRecordId == providerRecordId &&
        other.editionId == editionId &&
        other.workId == workId &&
        other.canonicalTitle == canonicalTitle &&
        other.subtitle == subtitle &&
        _listEquals(other.authors, authors) &&
        other.description == description &&
        _listEquals(other.publishers, publishers) &&
        other.publicationDate == publicationDate &&
        other.publicationYear == publicationYear &&
        _listEquals(other.languages, languages) &&
        _listEquals(other.subjects, subjects) &&
        _listEquals(other.isbn10Values, isbn10Values) &&
        _listEquals(other.isbn13Values, isbn13Values) &&
        other.recordUrl == recordUrl &&
        other.coverArtworkId == coverArtworkId &&
        other.fetchedAt == fetchedAt &&
        other.attribution == attribution;
  }

  @override
  int get hashCode => Object.hashAll([
        providerId,
        providerRecordId,
        editionId,
        workId,
        canonicalTitle,
        subtitle,
        Object.hashAll(authors),
        description,
        Object.hashAll(publishers),
        publicationDate,
        publicationYear,
        Object.hashAll(languages),
        Object.hashAll(subjects),
        Object.hashAll(isbn10Values),
        Object.hashAll(isbn13Values),
        recordUrl,
        coverArtworkId,
        fetchedAt,
        attribution,
      ]);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
