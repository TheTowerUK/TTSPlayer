import '../matching/book_candidate_match_set.dart';
import 'book_candidate_selection_context.dart';
import '../models/metadata_enrichment_record.dart';
import '../providers/book_metadata_provider_failure.dart';

sealed class BookMetadataMatchingOutcome {
  const BookMetadataMatchingOutcome();
}

class BookMetadataMatchingRejected extends BookMetadataMatchingOutcome {
  const BookMetadataMatchingRejected(this.reason);

  final String reason;
}

class BookMetadataMatchingProviderFailure extends BookMetadataMatchingOutcome {
  const BookMetadataMatchingProviderFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;
}

class BookMetadataMatchingRepositoryFailure extends BookMetadataMatchingOutcome {
  const BookMetadataMatchingRepositoryFailure(this.message);

  final String message;
}

sealed class BookIsbnMatchResult extends BookMetadataMatchingOutcome {
  const BookIsbnMatchResult();
}

class BookIsbnMatchRejected extends BookIsbnMatchResult {
  const BookIsbnMatchRejected(this.reason);

  final String reason;
}

class BookIsbnMatchProviderFailure extends BookIsbnMatchResult {
  const BookIsbnMatchProviderFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;
}

class BookIsbnMatchRepositoryFailure extends BookIsbnMatchResult {
  const BookIsbnMatchRepositoryFailure(this.message);

  final String message;
}

class BookIsbnMatchSuccess extends BookIsbnMatchResult {
  const BookIsbnMatchSuccess(this.record);

  final MetadataEnrichmentRecord record;
}

class BookIsbnMatchNoResult extends BookIsbnMatchResult {
  const BookIsbnMatchNoResult({this.record});

  final MetadataEnrichmentRecord? record;
}

class BookIsbnMatchConflict extends BookIsbnMatchResult {
  const BookIsbnMatchConflict({this.existingRecord});

  final MetadataEnrichmentRecord? existingRecord;
}

sealed class BookCandidateSearchEvaluationResult extends BookMetadataMatchingOutcome {
  const BookCandidateSearchEvaluationResult();
}

class BookCandidateSearchEvaluationRejected
    extends BookCandidateSearchEvaluationResult {
  const BookCandidateSearchEvaluationRejected(this.reason);

  final String reason;
}

class BookCandidateSearchEvaluationProviderFailure
    extends BookCandidateSearchEvaluationResult {
  const BookCandidateSearchEvaluationProviderFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;
}

/// Provider returned an empty candidate list.
class BookCandidateSearchNoProviderCandidates
    extends BookCandidateSearchEvaluationResult {
  const BookCandidateSearchNoProviderCandidates();
}

/// Evaluated provider candidates with transient recommendation metadata.
///
/// Non-empty evaluated results are never represented as [BookCandidateSearchNoProviderCandidates].
/// Use [hasReviewableCandidates] to distinguish manual-review availability from provider emptiness.
class BookCandidateSearchEvaluationSuccess
    extends BookCandidateSearchEvaluationResult {
  const BookCandidateSearchEvaluationSuccess({
    required this.matchSet,
    required this.selectionContext,
  });

  final BookCandidateMatchSet matchSet;
  final BookCandidateSelectionContext selectionContext;

  bool get hasAcceptableCandidates => matchSet.hasManualReviewCandidates;

  bool get hasReviewableCandidates => selectionContext.hasReviewableCandidates;

  bool get requiresConflictReview =>
      selectionContext.matchSet.isAmbiguous;
}

/// Bounded reason for explicit unmatched persistence.
enum BookNoMatchPersistenceReason {
  userSelectedNone,
  noReviewableCandidates,
}

sealed class BookCandidateSelectionResult extends BookMetadataMatchingOutcome {
  const BookCandidateSelectionResult();
}

class BookCandidateSelectionRejected extends BookCandidateSelectionResult {
  const BookCandidateSelectionRejected(this.reason);

  final String reason;
}

class BookCandidateSelectionRepositoryFailure
    extends BookCandidateSelectionResult {
  const BookCandidateSelectionRepositoryFailure(this.message);

  final String message;
}

class BookCandidateSelectionSuccess extends BookCandidateSelectionResult {
  const BookCandidateSelectionSuccess(this.record);

  final MetadataEnrichmentRecord record;
}

class BookCandidateSelectionConflictConfirmationRequired
    extends BookCandidateSelectionResult {
  const BookCandidateSelectionConflictConfirmationRequired();
}

class BookCandidateSelectionInvalidContext extends BookCandidateSelectionResult {
  const BookCandidateSelectionInvalidContext([this.reason]);

  final String? reason;
}

sealed class BookLinkTransitionResult extends BookMetadataMatchingOutcome {
  const BookLinkTransitionResult();
}

class BookLinkTransitionRejected extends BookLinkTransitionResult {
  const BookLinkTransitionRejected(this.reason);

  final String reason;
}

class BookLinkTransitionRepositoryFailure extends BookLinkTransitionResult {
  const BookLinkTransitionRepositoryFailure(this.message);

  final String message;
}

class BookLinkTransitionSuccess extends BookLinkTransitionResult {
  const BookLinkTransitionSuccess(this.record);

  final MetadataEnrichmentRecord record;
}

class BookLinkTransitionPreserved extends BookLinkTransitionResult {
  const BookLinkTransitionPreserved({
    required this.record,
    required this.reason,
  });

  final MetadataEnrichmentRecord record;
  final String reason;
}

class BookLinkTransitionInvalidState extends BookLinkTransitionResult {
  const BookLinkTransitionInvalidState(this.reason);

  final String reason;
}
