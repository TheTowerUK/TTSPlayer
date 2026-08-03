import '../providers/book_metadata_provider_failure.dart';
import '../services/book_metadata_matching_result.dart';

/// Maps coordinator outcomes to bounded user-facing messages (M7.3.3).
class MetadataEnrichmentUiMessages {
  const MetadataEnrichmentUiMessages._();

  static String isbnResultMessage(BookIsbnMatchResult result) {
    return switch (result) {
      BookIsbnMatchSuccess() => 'Metadata linked by ISBN.',
      BookIsbnMatchNoResult() => 'No matching book found for that ISBN.',
      BookIsbnMatchConflict() =>
        'The returned metadata did not confirm this ISBN. Try searching instead.',
      BookIsbnMatchRejected(:final reason) => _boundedRejection(reason),
      BookIsbnMatchProviderFailure(:final category) =>
        providerFailureMessage(category),
      BookIsbnMatchRepositoryFailure() => repositoryFailureMessage,
    };
  }

  static String searchResultMessage(
    BookCandidateSearchEvaluationResult result,
  ) {
    return switch (result) {
      BookCandidateSearchNoProviderCandidates() =>
        'No metadata candidates found.',
      BookCandidateSearchEvaluationSuccess(:final hasReviewableCandidates) =>
        hasReviewableCandidates
            ? 'Metadata candidates are available for review.'
            : 'No suitable metadata candidates found.',
      BookCandidateSearchEvaluationRejected(:final reason) =>
        _boundedRejection(reason),
      BookCandidateSearchEvaluationProviderFailure(:final category) =>
        providerFailureMessage(category),
    };
  }

  static String linkTransitionMessage(BookLinkTransitionResult result) {
    return switch (result) {
      BookLinkTransitionSuccess() => 'Metadata state updated.',
      BookLinkTransitionPreserved(:final reason) => reason,
      BookLinkTransitionRejected(:final reason) => _boundedRejection(reason),
      BookLinkTransitionInvalidState(:final reason) => reason,
      BookLinkTransitionRepositoryFailure() => repositoryFailureMessage,
    };
  }

  static String providerFailureMessage(
    BookMetadataProviderFailureCategory category,
  ) {
    return switch (category) {
      BookMetadataProviderFailureCategory.rateLimited ||
      BookMetadataProviderFailureCategory.quotaExhausted =>
        'Metadata requests are temporarily limited.',
      BookMetadataProviderFailureCategory.networkUnavailable ||
      BookMetadataProviderFailureCategory.timeout =>
        'Could not reach the metadata service.',
      BookMetadataProviderFailureCategory.providerUnavailable =>
        'Metadata service is currently unavailable.',
      BookMetadataProviderFailureCategory.authentication ||
      BookMetadataProviderFailureCategory.authorization =>
        'Metadata service access was denied.',
      BookMetadataProviderFailureCategory.malformedResponse ||
      BookMetadataProviderFailureCategory.unsupportedResponse =>
        'Metadata service returned an unreadable response.',
      BookMetadataProviderFailureCategory.invalidRequest =>
        'Metadata request was invalid.',
      BookMetadataProviderFailureCategory.cancelled =>
        'Metadata request was cancelled.',
      BookMetadataProviderFailureCategory.unknown =>
        'Metadata service is currently unavailable.',
    };
  }

  static const repositoryFailureMessage = 'Metadata could not be saved.';

  static const invalidIsbnMessage = 'Enter a valid ISBN-10 or ISBN-13.';

  static const candidateReviewDeferredMessage =
      'Candidate selection will be added in a later phase. No metadata was saved.';

  static const selectionSuccessMessage = 'Metadata linked manually.';

  static String selectionResultMessage(BookCandidateSelectionResult result) {
    return switch (result) {
      BookCandidateSelectionSuccess() => selectionSuccessMessage,
      BookCandidateSelectionRepositoryFailure() => repositoryFailureMessage,
      BookCandidateSelectionInvalidContext() =>
        'These metadata candidates are no longer valid. Search again.',
      BookCandidateSelectionConflictConfirmationRequired() =>
        'Review the warnings before continuing.',
      BookCandidateSelectionRejected(:final reason) => _selectionRejection(reason),
    };
  }

  static String _selectionRejection(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('ignored')) {
      return 'Resume matching before selecting metadata.';
    }
    if (lower.contains('books only')) {
      return 'Metadata selection is unavailable for this item.';
    }
    if (lower.contains('not reviewable')) {
      return 'Selected candidate is no longer available.';
    }
    if (lower.contains('relink requires')) {
      return 'Metadata could not be changed from its current state.';
    }
    return 'Metadata could not be changed from its current state.';
  }

  static String _boundedRejection(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('isbn')) {
      return invalidIsbnMessage;
    }
    if (lower.contains('ignored')) {
      return 'Resume matching before searching again.';
    }
    if (lower.contains('books only')) {
      return 'Metadata enrichment is supported for books only.';
    }
    return reason;
  }
}
