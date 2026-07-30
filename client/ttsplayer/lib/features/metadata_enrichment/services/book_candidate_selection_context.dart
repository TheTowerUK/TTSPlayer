import '../matching/book_candidate_match_evaluation.dart';
import '../matching/book_candidate_match_set.dart';
import '../matching/local_book_match_input.dart';
import 'book_candidate_review_policy.dart';

/// Transient in-memory validation token for manual candidate selection (M7.3.2).
///
/// Not persisted. Does not contain paths or raw provider payloads.
/// Contexts are reusable value objects; the coordinator does not consume them.
class BookCandidateSelectionContext {
  const BookCandidateSelectionContext({
    required this.itemId,
    required this.providerId,
    required this.searchFingerprint,
    required this.evaluationsByRecordId,
    required this.generatedAt,
    required this.matchSet,
    required this.reviewableRecordIds,
  });

  final String itemId;
  final String providerId;
  final String searchFingerprint;
  final Map<String, BookCandidateMatchEvaluation> evaluationsByRecordId;
  final DateTime generatedAt;
  final BookCandidateMatchSet matchSet;
  final List<String> reviewableRecordIds;

  bool get hasReviewableCandidates => reviewableRecordIds.isNotEmpty;

  BookCandidateMatchEvaluation? evaluationForRecordId(String providerRecordId) {
    return evaluationsByRecordId[providerRecordId];
  }

  bool matchesItem(String itemId) => this.itemId == itemId;

  bool matchesProvider(String providerId) => this.providerId == providerId;

  bool isReviewableRecord(String providerRecordId) {
    return reviewableRecordIds.contains(providerRecordId);
  }

  static BookCandidateSelectionContext fromEvaluation({
    required String itemId,
    required String providerId,
    required BookSearchFingerprint searchFingerprint,
    required BookCandidateMatchSet matchSet,
    required DateTime generatedAt,
  }) {
    final byId = <String, BookCandidateMatchEvaluation>{};
    for (final evaluation in matchSet.rankedEvaluations) {
      byId[evaluation.candidate.metadata.providerRecordId] = evaluation;
    }
    return BookCandidateSelectionContext(
      itemId: itemId,
      providerId: providerId,
      searchFingerprint: searchFingerprint.value,
      evaluationsByRecordId: byId,
      generatedAt: generatedAt,
      matchSet: matchSet,
      reviewableRecordIds: BookCandidateReviewPolicy.reviewableRecordIds(matchSet),
    );
  }
}

/// Deterministic fingerprint of explicit search inputs — not cryptographic.
class BookSearchFingerprint {
  const BookSearchFingerprint(this.value);

  final String value;

  factory BookSearchFingerprint.fromLocalInput(LocalBookMatchInput input) {
    final parts = <String>[
      input.itemId,
      input.title?.trim() ?? '',
      input.subtitle?.trim() ?? '',
      input.authors.join('|'),
      input.publicationYear?.toString() ?? '',
      input.publisher?.trim() ?? '',
      input.language?.trim() ?? '',
      input.isbn10Values.join('|'),
      input.isbn13Values.join('|'),
    ];
    return BookSearchFingerprint(parts.join('\u001f').toLowerCase());
  }
}

/// Confirmation policy for warned candidate selection (M7.3.2).
///
/// [overrideCriticalConflicts] is required only for ISBN conflict, contradictory
/// author, or [disqualifiedForAutoLink]. Non-critical warnings such as edition,
/// volume, language, omnibus, or abridged mismatches do not require it.
enum BookCandidateSelectionConfirmation {
  normal,
  overrideCriticalConflicts,
}
