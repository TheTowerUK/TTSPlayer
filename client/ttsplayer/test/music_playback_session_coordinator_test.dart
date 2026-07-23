import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_album.dart';
import 'package:ttsplayer/features/music/models/music_artist.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'playback_service_extensions_test.dart';

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

MusicAlbum _album(List<MediaItem> tracks, {String groupKey = 'album-a'}) {
  final representative = List<MediaItem>.from(tracks)
    ..sort((a, b) => a.filePath.compareTo(b.filePath));
  return MusicAlbum(
    groupKey: groupKey,
    displayTitle: 'Album A',
    displayArtist: 'Artist',
    tracks: tracks,
    representativeTrack: representative.first,
  );
}

MusicArtist _artist(List<MusicAlbum> albums, {String groupKey = 'artist-a'}) {
  final flat = [for (final album in albums) ...album.tracks];
  return MusicArtist(
    groupKey: groupKey,
    displayName: 'Artist',
    albums: albums,
    tracks: flat,
    tracksInAlbumOrder: flat,
  );
}

PlaybackService _stubPlayback() {
  return PlaybackService(
    mediaKitInitOverride: (service, uri, generation) async {
      final fake = FakePlaybackSessionControls();
      fake.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(fake);
      final item = service.currentItem;
      if (item != null) {
        service.simulatePlaybackMetricsForTest(
          duration: const Duration(minutes: 5),
          position: Duration.zero,
        );
        service.simulateReadyForTest(item);
      }
    },
  );
}

Future<void> _primePlayback(
  PlaybackService playback,
  MusicPlaybackQueueController queue,
  MediaItem track, {
  Duration position = Duration.zero,
  bool playing = true,
}) async {
  await queue.playCurrent();
  playback.simulateReadyForTest(track);
  playback.simulatePlaybackMetricsForTest(
    duration: const Duration(minutes: 5),
    position: position,
  );
  playback.simulatePlayingForTest(playing: playing);
  playback.notifyListeners();
}

Future<Map<String, dynamic>?> _readEnvelope() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(MusicPlaybackSessionRepository.storageKey);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

Future<List<String>> _persistedQueueIds() async {
  final envelope = await _readEnvelope();
  if (envelope == null) return const [];
  final session = envelope['session'] as Map<String, dynamic>?;
  if (session == null) return const [];
  return (session['queueTrackIds'] as List<dynamic>).cast<String>();
}

Future<String?> _persistedActiveId() async {
  final envelope = await _readEnvelope();
  final session = envelope?['session'] as Map<String, dynamic>?;
  return session?['activeTrackId'] as String?;
}

Future<int?> _persistedPositionMs() async {
  final envelope = await _readEnvelope();
  final session = envelope?['session'] as Map<String, dynamic>?;
  return session?['playbackPositionMs'] as int?;
}

typedef SessionStack = ({
  PlaybackService playback,
  MusicPlaybackSessionRepository repository,
  MusicPlaybackQueueController queue,
  MusicPlaybackSessionCoordinator coordinator,
});

SessionStack _stack({
  DateTime Function()? now,
  Duration debounce = const Duration(milliseconds: 50),
  Duration positionInterval = const Duration(seconds: 5),
}) {
  final playback = _stubPlayback();
  final repository = MusicPlaybackSessionRepository();
  final queue = MusicPlaybackQueueController(playbackService: playback);
  final coordinator = MusicPlaybackSessionCoordinator(
    repository: repository,
    playbackService: playback,
    queueController: queue,
    now: now,
    queueMutationDebounce: debounce,
    positionPersistInterval: positionInterval,
  );
  return (
    playback: playback,
    repository: repository,
    queue: queue,
    coordinator: coordinator,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlaybackSessionCoordinator queue persistence', () {
    test('1 queue creation persists ordered IDs', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')]);
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['t-a', 't-b']);
      stack.coordinator.dispose();
    });

    test('2 queue replacement persists the new order', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('old-a'), _track('old-b')]);
      await stack.coordinator.drainPendingWrites();
      stack.queue
          .replaceQueue([_track('new-c'), _track('new-d'), _track('new-e')]);
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['new-c', 'new-d', 'new-e']);
      stack.coordinator.dispose();
    });

    test('3 add track persists updated queue', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a')]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();
      stack.queue.addTrack(_track('t-b'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['t-a', 't-b']);
      stack.coordinator.dispose();
    });

    test('4 remove track persists updated queue', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b'), _track('t-c')]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();
      stack.queue.removeTrack('t-b');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['t-a', 't-c']);
      stack.coordinator.dispose();
    });

    test('5 clear queue persists empty session', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a')]);
      await stack.coordinator.drainPendingWrites();
      stack.queue.clearQueueOnly();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), isEmpty);
      expect(await _persistedActiveId(), isNull);
      stack.coordinator.dispose();
    });

    test('6 play album persists its queue', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      final album = _album([
        _track('qa-t1'),
        _track('qa-t2'),
        _track('qa-t3'),
      ]);
      stack.queue.seedAlbumQueue(album, sourceIndex: 1);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['qa-t1', 'qa-t2', 'qa-t3']);
      expect(await _persistedActiveId(), 'qa-t2');
      stack.coordinator.dispose();
    });

    test('7 play artist persists its queue', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      final artist = _artist([
        _album([_track('a1'), _track('a2')], groupKey: 'album-1'),
        _album([_track('b1')], groupKey: 'album-2'),
      ]);
      stack.queue.seedArtistQueue(artist);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['a1', 'a2', 'b1']);
      stack.coordinator.dispose();
    });

    test('8 play selection persists its queue', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.seedSingleTrack(_track('sel-1'));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['sel-1']);
      expect(await _persistedActiveId(), 'sel-1');
      stack.coordinator.dispose();
    });

    test('13 queue mutation keeps active ID valid', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')], startIndex: 1);
      await stack.coordinator.drainPendingWrites();
      stack.queue.removeTrack('t-b');
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedActiveId(), 't-a');
      expect(await _persistedQueueIds(), ['t-a']);
      stack.coordinator.dispose();
    });

    test('20 rapid queue changes coalesce to the latest snapshot', () async {
      final stack = _stack(debounce: const Duration(milliseconds: 80));
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('v1')]);
      stack.queue.replaceQueue([_track('v2')]);
      stack.queue.replaceQueue([_track('v3-a'), _track('v3-b')]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['v3-a', 'v3-b']);
      stack.coordinator.dispose();
    });
  });

  group('MusicPlaybackSessionCoordinator active track persistence', () {
    test('9 user-selected track persists active ID', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')]);
      await stack.coordinator.drainPendingWrites();
      stack.queue.selectTrack('t-b');
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedActiveId(), 't-b');
      stack.coordinator.dispose();
    });

    test('10 next persists the new active ID', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')]);
      await _primePlayback(stack.playback, stack.queue, _track('t-a'));
      await stack.coordinator.drainPendingWrites();

      await stack.queue.next();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedActiveId(), 't-b');
      stack.coordinator.dispose();
    });

    test('11 previous persists the new active ID', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')], startIndex: 1);
      await _primePlayback(stack.playback, stack.queue, _track('t-b'));
      stack.playback.simulatePlaybackMetricsForTest(
        position: const Duration(seconds: 1),
      );
      stack.playback.notifyListeners();
      await stack.coordinator.drainPendingWrites();

      await stack.queue.previous();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedActiveId(), 't-a');
      stack.coordinator.dispose();
    });

    test('12 natural advancement persists the new active ID', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')]);
      await _primePlayback(stack.playback, stack.queue, _track('t-a'));
      await stack.coordinator.drainPendingWrites();

      stack.playback.simulatePlaybackMetricsForTest(completed: true);
      stack.playback.notifyListeners();
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedActiveId(), 't-b');
      stack.coordinator.dispose();
    });
  });

  group('MusicPlaybackSessionCoordinator position persistence', () {
    test('14 position events are throttled', () async {
      var now = DateTime.utc(2026, 7, 22, 12);
      final stack = _stack(
        now: () => now,
        positionInterval: const Duration(seconds: 5),
      );
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.seedSingleTrack(_track('t-a'));
      await _primePlayback(stack.playback, stack.queue, _track('t-a'));
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();
      expect(await _persistedPositionMs(), 0);

      now = now.add(const Duration(seconds: 2));
      stack.playback.simulatePlaybackMetricsForTest(
        position: const Duration(milliseconds: 1500),
      );
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();
      expect(await _persistedPositionMs(), 0);

      now = now.add(const Duration(seconds: 4));
      stack.playback.simulatePlaybackMetricsForTest(
        position: const Duration(milliseconds: 2500),
      );
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();
      expect(await _persistedPositionMs(), 2500);

      now = now.add(const Duration(seconds: 2));
      stack.playback.simulatePlaybackMetricsForTest(
        position: const Duration(milliseconds: 3500),
      );
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();
      expect(await _persistedPositionMs(), 2500);

      now = now.add(const Duration(seconds: 4));
      stack.playback.simulatePlaybackMetricsForTest(
        position: const Duration(milliseconds: 6500),
      );
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();
      expect(await _persistedPositionMs(), 6500);
      stack.coordinator.dispose();
    });

    test('15 position is stored in milliseconds', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.seedSingleTrack(_track('t-a'));
      await _primePlayback(
        stack.playback,
        stack.queue,
        _track('t-a'),
        position: const Duration(milliseconds: 4321),
      );
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedPositionMs(), 4321);
      stack.coordinator.dispose();
    });

    test('16 pause forces an immediate position save', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.seedSingleTrack(_track('t-a'));
      await _primePlayback(
        stack.playback,
        stack.queue,
        _track('t-a'),
        position: const Duration(seconds: 12),
      );
      await stack.coordinator.drainPendingWrites();

      stack.playback.simulatePlayingForTest(playing: false);
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedPositionMs(), 12000);
      stack.coordinator.dispose();
    });

    test('17 seek forces an immediate position save', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.seedSingleTrack(_track('t-a'));
      await _primePlayback(
        stack.playback,
        stack.queue,
        _track('t-a'),
        position: const Duration(seconds: 5),
      );
      await stack.coordinator.drainPendingWrites();

      stack.playback.simulatePlaybackMetricsForTest(
        position: const Duration(seconds: 45),
      );
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedPositionMs(), 45000);
      stack.coordinator.dispose();
    });

    test('18 stop forces snapshot without clearing queue', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('t-a'), _track('t-b')]);
      await _primePlayback(
        stack.playback,
        stack.queue,
        _track('t-a'),
        position: const Duration(seconds: 20),
      );
      await stack.coordinator.drainPendingWrites();

      await stack.playback.stop();
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['t-a', 't-b']);
      expect(await _persistedActiveId(), 't-a');
      expect(stack.queue.queue.length, 2);
      stack.coordinator.dispose();
    });
  });

  group('MusicPlaybackSessionCoordinator ordering and failure', () {
    test('19 newer immediate save cannot be overwritten by older delayed save',
        () async {
      final stack = _stack(debounce: const Duration(milliseconds: 150));
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.queue.replaceQueue([_track('old')]);
      stack.queue.replaceQueue([_track('new-a'), _track('new-b')]);
      stack.queue.selectTrack('new-b');
      await stack.coordinator.drainPendingWrites();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedActiveId(), 'new-b');
      expect(await _persistedQueueIds(), ['new-a', 'new-b']);
      stack.coordinator.dispose();
    });

    test('21 disposal cancels pending writes safely', () async {
      final stack = _stack(debounce: const Duration(milliseconds: 200));
      await stack.repository.initialize();
      stack.coordinator.attach();
      stack.queue.replaceQueue([_track('t-a')]);

      stack.coordinator.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(stack.coordinator.snapshotGenerationForTest, greaterThan(0));
    });

    test('22 persist failure does not interrupt playback', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();
      stack.repository.simulatePersistFailure = true;

      stack.queue.seedSingleTrack(_track('t-a'));
      await _primePlayback(stack.playback, stack.queue, _track('t-a'));
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      expect(stack.playback.isReady, isTrue);
      expect(stack.coordinator.persistenceWarningPresent, isTrue);
      stack.coordinator.dispose();
    });

    test('23 later mutation retries successfully after failure', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();

      stack.repository.simulatePersistFailure = true;
      stack.queue.seedSingleTrack(_track('fail-track'));
      await stack.coordinator.drainPendingWrites();
      expect(await _persistedQueueIds(), isEmpty);

      stack.repository.simulatePersistFailure = false;
      stack.queue.replaceQueue([_track('retry-a'), _track('retry-b')]);
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['retry-a', 'retry-b']);
      stack.coordinator.dispose();
    });

    test('24 listening-history storage remains unchanged', () async {
      final listeningRaw = jsonEncode({
        'stateVersion': 1,
        'records': [
          {
            'trackId': 'hist-1',
            'title': 'Song',
            'artist': 'Artist',
            'album': 'Album',
            'lastPosition': 45,
            'completed': false,
            'lastPlayedAt': '2026-07-22T12:00:00.000Z',
          },
        ],
      });
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: listeningRaw,
      });

      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();
      stack.queue.replaceQueue([_track('t-a'), _track('t-b')]);
      await stack.coordinator.drainPendingWrites();

      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString(MusicListeningRepository.storageKey), listeningRaw);
      stack.coordinator.dispose();
    });

    test('25 video resume storage remains unchanged', () async {
      SharedPreferences.setMockInitialValues({
        'position_video-1': 120,
        'duration_video-1': 3600,
      });

      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.attach();
      stack.queue.seedSingleTrack(_track('t-a'));
      await stack.coordinator.drainPendingWrites();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_video-1'), 120);
      expect(prefs.getInt('duration_video-1'), 3600);
      stack.coordinator.dispose();
    });

    test('26 no startup restoration occurs in this step', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'session': {
            'queueTrackIds': ['stored-a', 'stored-b'],
            'activeTrackId': 'stored-b',
            'playbackPositionMs': 9000,
            'updatedAt': '2026-07-22T12:00:00.000Z',
          },
        }),
      });

      final playback = _stubPlayback();
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = MusicPlaybackSessionCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      coordinator.attach();

      expect(queue.isEmpty, isTrue);
      expect(queue.currentTrack, isNull);
      expect(repository.session.queueTrackIds, ['stored-a', 'stored-b']);

      coordinator.dispose();
    });
  });
}
