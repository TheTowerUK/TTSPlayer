import '../models/normalized_book_metadata.dart';
import '../models/provider_book_candidate.dart';
import 'book_match_normalizer.dart';

/// Deterministic candidate ranking independent of provider API order (M7.3.1).
class BookCandidateRanker {
  BookCandidateRanker._();

  static const _scoreTolerance = 1e-9;

  static List<ProviderBookCandidate> rank({
    required List<ProviderBookCandidate> candidates,
    required Map<ProviderBookCandidate, double> finalScores,
    required Map<ProviderBookCandidate, bool> identifierMatches,
  }) {
    final sorted = List<ProviderBookCandidate>.from(candidates);
    sorted.sort((a, b) => compareCandidates(
          a,
          b,
          finalScores: finalScores,
          identifierMatches: identifierMatches,
        ));
    return sorted;
  }

  static int compareCandidates(
    ProviderBookCandidate a,
    ProviderBookCandidate b, {
    required Map<ProviderBookCandidate, double> finalScores,
    required Map<ProviderBookCandidate, bool> identifierMatches,
  }) {
    final scoreA = finalScores[a] ?? 0.0;
    final scoreB = finalScores[b] ?? 0.0;
    final scoreCompare = scoreB.compareTo(scoreA);
    if (scoreCompare.abs() > _scoreTolerance) {
      return scoreCompare;
    }

    final idA = identifierMatches[a] ?? false;
    final idB = identifierMatches[b] ?? false;
    if (idA != idB) {
      return idB ? 1 : -1;
    }

    final hintA = _normalizedProviderHint(a.relevanceScore);
    final hintB = _normalizedProviderHint(b.relevanceScore);
    final hintCompare = hintB.compareTo(hintA);
    if (hintCompare != 0) {
      return hintCompare;
    }

    final recordA = a.metadata.providerRecordId;
    final recordB = b.metadata.providerRecordId;
    final recordCompare = recordA.compareTo(recordB);
    if (recordCompare != 0) {
      return recordCompare;
    }

    return _stableIdentityKey(a.metadata).compareTo(_stableIdentityKey(b.metadata));
  }

  static double _normalizedProviderHint(double? relevanceScore) {
    if (relevanceScore == null || relevanceScore.isNaN) {
      return 0.0;
    }
    if (relevanceScore < 0.0) {
      return 0.0;
    }
    if (relevanceScore > 1.0) {
      return 1.0;
    }
    return relevanceScore;
  }

  static String _stableIdentityKey(NormalizedBookMetadata metadata) {
    final title = BookMatchNormalizer.normalizeComparableTokens(
      metadata.canonicalTitle,
    );
    final authors = metadata.authors
        .map(BookMatchNormalizer.normalizeComparableTokens)
        .where((value) => value.isNotEmpty)
        .toList()
      ..sort();
    final year = metadata.publicationYear?.toString() ?? '';
    return '$title|${authors.join(';')}|$year|${metadata.providerId}';
  }
}
