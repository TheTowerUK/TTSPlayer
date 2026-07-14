import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/search/search_service.dart';
import '../models/catalog.dart';
import 'artwork/artwork_service.dart';
import 'library/library_metadata_repository.dart';

/// Coordinates catalogue-derived cache invalidation at the app composition root
/// (ADR-014). Invoked only from [CatalogService] on successful replacement.
class CatalogCacheCoordinator {
  CatalogCacheCoordinator({
    required ArtworkService artworkService,
    required SearchService searchService,
    required LibraryMetadataRepository libraryMetadataRepository,
  })  : _artworkService = artworkService,
        _searchService = searchService,
        _libraryMetadataRepository = libraryMetadataRepository;

  final ArtworkService _artworkService;
  final SearchService _searchService;
  final LibraryMetadataRepository _libraryMetadataRepository;

  /// Runs artwork, search, and favourites reconciliation for [catalog].
  void onCatalogReplaced(Catalog catalog) {
    _artworkService.clearCache();
    _searchService.onCatalogReplaced(catalog);
    unawaited(_validateLibraryMetadata(catalog));
  }

  Future<void> _validateLibraryMetadata(Catalog catalog) async {
    try {
      await _libraryMetadataRepository.validateAgainstCatalog(catalog);
    } catch (e, stackTrace) {
      debugPrint(
        '[CatalogCacheCoordinator] validateAgainstCatalog failed: $e\n$stackTrace',
      );
    }
  }
}
