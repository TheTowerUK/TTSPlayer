import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/widgets/music_playback_session_lifecycle_observer.dart';

import 'support/diagnostics_test_harness.dart';

Future<void> _emitLifecycleForTest(
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

  group('Music playback session production wiring', () {
    testWidgets('lifecycle observer receives Flutter lifecycle events',
        (tester) async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = musicPlaybackSessionCoordinatorHarness(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      coordinator.enablePersistenceAfterColdStartRestore();
      queue.replaceQueue([]);

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: coordinator,
            child: const SizedBox(),
          ),
        ),
      );

      await _emitLifecycleForTest(tester, AppLifecycleState.inactive);
      await coordinator.drainPendingWrites();

      expect(
        find.byType(MusicPlaybackSessionLifecycleObserver),
        findsOneWidget,
      );
    });

    testWidgets('lifecycle observer skips flush before persistence enabled',
        (tester) async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      final coordinator = musicPlaybackSessionCoordinatorHarness(
        repository: repository,
        deferPersistence: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MusicPlaybackSessionLifecycleObserver(
            coordinator: coordinator,
            child: const SizedBox(),
          ),
        ),
      );

      await _emitLifecycleForTest(tester, AppLifecycleState.inactive);
      await coordinator.drainPendingWrites();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(MusicPlaybackSessionRepository.storageKey),
          isFalse);
    });

    test('diagnostics service receives playback-session dependency', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final coordinator = musicPlaybackSessionCoordinatorHarness(
        repository: repository,
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackSessionCoordinator: coordinator,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession, isNotNull);
      expect(snapshot.musicPlaybackSession?.coordinatorAttached, isTrue);
    });

    test('missing optional coordinator remains safe for diagnostics', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.status.name, 'complete');
      expect(snapshot.musicPlaybackSession?.coordinatorAttached, isNull);
    });

    test('production stack uses one coordinator instance', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = MusicPlaybackSessionCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      final restorer = MusicPlaybackSessionRestorer(
        repository: repository,
        queueController: queue,
        musicLibraryService: MusicLibraryService(),
        playbackService: playback,
        sessionCoordinator: coordinator,
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackSessionCoordinator: coordinator,
        musicPlaybackQueueController: queue,
        musicPlaybackSessionRestorer: restorer,
      );

      coordinator.attach(deferPersistenceUntilColdStartComplete: true);
      var snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.persistenceEnabled, isFalse);

      coordinator.enablePersistenceAfterColdStartRestore();
      snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.persistenceEnabled, isTrue);
      expect(restorer.coldStartRestoreAttempted, isFalse);
    });
  });
}
