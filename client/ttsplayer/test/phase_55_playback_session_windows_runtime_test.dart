@Tags(['phase55-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_playback_session.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/widgets/music_playback_session_lifecycle_observer.dart';

import 'support/phase_55_playback_session_runtime_baseline.dart';
import 'support/phase_55_playback_session_runtime_harness.dart';

/// Windows Phase 5.5 playback-session runtime validation (Step 6).
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows --release
/// $env:PHASE_55_RUNTIME='1'
/// flutter test test/phase_55_playback_session_windows_runtime_test.dart --tags phase55-runtime
/// Remove-Item Env:PHASE_55_RUNTIME
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_55_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_55_RUNTIME=1 to run Phase 5.5 playback session runtime',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.5 playback session runtime is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final libmpv = phase55ResolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  final baseline = Phase55PlaybackSessionRuntimeBaseline();
  baseline.observe(
      'runtime_timestamp_utc', DateTime.now().toUtc().toIso8601String());
  baseline.observe(
    'release_exe_exists',
    File(r'build\windows\x64\runner\Release\ttsplayer.exe').existsSync(),
  );
  baseline.observe('libmpv_path', libmpv);

  group('Phase 5.5 Step 6 — Windows playback session runtime', () {
    tearDownAll(() => baseline.printReport());

    late Phase55RuntimeContext ctx;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ctx = await Phase55RuntimeContext.create(baseline: baseline);
    });

    tearDown(() async {
      await ctx.dispose();
    });

    test('PS1 — runtime gate and production wiring', () async {
      expect(Platform.isWindows, isTrue);
      expect(ctx.sessionRepository.isLoaded, isTrue);
      expect(ctx.sessionCoordinator.isAttached, isTrue);
      expect(ctx.sessionCoordinator.persistenceEnabled, isTrue);
      expect(ctx.restorer.coldStartRestoreAttempted, isTrue);
      expect(ctx.coldStartRestorePerformed, isTrue);
      expect(ctx.queue, isNotNull);
      expect(ctx.catalogService.catalog, isNotNull);
      expect(ctx.catalog.catalogueIdentity, contains('PHASE55'));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().contains(MusicPlaybackSessionRepository.storageKey) ||
            !ctx.sessionRepository.hasPersistedSession,
        isTrue,
      );

      final snapshot = await ctx.timedCapture('ps1_diagnostics');
      expect(
        snapshot.musicPlaybackSession?.status,
        DiagnosticSectionStatus.complete,
      );
      expect(snapshot.musicPlaybackSession?.repositoryLoaded, isTrue);
      expect(snapshot.musicPlaybackSession?.coordinatorAttached, isTrue);
      expect(snapshot.musicPlaybackSession?.stateVersion, 1);

      baseline.observe('ps1_queue_length', ctx.queue.queue.length);
      baseline.observe(
        'ps1_storage_isolated',
        'SharedPreferences.setMockInitialValues',
      );
    });

    test('PS2 — create persistent queue', () async {
      await ctx.seedThreeTrackQueue();

      expect(await ctx.persistedQueueIds(), phase55AlbumTrackIds);
      expect(await ctx.persistedActiveTrackId(), phase55AlbumTrackIds[0]);
      expect(ctx.queue.queue.items.map((e) => e.id).toList(),
          phase55AlbumTrackIds);
      expect(ctx.queue.currentTrack?.id, phase55AlbumTrackIds[0]);
      expect(ctx.sessionCoordinator.persistenceWarningPresent, isFalse);
      expect(ctx.sessionCoordinator.lastPersistenceWarning, isNull);

      baseline.observe('ps2_persisted_count', 3);
    });

    test('PS3 — active-track mutation', () async {
      await ctx.seedThreeTrackQueue();
      ctx.queue.selectTrack(phase55AlbumTrackIds[1]);
      await ctx.sessionCoordinator.waitForIdleForTest();
      await ctx.sessionCoordinator.drainPendingWrites();

      expect(ctx.queue.currentTrack?.id, phase55AlbumTrackIds[1]);
      expect(await ctx.persistedActiveTrackId(), phase55AlbumTrackIds[1]);
      expect(await ctx.persistedQueueIds(), phase55AlbumTrackIds);
      baseline.observe('ps3_active', phase55AlbumTrackIds[1]);
    });

    test('PS4 — playback-position persistence', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();

      final stored = await ctx.persistedPosition();
      phase55AssertPositionNear(stored, phase55ExpectedPosition);
      expect(stored >= const Duration(seconds: 30), isTrue);
      expect(stored < const Duration(minutes: 2), isTrue);
      expect(await ctx.persistedActiveTrackId(), phase55AlbumTrackIds[1]);

      baseline.observe('ps4_stored_position_ms', stored.inMilliseconds);
      baseline.observe(
        'ps4_tolerance',
        phase55PositionTolerance.inMilliseconds,
      );
    });

    testWidgets('PS5 — lifecycle flush', (tester) async {
      await ctx.seedThreeTrackQueue(startIndex: 2);
      await ctx.playAndSeekToMeaningfulPosition(
        position: const Duration(seconds: 50),
      );

      // Debounced add (active track unchanged) then lifecycle flush supersedes.
      ctx.queue.addTrack(ctx.track(phase55RootTrackId));
      expect(ctx.sessionCoordinator.pendingQueueDebounce, isTrue);

      await tester.pumpWidget(
        ctx.lifecycleApp(home: const SizedBox.shrink()),
      );
      await tester.pump();
      final observerState = tester.state(
        find.byType(MusicPlaybackSessionLifecycleObserver),
      );
      (observerState as dynamic)
          .handleAppLifecycleStateChangedForTest(AppLifecycleState.paused);
      await tester.pump();
      await ctx.sessionCoordinator.drainPendingWrites();

      expect(ctx.sessionCoordinator.pendingQueueDebounce, isFalse);
      expect(await ctx.persistedActiveTrackId(), phase55AlbumTrackIds[2]);
      expect(
        await ctx.persistedQueueIds(),
        [...phase55AlbumTrackIds, phase55RootTrackId],
      );
      final stored = await ctx.persistedPosition();
      phase55AssertPositionNear(stored, const Duration(seconds: 50));
      baseline.observe('ps5_lifecycle_flush', true);
      baseline.observe('ps5_stored_position_ms', stored.inMilliseconds);
    });

    test('PS6 — simulated cold restart (pre-restore)', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();
      final prefs = await ctx.snapshotPrefs();
      expect(
        prefs.containsKey(MusicPlaybackSessionRepository.storageKey),
        isTrue,
      );

      await ctx.dispose();

      final restarted = await Phase55RuntimeContext.create(
        baseline: baseline,
        initialPrefs: prefs,
        performColdStartRestore: false,
      );
      try {
        expect(restarted.sessionRepository.isLoaded, isTrue);
        expect(restarted.sessionRepository.hasPersistedSession, isTrue);
        expect(
          restarted.sessionRepository.session.queueTrackIds,
          phase55AlbumTrackIds,
        );
        expect(restarted.queue.isEmpty, isTrue);
        expect(restarted.playback.isPlaying, isFalse);
        expect(restarted.playback.currentItem, isNull);
        expect(restarted.sessionCoordinator.persistenceEnabled, isFalse);
        baseline.observe('ps6_pre_restore_queue_empty', true);
      } finally {
        await restarted.dispose();
        // Prevent outer tearDown from disposing twice.
        SharedPreferences.setMockInitialValues({});
        ctx = await Phase55RuntimeContext.create(baseline: baseline);
      }
    });

    test('PS7 — cold-start restoration', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();
      final prefs = await ctx.snapshotPrefs();
      final beforeEnvelope = await ctx.readSessionEnvelope();
      await ctx.dispose();

      final restarted = await Phase55RuntimeContext.create(
        baseline: baseline,
        initialPrefs: prefs,
        performColdStartRestore: true,
      );
      try {
        expect(restarted.queue.queue.items.map((e) => e.id).toList(),
            phase55AlbumTrackIds);
        expect(restarted.queue.currentTrack?.id, phase55AlbumTrackIds[1]);
        expect(
          restarted.queue.restoredStartPosition,
          phase55ExpectedPosition,
        );
        expect(restarted.sessionCoordinator.persistenceEnabled, isTrue);
        expect(restarted.restorer.coldStartRestoreAttempted, isTrue);
        expect(
          restarted.restorer.lastRestoreResult?.restoredQueueCount,
          3,
        );

        final afterEnvelope = await restarted.readSessionEnvelope();
        expect(
          afterEnvelope?['session']?['queueTrackIds'],
          beforeEnvelope?['session']?['queueTrackIds'],
        );
        expect(
          afterEnvelope?['session']?['activeTrackId'],
          beforeEnvelope?['session']?['activeTrackId'],
        );
        baseline.observe('ps7_restored_count', 3);
      } finally {
        await restarted.dispose();
        SharedPreferences.setMockInitialValues({});
        ctx = await Phase55RuntimeContext.create(baseline: baseline);
      }
    });

    test('PS8 — no-autoplay guarantee', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();
      final prefs = await ctx.snapshotPrefs();
      await ctx.dispose();

      final restarted = await Phase55RuntimeContext.create(
        baseline: baseline,
        initialPrefs: prefs,
        performColdStartRestore: true,
      );
      try {
        expect(restarted.playback.isPlaying, isFalse);
        expect(restarted.playback.currentItem, isNull);
        expect(restarted.playback.isReady, isFalse);
        expect(restarted.queue.currentTrack?.id, phase55AlbumTrackIds[1]);
        expect(restarted.queue.queue.length, 3);
        // Engine remains stopped (not prepared); queue selection only.
        baseline.observe('ps8_isPlaying', false);
        baseline.observe('ps8_engine_item', 'null');
        baseline.observe(
          'ps8_manual_audible',
          'Confirm no audio on Release relaunch before Play',
        );
      } finally {
        await restarted.dispose();
        SharedPreferences.setMockInitialValues({});
        ctx = await Phase55RuntimeContext.create(baseline: baseline);
      }
    });

    test('PS9 — deferred position application', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();
      final prefs = await ctx.snapshotPrefs();
      await ctx.dispose();

      final restarted = await Phase55RuntimeContext.create(
        baseline: baseline,
        initialPrefs: prefs,
        performColdStartRestore: true,
      );
      try {
        expect(
          restarted.queue.restoredStartPosition,
          phase55ExpectedPosition,
        );
        expect(restarted.playback.currentItem, isNull);

        restarted.queue.onPlayerRouteOpened();
        await restarted.queue.playCurrent();

        expect(restarted.queue.restoredStartPosition, isNull);
        expect(restarted.playback.currentItem?.id, phase55AlbumTrackIds[1]);
        phase55AssertPositionNear(
          restarted.playback.position,
          phase55ExpectedPosition,
        );

        restarted.playback.simulatePlayingForTest(playing: true);
        expect(restarted.playback.isPlaying, isTrue);

        baseline.observe(
          'ps9_applied_position_ms',
          restarted.playback.position.inMilliseconds,
        );
      } finally {
        await restarted.dispose();
        SharedPreferences.setMockInitialValues({});
        ctx = await Phase55RuntimeContext.create(baseline: baseline);
      }
    });

    test('PS10 — queue transport after restore', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();
      final prefs = await ctx.snapshotPrefs();
      await ctx.dispose();

      final restarted = await Phase55RuntimeContext.create(
        baseline: baseline,
        initialPrefs: prefs,
        performColdStartRestore: true,
      );
      try {
        restarted.queue.onPlayerRouteOpened();
        await restarted.queue.playCurrent();
        restarted.playback.simulatePlayingForTest(playing: true);

        await restarted.queue.next();
        await restarted.sessionCoordinator.waitForIdleForTest();
        await restarted.sessionCoordinator.drainPendingWrites();
        expect(restarted.queue.currentTrack?.id, phase55AlbumTrackIds[2]);
        expect(
            await restarted.persistedActiveTrackId(), phase55AlbumTrackIds[2]);
        expect(await restarted.persistedQueueIds(), phase55AlbumTrackIds);

        await restarted.queue.previous();
        await restarted.sessionCoordinator.waitForIdleForTest();
        await restarted.sessionCoordinator.drainPendingWrites();
        expect(restarted.queue.currentTrack?.id, phase55AlbumTrackIds[1]);

        restarted.queue.selectTrack(phase55AlbumTrackIds[0]);
        await restarted.sessionCoordinator.waitForIdleForTest();
        await restarted.sessionCoordinator.drainPendingWrites();
        expect(restarted.queue.currentTrack?.id, phase55AlbumTrackIds[0]);
        expect(
            await restarted.persistedActiveTrackId(), phase55AlbumTrackIds[0]);
        expect(restarted.queue.queue.length, 3);
        baseline.observe('ps10_transport_ok', true);
      } finally {
        await restarted.dispose();
        SharedPreferences.setMockInitialValues({});
        ctx = await Phase55RuntimeContext.create(baseline: baseline);
      }
    });

    test('PS11 — catalogue reconciliation', () async {
      await ctx.sessionRepository.save(
        MusicPlaybackSession(
          queueTrackIds: [
            phase55AlbumTrackIds[0],
            phase55MissingTrackId,
            phase55VideoItemId,
            phase55AlbumTrackIds[1],
            phase55AlbumTrackIds[2],
          ],
          activeTrackId: phase55AlbumTrackIds[2],
          playbackPosition: const Duration(seconds: 40),
          updatedAt: DateTime.utc(2026, 7, 23, 6),
        ),
      );

      final replacement = phase55ReconciliationCatalogJson(
        retainedTrack1Path: ctx.track(phase55AlbumTrackIds[0]).filePath,
        retainedTrack2Path: ctx.track(phase55AlbumTrackIds[1]).filePath,
        rootPath: ctx.track(phase55RootTrackId).filePath,
      );
      final replacementPath = '${ctx.tempCatalogDir.path}/reconcile.json';
      await File(replacementPath).writeAsString(jsonEncode(replacement));
      await ctx.catalogService.loadFromFile(replacementPath);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        ctx.sessionRepository.session.queueTrackIds,
        [phase55AlbumTrackIds[0], phase55AlbumTrackIds[1]],
      );
      expect(
        ctx.sessionRepository.session.activeTrackId,
        phase55AlbumTrackIds[0],
      );
      expect(ctx.sessionRepository.session.playbackPosition, Duration.zero);
      expect(ctx.sessionRepository.lastValidationResult?.removedCount, 3);
      expect(ctx.sessionRepository.lastValidationResult?.persisted, isTrue);
      expect(await ctx.persistedQueueIds(),
          [phase55AlbumTrackIds[0], phase55AlbumTrackIds[1]]);
      baseline.observe(
        'ps11_removed',
        ctx.sessionRepository.lastValidationResult?.removedCount,
      );
    });

    test('PS12 — empty reconciliation result', () async {
      await ctx.sessionRepository.save(
        MusicPlaybackSession(
          queueTrackIds: phase55AlbumTrackIds,
          activeTrackId: phase55AlbumTrackIds[0],
          playbackPosition: const Duration(seconds: 20),
          updatedAt: DateTime.utc(2026, 7, 23, 6),
        ),
      );

      final emptyPath = '${ctx.tempCatalogDir.path}/empty_audio.json';
      await File(emptyPath)
          .writeAsString(jsonEncode(phase55EmptyAudioCatalogJson()));
      await ctx.catalogService.loadFromFile(emptyPath);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ctx.sessionRepository.session.isEmpty, isTrue);
      expect(ctx.sessionRepository.session.activeTrackId, isNull);
      expect(ctx.sessionRepository.session.playbackPosition, Duration.zero);
      expect(
          ctx.sessionRepository.lastValidationResult?.sessionCleared, isTrue);
      expect(ctx.catalogService.catalog, isNotNull);
      baseline.observe('ps12_session_cleared', true);
    });

    test('PS13 — diagnostics snapshot and export', () async {
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();

      final snapshot = await ctx.timedCapture('ps13_diagnostics');
      final section = snapshot.musicPlaybackSession!;
      expect(section.status, DiagnosticSectionStatus.complete);
      expect(section.stateVersion, 1);
      expect(section.repositoryLoaded, isTrue);
      expect(section.persistedSessionPresent, isTrue);
      expect(section.persistedQueueCount, 3);
      expect(section.liveQueueCount, 3);
      expect(section.activeTrackPresent, isTrue);
      expect(section.storedPositionAvailable, isTrue);
      expect(section.persistenceEnabled, isTrue);
      expect(section.coordinatorAttached, isTrue);
      expect(section.persistenceWarningPresent, isFalse);

      final export = await ctx.exportDiagnostics();
      expect(export, contains('=== Music Playback Session ==='));
      expect(export, contains('Persisted queue items: 3'));
      expect(export, contains('Live queue items: 3'));
      baseline.observe('ps13_export_chars', export.length);
    });

    test('PS14 — diagnostics redaction', () async {
      await ctx.seedThreeTrackQueue();
      await ctx.sessionRepository.save(
        MusicPlaybackSession(
          queueTrackIds: phase55AlbumTrackIds,
          activeTrackId: phase55AlbumTrackIds[0],
          playbackPosition: const Duration(seconds: 12),
          updatedAt: DateTime.utc(2026, 7, 23, 6),
        ),
      );

      final export = await ctx.exportDiagnostics();
      phase55AssertNoForbiddenContent(export);
      expect(export, contains('=== Music Playback Session ==='));
      expect(export, isNot(contains(phase55AlbumTrackIds[0])));
      expect(export, isNot(contains(phase55RuntimeArtist)));
      expect(export, isNot(contains(phase55SentinelTitlePrefix)));
      baseline.observe('ps14_redaction_ok', true);
    });

    test('PS15 — state isolation', () async {
      await phase55SeedIsolationMarkers();
      await ctx.seedThreeTrackQueue(startIndex: 1);
      await ctx.playAndSeekToMeaningfulPosition();
      await ctx.pauseAndFlush();

      final prefsBefore = await SharedPreferences.getInstance();
      final settingsRaw = prefsBefore.getString(SettingsRepository.storageKey);
      final listeningBefore =
          prefsBefore.getString(MusicListeningRepository.storageKey);
      final videoPosBefore = prefsBefore.getInt(phase55VideoResumePositionKey);
      final videoDurBefore = prefsBefore.getInt(phase55VideoResumeDurationKey);

      // Session-only operations — must not mutate foreign stores.
      await ctx.sessionRepository.clear();
      await ctx.seedThreeTrackQueue();
      ctx.queue.selectTrack(phase55AlbumTrackIds[2]);
      await ctx.sessionCoordinator.waitForIdleForTest();
      await ctx.sessionCoordinator.drainPendingWrites();

      final prefsAfter = await SharedPreferences.getInstance();
      expect(prefsAfter.getInt(phase55VideoResumePositionKey), videoPosBefore);
      expect(prefsAfter.getInt(phase55VideoResumeDurationKey), videoDurBefore);
      expect(
        prefsAfter.getString(SettingsRepository.storageKey),
        settingsRaw,
      );
      expect(
        prefsAfter.getString(MusicListeningRepository.storageKey),
        listeningBefore,
      );
      expect(
        prefsAfter.containsKey(MusicPlaybackSessionRepository.storageKey),
        isTrue,
      );
      baseline.observe('ps15_isolation_ok', true);
    });

    test('PS16 — failure recovery', () async {
      await ctx.seedThreeTrackQueue();
      expect(ctx.sessionCoordinator.persistenceWarningPresent, isFalse);

      ctx.sessionRepository.simulatePersistFailure = true;
      ctx.queue.selectTrack(phase55AlbumTrackIds[2]);
      await ctx.sessionCoordinator.waitForIdleForTest();
      await ctx.sessionCoordinator.drainPendingWrites();

      expect(ctx.sessionCoordinator.persistenceWarningPresent, isTrue);
      expect(ctx.queue.currentTrack?.id, phase55AlbumTrackIds[2]);
      expect(ctx.queue.queue.length, 3);

      ctx.sessionRepository.simulatePersistFailure = false;
      ctx.queue.selectTrack(phase55AlbumTrackIds[1]);
      await ctx.sessionCoordinator.waitForIdleForTest();
      await ctx.sessionCoordinator.drainPendingWrites();

      expect(await ctx.persistedActiveTrackId(), phase55AlbumTrackIds[1]);
      expect(ctx.sessionCoordinator.persistenceWarningPresent, isFalse);
      baseline.observe('ps16_recovery_ok', true);
    });
  });
}
