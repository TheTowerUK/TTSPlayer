@Tags(['phase54-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_listening_presentation.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/settings/diagnostics_export_coordinator.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';

import 'support/phase_46_runtime_harness.dart';
import 'support/phase_54_listening_history_runtime_baseline.dart';
import 'support/phase_54_listening_history_runtime_harness.dart';
import 'support/phase_54_listening_history_support.dart';

/// Windows Phase 5.4 listening-history runtime validation (Step 9).
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows --release
/// $env:PHASE_54_RUNTIME='1'
/// flutter test test/phase_54_listening_history_windows_runtime_test.dart --tags phase54-runtime
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_54_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_54_RUNTIME=1 to run Phase 5.4 listening history runtime',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.4 listening history runtime is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final libmpv = phase54ResolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  final baseline = Phase54ListeningHistoryRuntimeBaseline();
  baseline.observe('runtime_timestamp_utc', DateTime.now().toUtc().toIso8601String());
  baseline.observe(
    'release_exe_exists',
    File(r'build\windows\x64\runner\Release\ttsplayer.exe').existsSync(),
  );

  group('Phase 5.4 Step 9 — Windows listening history runtime', () {
    tearDownAll(() => baseline.printReport());

    late Phase54RuntimeContext ctx;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ctx = await Phase54RuntimeContext.create(baseline: baseline);
    });

    tearDown(() async {
      await ctx.dispose();
    });

    test('R1 — runtime startup and production wiring', () async {
      expect(ctx.repository.isLoaded, isTrue);
      expect(ctx.coordinator.isAttached, isTrue);
      expect(ctx.queue, isNotNull);
      expect(ctx.catalogService.catalog, isNotNull);

      final snapshot = await ctx.timedCapture('r1_diagnostics');
      expect(snapshot.musicListening?.status, DiagnosticSectionStatus.complete);
      expect(snapshot.musicListening?.storedRecordCount, 0);

      baseline.observe('r1_queue_length', ctx.queue.queue.length);
    });

    test('R2 — empty-history baseline', () async {
      await ctx.clearHistory();

      expect(ctx.repository.storedRecordCount, 0);
      expect(ctx.repository.continueListening(), isEmpty);
      expect(ctx.repository.recentlyPlayed(), isEmpty);

      final snapshot = await ctx.timedCapture('r2_diagnostics');
      expect(snapshot.musicListening?.storedRecordCount, 0);
      expect(snapshot.musicListening?.continueListeningCount, 0);
      expect(snapshot.musicListening?.recentlyPlayedCount, 0);
    });

    testWidgets('R2 UI — Recently Played navigation with empty history',
        (tester) async {
      await phase54ConfigureViewport(tester);
      await phase54PumpMusicScreen(tester, ctx);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsNothing);
      expect(find.byKey(const Key('music_recently_played_tile')), findsOneWidget);
      expect(find.textContaining('0 tracks in history'), findsOneWidget);
    });

    test('R3 — meaningful-listening creation (deterministic events)', () async {
      final track = ctx.track(phase54AlbumTrackIds[0]);

      await ctx.simulatePlayForSeconds(track, 15);
      await ctx.simulateTick(position: const Duration(seconds: 20));

      expect(ctx.repository.storedRecordCount, 1);
      expect(ctx.repository.recentlyPlayed(), hasLength(1));
      expect(ctx.repository.getByTrackId(track.id)?.lastPosition,
          greaterThan(const Duration(seconds: 14)));

      await ctx.simulateTick(position: const Duration(seconds: 25));
      expect(ctx.repository.storedRecordCount, 1);

      baseline.observe('r3_stored_records', ctx.repository.storedRecordCount);
    });

    test('R4 — Continue Listening threshold (deterministic events)', () async {
      final track = ctx.track(phase54AlbumTrackIds[0]);

      await ctx.simulatePlayForSeconds(track, 45, stopAtEnd: true);

      final record = ctx.repository.getByTrackId(track.id)!;
      expect(record.lastPosition, const Duration(seconds: 45));
      expect(ctx.repository.continueListening(), hasLength(1));
      expect(historyPlaybackStartPosition(record), record.lastPosition);

      baseline.observe(
        'r4_continue_count',
        ctx.repository.continueListening().length,
      );
    });

    test('R5 — real Windows playback', () async {
      if (!ctx.audioFixture.isValid) {
        // ignore: avoid_print
        print('R5 skipped — no valid audio fixture');
        return;
      }

      final track = ctx.track(phase54AlbumTrackIds[0]);
      final realPlayback = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        ),
      );
      final realQueue =
          MusicPlaybackQueueController(playbackService: realPlayback);

      try {
        realQueue.seedSingleTrack(track);
        realQueue.onPlayerRouteOpened();
        final startup = Stopwatch()..start();
        await realQueue.playCurrent();

        await phase54WaitFor(() => realPlayback.isReady);
        expect(realPlayback.isPlaying, isTrue);

        final startPosition = realPlayback.position;
        await phase54WaitFor(
          () => realPlayback.position > startPosition,
          timeout: const Duration(seconds: 15),
        );

        await realPlayback.togglePlayPause();
        await phase54WaitFor(() => !realPlayback.isPlaying);
        expect(realPlayback.playbackErrorKind, isNull);

        await realPlayback.togglePlayPause();
        await phase54WaitFor(() => realPlayback.isPlaying);

        baseline.observe('r5_playback_startup_ms', startup.elapsedMilliseconds);
        baseline.realAudioExercised = true;
        ctx.baseline.realAudioExercised = true;
      } finally {
        await realQueue.onPlayerRouteClosed();
        await realPlayback.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('R6 — pause/transition flush (deterministic events)', () async {
      final trackA = ctx.track(phase54AlbumTrackIds[0]);
      final trackB = ctx.track(phase54AlbumTrackIds[1]);

      ctx.queue.replaceQueue([trackA, trackB], startIndex: 0);
      await ctx.simulatePlayForSeconds(trackA, 20);
      await ctx.simulateTick(
        position: const Duration(seconds: 20),
        playing: false,
      );

      expect(ctx.repository.getByTrackId(trackA.id)?.lastPosition,
          const Duration(seconds: 20));

      await ctx.queue.next();
      await ctx.seedAndSimulatePlay(trackB);
      await ctx.simulatePlayForSeconds(trackB, 18);

      expect(ctx.repository.getByTrackId(trackB.id), isNotNull);
      expect(ctx.queue.currentTrack?.id, trackB.id);
      expect(ctx.queue.queue.length, 2);
    });

    test('R7 — completion and replay (deterministic events)', () async {
      final track = ctx.track(phase54AlbumTrackIds[0]);

      await ctx.simulatePlayForSeconds(track, 20);
      await ctx.simulateTick(
        position: const Duration(minutes: 4),
        completed: true,
        playing: false,
      );

      final record = ctx.repository.getByTrackId(track.id)!;
      expect(record.completed, isTrue);
      expect(ctx.repository.continueListening(), isEmpty);
      expect(ctx.repository.recentlyPlayed(), hasLength(1));
      expect(historyPlaybackStartPosition(record), Duration.zero);
    });

    test('R8 — catalogue replacement retains ID and prunes removed track',
        () async {
      await ctx.repository.upsert(
        phase54Record(
          trackId: phase54AlbumTrackIds[0],
          lastPosition: const Duration(seconds: 50),
          title: 'Stale Title',
        ),
      );
      await ctx.repository.upsert(
        phase54Record(trackId: phase54AlbumTrackIds[1]),
      );

      final track = ctx.track(phase54AlbumTrackIds[0]);
      await ctx.seedAndSimulatePlay(track);
      await ctx.simulatePlayForSeconds(track, 20);

      final reconcileStopwatch = Stopwatch()..start();
      final replacementJson = phase54ReplacementCatalogJson(
        retainedTrackPath: track.filePath,
        rootPath: ctx.track(phase54RootTrackId).filePath,
      );
      final replacementPath =
          '${ctx.tempCatalogDir.path}/replacement.json';
      await File(replacementPath).writeAsString(jsonEncode(replacementJson));
      await ctx.catalogService.loadFromFile(replacementPath);
      await Future<void>.delayed(Duration.zero);
      baseline.observe(
        'r8_reconcile_ms',
        reconcileStopwatch.elapsedMilliseconds,
      );

      final retained = ctx.repository.getByTrackId(phase54AlbumTrackIds[0])!;
      expect(retained.title, 'Refreshed Album Track One');
      expect(retained.lastPosition, const Duration(seconds: 50));
      expect(ctx.repository.getByTrackId(phase54AlbumTrackIds[1]), isNull);
      expect(ctx.playback.currentItem?.id, phase54AlbumTrackIds[0]);
    });

    test('R9 — failed catalogue refresh preserves history', () async {
      await ctx.repository.upsert(
        phase54Record(
          trackId: phase54AlbumTrackIds[0],
          lastPosition: const Duration(seconds: 45),
        ),
      );
      final before = ctx.repository.storedRecordCount;

      await ctx.catalogService
          .loadFromFile('${ctx.tempCatalogDir.path}/missing.json');
      await Future<void>.delayed(Duration.zero);

      expect(ctx.repository.storedRecordCount, before);
      expect(ctx.catalogService.catalog, isNotNull);
      expect(ctx.repository.continueListening(), isNotEmpty);

      final snapshot = await ctx.timedCapture('r9_diagnostics');
      expect(snapshot.musicListening?.storedRecordCount, before);
    });

    testWidgets('R10 — clear listening history via production UI',
        (tester) async {
      final track = ctx.track(phase54AlbumTrackIds[0]);
      await ctx.simulatePlayForSeconds(track, 45, stopAtEnd: true);
      expect(ctx.repository.storedRecordCount, 1);

      final queueTrackBefore = ctx.queue.currentTrack?.id;
      await phase54ConfigureViewport(tester);
      await phase54PumpRecentlyPlayed(tester, ctx);

      expect(find.byKey(const Key('music_recently_played_list')), findsOneWidget);

      await tester.tap(find.byKey(const Key('music_recently_played_menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('music_clear_listening_history_menu_item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('music_clear_listening_history_dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(ctx.repository.storedRecordCount, 1);

      await tester.tap(find.byKey(const Key('music_recently_played_menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('music_clear_listening_history_menu_item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_clear_listening_history')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('music_clear_listening_history_success')),
        findsOneWidget,
      );
      expect(ctx.repository.storedRecordCount, 0);
      expect(ctx.repository.continueListening(), isEmpty);
      expect(ctx.queue.currentTrack?.id, queueTrackBefore);

      await phase54PumpMusicScreen(tester, ctx);
      expect(find.byKey(const Key('music_continue_listening_section')),
          findsNothing);
      expect(find.byKey(const Key('music_recently_played_tile')), findsOneWidget);

      final snapshot = await ctx.timedCapture('r10_diagnostics');
      expect(snapshot.musicListening?.storedRecordCount, 0);
    });

    testWidgets('R11 — diagnostics UI and section order', (tester) async {
      await ctx.repository.upsert(
        phase54Record(
          trackId: phase54AlbumTrackIds[0],
          lastPosition: const Duration(seconds: 45),
        ),
      );

      await phase54ConfigureViewport(tester);
      await phase54OpenDiagnosticsFromSettings(tester, ctx);
      tester.takeException();
      expect(find.text('Music Listening'), findsOneWidget);

      await phase54PumpDiagnostics(tester, ctx);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .byKey(const Key('diagnostics_music_listening_stored'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }

      phase54AssertDiagnosticsSectionOrder(tester);
      expect(find.byKey(const Key('diagnostics_music_listening_stored')),
          findsOneWidget);
      phase46AssertNoForbiddenWidgets(tester);
    });

    test('R11 — diagnostics export privacy via FakeClipboardWriter', () async {
      await ctx.repository.upsert(
        phase54Record(
          trackId: 'secret-track-id',
          title: 'Secret Title',
          artist: 'Secret Artist',
          album: 'Secret Album',
          lastPosition: const Duration(seconds: 45),
        ),
      );

      final coordinator = DiagnosticsExportCoordinator(
        diagnosticsService: ctx.diagnostics,
        clipboardWriter: ctx.clipboard,
      );
      final result = await coordinator.copyDiagnostics();

      expect(result, isA<DiagnosticsExportSuccess>());
      expect(ctx.clipboard.writeCount, 1);
      final export = ctx.clipboard.lastWrittenText!;
      phase54AssertExportHeadings(export);
      phase54AssertNoForbiddenContent(export);
      expect(export.split('=== Music Listening ===').length, 2);
      expect(export, contains('Stored records: 1'));
    });

    test('R12 — persistence restart', () async {
      final track = ctx.track(phase54AlbumTrackIds[0]);
      await ctx.simulatePlayForSeconds(track, 45, stopAtEnd: true);
      expect(ctx.repository.storedRecordCount, 1);

      ctx.coordinator.dispose();
      await ctx.playback.stop();

      final reloaded = await ctx.reloadRepository();
      expect(reloaded.storedRecordCount, 1);
      final record = reloaded.getByTrackId(track.id)!;
      expect(record.lastPosition, const Duration(seconds: 45));
      expect(record.completed, isFalse);
      expect(reloaded.continueListening(), hasLength(1));
      expect(reloaded.recentlyPlayed().first.trackId, track.id);
    });

    test('R13 — optional local catalogue', () async {
      final result = await phase54TryOptionalLocalCatalog(ctx);
      baseline.optionalLocalCatalogExercised =
          result.status != 'skipped';
      baseline.optionalLocalCatalogResult = '${result.status}: ${result.detail}';

      if (result.status == 'skipped') {
        // ignore: avoid_print
        print('R13 skipped — PHASE_54_LOCAL_CATALOG unset');
        return;
      }

      expect(result.status, isNot('failed'));
    });

    testWidgets('UI — Continue Listening appears after qualifying history',
        (tester) async {
      final track = ctx.track(phase54AlbumTrackIds[0]);
      await ctx.simulatePlayForSeconds(track, 45, stopAtEnd: true);

      await phase54ConfigureViewport(tester);
      await phase54PumpMusicScreen(tester, ctx);

      expect(find.byKey(const Key('music_continue_listening_section')),
          findsOneWidget);
      expect(
        find.byKey(Key('music_continue_listening_card_${track.id}')),
        findsOneWidget,
      );
    });

    testWidgets('UI — completed Recently Played row shows replay semantics',
        (tester) async {
      final track = ctx.track(phase54AlbumTrackIds[0]);
      await ctx.simulatePlayForSeconds(track, 20);
      await ctx.simulateTick(
        position: const Duration(minutes: 4),
        completed: true,
        playing: false,
      );

      await phase54ConfigureViewport(tester);
      await phase54PumpRecentlyPlayed(tester, ctx);

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byIcon(Icons.replay_outlined), findsWidgets);
    });

    group('failure and recovery', () {
      test('malformed stored JSON loads empty without crash', () async {
        SharedPreferences.setMockInitialValues({
          MusicListeningRepository.storageKey: '{not-json',
        });
        final repository = MusicListeningRepository();
        final result = await repository.initialize();
        expect(result.records, isEmpty);
        expect(result.recoveryWarnings, isNotEmpty);
        expect(repository.isLoaded, isTrue);
      });

      test('unsupported stateVersion loads empty', () async {
        SharedPreferences.setMockInitialValues({
          MusicListeningRepository.storageKey: jsonEncode({
            'stateVersion': 99,
            'records': [
              {
                'trackId': 'ghost',
                'title': 'Ghost',
                'artist': 'Ghost',
                'album': 'Ghost',
                'lastPositionSeconds': 45,
                'completed': false,
                'lastPlayedAt': '2026-07-21T12:00:00.000Z',
              },
            ],
          }),
        });
        final repository = MusicListeningRepository();
        await repository.initialize();
        expect(repository.getByTrackId('ghost'), isNull);
      });

      test('stale track ID hidden from playable entries', () async {
        await ctx.repository.upsert(
          phase54Record(
            trackId: 'missing-track-id',
            lastPosition: const Duration(seconds: 45),
          ),
        );
        final entries = resolvePlayableListeningEntries(
          ctx.repository.continueListening(),
          ctx.projection,
        );
        expect(entries, isEmpty);
        expect(ctx.repository.storedRecordCount, 1);
      });
    });
  });
}
