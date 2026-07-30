import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/book_candidate_evaluator.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/book_candidate_match_decision.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/book_candidate_match_signal.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/isbn_equivalence.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/local_book_match_input.dart';

import 'support/book_match_test_support.dart';

void main() {
  const evaluator = BookCandidateEvaluator();
  const tolerance = 1e-9;

  group('BookCandidateEvaluator title scoring', () {
    test('exact full title contributes one title tier', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(title: 'The Republic', authors: ['Plato']),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Plato'],
        ),
      );
      expect(evaluation.rawScore, closeTo(0.65, tolerance));
      expect(
        evaluation.signals
            .where((signal) => signal.kind == BookCandidateMatchSignalKind.titleExact)
            .length,
        1,
      );
    });

    test('exact main title with different subtitle uses main tier', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(title: 'Dune: Book One'),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'Dune: Messiah',
        ),
      );
      expect(
        evaluation.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.titleMainExact,
        ),
        isTrue,
      );
    });

    test('filename fallback does not stack with stronger title tier', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          filenameStem: 'republic',
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Plato'],
        ),
      );
      expect(
        evaluation.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.titleFilename,
        ),
        isFalse,
      );
    });

    test('subtitle bonus requires partial-or-better main title agreement', () {
      final withBonus = evaluator.evaluateCandidate(
        local: localInput(
          title: 'Dune',
          subtitle: 'Messiah',
          authors: ['Frank Herbert'],
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'Dune',
          subtitle: 'Messiah',
          authors: ['Frank Herbert'],
        ),
      );
      expect(
        withBonus.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.subtitleAgree,
        ),
        isTrue,
      );

      final withoutBonus = evaluator.evaluateCandidate(
        local: localInput(title: 'Totally Different', subtitle: 'Messiah'),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'Dune',
          subtitle: 'Messiah',
        ),
      );
      expect(
        withoutBonus.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.subtitleAgree,
        ),
        isFalse,
      );
    });

    test('title-only match cannot reach high confidence', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(title: 'The Republic'),
        candidate: matchCandidate(recordId: 'a', title: 'The Republic'),
      );
      expect(evaluation.finalScore, lessThan(0.85));
    });
  });

  group('BookCandidateEvaluator author scoring', () {
    test('primary exact and any exact tiers are mutually exclusive', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(title: 'Title', authors: ['Plato']),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'Title',
          authors: ['Plato', 'Aristotle'],
        ),
      );
      final authorSignals = evaluation.signals.where(
        (signal) =>
            signal.kind == BookCandidateMatchSignalKind.authorPrimaryExact ||
            signal.kind == BookCandidateMatchSignalKind.authorAnyExact ||
            signal.kind == BookCandidateMatchSignalKind.authorSurname,
      );
      expect(authorSignals.length, 1);
      expect(
        authorSignals.first.kind,
        BookCandidateMatchSignalKind.authorPrimaryExact,
      );
    });

    test('missing candidate author is not an author conflict', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(title: 'The Republic', authors: ['Plato']),
        candidate: matchCandidate(recordId: 'a', title: 'The Republic', authors: []),
      );
      expect(
        evaluation.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.authorConflict,
        ),
        isFalse,
      );
    });

    test('contradictory usable authors trigger conflict penalty', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(title: 'The Republic', authors: ['Plato']),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Aristotle'],
        ),
      );
      expect(
        evaluation.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.authorConflict,
        ),
        isTrue,
      );
      expect(evaluation.finalScore, lessThan(0.12));
    });
  });

  group('BookCandidateEvaluator year and penalties', () {
    test('year tiers follow exact, near and loose windows', () {
      final exact = evaluator.evaluateCandidate(
        local: localInput(title: 'Title', year: 2007),
        candidate: matchCandidate(recordId: 'a', title: 'Title', year: 2007),
      );
      expect(
        exact.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.yearExact,
        ),
        isTrue,
      );

      final near = evaluator.evaluateCandidate(
        local: localInput(title: 'Title', year: 2007),
        candidate: matchCandidate(recordId: 'a', title: 'Title', year: 2008),
      );
      expect(
        near.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.yearNear,
        ),
        isTrue,
      );

      final loose = evaluator.evaluateCandidate(
        local: localInput(title: 'Title', year: 2007),
        candidate: matchCandidate(recordId: 'a', title: 'Title', year: 2010),
      );
      expect(
        loose.signals.any(
          (signal) => signal.kind == BookCandidateMatchSignalKind.yearLoose,
        ),
        isTrue,
      );

      final outside = evaluator.evaluateCandidate(
        local: localInput(title: 'Title', year: 2007),
        candidate: matchCandidate(recordId: 'a', title: 'Title', year: 2015),
      );
      expect(
        outside.signals.any(
          (signal) =>
              signal.kind == BookCandidateMatchSignalKind.yearExact ||
              signal.kind == BookCandidateMatchSignalKind.yearNear ||
              signal.kind == BookCandidateMatchSignalKind.yearLoose,
        ),
        isFalse,
      );
    });

    test('multiple penalties floor at zero and clamp at one', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
          language: 'eng',
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Aristotle'],
          year: 1990,
          languages: ['fre'],
        ),
      );
      expect(evaluation.finalScore, 0.0);

      final highRaw = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
          publisher: 'Publisher',
          language: 'eng',
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
          publishers: ['Publisher'],
          languages: ['eng'],
        ),
      );
      expect(highRaw.finalScore, lessThanOrEqualTo(1.0));
    });
  });

  group('BookCandidateEvaluator identifiers and confidence', () {
    test('identifier match produces identifier decision and band', () {
      final set = evaluator.evaluateSet(
        local: localInput(
          title: 'The Republic',
          isbn13: ['9780140449136'],
        ),
        candidates: [
          matchCandidate(
            recordId: 'a',
            title: 'The Republic',
            isbn13: ['9780140449136'],
          ),
        ],
      );
      expect(set.decision, BookCandidateMatchDecision.identifierLinked);
      expect(set.topCandidate!.identifierStatus, IsbnComparisonResult.match);
    });

    test('ISBN conflict disqualifies automatic linking without giant penalty', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          isbn13: ['9780140449136'],
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          isbn10: ['0061120081'],
        ),
      );
      expect(evaluation.disqualifiedForAutoLink, isTrue);
      expect(evaluation.penaltyTotal, lessThan(1.0));
    });

    test('confidence band thresholds are inclusive at 0.85 and 0.60', () {
      final high = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
        ),
      );
      expect(high.finalScore, closeTo(0.75, tolerance));

      final exactHigh = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          subtitle: 'Translated Edition',
          authors: ['Plato'],
          year: 2007,
          publisher: 'Penguin',
          language: 'eng',
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          subtitle: 'Translated Edition',
          authors: ['Plato'],
          year: 2007,
          publishers: ['Penguin'],
          languages: ['eng'],
        ),
      );
      expect(exactHigh.finalScore, greaterThanOrEqualTo(0.85));
    });

    test('provider hint never changes score', () {
      final lowHint = evaluator.evaluateCandidate(
        local: localInput(title: 'The Republic', authors: ['Plato']),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Plato'],
          relevanceScore: 0.1,
        ),
      );
      final highHint = evaluator.evaluateCandidate(
        local: localInput(title: 'The Republic', authors: ['Plato']),
        candidate: matchCandidate(
          recordId: 'b',
          title: 'The Republic',
          authors: ['Plato'],
          relevanceScore: 0.99,
        ),
      );
      expect(lowHint.finalScore, closeTo(highHint.finalScore, tolerance));
    });
  });

  group('BookCandidateEvaluator ambiguity and explainability', () {
    test('detects ambiguity when top-two margin is below 0.08', () {
      final set = evaluator.evaluateSet(
        local: localInput(title: 'The Republic', authors: ['Plato'], year: 2007),
        candidates: [
          matchCandidate(
            recordId: 'a',
            title: 'The Republic',
            authors: ['Plato'],
            year: 2007,
            publishers: ['A'],
          ),
          matchCandidate(
            recordId: 'b',
            title: 'The Republic',
            authors: ['Plato'],
            year: 2007,
            publishers: ['B'],
          ),
        ],
      );
      expect(set.isAmbiguous, isTrue);
      expect(set.decision, BookCandidateMatchDecision.ambiguous);
      expect(set.ambiguityReasonIds, contains('multiple_close_matches'));
    });

    test('single acceptable candidate keeps decision unmatched for manual review', () {
      final set = evaluator.evaluateSet(
        local: localInput(title: 'The Republic', authors: ['Plato'], year: 2007),
        candidates: [
          matchCandidate(
            recordId: 'a',
            title: 'The Republic',
            authors: ['Plato'],
            year: 2007,
          ),
        ],
      );
      expect(set.hasManualReviewCandidates, isTrue);
      expect(set.hasNoAcceptableCandidates, isFalse);
      expect(set.decision, BookCandidateMatchDecision.unmatched);
      expect(set.topCandidate!.finalScore, closeTo(0.75, tolerance));
    });

    test('single candidate with ISBN conflict is ambiguous for manual review', () {
      final set = evaluator.evaluateSet(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          isbn13: ['9780140449136'],
        ),
        candidates: [
          matchCandidate(
            recordId: 'a',
            title: 'The Republic',
            authors: ['Plato'],
            isbn10: ['0061120081'],
          ),
        ],
      );
      expect(set.topCandidate!.finalScore, greaterThanOrEqualTo(0.60));
      expect(set.isAmbiguous, isTrue);
      expect(set.decision, BookCandidateMatchDecision.ambiguous);
      expect(set.ambiguityReasonIds, contains('identifier_conflict'));
      expect(set.ambiguityReasonIds, isNot(contains('multiple_close_matches')));
    });

    test('single candidate with author conflict is ambiguous for manual review', () {
      final set = evaluator.evaluateSet(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
        ),
        candidates: [
          matchCandidate(
            recordId: 'a',
            title: 'The Republic',
            authors: ['Aristotle'],
            year: 2007,
          ),
        ],
      );
      expect(set.topCandidate!.finalScore, lessThan(0.60));
      expect(set.isAmbiguous, isTrue);
      expect(set.ambiguityReasonIds, contains('contradictory_author'));
      expect(set.ambiguityReasonIds, isNot(contains('multiple_close_matches')));
    });

    test('filename fallback never appears in explanation identifiers', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(
          filenameStem: 'secret_filename',
          authors: ['Plato'],
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'Secret Filename',
          authors: ['Plato'],
        ),
      );
      for (final signal in evaluation.signals) {
        expect(signal.explanationId, isNot(contains('secret')));
        expect(signal.comparedField, isNot(contains('secret')));
      }
      for (final id in evaluation.explanationIds) {
        expect(id.toLowerCase(), isNot(contains('filename')));
        expect(id.toLowerCase(), isNot(contains('secret')));
      }
    });

    test('exactly 0.08 margin is not ambiguous', () {
      final set = evaluator.evaluateSet(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          year: 2007,
          publisher: 'Penguin',
          language: 'eng',
        ),
        candidates: [
          matchCandidate(
            recordId: 'a',
            title: 'The Republic',
            authors: ['Plato'],
            year: 2007,
            publishers: ['Penguin'],
            languages: ['eng'],
          ),
          matchCandidate(
            recordId: 'b',
            title: 'The Republic',
            authors: ['Plato'],
            year: 2007,
          ),
        ],
      );
      expect(set.rankedEvaluations.length, 2);
      final margin = set.rankedEvaluations[0].finalScore -
          set.rankedEvaluations[1].finalScore;
      expect(margin, closeTo(0.08, tolerance));
      expect(set.isAmbiguous, isFalse);
    });

    test('explanations use bounded identifiers without raw metadata', () {
      final evaluation = evaluator.evaluateCandidate(
        local: localInput(
          title: 'The Republic',
          authors: ['Plato'],
          isbn13: ['9780140449136'],
        ),
        candidate: matchCandidate(
          recordId: 'a',
          title: 'The Republic',
          authors: ['Plato'],
          isbn10: ['0061120081'],
        ),
      );
      for (final id in evaluation.explanationIds) {
        expect(id.contains('Plato'), isFalse);
        expect(id.contains('978'), isFalse);
        expect(id.contains('/'), isFalse);
      }
      for (final signal in evaluation.signals) {
        expect(signal.explanationId, isNot(contains('Plato')));
      }
    });
  });

  group('BookCandidateEvaluator isolation', () {
    test('does not mutate local input or candidate', () {
      final local = localInput(title: 'The Republic', authors: ['Plato']);
      final candidate = matchCandidate(
        recordId: 'a',
        title: 'The Republic',
        authors: ['Plato'],
      );
      final localCopy = LocalBookMatchInput(
        itemId: local.itemId,
        title: local.title,
        authors: List<String>.from(local.authors),
      );
      final candidateCopy = matchCandidate(
        recordId: candidate.metadata.providerRecordId,
        title: candidate.metadata.canonicalTitle,
        authors: List<String>.from(candidate.metadata.authors),
      );

      evaluator.evaluateCandidate(local: local, candidate: candidate);

      expect(local.title, localCopy.title);
      expect(local.authors, localCopy.authors);
      expect(candidate.metadata.canonicalTitle, candidateCopy.metadata.canonicalTitle);
      expect(candidate.metadata.authors, candidateCopy.metadata.authors);
    });
  });
}
