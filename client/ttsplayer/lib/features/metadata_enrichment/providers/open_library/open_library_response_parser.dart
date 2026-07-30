import '../../models/normalized_book_metadata.dart';
import '../../models/provider_attribution.dart';
import '../../models/provider_book_candidate.dart';

/// Parses Open Library JSON responses into provider-neutral models (M7.2).
class OpenLibraryResponseParser {
  const OpenLibraryResponseParser({
    this.providerId = 'open_library',
    this.attribution = const ProviderAttribution(
      providerId: 'open_library',
      displayName: 'Open Library',
      homepageUrl: 'https://openlibrary.org',
      attributionText: 'Metadata courtesy of Open Library',
      attributionRequired: false,
    ),
  });

  final String providerId;
  final ProviderAttribution attribution;

  /// Parses a Books API response keyed by `ISBN:<value>`.
  NormalizedBookMetadata? parseBooksApiResponse(
    Map<String, dynamic> json,
    String lookupIsbn, {
    required DateTime fetchedAt,
  }) {
    final key = 'ISBN:$lookupIsbn';
    final edition = json[key];
    if (edition == null) return null;
    if (edition is! Map) return null;
    return _parseEditionMap(
      Map<String, dynamic>.from(edition),
      fetchedAt: fetchedAt,
    );
  }

  /// Parses a Search API `docs` array into candidates.
  List<ProviderBookCandidate> parseSearchResponse(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
    int? requestedLimit,
  }) {
    final docs = json['docs'];
    if (docs is! List) return const [];

    final candidates = <ProviderBookCandidate>[];
    for (final doc in docs) {
      if (doc is! Map) continue;
      final metadata = _parseSearchDoc(
        Map<String, dynamic>.from(doc),
        fetchedAt: fetchedAt,
      );
      if (metadata == null) continue;
      candidates.add(
        ProviderBookCandidate(
          metadata: metadata,
          relevanceScore: _readDouble(doc['score']),
          exactIdentifierMatch: _hasIsbn(metadata),
        ),
      );
    }

    final deduped = _dedupeCandidates(candidates);
    if (requestedLimit != null && deduped.length > requestedLimit) {
      return deduped.sublist(0, requestedLimit);
    }
    return deduped;
  }

  List<ProviderBookCandidate> _dedupeCandidates(
    List<ProviderBookCandidate> candidates,
  ) {
    final byKey = <String, ProviderBookCandidate>{};
    for (final candidate in candidates) {
      final key = _dedupeKey(candidate.metadata);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = candidate;
        continue;
      }
      if (_candidateRank(candidate) > _candidateRank(existing)) {
        byKey[key] = candidate;
      }
    }

    final sorted = byKey.values.toList()
      ..sort((a, b) {
        final scoreA = a.relevanceScore ?? 0;
        final scoreB = b.relevanceScore ?? 0;
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) return scoreCompare;
        return a.metadata.providerRecordId.compareTo(b.metadata.providerRecordId);
      });
    return sorted;
  }

  /// Deduplication key preference:
  /// 1. edition key
  /// 2. work key + title + first author + year
  String _dedupeKey(NormalizedBookMetadata metadata) {
    if (metadata.editionId != null && metadata.editionId!.isNotEmpty) {
      return 'edition:${metadata.editionId}';
    }
    final author = metadata.authors.isEmpty ? '' : metadata.authors.first;
    final year = metadata.publicationYear?.toString() ?? '';
    return 'work:${metadata.workId ?? metadata.providerRecordId}:'
        '${metadata.canonicalTitle}:$author:$year';
  }

  int _candidateRank(ProviderBookCandidate candidate) {
    var rank = 0;
    if (candidate.exactIdentifierMatch) rank += 100;
    if (candidate.metadata.editionId != null) rank += 10;
    if (candidate.metadata.workId != null) rank += 5;
    if (candidate.metadata.authors.isNotEmpty) rank += 1;
    return rank;
  }

  NormalizedBookMetadata? _parseEditionMap(
    Map<String, dynamic> edition, {
    required DateTime fetchedAt,
  }) {
    final title = _readString(edition['title']);
    if (title == null) return null;

    final editionKey = _readString(edition['key']);
    final workKey = _extractWorkKey(edition['works']);
    final providerRecordId = editionKey ?? workKey ?? title;

    return NormalizedBookMetadata(
      providerId: providerId,
      providerRecordId: providerRecordId,
      editionId: editionKey,
      workId: workKey,
      canonicalTitle: title,
      subtitle: _readString(edition['subtitle']),
      authors: _readAuthorNames(edition['authors']),
      description: _readDescription(edition['description']),
      publishers: _readStringList(edition['publishers']),
      publicationDate: _readString(edition['publish_date']),
      publicationYear: _readInt(edition['publish_year']) ??
          _yearFromDate(_readString(edition['publish_date'])),
      languages: _readLanguageKeys(edition['languages']),
      subjects: _readStringList(edition['subjects']),
      isbn10Values: _readIsbnList(edition['identifiers']?['isbn_10']),
      isbn13Values: _readIsbnList(edition['identifiers']?['isbn_13']),
      recordUrl: editionKey == null
          ? null
          : 'https://openlibrary.org$editionKey',
      fetchedAt: fetchedAt,
      attribution: attribution,
    );
  }

  NormalizedBookMetadata? _parseSearchDoc(
    Map<String, dynamic> doc, {
    required DateTime fetchedAt,
  }) {
    final title = _readString(doc['title']);
    if (title == null) return null;

    final editionKey = _readStringFromList(doc['edition_key']);
    final workKey = _readString(doc['key']) ??
        _readStringFromList(doc['seed']);
    final providerRecordId = editionKey ?? workKey ?? title;

    final isbn = _readStringList(doc['isbn']);
    final isbn10 = <String>[];
    final isbn13 = <String>[];
    for (final value in isbn) {
      if (value.length == 10) {
        isbn10.add(value);
      } else if (value.length == 13) {
        isbn13.add(value);
      }
    }

    return NormalizedBookMetadata(
      providerId: providerId,
      providerRecordId: providerRecordId,
      editionId: editionKey,
      workId: workKey,
      canonicalTitle: title,
      subtitle: _readString(doc['subtitle']),
      authors: _readStringList(doc['author_name']),
      description: null,
      publishers: _readStringList(doc['publisher']),
      publicationDate: null,
      publicationYear: _readInt(doc['first_publish_year']) ??
          _readInt(doc['publish_year']),
      languages: _readStringList(doc['language']),
      subjects: _readStringList(doc['subject']),
      isbn10Values: isbn10,
      isbn13Values: isbn13,
      recordUrl: editionKey != null
          ? 'https://openlibrary.org/books/$editionKey'
          : workKey != null
              ? 'https://openlibrary.org$workKey'
              : null,
      fetchedAt: fetchedAt,
      attribution: attribution,
    );
  }

  String? _extractWorkKey(dynamic works) {
    if (works is! List || works.isEmpty) return null;
    final first = works.first;
    if (first is Map) {
      return _readString(first['key']);
    }
    if (first is String) return first;
    return null;
  }

  String? _readDescription(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      return _readDescription(value['value']);
    }
    return null;
  }

  List<String> _readAuthorNames(dynamic value) {
    if (value is! List) return const [];
    final names = <String>[];
    for (final entry in value) {
      if (entry is Map) {
        final name = _readString(entry['name']);
        if (name != null) names.add(name);
      } else if (entry is String && entry.trim().isNotEmpty) {
        names.add(entry.trim());
      }
    }
    return names;
  }

  List<String> _readLanguageKeys(dynamic value) {
    if (value is! List) return const [];
    final languages = <String>[];
    for (final entry in value) {
      if (entry is Map) {
        final key = _readString(entry['key']);
        if (key != null) languages.add(key.replaceFirst('/languages/', ''));
      } else if (entry is String && entry.trim().isNotEmpty) {
        languages.add(entry.trim().replaceFirst('/languages/', ''));
      }
    }
    return languages;
  }

  List<String> _readIsbnList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(_readString)
        .whereType<String>()
        .toList(growable: false);
  }

  String? _readStringFromList(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    return _readString(value.first);
  }

  String? _readString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int? _yearFromDate(String? date) {
    if (date == null) return null;
    final match = RegExp(r'(\d{4})').firstMatch(date);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  bool _hasIsbn(NormalizedBookMetadata metadata) =>
      metadata.isbn10Values.isNotEmpty || metadata.isbn13Values.isNotEmpty;
}
