import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/book_candidate_ranker.dart';

import 'support/book_match_test_support.dart';

void main() {
  group('BookCandidateRanker', () {
    test('ranks by score descending regardless of input order', () {
      final low = matchCandidate(recordId: 'low', title: 'Other Book');
      final high = matchCandidate(
        recordId: 'high',
        title: 'The Republic',
        authors: ['Plato'],
        year: 2007,
      );
      final ranked = BookCandidateRanker.rank(
        candidates: [low, high],
        finalScores: {
          low: 0.2,
          high: 0.75,
        },
        identifierMatches: {
          low: false,
          high: false,
        },
      );
      expect(ranked.first.metadata.providerRecordId, 'high');
    });

    test('uses identifier flag as first tie-break', () {
      final a = matchCandidate(recordId: 'a', title: 'Title');
      final b = matchCandidate(recordId: 'b', title: 'Title');
      final ranked = BookCandidateRanker.rank(
        candidates: [a, b],
        finalScores: {a: 0.75, b: 0.75},
        identifierMatches: {a: false, b: true},
      );
      expect(ranked.first.metadata.providerRecordId, 'b');
    });

    test('uses provider hint then record id for stable tie-breaks', () {
      final a = matchCandidate(recordId: 'b-record', title: 'Title', relevanceScore: 0.2);
      final b = matchCandidate(recordId: 'a-record', title: 'Title', relevanceScore: 0.8);
      final ranked = BookCandidateRanker.rank(
        candidates: [a, b],
        finalScores: {a: 0.75, b: 0.75},
        identifierMatches: {a: false, b: false},
      );
      expect(ranked.first.metadata.providerRecordId, 'a-record');
    });

    test('repeated runs produce identical order', () {
      final candidates = [
        matchCandidate(recordId: 'c', title: 'Title C', relevanceScore: 0.5),
        matchCandidate(recordId: 'a', title: 'Title A', relevanceScore: 0.5),
        matchCandidate(recordId: 'b', title: 'Title B', relevanceScore: 0.5),
      ];
      final scores = {for (final c in candidates) c: 0.75};
      final ids = {for (final c in candidates) c: false};

      final first = BookCandidateRanker.rank(
        candidates: candidates,
        finalScores: scores,
        identifierMatches: ids,
      );
      final second = BookCandidateRanker.rank(
        candidates: candidates.reversed.toList(),
        finalScores: scores,
        identifierMatches: ids,
      );

      expect(
        first.map((c) => c.metadata.providerRecordId).toList(),
        second.map((c) => c.metadata.providerRecordId).toList(),
      );
    });
  });
}
