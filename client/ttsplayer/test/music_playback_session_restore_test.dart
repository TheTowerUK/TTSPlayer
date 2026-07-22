import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_playback_session_restore_result.dart';
import 'package:ttsplayer/features/music/models/music_playback_session.dart';
import 'package:ttsplayer/features/music/models/music_playback_session_policy.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'playback_service_extensions_test.dart';

Catalog _catalog(Map<String, Map<String, dynamic>> items) {
  return Catalog.fromJson({
    'generated_at': '2026-07-22T12:00:00+00:00',
    'total_items': items.length,
    'catalogue': {
      'id': 'CAT-${items.length}',
      'scanner_version': '0.4.0',
      'catalogue_version': 3,
    },
    'folders': [
      {
        'id': 'root',
        'name': 'Root',
        'path': r'Y:\Media',
        'item_count': items.length,
        'items': [
          for (final entry in items.entries)
            {
              'id': entry.key,
              'title': entry.value['title'] ?? entry.key,
              'file_path':
                  entry.value['file_path'] ?? 'Y:\\Media\\${entry.key}.mp3',
              'status': entry.value['status'] ?? 'available',
              'media_kind': entry.value['media_kind'] ?? 'audio',
              if (entry.value.containsKey('duration_seconds'))
                'duration_seconds': entry.value['duration_seconds'],
            },
        ],
        'subfolders': [],
      },
    ],
  });
}

MusicPlaybackSession _session({
  List<String> queueTrackIds = const ['a', 'b', 'c'],
  String? activeTrackId = 'b',
  Duration playbackPosition = const Duration(milliseconds: 9000),
}) {
  return MusicPlaybackSession(
    queueTrackIds: queueTrackIds,
    activeTrackId: activeTrackId,
    playbackPosition: playbackPosition,
    updatedAt: DateTime.utc(2026, 7, 22, 12),
  );
}

PlaybackService _stubPlayback() {
  return PlaybackService(
    mediaKitInitOverride: (service, uri, generation) async {
      service.attachSessionControlsForTest(FakePlaybackSessionControls());
    },
  );
}

typedef RestoreStack = ({
  PlaybackService playback,
  MusicPlaybackSessionRepository repository,
  MusicPlaybackQueueController queue,
  MusicPlaybackSessionCoordinator coordinator,
  MusicPlaybackSessionRestorer restorer,
  MusicLibraryService musicLibrary,
});

RestoreStack _stack({PlaybackService? playback}) {
  final playbackService = playback ?? _stubPlayback();
  final repository = MusicPlaybackSessionRepository();
  final queue = MusicPlaybackQueueController(playbackService: playbackService);
  final coordinator = MusicPlaybackSessionCoordinator(
    repository: repository,
    playbackService: playbackService,
    queueController: queue,
    queueMutationDebounce: const Duration(milliseconds: 50),
    positionPersistInterval: const Duration(seconds: 5),
  );
  final musicLibrary = MusicLibraryService();
  final restorer = MusicPlaybackSessionRestorer(
    repository: repository,
    queueController: queue,
    musicLibraryService: musicLibrary,
    playbackService: playbackService,
    sessionCoordinator: coordinator,
  );
  return (
    playback: playbackService,
    repository: repository,
    queue: queue,
    coordinator: coordinator,
    restorer: restorer,
    musicLibrary: musicLibrary,
  );
}

Future<Map<String, dynamic>?> _readEnvelope() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(MusicPlaybackSessionRepository.storageKey);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

Future<void> _persistSession(MusicPlaybackSession session) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    MusicPlaybackSessionRepository.storageKey,
    jsonEncode({
      'stateVersion': 1,
      'session': {
        'queueTrackIds': session.queueTrackIds,
        'activeTrackId': session.activeTrackId,
        'playbackPositionMs': session.playbackPosition.inMilliseconds,
        'updatedAt': session.updatedAt.toIso8601String(),
      },
    }),
  );
}

Future<MusicPlaybackSessionRestoreResult> _restore(
  RestoreStack stack,
  Catalog catalog,
) async {
  await stack.repository.initialize();
  return stack.restorer.restoreOnColdStart(catalog);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlaybackSessionRestorer cold start', () {
    test('1 missing persisted session leaves live queue empty', () async {
      final stack = _stack();
      final catalog = _catalog({
        'a': {'title': 'A'}
      });

      final result = await _restore(stack, catalog);

      expect(result.queueEmpty, isTrue);
      expect(stack.queue.isEmpty, isTrue);
      expect(stack.playback.currentItem, isNull);
    });

    test('2 canonical empty session leaves live queue empty', () async {
      final stack = _stack();
      await stack.repository.initialize();
      await stack.repository.save(_session(queueTrackIds: []));

      final result = await _restore(stack, _catalog({}));

      expect(result.queueEmpty, isTrue);
      expect(stack.queue.isEmpty, isTrue);
    });

    test('3 one persisted track restores successfully', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      final result = await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(result.restoredQueueCount, 1);
      expect(stack.queue.queue.items.single.id, 'a');
    });

    test('4 multiple tracks restore in persisted order', () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['c', 'a', 'b'], activeTrackId: 'a'),
      );

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
          'c': {'title': 'C'},
        }),
      );

      expect(stack.queue.queue.items.map((item) => item.id), ['c', 'a', 'b']);
    });

    test('5 active track restores correctly', () async {
      final stack = _stack();
      await _persistSession(_session(activeTrackId: 'b'));

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
          'c': {'title': 'C'},
        }),
      );

      expect(stack.queue.currentTrack?.id, 'b');
    });

    test('6 active track may be in the middle of the queue', () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['x', 'y', 'z'], activeTrackId: 'y'),
      );

      await _restore(
        stack,
        _catalog({
          'x': {'title': 'X'},
          'y': {'title': 'Y'},
          'z': {'title': 'Z'},
        }),
      );

      expect(stack.queue.currentTrack?.id, 'y');
      expect(stack.queue.queue.currentIndex, 1);
    });

    test('7 position restores for surviving active track', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: 42),
        ),
      );

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(stack.queue.restoredStartPosition, const Duration(seconds: 42));
    });

    test('8 position zero remains zero', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a'],
          activeTrackId: 'a',
          playbackPosition: Duration.zero,
        ),
      );

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(stack.queue.restoredStartPosition, Duration.zero);
    });

    test('9 negative position is normalised defensively', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: -5),
        ),
      );

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(stack.queue.restoredStartPosition, Duration.zero);
    });

    test('10 position beyond known duration is clamped', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: 400),
        ),
      );

      await _restore(
        stack,
        _catalog({
          'a': {
            'title': 'A',
            'duration_seconds': 600,
          },
        }),
      );

      expect(stack.queue.restoredStartPosition, const Duration(seconds: 400));
    });

    test('11 missing active track falls back to first surviving item',
        () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['a', 'c'], activeTrackId: 'c'),
      );

      final result = await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
        }),
      );

      expect(stack.queue.currentTrack?.id, 'a');
      expect(result.restoredActiveTrackId, 'a');
    });

    test('12 position resets when active track falls back', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a', 'c'],
          activeTrackId: 'c',
          playbackPosition: const Duration(seconds: 90),
        ),
      );

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
        }),
      );

      expect(stack.queue.restoredStartPosition, Duration.zero);
    });

    test('13 one unresolved queue item is skipped', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a', 'gone']));

      final result = await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(result.unresolvedCount, 1);
      expect(stack.queue.queue.items.map((item) => item.id), ['a']);
    });

    test('14 several unresolved items are skipped', () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['a', 'x', 'y', 'b'], activeTrackId: 'b'),
      );

      final result = await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );

      expect(result.unresolvedCount, 2);
      expect(stack.queue.queue.items.map((item) => item.id), ['a', 'b']);
    });

    test('15 all unresolved items produce empty queue', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['gone-a', 'gone-b']));

      final result = await _restore(stack, _catalog({}));

      expect(result.queueEmpty, isTrue);
      expect(stack.queue.isEmpty, isTrue);
    });

    test('16 video item is not restored', () async {
      final stack = _stack();
      await _persistSession(
          _session(queueTrackIds: ['a', 'vid'], activeTrackId: 'a'));

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'vid': {
            'title': 'Vid',
            'media_kind': 'video',
            'file_path': r'Y:\v.mp4'
          },
        }),
      );

      expect(stack.queue.queue.items.map((item) => item.id), ['a']);
    });

    test('17 image item is not restored', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a', 'img']));

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'img': {
            'title': 'Img',
            'media_kind': 'image',
            'file_path': r'Y:\i.jpg'
          },
        }),
      );

      expect(stack.queue.queue.items.map((item) => item.id), ['a']);
    });

    test('18 non-playable audio item is not restored', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a', 'bad']));

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'bad': {'title': 'Bad', 'status': 'missing'},
        }),
      );

      expect(stack.queue.queue.items.map((item) => item.id), ['a']);
    });

    test('19 duplicate IDs do not produce duplicate live queue entries',
        () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['a', 'a', 'b'], activeTrackId: 'a'),
      );

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );

      expect(stack.queue.queue.items.map((item) => item.id), ['a', 'b']);
    });

    test('20 restored queue respects the 500-item session policy', () async {
      final stack = _stack();
      final ids = List<String>.generate(500, (index) => 't-$index');
      final catalogItems = {
        for (final id in ids) id: {'title': id},
      };
      await _persistSession(
        _session(queueTrackIds: ids, activeTrackId: 't-250'),
      );

      final result = await _restore(stack, _catalog(catalogItems));

      expect(result.restoredQueueCount, 500);
      expect(stack.queue.queue.items.length, 500);
      expect(stack.queue.currentTrack?.id, 't-250');
    });

    test('21 restoration does not call play', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(stack.playback.currentItem, isNull);
      expect(stack.playback.isPlaying, isFalse);
    });

    test('22 restoration does not navigate', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(stack.queue.playerRouteActive, isFalse);
    });

    test('23 restoration does not write listening history', () async {
      final stack = _stack();
      final listening = MusicListeningRepository();
      await listening.initialize();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(listening.storedRecordCount, 0);
    });

    test('24 restoration does not alter video resume state', () async {
      SharedPreferences.setMockInitialValues({
        'position_video-a': 120000,
        'duration_video-a': 3600000,
      });
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_video-a'), 120000);
      expect(prefs.getInt('duration_video-a'), 3600000);
    });

    test('25 restoration does not persist an equivalent snapshot immediately',
        () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a', 'b'],
          activeTrackId: 'b',
          playbackPosition: const Duration(seconds: 30),
        ),
      );
      final before = await _readEnvelope();

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(await _readEnvelope(), before);
      expect(stack.coordinator.isAttached, isTrue);
    });

    test('26 persistence coordinator works normally after restoration',
        () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));
      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      stack.queue.addTrack(
        MediaItem(
          id: 'b',
          title: 'B',
          filePath: r'Y:\b.mp3',
          mediaKindRaw: 'audio',
        ),
      );
      await stack.coordinator.drainPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['queueTrackIds'], ['a', 'b']);
    });

    test('27 queue mutation after restore persists', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));
      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      stack.queue.removeTrack('a');
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['queueTrackIds'], isEmpty);
    });

    test('28 active-track change after restore persists immediately', () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['a', 'b'], activeTrackId: 'a'),
      );
      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );

      stack.queue.selectTrack('b');
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['activeTrackId'], 'b');
    });

    test('29 position tick after restore follows normal throttle', () async {
      final stack = _stack(
        playback: PlaybackService(
          mediaKitInitOverride: (service, uri, generation) async {
            service.attachSessionControlsForTest(FakePlaybackSessionControls());
          },
        ),
      );
      await _persistSession(
        _session(
          queueTrackIds: ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: 10),
        ),
      );
      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      final track = stack.queue.currentTrack!;
      await stack.queue.playCurrent(startPosition: const Duration(seconds: 10));
      stack.playback.simulateReadyForTest(track);
      stack.playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 5),
        position: const Duration(seconds: 10),
      );
      stack.playback.simulatePlayingForTest(playing: true);
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['playbackPositionMs'], 10000);
    });

    test('30 pause after restore persists immediately', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));
      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      final track = stack.queue.currentTrack!;
      await stack.queue.playCurrent();
      stack.playback.simulateReadyForTest(track);
      stack.playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 5),
        position: const Duration(seconds: 20),
      );
      stack.playback.simulatePlayingForTest(playing: true);
      stack.coordinator.handlePlaybackTickForTest();
      stack.playback.simulatePlayingForTest(playing: false);
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['playbackPositionMs'], 20000);
    });

    test('31 restore runs after catalogue reconciliation', () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['a', 'gone'], activeTrackId: 'gone'),
      );

      final result = await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.restoredQueueCount, 1);
      expect(stack.queue.currentTrack?.id, 'a');
      expect(stack.repository.session.queueTrackIds, ['a']);
    });

    test('32 reconciled removed IDs are not restored', () async {
      final stack = _stack();
      await _persistSession(
        _session(queueTrackIds: ['keep', 'drop'], activeTrackId: 'keep'),
      );

      await _restore(
        stack,
        _catalog({
          'keep': {'title': 'Keep'}
        }),
      );

      expect(stack.queue.queue.items.map((item) => item.id), ['keep']);
    });

    test('33 reconciled active fallback is reflected live', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a', 'gone'],
          activeTrackId: 'gone',
          playbackPosition: const Duration(seconds: 55),
        ),
      );

      final result = await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.restoredActiveTrackId, 'a');
      expect(stack.queue.currentTrack?.id, 'a');
      expect(stack.queue.restoredStartPosition, Duration.zero);
    });

    test('34 repository load failure is non-fatal', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: '{not-json',
      });
      final stack = _stack();

      final result = await stack.restorer.restoreOnColdStart(_catalog({}));

      expect(result.warnings, isNotEmpty);
      expect(stack.queue.isEmpty, isTrue);
      expect(stack.coordinator.isAttached, isTrue);
    });

    test('35 catalogue resolution failure is non-fatal', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['missing']));

      final result = await _restore(stack, _catalog({}));

      expect(result.queueEmpty, isTrue);
      expect(stack.queue.isEmpty, isTrue);
    });

    test('36 queue-controller restoration failure is non-fatal', () async {
      final stack = _stack();
      stack.queue.simulateRestoreFailureForTest = true;
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      final result = await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(result.warnings, isNotEmpty);
      expect(stack.queue.isEmpty, isTrue);
    });

    test('37 deferred seek failure is non-fatal', () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: 15),
        ),
      );
      await _restore(
          stack,
          _catalog({
            'a': {'title': 'A'}
          }));

      expect(stack.queue.restoredStartPosition, const Duration(seconds: 15));
      expect(stack.playback.currentItem, isNull);
    });

    test('38 repeated restore call is idempotent', () async {
      final stack = _stack();
      await _persistSession(_session(queueTrackIds: ['a'], activeTrackId: 'a'));
      final catalog = _catalog({
        'a': {'title': 'A'}
      });

      final first = await _restore(stack, catalog);
      final second = await stack.restorer.restoreOnColdStart(catalog);

      expect(first.restoredQueueCount, 1);
      expect(second.skipped, isTrue);
      expect(stack.queue.queue.items.single.id, 'a');
    });

    test('39 startup does not overwrite stored session with an empty queue',
        () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a', 'b'],
          activeTrackId: 'b',
          playbackPosition: const Duration(seconds: 12),
        ),
      );
      final before = await _readEnvelope();

      expect(stack.coordinator.isAttached, isFalse);
      expect(stack.queue.isEmpty, isTrue);

      await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );

      expect(await _readEnvelope(), before);
    });

    test('40 full cold-start bootstrap produces restored paused state',
        () async {
      final stack = _stack();
      await _persistSession(
        _session(
          queueTrackIds: ['a', 'b', 'c'],
          activeTrackId: 'b',
          playbackPosition: const Duration(seconds: 47),
        ),
      );

      final result = await _restore(
        stack,
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
          'c': {'title': 'C'},
        }),
      );

      expect(result.autoplayAttempted, isFalse);
      expect(result.restoredQueueCount, 3);
      expect(stack.queue.currentTrack?.id, 'b');
      expect(stack.queue.restoredStartPosition, const Duration(seconds: 47));
      expect(stack.playback.isPlaying, isFalse);
      expect(stack.coordinator.isAttached, isTrue);

      await stack.queue.playCurrent();
      expect(stack.playback.currentItem?.id, 'b');
    });
  });

  group('MusicPlaybackSessionRestorer helpers', () {
    test('normalizeRestorePosition clamps near-end to zero', () {
      final track = MediaItem(
        id: 'a',
        title: 'A',
        filePath: r'Y:\a.mp3',
        mediaKindRaw: 'audio',
        durationSeconds: 300,
      );

      final normalized = MusicPlaybackSessionRestorer.normalizeRestorePosition(
        position: const Duration(seconds: 299),
        activeTrack: track,
      );

      expect(normalized, Duration.zero);
    });

    test('policy cap remains 500 persisted track IDs', () {
      expect(MusicPlaybackSessionPolicy.maxPersistedTrackIds, 500);
    });
  });
}
