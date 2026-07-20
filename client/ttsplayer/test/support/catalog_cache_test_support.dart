import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/playback_service.dart';

CatalogCacheCoordinator createTestCatalogCacheCoordinator({
  required ArtworkService artworkService,
  required SearchService searchService,
  required MusicLibraryService musicLibraryService,
  required LibraryMetadataRepository libraryMetadataRepository,
  PlaybackService? playbackService,
  MusicPlaybackQueueController? musicPlaybackQueueController,
}) {
  final playback = playbackService ?? PlaybackService();
  final queue = musicPlaybackQueueController ??
      MusicPlaybackQueueController(playbackService: playback);
  return CatalogCacheCoordinator(
    artworkService: artworkService,
    searchService: searchService,
    musicLibraryService: musicLibraryService,
    libraryMetadataRepository: libraryMetadataRepository,
    musicPlaybackQueueController: queue,
  );
}
