import '../models/normalized_book_metadata.dart';
import '../models/provider_book_candidate.dart';
import 'book_metadata_provider_failure.dart';

/// Outcome of a provider ISBN lookup (M7.2).
sealed class BookMetadataLookupResult {
  const BookMetadataLookupResult();
}

class BookMetadataLookupSuccess extends BookMetadataLookupResult {
  const BookMetadataLookupSuccess(this.metadata);

  /// Null when the provider returned no matching edition.
  final NormalizedBookMetadata? metadata;

  bool get isEmpty => metadata == null;
}

class BookMetadataLookupFailure extends BookMetadataLookupResult {
  const BookMetadataLookupFailure(this.failure);

  final BookMetadataProviderFailure failure;
}

/// Outcome of a provider search (M7.2).
sealed class BookMetadataSearchResult {
  const BookMetadataSearchResult();
}

class BookMetadataSearchSuccess extends BookMetadataSearchResult {
  const BookMetadataSearchSuccess(this.candidates);

  final List<ProviderBookCandidate> candidates;

  bool get isEmpty => candidates.isEmpty;
}

class BookMetadataSearchFailure extends BookMetadataSearchResult {
  const BookMetadataSearchFailure(this.failure);

  final BookMetadataProviderFailure failure;
}
