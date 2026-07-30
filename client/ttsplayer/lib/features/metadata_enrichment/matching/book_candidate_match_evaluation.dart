import '../models/provider_book_candidate.dart';
import 'book_candidate_match_decision.dart';
import 'book_candidate_match_signal.dart';
import 'book_candidate_match_warning.dart';
import 'isbn_equivalence.dart';

/// Transient per-candidate evaluation result (M7.3.1).
class BookCandidateMatchEvaluation {
  const BookCandidateMatchEvaluation({
    required this.candidate,
    required this.rawScore,
    required this.penaltyTotal,
    required this.finalScore,
    required this.signals,
    required this.warnings,
    required this.identifierStatus,
    required this.disqualifiedForAutoLink,
    required this.rank,
    required this.deltaFromTop,
    required this.confidenceBand,
    required this.explanationIds,
    required this.identifierMatch,
  });

  final ProviderBookCandidate candidate;
  final double rawScore;
  final double penaltyTotal;
  final double finalScore;
  final List<BookCandidateMatchSignal> signals;
  final List<BookCandidateMatchWarning> warnings;
  final IsbnComparisonResult identifierStatus;
  final bool disqualifiedForAutoLink;
  final int rank;
  final double deltaFromTop;
  final BookCandidateMatchBand confidenceBand;
  final List<String> explanationIds;
  final bool identifierMatch;
}
