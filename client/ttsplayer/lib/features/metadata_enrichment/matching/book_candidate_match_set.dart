import 'book_candidate_match_decision.dart';
import 'book_candidate_match_evaluation.dart';

/// Transient ranked evaluation set (M7.3.1).
///
/// Use [acceptableEvaluations] to distinguish manual-review candidates from a
/// truly empty result set. [decision] describes recommendation strength only:
///
/// - [acceptableEvaluations.isEmpty] and [BookCandidateMatchDecision.unmatched]
///   → no candidates met the minimum score threshold.
/// - [acceptableEvaluations.isNotEmpty] and
///   [BookCandidateMatchDecision.unmatched] → one or more manually reviewable
///   candidates exist, but no identifier, high-confidence, or ambiguous
///   recommendation was issued.
class BookCandidateMatchSet {
  const BookCandidateMatchSet({
    required this.rankedEvaluations,
    required this.acceptableEvaluations,
    required this.topCandidate,
    required this.isAmbiguous,
    required this.ambiguityMargin,
    required this.ambiguityReasonIds,
    required this.decision,
  });

  final List<BookCandidateMatchEvaluation> rankedEvaluations;
  final List<BookCandidateMatchEvaluation> acceptableEvaluations;
  final BookCandidateMatchEvaluation? topCandidate;

  /// When true, the UI should present candidates for explicit user selection.
  ///
  /// True for close-score ambiguity or when the top acceptable candidate has a
  /// critical conflict (ISBN mismatch or contradictory author).
  final bool isAmbiguous;
  final double? ambiguityMargin;

  /// Bounded reason identifiers explaining [isAmbiguous].
  ///
  /// Uses `multiple_close_matches` only when two or more acceptable candidates
  /// are within the ambiguity margin. Single-candidate conflict ambiguity uses
  /// `identifier_conflict` or `contradictory_author` instead.
  final List<String> ambiguityReasonIds;
  final BookCandidateMatchDecision decision;

  /// True when at least one candidate scored ≥ 0.60 (or identifier-matched).
  bool get hasManualReviewCandidates => acceptableEvaluations.isNotEmpty;

  /// True when no candidate met the acceptable threshold.
  bool get hasNoAcceptableCandidates => acceptableEvaluations.isEmpty;
}
