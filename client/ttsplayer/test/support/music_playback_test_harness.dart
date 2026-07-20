import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';

List<SingleChildWidget> musicPlayerTestProviders(
  PlaybackService service, {
  MusicPlaybackQueueController? queueController,
}) {
  final queue = queueController ??
      MusicPlaybackQueueController(playbackService: service);
  return [
    Provider<MediaLocationResolver>.value(
      value: MediaLocationResolver(
        config: MediaAccessConfig.defaults(),
        isWindowsDesktop: false,
      ),
    ),
    Provider<ArtworkService>.value(
      value: ArtworkService(fileExists: (_) => false),
    ),
    ChangeNotifierProvider<PlaybackService>.value(value: service),
    ChangeNotifierProvider<MusicPlaybackQueueController>.value(value: queue),
  ];
}

Widget musicPlayerScreenHarness(
  PlaybackService service, {
  required MediaItem track,
  MusicPlaybackQueueController? queueController,
  bool autoPlay = false,
  List<MediaItem>? queueItems,
  int startIndex = 0,
}) {
  final queue = queueController ??
      MusicPlaybackQueueController(playbackService: service);
  if (queue.isEmpty) {
    if (queueItems != null && queueItems.length > 1) {
      queue.replaceQueue(queueItems, startIndex: startIndex);
    } else {
      queue.seedSingleTrack(track);
    }
  }

  return MultiProvider(
    providers: musicPlayerTestProviders(service, queueController: queue),
    child: MaterialApp(
      home: MusicPlayerScreen(autoPlay: autoPlay),
    ),
  );
}

void readyMusicPlayer(
  PlaybackService service, {
  required MediaItem item,
  Duration position = Duration.zero,
  Duration duration = const Duration(minutes: 4),
  bool playing = false,
}) {
  service.simulateReadyForTest(item);
  service.simulatePlaybackMetricsForTest(
    duration: duration,
    position: position,
    completed: false,
  );
  service.simulatePlayingForTest(playing: playing);
  service.notifyListeners();
}

MediaItem musicTrackPartial() {
  return MediaItem.fromJson({
    'id': 'track-partial',
    'title': 'Something',
    'file_path': r'Y:\Media\Music\The Beatles\Abbey Road\02 - Something.mp3',
    'status': 'available',
    'media_kind': 'audio',
    'artist': 'The Beatles',
    'album': 'Abbey Road',
    'album_artist': 'The Beatles',
    'track_number': 2,
  });
}
