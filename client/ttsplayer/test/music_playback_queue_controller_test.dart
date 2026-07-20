import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/models/playback/playback_queue.dart';
import 'package:ttsplayer/services/playback/playback_error_messages.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'playback_service_extensions_test.dart';
import 'support/music_catalog_fixtures.dart';
import 'support/music_playback_test_harness.dart';

MediaItem _audio(String id, {String title = 'Track'}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
  );
}

MediaItem _video(String id) {
  return MediaItem(
    id: id,
    title: 'Video',
    filePath: r'Y:\Media\Videos\$id.mp4',
    mediaKindRaw: 'video',
  );
}

PlaybackService _stubPlaybackService() {
  return PlaybackService(
    mediaKitInitOverride: (service, uri, generation) async {
      final fake = FakePlaybackSessionControls();
      fake.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(fake);
      final item = service.currentItem;
      if (item != null) {
        service.simulatePlaybackMetricsForTest(
          duration: const Duration(minutes: 3),
          position: Duration.zero,
        );
        service.simulateReadyForTest(item);
      }
    },
  );
}

Future<void> _primeQueuePlayback(
  PlaybackService playback,
  MusicPlaybackQueueController controller, {
  MediaItem? item,
}) async {
  final track = item ?? controller.currentTrack!;
  await controller.playCurrent();
  playback.simulateReadyForTest(track);
  playback.simulatePlaybackMetricsForTest(
    duration: const Duration(minutes: 3),
    position: Duration.zero,
  );
  playback.notifyListeners();
}

Catalog _catalogWithAudioIds(List<String> ids) {
  return Catalog.fromJson({
    'generated_at': '2026-07-20T12:00:00+00:00',
    'total_items': ids.length,
    'catalogue': {'id': 'test', 'catalogue_version': 3},
    'folders': [
      {
        'id': 'music',
        'name': 'Music',
        'path': r'Y:\Music',
        'item_count': ids.length,
        'items': [
          for (final id in ids)
            {
              'id': id,
              'title': id,
              'file_path': r'Y:\Music\$id.mp3',
              'status': 'available',
              'media_kind': 'audio',
            },
        ],
        'subfolders': [],
      },
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlaybackQueueController', () {
    test('seedSingleTrack creates one-item queue', () {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      final track = musicTrackComplete();

      controller.seedSingleTrack(track);

      expect(controller.queue.length, 1);
      expect(controller.currentTrack?.id, 'track-complete');
      expect(controller.hasNext, isFalse);
    });

    test('playCurrent loads track through PlaybackService', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.seedSingleTrack(musicTrackComplete());

      await _primeQueuePlayback(playback, controller);

      expect(playback.currentItem?.id, 'track-complete');
      expect(playback.isReady, isTrue);
    });

    test('next loads the following queue item', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ]);

      await _primeQueuePlayback(playback, controller);
      await controller.next();

      expect(controller.currentTrack?.id, 'track-partial');
      expect(playback.currentItem?.id, 'track-partial');
    });

    test('next at final item is no-op', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete()]);

      await _primeQueuePlayback(playback, controller);
      await controller.next();

      expect(controller.currentTrack?.id, 'track-complete');
    });

    test('previous restarts when position exceeds threshold', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ], startIndex: 1);

      await _primeQueuePlayback(playback, controller, item: musicTrackPartial());
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 3),
        position: const Duration(seconds: 10),
      );
      playback.notifyListeners();

      await controller.previous();

      expect(controller.currentTrack?.id, 'track-partial');
      expect(playback.position, Duration.zero);
    });

    test('previous moves to prior item when near start', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ], startIndex: 1);

      await _primeQueuePlayback(playback, controller, item: musicTrackPartial());
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 3),
        position: const Duration(seconds: 2),
      );
      playback.notifyListeners();

      await controller.previous();

      expect(controller.currentTrack?.id, 'track-complete');
      expect(playback.currentItem?.id, 'track-complete');
    });

    test('completion advances to next track', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ]);

      await _primeQueuePlayback(playback, controller);
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 3),
        position: const Duration(minutes: 3),
        completed: true,
      );
      playback.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack?.id, 'track-partial');
    });

    test('final completion does not wrap', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete()]);

      await _primeQueuePlayback(playback, controller);
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 3),
        position: const Duration(minutes: 3),
        completed: true,
      );
      playback.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack?.id, 'track-complete');
      expect(playback.isCompleted, isTrue);
    });

    test('duplicate completion events do not double-advance', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
        _audio('third'),
      ]);

      await _primeQueuePlayback(playback, controller);
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 3),
        position: const Duration(minutes: 3),
        completed: true,
      );
      playback.notifyListeners();
      playback.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack?.id, 'track-partial');
    });

    test('retry retains queue index after error', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ], startIndex: 1);
      controller.onPlayerRouteOpened();
      await _primeQueuePlayback(playback, controller, item: musicTrackPartial());
      playback.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );

      await controller.retryCurrent();

      expect(controller.currentTrack?.id, 'track-partial');
    });

    test('next from failed item advances when next exists', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ]);

      await _primeQueuePlayback(playback, controller);
      playback.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );

      await controller.next();

      expect(controller.currentTrack?.id, 'track-partial');
    });

    test('reconcile removes missing catalogue items', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([
        musicTrackComplete(),
        musicTrackPartial(),
      ]);
      controller.onPlayerRouteOpened();
      await controller.playCurrent();

      final catalog = _catalogWithAudioIds(['track-complete']);
      await controller.reconcileWithCatalog(catalog);

      expect(controller.queue.length, 1);
      expect(controller.currentTrack?.id, 'track-complete');
    });

    test('reconcile stops when all items removed', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete()]);
      await controller.playCurrent();

      await controller.reconcileWithCatalog(_catalogWithAudioIds([]));

      expect(controller.isEmpty, isTrue);
      expect(playback.currentItem, isNull);
    });

    test('failed refresh preserves queue when reconcile is not invoked', () {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete(), musicTrackPartial()]);

      expect(controller.queue.length, 2);
    });

    test('video session clears music queue', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete()]);
      await controller.playCurrent();

      playback.simulateReadyForTest(_video('video-1'));
      playback.notifyListeners();

      expect(controller.isEmpty, isTrue);
    });

    test('route close stops playback and clears queue', () async {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete()]);
      controller.onPlayerRouteOpened();
      await controller.playCurrent();

      await controller.onPlayerRouteClosed();

      expect(controller.isEmpty, isTrue);
      expect(playback.currentItem, isNull);
    });

    test('queued audio does not write Continue Watching', () async {
      final playback = PlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      controller.replaceQueue([musicTrackComplete()]);
      controller.onPlayerRouteOpened();

      playback.simulateReadyForTest(musicTrackComplete());
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 2),
      );
      playback.notifyListeners();

      final entries = await playback.getContinueWatching(
        Catalog.fromJson(
          jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
        ),
      );
      expect(entries, isEmpty);
    });

    test('replaceQueue filters non-audio items', () {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);

      controller.replaceQueue([
        musicTrackComplete(),
        _video('v1'),
      ]);

      expect(controller.queue.length, 1);
    });

    test('setQueueForTest exposes model seam', () {
      final playback = _stubPlaybackService();
      final controller = MusicPlaybackQueueController(playbackService: playback);
      final queue = const PlaybackQueue.empty().replaceItems([
        _audio('a'),
        _audio('b'),
      ]);
      controller.setQueueForTest(queue);
      expect(controller.queue.length, 2);
    });
  });
}
