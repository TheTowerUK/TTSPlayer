import '../artwork/metadata_artwork_download_result.dart';

/// Bounded artwork workflow outcomes for book metadata enrichment (M7.4.5).
sealed class BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkWorkflowResult();
}

class BookMetadataArtworkDownloaded extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkDownloaded();
}

class BookMetadataArtworkRefreshed extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkRefreshed();
}

class BookMetadataArtworkAlreadyCached extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkAlreadyCached();
}

class BookMetadataArtworkNoArtworkAvailable
    extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkNoArtworkAvailable();
}

class BookMetadataArtworkNotLinked extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkNotLinked();
}

class BookMetadataArtworkIdentityChanged
    extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkIdentityChanged();
}

class BookMetadataArtworkCancelled extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkCancelled();
}

class BookMetadataArtworkProviderFailure
    extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkProviderFailure(this.category);

  final MetadataArtworkDownloadFailureCategory category;
}

class BookMetadataArtworkValidationFailure
    extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkValidationFailure();
}

class BookMetadataArtworkDiskFailure extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkDiskFailure();
}

class BookMetadataArtworkPersistenceFailure
    extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkPersistenceFailure();
}

class BookMetadataArtworkPriorCacheRetained
    extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkPriorCacheRetained(this.category);

  final MetadataArtworkDownloadFailureCategory category;
}

class BookMetadataArtworkItemChanged extends BookMetadataArtworkWorkflowResult {
  const BookMetadataArtworkItemChanged();
}
