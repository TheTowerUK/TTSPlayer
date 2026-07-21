import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/services/music_listening_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'playback_service_extensions_test.dart';

MediaItem _audio(String id, {String title = 'Track'}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
    artist: 'Artist',
    album: 'Album',
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

MediaItem _track(String id, {String title = 'Track'}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
    artist: 'Artist',
    album: 'Album',
  );
}

Future<void> _primeAudioPlayback(
  PlaybackService playback,
  MusicPlaybackQueueController queue,
  MediaItem track,
  MusicListeningCoordinator coordinator, {
  Duration position = Duration.zero,
  Duration duration = const Duration(minutes: 4),
  bool playing = true,
}) async {
  await queue.playCurrent();
  playback.simulateReadyForTest(track);
  playback.simulatePlaybackMetricsForTest(
    duration: duration,
    position: position,
    completed: false,
  );
  playback.simulatePlayingForTest(playing: playing);
  playback.notifyListeners();
  await coordinator.waitForIdleForTest();
}

Future<void> _tick(
  MusicListeningCoordinator coordinator,
  PlaybackService playback, {
  required Duration position,
  bool? playing,
  bool completed = false,
}) async {
  playback.simulatePlaybackMetricsForTest(
    position: position,
    completed: completed,
  );
  if (playing != null) {
    playback.simulatePlayingForTest(playing: playing);
  }
  coordinator.handlePlaybackTickForTest();
  await coordinator.waitForIdleForTest();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicListeningCoordinator threshold', () {
    test('play 14 seconds then stop creates no record', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 14; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await _tick(
        coordinator,
        playback,
        position: const Duration(seconds: 14),
        playing: false,
      );
      await queue.onPlayerRouteClosed();
      await coordinator.waitForIdleForTest();

      expect(repository.allRecords, isEmpty);
      coordinator.dispose();
    });

    test('crossing 15 seconds creates a record', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 16; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await coordinator.waitForIdleForTest();

      expect(repository.getByTrackId('track-a'), isNotNull);
      coordinator.dispose();
    });

    test('paused time does not count toward creation threshold', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 10; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await _tick(
        coordinator,
        playback,
        position: const Duration(seconds: 10),
        playing: false,
      );
      now = now.add(const Duration(minutes: 5));

      for (var i = 11; i <= 14; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
          playing: true,
        );
      }

      await coordinator.waitForIdleForTest();

      expect(repository.allRecords, isEmpty);
      coordinator.dispose();
    });

    test('seek beyond 15 seconds without playing does not create a record',
        () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(
        playback,
        queue,
        track,
        coordinator,
        playing: false,
      );

      await _tick(
        coordinator,
        playback,
        position: const Duration(seconds: 45),
        playing: false,
      );

      await coordinator.waitForIdleForTest();

      expect(repository.allRecords, isEmpty);
      coordinator.dispose();
    });

    test('existing record updates before creation threshold is crossed again',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        MusicListeningRecord(
          trackId: 'track-a',
          title: 'Track',
          artist: 'Artist',
          album: 'Album',
          lastPosition: const Duration(seconds: 40),
          completed: false,
          lastPlayedAt: DateTime.utc(2026, 7, 20),
        ),
      );

      final playback = _stubPlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      await _tick(
        coordinator,
        playback,
        position: const Duration(seconds: 42),
      );

      await coordinator.waitForIdleForTest();

      expect(repository.getByTrackId('track-a')?.lastPosition,
          const Duration(seconds: 42));
      coordinator.dispose();
    });
  });

  group('MusicListeningCoordinator throttle', () {
    test('persists at most once per 5 seconds during continuous playback',
        () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await coordinator.waitForIdleForTest();
      final record = repository.getByTrackId('track-a');
      expect(record, isNotNull);
      expect(record!.lastPosition.inSeconds, greaterThanOrEqualTo(15));
      coordinator.dispose();
    });

    test('pause flush bypasses throttle', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 16; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await coordinator.waitForIdleForTest();

      now = now.add(const Duration(seconds: 1));
      await _tick(
        coordinator,
        playback,
        position: const Duration(seconds: 17),
        playing: false,
      );

      await coordinator.waitForIdleForTest();

      expect(
        repository.getByTrackId('track-a')?.lastPosition,
        const Duration(seconds: 17),
      );
      coordinator.dispose();
    });
  });

  group('MusicListeningCoordinator lifecycle', () {
    test('manual next flushes previous track as incomplete', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final trackA = _track('track-a', title: 'A');
      final trackB = _track('track-b', title: 'B');
      queue.replaceQueue([trackA, trackB], startIndex: 0);
      await _primeAudioPlayback(playback, queue, trackA, coordinator);

      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await queue.next();
      playback.simulateReadyForTest(trackB);
      playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: Duration.zero,
      );
      playback.simulatePlayingForTest(playing: true);
      playback.notifyListeners();
      await coordinator.waitForIdleForTest();

      final recordA = repository.getByTrackId('track-a');
      expect(recordA, isNotNull);
      expect(recordA!.completed, isFalse);
      expect(recordA.lastPosition.inSeconds, greaterThanOrEqualTo(15));
      coordinator.dispose();
    });

    test('no writes after coordinator disposal', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);
      coordinator.dispose();

      playback.simulatePlaybackMetricsForTest(
          position: const Duration(seconds: 30));
      coordinator.handlePlaybackTickForTest();

      expect(repository.allRecords, isEmpty);
    });
  });

  group('MusicListeningCoordinator completion', () {
    test('natural completion marks completed and clears active session',
        () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await _tick(
        coordinator,
        playback,
        position: const Duration(minutes: 4),
        playing: false,
        completed: true,
      );

      await coordinator.waitForIdleForTest();

      final record = repository.getByTrackId('track-a');
      expect(record?.completed, isTrue);
      expect(record?.lastPosition, Duration.zero);
      expect(record?.completedAt, isNotNull);
      coordinator.dispose();
    });

    test('manual next does not mark previous track completed', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      queue.replaceQueue([_track('track-a'), _track('track-b')]);
      await _primeAudioPlayback(
          playback, queue, _track('track-a'), coordinator);

      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await queue.next();
      await coordinator.waitForIdleForTest();
      expect(repository.getByTrackId('track-a')?.completed, isFalse);
      coordinator.dispose();
    });
  });

  group('MusicListeningCoordinator existing records', () {
    test('completed track remains completed before 15 seconds of replay',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        MusicListeningRecord(
          trackId: 'track-a',
          title: 'Track',
          artist: 'Artist',
          album: 'Album',
          lastPosition: Duration.zero,
          completed: true,
          completedAt: DateTime.utc(2026, 7, 20),
          lastPlayedAt: DateTime.utc(2026, 7, 20),
        ),
      );

      final playback = _stubPlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 10; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await _tick(
        coordinator,
        playback,
        position: const Duration(seconds: 10),
        playing: false,
      );

      await coordinator.waitForIdleForTest();

      expect(repository.getByTrackId('track-a')?.completed, isTrue);
      coordinator.dispose();
    });

    test(
        'completed track becomes incomplete after 15 seconds of meaningful replay',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        MusicListeningRecord(
          trackId: 'track-a',
          title: 'Track',
          artist: 'Artist',
          album: 'Album',
          lastPosition: Duration.zero,
          completed: true,
          completedAt: DateTime.utc(2026, 7, 20),
          lastPlayedAt: DateTime.utc(2026, 7, 20),
        ),
      );

      final playback = _stubPlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 16; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await coordinator.waitForIdleForTest();

      expect(repository.getByTrackId('track-a')?.completed, isFalse);
      coordinator.dispose();
    });
  });

  group('MusicListeningCoordinator failure isolation', () {
    test('repository failure does not throw and later write succeeds',
        () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      repository.simulatePersistFailure = true;
      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 16; i++) {
        now = now.add(const Duration(seconds: 1));
        playback.simulatePlaybackMetricsForTest(position: Duration(seconds: i));
        expect(() => coordinator.handlePlaybackTickForTest(), returnsNormally);
        await coordinator.waitForIdleForTest();
      }

      expect(coordinator.lastPersistenceWarning, isNotNull);
      repository.simulatePersistFailure = false;
      playback.simulatePlaybackMetricsForTest(
          position: const Duration(seconds: 17));
      coordinator.handlePlaybackTickForTest();
      await coordinator.waitForIdleForTest();
      expect(repository.getByTrackId('track-a'), isNotNull);
      coordinator.dispose();
    });
  });

  group('MusicListeningCoordinator video regression', () {
    test('video keys remain unchanged during audio listening', () async {
      const videoId = 'video-1';
      SharedPreferences.setMockInitialValues({
        'position_$videoId': 90,
        'duration_$videoId': 3600,
      });

      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final track = _track('track-a');
      queue.seedSingleTrack(track);
      await _primeAudioPlayback(playback, queue, track, coordinator);

      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await coordinator.waitForIdleForTest();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoId'), 90);
      expect(prefs.getInt('duration_$videoId'), 3600);
      expect(prefs.containsKey('position_track-a'), isFalse);
      expect(prefs.containsKey('duration_track-a'), isFalse);
      coordinator.dispose();
    });
  });

  group('MusicListeningCoordinator integration', () {
    test('natural completion persists track A before queue advances to track B',
        () async {
      SharedPreferences.setMockInitialValues({});
      final playback = _stubPlaybackService();
      final repository = MusicListeningRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var now = DateTime.utc(2026, 7, 21, 12);
      final coordinator = MusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        now: () => now,
      );
      queue.pendingListeningWriteDrain = coordinator.drainPendingWrites;
      coordinator.attach();

      final trackA = _audio('track-a', title: 'A');
      final trackB = _audio('track-b', title: 'B');
      queue.replaceQueue([trackA, trackB], startIndex: 0);
      await _primeAudioPlayback(playback, queue, trackA, coordinator);

      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        await _tick(
          coordinator,
          playback,
          position: Duration(seconds: i),
        );
      }

      await _tick(
        coordinator,
        playback,
        position: const Duration(minutes: 3),
        playing: false,
        completed: true,
      );
      playback.notifyListeners();

      await coordinator.waitForIdleForTest();
      await pumpEventQueue();

      final recordA = repository.getByTrackId('track-a');
      expect(recordA?.completed, isTrue);

      if (queue.currentTrack?.id == 'track-b') {
        expect(
            coordinator.accumulatedListeningForTest('track-b'), Duration.zero);
      }

      coordinator.dispose();
    });
  });
}
