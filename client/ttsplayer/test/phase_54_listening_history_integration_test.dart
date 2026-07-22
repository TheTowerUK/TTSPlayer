import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_screen.dart';
import 'package:ttsplayer/features/music/models/music_listening_policy.dart';
import 'package:ttsplayer/features/music/music_listening_presentation.dart';
import 'package:ttsplayer/features/music/music_navigation.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';

import 'support/diagnostics_test_harness.dart';
import 'support/phase_54_listening_history_support.dart';

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5.4 I1 cold start', () {
    test('I1 repository loads empty; diagnostics reports zero counts',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);

      expect(stack.repository.isLoaded, isTrue);
      expect(stack.repository.storedRecordCount, 0);
      expect(stack.repository.continueListening(), isEmpty);
      expect(stack.repository.recentlyPlayed(), isEmpty);

      final diagnostics = await phase54DiagnosticsForRepository(
        stack.repository,
        stack: stack,
      );
      final snapshot = await diagnostics.captureSnapshot();

      expect(snapshot.musicListening?.status, DiagnosticSectionStatus.complete);
      expect(snapshot.musicListening?.storedRecordCount, 0);
      expect(snapshot.musicListening?.continueListeningCount, 0);
      expect(snapshot.musicListening?.recentlyPlayedCount, 0);
    });
  });

  group('Phase 5.4 I2-I3 creation threshold', () {
    test('I2 below 15 seconds creates no record', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 14, stopAtEnd: true);

      expect(stack.repository.storedRecordCount, 0);
      expect(stack.repository.recentlyPlayed(), isEmpty);
    });

    test('I3 at 15 seconds creates one record without duplicates', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 15);
      await stack.tick(position: const Duration(seconds: 20));
      await stack.tick(position: const Duration(seconds: 25));

      expect(stack.repository.storedRecordCount, 1);
      expect(stack.repository.recentlyPlayed(), hasLength(1));
      expect(stack.repository.getByTrackId('track-a')?.lastPosition,
          greaterThan(const Duration(seconds: 14)));
    });
  });

  group('Phase 5.4 I4-I5 resume eligibility', () {
    test('I4 sub-30 position excluded from Continue Listening', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 16, stopAtEnd: true);

      final record = stack.repository.getByTrackId('track-a');
      expect(record, isNotNull);
      expect(record!.lastPosition,
          lessThan(MusicListeningPolicy.minResumePosition));
      expect(stack.repository.continueListening(), isEmpty);
      expect(stack.repository.recentlyPlayed(), hasLength(1));
      expect(historyPlaybackStartPosition(record), Duration.zero);
    });

    test('I5 resumable position appears in Continue Listening', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 45, stopAtEnd: true);

      final record = stack.repository.getByTrackId('track-a')!;
      expect(stack.repository.continueListening(), hasLength(1));
      expect(historyPlaybackStartPosition(record), record.lastPosition);
    });
  });

  group('Phase 5.4 I6 seek-only protection', () {
    test('I6 seek without playing does not create record', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.primeTrack(track, playing: false);
      await stack.tick(position: const Duration(seconds: 60), playing: false);
      await stack.tick(position: const Duration(seconds: 90), playing: false);

      expect(stack.repository.storedRecordCount, 0);
    });
  });

  group('Phase 5.4 I7 pause flush', () {
    test('I7 pause flushes pending progress', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 20);
      await stack.tick(position: const Duration(seconds: 20), playing: false);

      final record = stack.repository.getByTrackId('track-a');
      expect(record, isNotNull);
      expect(record!.lastPosition, const Duration(seconds: 20));
      expect(stack.playback.isPlaying, isFalse);
    });
  });

  group('Phase 5.4 I8 track transition', () {
    test('I8 track change flushes outgoing and starts new session', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final trackA = phase54AudioTrack('track-a', title: 'A');
      final trackB = phase54AudioTrack('track-b', title: 'B');

      stack.queue.replaceQueue([trackA, trackB], startIndex: 0);
      await stack.primeTrack(trackA);
      await stack.playForSeconds(trackA, 20);

      await stack.queue.next();
      await stack.primeTrack(trackB);
      await stack.playForSeconds(trackB, 18);

      expect(stack.repository.getByTrackId('track-a')?.lastPosition,
          const Duration(seconds: 20));
      expect(stack.repository.getByTrackId('track-b'), isNotNull);
      expect(stack.repository.getByTrackId('track-b')!.lastPosition,
          greaterThan(const Duration(seconds: 15)));
    });
  });

  group('Phase 5.4 I9-I10 completion and replay', () {
    test('I9 completion removes from Continue Listening, keeps Recently Played',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 20);
      await stack.tick(
        position: const Duration(minutes: 4),
        completed: true,
        playing: false,
      );

      final record = stack.repository.getByTrackId('track-a')!;
      expect(record.completed, isTrue);
      expect(stack.repository.continueListening(), isEmpty);
      expect(stack.repository.recentlyPlayed(), hasLength(1));
      expect(historyPlaybackStartPosition(record), Duration.zero);
    });

    test('I10 completed replay stays completed until 15 s meaningful replay',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 20);
      await stack.tick(
        position: const Duration(minutes: 4),
        completed: true,
        playing: false,
      );

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 10, stopAtEnd: true);
      expect(stack.repository.getByTrackId('track-a')!.completed, isTrue);

      await stack.playForSeconds(track, 16);
      expect(stack.repository.getByTrackId('track-a')!.completed, isFalse);
    });
  });

  group('Phase 5.4 I11-I13 catalogue integration', () {
    test(
        'I11 catalogue replace refreshes metadata and preserves listening state',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);

      await stack.repository.upsert(
        phase54Record(
          trackId: 'track-a',
          lastPosition: const Duration(seconds: 50),
          title: 'Old Title',
        ),
      );

      stack.catalogCache.onCatalogReplaced(
        phase54AudioCatalog({'track-a': 'Fresh Title'}),
      );
      await Future<void>.delayed(Duration.zero);

      final record = stack.repository.getByTrackId('track-a')!;
      expect(record.title, 'Fresh Title');
      expect(record.lastPosition, const Duration(seconds: 50));
      expect(record.completed, isFalse);
    });

    test('I11 active playback survives catalogue metadata refresh', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 20);

      stack.catalogCache.onCatalogReplaced(
        phase54AudioCatalog({'track-a': 'Renamed'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(stack.playback.currentItem?.id, 'track-a');
      expect(stack.queue.currentTrack?.id, 'track-a');
      expect(stack.repository.getByTrackId('track-a')?.lastPosition,
          const Duration(seconds: 20));
    });

    test('I12 catalogue replace prunes missing trackId', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);

      await stack.repository.upsert(phase54Record(trackId: 'track-a'));
      await stack.repository.upsert(phase54Record(trackId: 'track-b'));

      stack.catalogCache.onCatalogReplaced(
        phase54AudioCatalog({'track-a': 'Keep'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(stack.repository.getByTrackId('track-a'), isNotNull);
      expect(stack.repository.getByTrackId('track-b'), isNull);
      expect(stack.repository.storedRecordCount, 1);
    });

    test('I13 failed catalogue load does not reconcile history', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      await stack.repository.upsert(phase54Record(trackId: 'track-a'));

      final catalogService = CatalogService(
        onCatalogReplaced: stack.catalogCache.onCatalogReplaced,
      )..includeLegacyCataloguePaths = false;

      final tempDir = await Directory.systemTemp.createTemp('p54_listen_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final goodPath = '${tempDir.path}/good.json';
      await File(goodPath).writeAsString(
        jsonEncode(phase54AudioCatalogJson({'track-a': 'Keep'})),
      );

      await catalogService.loadFromFile(goodPath);
      await Future<void>.delayed(Duration.zero);
      expect(stack.repository.storedRecordCount, 1);

      await catalogService.loadFromFile('${tempDir.path}/missing.json');
      await Future<void>.delayed(Duration.zero);

      expect(stack.repository.storedRecordCount, 1);
      expect(stack.repository.continueListening(), isNotEmpty);
    });
  });

  group('Phase 5.4 I14-I15 clear history', () {
    test('I14 clear removes records; playback and queue unchanged', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 45, stopAtEnd: true);
      expect(stack.repository.storedRecordCount, 1);

      final result = await stack.repository.clearAll();
      expect(result.success, isTrue);

      expect(stack.repository.storedRecordCount, 0);
      expect(stack.repository.continueListening(), isEmpty);
      expect(stack.repository.recentlyPlayed(), isEmpty);
      expect(stack.queue.currentTrack?.id, 'track-a');
      expect(stack.playback.currentItem?.id, 'track-a');
    });

    test('I14 diagnostics reflect zero counts after clear', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      await stack.repository.upsert(
        phase54Record(
            trackId: 'track-a', lastPosition: const Duration(seconds: 45)),
      );

      await stack.repository.clearAll();

      final diagnostics = await phase54DiagnosticsForRepository(
        stack.repository,
        stack: stack,
      );
      final snapshot = await diagnostics.captureSnapshot();
      expect(snapshot.musicListening?.storedRecordCount, 0);
      expect(snapshot.musicListening?.continueListeningCount, 0);
    });

    test('I15 clear during playback does not immediately recreate history',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 45);
      await stack.repository.clearAll();

      expect(stack.repository.storedRecordCount, 0);
      await stack.tick(position: const Duration(seconds: 46), playing: true);
      expect(stack.repository.storedRecordCount, 0);
    });

    test('I15 later meaningful playback recreates history after clear',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 45);
      await stack.repository.clearAll();
      expect(stack.repository.storedRecordCount, 0);

      await stack.playForSeconds(track, 16);
      expect(stack.repository.storedRecordCount, 1);
    });
  });

  group('Phase 5.4 I16 diagnostics and export', () {
    test('I16 export contains counts once without media metadata', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);

      await stack.repository.upsert(
        phase54Record(
          trackId: 'secret-track-id',
          title: 'Secret Title',
          artist: 'Secret Artist',
          album: 'Secret Album',
          lastPosition: const Duration(seconds: 45),
        ),
      );

      final diagnostics = await phase54DiagnosticsForRepository(
        stack.repository,
        stack: stack,
      );
      final snapshot = await diagnostics.captureSnapshot();
      final export = formatDiagnosticsExport(snapshot);

      expect(export.split('=== Music Listening ===').length, 2);
      expect(export, contains('Stored records: 1'));
      expect(export, contains('Continue listening: 1'));
      expect(export, isNot(contains('Secret Title')));
      expect(export, isNot(contains('secret-track-id')));
      expect(exportContainsSensitiveData(export), isFalse);
    });
  });

  group('Phase 5.4 persistence reload', () {
    test('cross-instance reload preserves records after coordinator write',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 45, stopAtEnd: true);

      stack.dispose();

      final reloaded = await phase54ReloadRepository();
      expect(reloaded.storedRecordCount, 1);
      final record = reloaded.getByTrackId('track-a')!;
      expect(record.lastPosition, const Duration(seconds: 45));
      expect(record.completed, isFalse);
      expect(reloaded.continueListening(), hasLength(1));
    });

    test('corrupt envelope loads empty with recovery warning', () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: '{not-json',
      });

      final repository = MusicListeningRepository();
      final result = await repository.initialize();

      expect(result.records, isEmpty);
      expect(result.recoveryWarnings, isNotEmpty);
      expect(repository.isLoaded, isTrue);
    });

    test('unsupported stateVersion loads empty without parsing records',
        () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: jsonEncode({
          'stateVersion': 99,
          'records': [
            {
              'trackId': 'should-not-load',
              'title': 'Hidden',
              'artist': 'Hidden',
              'album': 'Hidden',
              'lastPositionSeconds': 45,
              'completed': false,
              'lastPlayedAt': '2026-07-21T12:00:00.000Z',
            },
          ],
        }),
      });

      final repository = MusicListeningRepository();
      final result = await repository.initialize();

      expect(result.records, isEmpty);
      expect(repository.getByTrackId('should-not-load'), isNull);
    });
  });

  group('Phase 5.4 queue and navigation integration', () {
    testWidgets('resumable history launch uses saved startPosition',
        (tester) async {
      final catalog = phase54QueueSeedingCatalog();
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        phase54Record(
          trackId: 'qa-t1',
          lastPosition: const Duration(seconds: 75),
        ),
      );

      final playback = stubPhase54PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var opened = false;

      await tester.pumpWidget(
        phase54WidgetHarness(
          catalog: catalog,
          repository: repository,
          queue: queue,
          playback: playback,
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  opened = openMusicPlayerFromListeningRecord(
                    context,
                    record: repository.getByTrackId('qa-t1')!,
                  );
                },
                child: const Text('Launch'),
              );
            },
          ),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('Launch'));
      await _pumpUi(tester);

      expect(opened, isTrue);
      expect(find.byType(MusicPlayerScreen), findsOneWidget);
      final screen =
          tester.widget<MusicPlayerScreen>(find.byType(MusicPlayerScreen));
      expect(screen.startPosition, const Duration(seconds: 75));
      expect(queue.currentTrack?.id, 'qa-t1');
      expect(queue.queue.items.length, 3);
    });

    testWidgets('single-track fallback seeds one-track queue for audio-root',
        (tester) async {
      final catalog = phase54MixedCatalog();
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        phase54Record(
          trackId: 'audio-root',
          lastPosition: const Duration(seconds: 45),
        ),
      );

      final playback = stubPhase54PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);

      await tester.pumpWidget(
        phase54WidgetHarness(
          catalog: catalog,
          repository: repository,
          queue: queue,
          playback: playback,
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  openMusicPlayerFromListeningRecord(
                    context,
                    record: repository.getByTrackId('audio-root')!,
                  );
                },
                child: const Text('Launch root'),
              );
            },
          ),
        ),
      );
      await _pumpUi(tester);
      await tester.tap(find.text('Launch root'));
      await _pumpUi(tester);

      expect(queue.queue.items.length, 1);
      expect(queue.currentTrack?.id, 'audio-root');
    });

    testWidgets('stale trackId cannot launch from history', (tester) async {
      final catalog = phase54MixedCatalog();
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        phase54Record(
          trackId: 'missing-track',
          lastPosition: const Duration(seconds: 45),
        ),
      );

      final playback = stubPhase54PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      var opened = true;

      await tester.pumpWidget(
        phase54WidgetHarness(
          catalog: catalog,
          repository: repository,
          queue: queue,
          playback: playback,
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  opened = openMusicPlayerFromListeningRecord(
                    context,
                    record: repository.getByTrackId('missing-track')!,
                  );
                },
                child: const Text('Launch stale'),
              );
            },
          ),
        ),
      );
      await _pumpUi(tester);
      await tester.tap(find.text('Launch stale'));
      await _pumpUi(tester);

      expect(opened, isFalse);
      expect(find.byType(MusicPlayerScreen), findsNothing);
    });
  });

  group('Phase 5.4 UI lifecycle integration', () {
    testWidgets('Continue Listening appears after repository notification',
        (tester) async {
      final catalog = phase54MixedCatalog();
      final repository = MusicListeningRepository();
      await repository.initialize();

      await tester.pumpWidget(
        phase54WidgetHarness(
          catalog: catalog,
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpUi(tester);
      expect(find.text('CONTINUE LISTENING'), findsNothing);

      await repository.upsert(
        phase54Record(
          trackId: 'track-partial',
          lastPosition: const Duration(seconds: 45),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('CONTINUE LISTENING'), findsOneWidget);
      expect(
        find.byKey(const Key('music_continue_listening_card_track-partial')),
        findsOneWidget,
      );
    });

    testWidgets('clear history removes Continue Listening from MusicScreen',
        (tester) async {
      final catalog = phase54MixedCatalog();
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        phase54Record(
          trackId: 'track-partial',
          lastPosition: const Duration(seconds: 45),
        ),
      );

      await tester.pumpWidget(
        phase54WidgetHarness(
          catalog: catalog,
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpUi(tester);
      expect(find.text('CONTINUE LISTENING'), findsOneWidget);

      await repository.clearAll();
      await _pumpUi(tester);

      expect(find.text('CONTINUE LISTENING'), findsNothing);
    });

    testWidgets('Recently Played tile visible with empty history',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await tester.pumpWidget(
        phase54WidgetHarness(
          catalog: phase54MixedCatalog(),
          repository: repository,
          child: const MusicScreen(),
        ),
      );
      await _pumpUi(tester);

      expect(
          find.byKey(const Key('music_recently_played_tile')), findsOneWidget);
    });
  });

  group('Phase 5.4 failure injection', () {
    test(
        'persistence failure during save leaves prior state and retry succeeds',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final track = phase54AudioTrack('track-a');

      queueSeedAndPlay(stack, track);
      stack.repository.simulatePersistFailure = true;
      await stack.playForSeconds(track, 20);
      expect(stack.repository.storedRecordCount, 0);
      expect(stack.coordinator.lastPersistenceWarning, isNotNull);

      stack.repository.simulatePersistFailure = false;
      await stack.tick(position: const Duration(seconds: 21));
      expect(stack.repository.storedRecordCount, 1);
    });

    test('clear persistence failure preserves records', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      await stack.repository.upsert(phase54Record(trackId: 'track-a'));

      stack.repository.simulatePersistFailure = true;
      final result = await stack.repository.clearAll();
      expect(result.success, isFalse);
      expect(stack.repository.storedRecordCount, 1);
    });

    test('reconciliation persistence failure leaves prior history', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      await stack.repository.upsert(phase54Record(trackId: 'track-a'));
      await stack.repository.upsert(phase54Record(trackId: 'track-b'));

      stack.repository.simulatePersistFailure = true;
      final validation = await stack.repository.validateAgainstCatalog(
        phase54AudioCatalog({'track-a': 'Fresh'}),
      );
      expect(validation.persistenceFailed, isTrue);
      expect(stack.repository.getByTrackId('track-b'), isNotNull);
      expect(stack.repository.storedRecordCount, 2);
    });

    test('diagnostics music failure does not suppress provider section',
        () async {
      final repository = ThrowingMusicListeningRepository();
      await repository.initialize();

      final diagnostics = await buildDiagnosticsHarness(
        catalog: phase54MixedCatalog(),
        musicListeningRepository: repository,
      );
      repository.throwOnDiagnosticsRead = true;

      final snapshot = await diagnostics.captureSnapshot();
      expect(
          snapshot.musicListening?.status, DiagnosticSectionStatus.unavailable);
      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
    });
  });

  group('Phase 5.4 regression matrix', () {
    test('video Continue Watching keys unchanged after music lifecycle',
        () async {
      const videoId = 'video-1';
      final stack = await Phase54ListeningStack.create(
        initialPrefs: {
          'position_$videoId': 90,
          'duration_$videoId': 3600,
        },
      );
      addTearDown(stack.dispose);

      final track = phase54AudioTrack('track-a');
      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 20);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoId'), 90);
      expect(prefs.getInt('duration_$videoId'), 3600);
      expect(prefs.containsKey('position_track-a'), isFalse);
    });

    test('audio listening does not write video Continue Watching keys',
        () async {
      const videoId = 'video-1';
      final stack = await Phase54ListeningStack.create(
        initialPrefs: {
          'position_$videoId': 90,
          'duration_$videoId': 3600,
        },
      );
      addTearDown(stack.dispose);

      final track = phase54AudioTrack('track-a');
      queueSeedAndPlay(stack, track);
      await stack.playForSeconds(track, 20);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoId'), 90);
      expect(prefs.containsKey('position_track-a'), isFalse);
    });

    test('queue next previous behaviour unchanged after listening writes',
        () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      final trackA = phase54AudioTrack('track-a', title: 'A');
      final trackB = phase54AudioTrack('track-b', title: 'B');

      stack.queue.replaceQueue([trackA, trackB], startIndex: 0);
      await stack.primeTrack(trackA);
      expect(stack.queue.hasNext, isTrue);

      await stack.queue.next();
      expect(stack.queue.currentTrack?.id, 'track-b');

      await stack.queue.previous();
      expect(stack.queue.currentTrack?.id, 'track-a');
    });

    test('favourites survive listening history mutations', () async {
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      await stack.metadata.addItemFavourite('fav-1');

      await stack.repository.upsert(phase54Record(trackId: 'track-a'));
      await stack.repository.clearAll();

      expect(stack.metadata.isItemFavourited('fav-1'), isTrue);
    });

    test('diagnostics capture does not build search index', () async {
      final search = SearchService();
      final stack = await Phase54ListeningStack.create();
      addTearDown(stack.dispose);
      await stack.repository.upsert(phase54Record(trackId: 'track-a'));

      final config = MediaProviderConfigService();
      await config.load();

      final diagnostics = DiagnosticsService(
        catalogService: StubCatalogService(stubCatalog: phase54MixedCatalog()),
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: search,
        playbackService: stack.playback,
        mediaProviderConfigService: config,
        libraryMetadataRepository: stack.metadata,
        musicListeningRepository: stack.repository,
        musicListeningCoordinator: stack.coordinator,
        applicationStartedAt: DateTime.utc(2026, 7, 21, 9),
        platformNameProvider: () => 'windows',
        imageCacheAvailableProvider: () => false,
      );

      await diagnostics.captureSnapshot();
      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 0);
    });

    testWidgets('dashboard does not show music Continue Listening',
        (tester) async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        phase54Record(
          trackId: 'track-partial',
          lastPosition: const Duration(seconds: 45),
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MusicListeningRepository>.value(
              value: repository,
            ),
            ChangeNotifierProvider<CatalogService>(
              create: (_) => Phase54FakeCatalogService(phase54MixedCatalog()),
            ),
            ChangeNotifierProvider<PlaybackService>(
              create: (_) => PlaybackService(),
            ),
            ChangeNotifierProvider<ScannerService>(
              create: (_) => ScannerService(),
            ),
            ChangeNotifierProvider<ScanHistoryService>(
              create: (_) => ScanHistoryService(),
            ),
            ChangeNotifierProvider<MediaProviderConfigService>(
              create: (_) => MediaProviderConfigService(),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('CONTINUE LISTENING'), findsNothing);
      expect(find.text('Continue Listening'), findsNothing);
    });
  });
}

void queueSeedAndPlay(Phase54ListeningStack stack, MediaItem track) {
  stack.queue.seedSingleTrack(track);
}
