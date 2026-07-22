import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/widgets/music_playback_session_lifecycle_observer.dart';

import 'playback_service_extensions_test.dart';

MediaItem _track(String id) {
  return MediaItem(
    id: id,
    title: 'Track $id',
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
  );
}

Future<Map<String, dynamic>?> _readEnvelope() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(MusicPlaybackSessionRepository.storageKey);
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

Future<List<String>> _persistedQueueIds() async {
  final envelope = await _readEnvelope();
  final session = envelope?['session'] as Map<String, dynamic>?;
  if (session == null) return const [];
  return (session['queueTrackIds'] as List<dynamic>).cast<String>();
}

typedef LifecycleStack = ({
  PlaybackService playback,
  MusicPlaybackSessionRepository repository,
  MusicPlaybackQueueController queue,
  MusicPlaybackSessionCoordinator coordinator,
});

LifecycleStack _stack({bool deferPersistence = false}) {
  final playback = PlaybackService(
    mediaKitInitOverride: (service, uri, generation) async {
      service.attachSessionControlsForTest(FakePlaybackSessionControls());
    },
  );
  final repository = MusicPlaybackSessionRepository();
  final queue = MusicPlaybackQueueController(playbackService: playback);
  final coordinator = MusicPlaybackSessionCoordinator(
    repository: repository,
    playbackService: playback,
    queueController: queue,
    queueMutationDebounce: const Duration(milliseconds: 50),
  );
  coordinator.attach(deferPersistenceUntilColdStartComplete: deferPersistence);
  return (
    playback: playback,
    repository: repository,
    queue: queue,
    coordinator: coordinator,
  );
}

Future<void> _primePlayback(
  LifecycleStack stack,
  MediaItem track, {
  Duration position = const Duration(seconds: 30),
}) async {
  stack.queue.replaceQueue([track]);
  await stack.queue.playCurrent();
  stack.playback.simulateReadyForTest(track);
  stack.playback.simulatePlaybackMetricsForTest(
    duration: const Duration(minutes: 5),
    position: position,
  );
  stack.playback.simulatePlayingForTest(playing: false);
  stack.playback.notifyListeners();
  stack.coordinator.handlePlaybackTickForTest();
  await stack.coordinator.drainPendingWrites();
}

Future<void> _emitLifecycle(
  WidgetTester tester,
  AppLifecycleState state,
) async {
  final observerState = tester.state(
    find.byType(MusicPlaybackSessionLifecycleObserver),
  );
  (observerState as dynamic).handleAppLifecycleStateChangedForTest(state);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlaybackSessionLifecycleObserver', () {
    testWidgets('1 inactive triggers immediate persistence', (tester) async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.inactive);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['a']);
    });

    testWidgets('2 paused triggers immediate persistence', (tester) async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('b'), _track('c')], startIndex: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.paused);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['b', 'c']);
    });

    testWidgets('3 detached triggers persistence', (tester) async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('d')]);

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.detached);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['d']);
    });

    testWidgets('4 hidden triggers persistence', (tester) async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('h')]);

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.hidden);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['h']);
    });

    testWidgets('5 repeated equivalent lifecycle event avoids redundant writes',
        (tester) async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.inactive);
      await stack.coordinator.drainPendingWrites();
      final first = await _readEnvelope();

      await _emitLifecycle(tester, AppLifecycleState.paused);
      await stack.coordinator.drainPendingWrites();
      final second = await _readEnvelope();

      expect(first, isNotNull);
      expect(second, equals(first));
    });

    testWidgets('14 lifecycle before cold-start restore does not overwrite',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'session': {
            'queueTrackIds': ['stored'],
            'activeTrackId': 'stored',
            'playbackPositionMs': 12000,
            'updatedAt': '2026-07-22T12:00:00Z',
          },
        }),
      });

      final stack = _stack(deferPersistence: true);
      await stack.repository.initialize();
      final before = await _readEnvelope();

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.inactive);
      await stack.coordinator.drainPendingWrites();

      expect(await _readEnvelope(), before);
      expect(stack.queue.isEmpty, isTrue);
    });

    testWidgets('15 lifecycle after restore persists normally', (tester) async {
      final stack = _stack(deferPersistence: true);
      await stack.repository.initialize();
      stack.queue.replaceQueue([_track('live')]);
      stack.coordinator.enablePersistenceAfterColdStartRestore();

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await _emitLifecycle(tester, AppLifecycleState.paused);
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['live']);
    });

    testWidgets('19 disposal removes lifecycle observer safely',
        (tester) async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: stack.coordinator,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await stack.coordinator.drainPendingWrites();
      expect(await _readEnvelope(), isNull);
    });
  });

  group('MusicPlaybackSessionCoordinator lifecycle persistence', () {
    test('7 lifecycle bypasses position throttle', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      final track = _track('a');
      stack.queue.replaceQueue([track]);
      await stack.queue.playCurrent();
      stack.playback.simulateReadyForTest(track);
      stack.playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 5),
        position: const Duration(seconds: 10),
      );
      stack.playback.simulatePlayingForTest(playing: true);
      stack.coordinator.handlePlaybackTickForTest();
      await stack.coordinator.drainPendingWrites();

      stack.playback.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 5),
        position: const Duration(seconds: 12),
      );
      stack.coordinator.handlePlaybackTickForTest();

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['playbackPositionMs'], 12000);
    });

    test('8 lifecycle cancels pending queue debounce', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);
      stack.queue.addTrack(_track('b'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['a', 'b']);
    });

    test('9 latest queue snapshot is persisted', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('x'), _track('y'), _track('z')]);

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['x', 'y', 'z']);
    });

    test('10 latest active track is persisted', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a'), _track('b')], startIndex: 1);

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['activeTrackId'], 'b');
    });

    test('11 latest playback position is persisted', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      await _primePlayback(stack, _track('a'),
          position: const Duration(seconds: 47));

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      final session = envelope!['session'] as Map<String, dynamic>;
      expect(session['playbackPositionMs'], 47000);
    });

    test('12 stopped playback retains queue in persisted session', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a'), _track('b')]);
      await stack.playback.stop();

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['a', 'b']);
    });

    test('13 empty live queue persists canonical empty session', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      final envelope = await _readEnvelope();
      expect(envelope, isNull);
      expect(stack.repository.session.isEmpty, isTrue);
    });

    test('16 persistence failure is non-fatal', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);
      stack.repository.simulatePersistFailure = true;

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(stack.coordinator.persistenceWarningPresent, isTrue);
      expect(stack.queue.queue.items.single.id, 'a');
    });

    test('17 warning state updates after lifecycle failure', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);
      stack.repository.simulatePersistFailure = true;

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(stack.coordinator.lastPersistenceWarning, isNotNull);
    });

    test('18 later lifecycle event retries successfully', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);
      stack.repository.simulatePersistFailure = true;

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();
      stack.repository.simulatePersistFailure = false;

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(await _persistedQueueIds(), ['a']);
      expect(stack.coordinator.persistenceWarningPresent, isFalse);
    });

    test('20 no playback command is issued by lifecycle persistence', () async {
      final stack = _stack();
      await stack.repository.initialize();
      stack.coordinator.enablePersistenceAfterColdStartRestore();
      stack.queue.replaceQueue([_track('a')]);

      await stack.coordinator.onAppLifecyclePaused();
      await stack.coordinator.drainPendingWrites();

      expect(stack.playback.currentItem, isNull);
      expect(stack.playback.isPlaying, isFalse);
    });
  });
}
