import '../matching/book_candidate_match_evaluation.dart';
import '../matching/book_candidate_match_set.dart';
import '../matching/book_candidate_match_signal.dart';
import '../matching/book_candidate_match_warning.dart';

/// Selectability rules for manual candidate review (M7.3.2).
///
/// Ordinary weak candidates below the acceptable threshold are not offered for
/// manual selection. Candidates may remain reviewable when a critical conflict
/// intentionally requires explicit user confirmation.
class BookCandidateReviewPolicy {
  const BookCandidateReviewPolicy._();

  static bool requiresCriticalConflictOverride(
    BookCandidateMatchEvaluation evaluation,
  ) {
    if (evaluation.disqualifiedForAutoLink) {
      return true;
    }
    for (final warning in evaluation.warnings) {
      if (warning.kind == BookCandidateMatchWarningKind.isbnConflict ||
          warning.kind == BookCandidateMatchWarningKind.contradictoryAuthor) {
        return true;
      }
    }
    for (final signal in evaluation.signals) {
      if (signal.kind == BookCandidateMatchSignalKind.isbnConflict ||
          signal.kind == BookCandidateMatchSignalKind.authorConflict) {
        return true;
      }
    }
    return false;
  }

  static bool hasPartialOrBetterTitleAgreement(
    BookCandidateMatchEvaluation evaluation,
  ) {
    return evaluation.signals.any(
      (signal) =>
          signal.kind == BookCandidateMatchSignalKind.titleExact ||
          signal.kind == BookCandidateMatchSignalKind.titleMainExact ||
          signal.kind == BookCandidateMatchSignalKind.titleStrong ||
          signal.kind == BookCandidateMatchSignalKind.titlePartial,
    );
  }

  static bool isReviewable(
    BookCandidateMatchEvaluation evaluation,
    BookCandidateMatchSet matchSet,
  ) {
    final recordId = evaluation.candidate.metadata.providerRecordId;
    final acceptable = matchSet.acceptableEvaluations.any(
      (candidate) => candidate.candidate.metadata.providerRecordId == recordId,
    );
    if (acceptable) {
      return true;
    }
    if (requiresCriticalConflictOverride(evaluation) &&
        hasPartialOrBetterTitleAgreement(evaluation)) {
      return true;
    }
    return false;
  }

  static List<String> reviewableRecordIds(BookCandidateMatchSet matchSet) {
    final ids = <String>[];
    for (final evaluation in matchSet.rankedEvaluations) {
      if (isReviewable(evaluation, matchSet)) {
        ids.add(evaluation.candidate.metadata.providerRecordId);
      }
    }
    return ids;
  }

  static bool requiresConflictReview(BookCandidateMatchSet matchSet) {
    return matchSet.isAmbiguous;
  }

  static bool canRecordAmbiguousOutcome(BookCandidateMatchSet matchSet) {
    if (matchSet.rankedEvaluations.isEmpty) {
      return false;
    }
    return matchSet.isAmbiguous || requiresConflictReview(matchSet);
  }
}
