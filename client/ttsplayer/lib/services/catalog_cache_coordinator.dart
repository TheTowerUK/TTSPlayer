import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/music/music_library_service.dart';
import '../features/music/services/music_listening_repository.dart';
import '../features/music/services/music_playback_queue_controller.dart';
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
    required MusicLibraryService musicLibraryService,
    required LibraryMetadataRepository libraryMetadataRepository,
    required MusicPlaybackQueueController musicPlaybackQueueController,
    required MusicListeningRepository musicListeningRepository,
  })  : _artworkService = artworkService,
        _searchService = searchService,
        _musicLibraryService = musicLibraryService,
        _libraryMetadataRepository = libraryMetadataRepository,
        _musicPlaybackQueueController = musicPlaybackQueueController,
        _musicListeningRepository = musicListeningRepository;

  final ArtworkService _artworkService;
  final SearchService _searchService;
  final MusicLibraryService _musicLibraryService;
  final LibraryMetadataRepository _libraryMetadataRepository;
  final MusicPlaybackQueueController _musicPlaybackQueueController;
  final MusicListeningRepository _musicListeningRepository;

  /// Runs artwork, search, music projection, favourites, listening history, and queue reconciliation.
  void onCatalogReplaced(Catalog catalog) {
    _artworkService.clearCache();
    _searchService.onCatalogReplaced(catalog);
    _musicLibraryService.invalidate();
    unawaited(_musicPlaybackQueueController.reconcileWithCatalog(catalog));
    unawaited(_validateLibraryMetadata(catalog));
    unawaited(_validateListeningHistory(catalog));
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

  Future<void> _validateListeningHistory(Catalog catalog) async {
    try {
      await _musicListeningRepository.validateAgainstCatalog(catalog);
    } catch (e, stackTrace) {
      debugPrint(
        '[CatalogCacheCoordinator] listening validateAgainstCatalog failed: '
        '$e\n$stackTrace',
      );
    }
  }
}
