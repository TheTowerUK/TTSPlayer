import 'package:ttsplayer/features/metadata_enrichment/matching/local_book_match_input.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/normalized_book_metadata.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_book_candidate.dart';

ProviderBookCandidate matchCandidate({
  required String recordId,
  String title = 'Sample Title',
  String? subtitle,
  List<String> authors = const ['Sample Author'],
  int? year,
  List<String> isbn10 = const [],
  List<String> isbn13 = const [],
  List<String> publishers = const [],
  List<String> languages = const [],
  double? relevanceScore,
  bool exactIdentifierMatch = false,
}) {
  return ProviderBookCandidate(
    metadata: NormalizedBookMetadata(
      providerId: 'test_provider',
      providerRecordId: recordId,
      canonicalTitle: title,
      subtitle: subtitle,
      authors: authors,
      publicationYear: year,
      isbn10Values: isbn10,
      isbn13Values: isbn13,
      publishers: publishers,
      languages: languages,
      fetchedAt: DateTime.utc(2026, 7, 30),
    ),
    relevanceScore: relevanceScore,
    exactIdentifierMatch: exactIdentifierMatch,
  );
}

LocalBookMatchInput localInput({
  String itemId = 'item-1',
  String? title,
  String? subtitle,
  List<String> authors = const [],
  int? year,
  String? publisher,
  String? language,
  List<String> isbn10 = const [],
  List<String> isbn13 = const [],
  String? filenameStem,
  String? volume,
  List<String> editionMarkers = const [],
}) {
  return LocalBookMatchInput(
    itemId: itemId,
    title: title,
    subtitle: subtitle,
    authors: authors,
    publicationYear: year,
    publisher: publisher,
    language: language,
    isbn10Values: isbn10,
    isbn13Values: isbn13,
    filenameStem: filenameStem,
    volume: volume,
    editionMarkers: editionMarkers,
  );
}
