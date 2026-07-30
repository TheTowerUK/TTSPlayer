import '../models/enrichment_last_error_category.dart';

/// Bounded provider failure categories for book metadata requests (M7.2).
enum BookMetadataProviderFailureCategory {
  invalidRequest,
  authentication,
  authorization,
  rateLimited,
  quotaExhausted,
  timeout,
  networkUnavailable,
  cancelled,
  providerUnavailable,
  malformedResponse,
  unsupportedResponse,
  unknown,
}

/// Provider failure without raw exception text (M7.2).
class BookMetadataProviderFailure {
  const BookMetadataProviderFailure({
    required this.category,
    this.retryAfter,
  });

  final BookMetadataProviderFailureCategory category;
  final Duration? retryAfter;

  EnrichmentLastErrorCategory toEnrichmentErrorCategory() {
    switch (category) {
      case BookMetadataProviderFailureCategory.invalidRequest:
      case BookMetadataProviderFailureCategory.malformedResponse:
      case BookMetadataProviderFailureCategory.unsupportedResponse:
        return EnrichmentLastErrorCategory.parseFailure;
      case BookMetadataProviderFailureCategory.authentication:
        return EnrichmentLastErrorCategory.authenticationFailure;
      case BookMetadataProviderFailureCategory.authorization:
        return EnrichmentLastErrorCategory.providerUnavailable;
      case BookMetadataProviderFailureCategory.rateLimited:
        return EnrichmentLastErrorCategory.rateLimited;
      case BookMetadataProviderFailureCategory.quotaExhausted:
        return EnrichmentLastErrorCategory.rateLimited;
      case BookMetadataProviderFailureCategory.timeout:
      case BookMetadataProviderFailureCategory.networkUnavailable:
        return EnrichmentLastErrorCategory.networkFailure;
      case BookMetadataProviderFailureCategory.cancelled:
        return EnrichmentLastErrorCategory.cancelled;
      case BookMetadataProviderFailureCategory.providerUnavailable:
        return EnrichmentLastErrorCategory.providerUnavailable;
      case BookMetadataProviderFailureCategory.unknown:
        return EnrichmentLastErrorCategory.providerUnavailable;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is BookMetadataProviderFailure &&
        other.category == category &&
        other.retryAfter == retryAfter;
  }

  @override
  int get hashCode => Object.hash(category, retryAfter);
}
