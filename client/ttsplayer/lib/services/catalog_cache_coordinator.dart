import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/music/music_library_service.dart';
import '../features/music/services/music_listening_repository.dart';
import '../features/music/services/music_playback_queue_controller.dart';
import '../features/music/services/music_playback_session_repository.dart';
import '../features/reading/services/reading_progress_repository.dart';
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
    required MusicPlaybackSessionRepository musicPlaybackSessionRepository,
    required ReadingProgressRepository readingProgressRepository,
  })  : _artworkService = artworkService,
        _searchService = searchService,
        _musicLibraryService = musicLibraryService,
        _libraryMetadataRepository = libraryMetadataRepository,
        _musicPlaybackQueueController = musicPlaybackQueueController,
        _musicListeningRepository = musicListeningRepository,
        _musicPlaybackSessionRepository = musicPlaybackSessionRepository,
        _readingProgressRepository = readingProgressRepository;

  final ArtworkService _artworkService;
  final SearchService _searchService;
  final MusicLibraryService _musicLibraryService;
  final LibraryMetadataRepository _libraryMetadataRepository;
  final MusicPlaybackQueueController _musicPlaybackQueueController;
  final MusicListeningRepository _musicListeningRepository;
  final MusicPlaybackSessionRepository _musicPlaybackSessionRepository;
  final ReadingProgressRepository _readingProgressRepository;

  /// Runs artwork, search, music projection, favourites, listening history,
  /// playback session, and live queue reconciliation.
  void onCatalogReplaced(Catalog catalog) {
    _artworkService.clearCache();
    _searchService.onCatalogReplaced(catalog);
    _musicLibraryService.invalidate();
    unawaited(_musicPlaybackQueueController.reconcileWithCatalog(catalog));
    unawaited(_validateLibraryMetadata(catalog));
    unawaited(_validateListeningHistory(catalog));
    unawaited(_validatePlaybackSession(catalog));
    unawaited(_validateReadingProgress(catalog));
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

  Future<void> _validatePlaybackSession(Catalog catalog) async {
    try {
      await _musicPlaybackSessionRepository.validateAgainstCatalog(catalog);
    } catch (e, stackTrace) {
      debugPrint(
        '[CatalogCacheCoordinator] playback session validateAgainstCatalog '
        'failed: $e\n$stackTrace',
      );
    }
  }

  Future<void> _validateReadingProgress(Catalog catalog) async {
    try {
      await _readingProgressRepository.validateAgainstCatalog(catalog);
    } catch (e, stackTrace) {
      debugPrint(
        '[CatalogCacheCoordinator] reading progress validateAgainstCatalog '
        'failed: $e\n$stackTrace',
      );
    }
  }
}
