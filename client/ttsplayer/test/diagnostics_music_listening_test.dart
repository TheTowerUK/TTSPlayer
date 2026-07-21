import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_listening_policy.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_export_coordinator.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';

import 'support/diagnostics_test_harness.dart';

MusicListeningRecord _diagnosticsRecord({
  required String trackId,
  String title = 'Secret Title',
  String artist = 'Secret Artist',
  String album = 'Secret Album',
  Duration lastPosition = const Duration(minutes: 2),
  bool completed = false,
  DateTime? lastPlayedAt,
}) {
  final playedAt = lastPlayedAt ?? DateTime.utc(2026, 7, 21, 12);
  return MusicListeningRecord(
    trackId: trackId,
    title: title,
    artist: artist,
    album: album,
    duration: const Duration(minutes: 5),
    lastPosition: lastPosition,
    completed: completed,
    completedAt: completed ? playedAt : null,
    lastPlayedAt: playedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Music listening diagnostics capture', () {
    test('maps empty loaded repository', () async {
      final repository = await initializedMusicListeningRepository();
      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
      );

      final snapshot = await service.captureSnapshot();

      expect(snapshot.musicListening?.status, DiagnosticSectionStatus.complete);
      expect(snapshot.musicListening?.repositoryLoaded, isTrue);
      expect(snapshot.musicListening?.storedRecordCount, 0);
      expect(snapshot.musicListening?.continueListeningCount, 0);
      expect(snapshot.musicListening?.recentlyPlayedCount, 0);
      expect(snapshot.musicListening?.completedRecordCount, 0);
      expect(snapshot.musicListening?.incompleteRecordCount, 0);
    });

    test('maps populated history counts', () async {
      final repository = await initializedMusicListeningRepository(
        initialRecords: [
          _diagnosticsRecord(
            trackId: 'track-resume',
            lastPosition: const Duration(minutes: 2),
          ),
          _diagnosticsRecord(
            trackId: 'track-complete',
            completed: true,
            lastPosition: Duration.zero,
          ),
          _diagnosticsRecord(
            trackId: 'track-too-early',
            lastPosition: const Duration(seconds: 10),
          ),
        ],
      );
      final coordinator = musicListeningCoordinatorHarness(
        repository: repository,
      );
      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
        musicListeningCoordinator: coordinator,
      );

      final snapshot = await service.captureSnapshot();

      expect(snapshot.musicListening?.storedRecordCount, 3);
      expect(snapshot.musicListening?.continueListeningCount, 1);
      expect(snapshot.musicListening?.recentlyPlayedCount, 3);
      expect(snapshot.musicListening?.completedRecordCount, 1);
      expect(snapshot.musicListening?.incompleteRecordCount, 2);
      expect(snapshot.musicListening?.coordinatorAttached, isTrue);
      expect(snapshot.musicListening?.sessionActive, isFalse);
    });

    test('unloaded repository yields null section', () async {
      final repository = MusicListeningRepository();
      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicListening, isNull);
    });

    test('recently played count respects default query cap', () async {
      final records = List<MusicListeningRecord>.generate(
        MusicListeningPolicy.defaultRecentlyPlayedQueryCap + 5,
        (index) => _diagnosticsRecord(
          trackId: 'track-$index',
          lastPlayedAt: DateTime.utc(2026, 7, 21, index),
        ),
      );
      final repository = await initializedMusicListeningRepository(
        initialRecords: records,
      );
      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicListening?.storedRecordCount, records.length);
      expect(
        snapshot.musicListening?.recentlyPlayedCount,
        MusicListeningPolicy.defaultRecentlyPlayedQueryCap,
      );
    });

    test('repository read failure yields unavailable section', () async {
      final repository = ThrowingMusicListeningRepository()
        ..throwOnDiagnosticsRead = true;
      await repository.initialize();

      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(
          snapshot.musicListening?.status, DiagnosticSectionStatus.unavailable);
      expect(snapshot.musicListening?.repositoryLoaded, isFalse);
    });

    test('coordinator read failure keeps repository counts partial', () async {
      final repository = await initializedMusicListeningRepository(
        initialRecords: [
          _diagnosticsRecord(trackId: 'track-a'),
        ],
      );
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = ThrowingSessionMusicListeningCoordinator(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      )..attach();

      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
        musicListeningCoordinator: coordinator,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicListening?.status, DiagnosticSectionStatus.partial);
      expect(snapshot.musicListening?.storedRecordCount, 1);
      expect(snapshot.musicListening?.sessionActive, isNull);
      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
    });

    test('capture is read-only and does not mutate repository', () async {
      final repository = await initializedMusicListeningRepository(
        initialRecords: [
          _diagnosticsRecord(trackId: 'track-a'),
        ],
      );
      final beforeCount = repository.storedRecordCount;
      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
      );

      await service.captureSnapshot();
      await service.captureSnapshot();

      expect(repository.storedRecordCount, beforeCount);
      expect(repository.allRecords, hasLength(beforeCount));
    });
  });

  group('Music listening formatter privacy', () {
    test('excludes titles artists albums track ids paths and urls', () async {
      final repository = await initializedMusicListeningRepository(
        initialRecords: [
          _diagnosticsRecord(
            trackId: 'md5-track-secret-id',
            title: 'Oh Yeah',
            artist: 'Example Artist',
            album: 'Singles Collection',
          ),
        ],
      );
      repository.simulatePersistFailure = true;
      final coordinator = musicListeningCoordinatorHarness(
        repository: repository,
      );
      final service = await buildDiagnosticsHarness(
        musicListeningRepository: repository,
        musicListeningCoordinator: coordinator,
      );

      final snapshot = await service.captureSnapshot();
      final export = service.formatExport(snapshot);

      expect(export, contains('=== Music Listening ==='));
      expect(export, contains('Stored records: 1'));
      expect(export, isNot(contains('Oh Yeah')));
      expect(export, isNot(contains('Example Artist')));
      expect(export, isNot(contains('Singles Collection')));
      expect(export, isNot(contains('md5-track-secret-id')));
      expect(export, isNot(contains(r'Y:\Media')));
      expect(export, isNot(contains('https://')));
      expect(exportContainsSensitiveData(export), isFalse);
    });

    test('uses deterministic labels booleans and section order', () {
      final export = formatDiagnosticsExport(minimalSnapshot());
      final playbackIndex = export.indexOf('=== Playback ===');
      final musicIndex = export.indexOf('=== Music Listening ===');
      final libraryIndex = export.indexOf('=== Library ===');

      expect(musicIndex, greaterThan(playbackIndex));
      expect(libraryIndex, greaterThan(musicIndex));
      expect(export, contains('Repository loaded: true'));
      expect(export, contains('Active session: false'));
      expect(export, contains('Recovery warning present: false'));
      expect(export, isNot(contains('Instance of')));
    });

    test('unavailable music section renders single status line', () {
      final export = formatDiagnosticsExport(
        minimalSnapshot(omitMusicListening: true),
      );
      expect(export, contains('=== Music Listening ==='));
      expect(export.split('=== Music Listening ===').length, 2);
    });
  });

  group('Failure isolation regression', () {
    test('music listening failure does not suppress other sections', () async {
      final repository = ThrowingMusicListeningRepository()
        ..throwOnDiagnosticsRead = true;
      await repository.initialize();

      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-MUSIC-FAIL', itemCount: 1),
        musicListeningRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      final export = service.formatExport(snapshot);

      expect(
          snapshot.musicListening?.status, DiagnosticSectionStatus.unavailable);
      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
      expect(snapshot.cache.status, DiagnosticSectionStatus.complete);
      expect(export, contains('=== Provider ==='));
      expect(export, contains('=== Music Listening ==='));
      expect(exportContainsSensitiveData(export), isFalse);
    });
  });

  group('DiagnosticsScreen music listening', () {
    testWidgets('displays section and refresh updates counts', (tester) async {
      final repository = await initializedMusicListeningRepository(
        initialRecords: [
          _diagnosticsRecord(trackId: 'track-a'),
        ],
      );
      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-MUSIC-UI', itemCount: 1),
        musicListeningRepository: repository,
      );

      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(diagnosticsScreenHarness(service));
      await tester.pumpAndSettle();

      expect(find.text('Music Listening'), findsOneWidget);
      expect(find.byKey(const Key('diagnostics_music_listening_stored')),
          findsOneWidget);
      expect(find.text('1'), findsWidgets);

      await repository.clearAll();
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pumpAndSettle();

      final stored = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_music_listening_stored')),
      );
      expect(stored.data, '0');
    });

    testWidgets('unavailable music section does not crash screen',
        (tester) async {
      final service = FakeDiagnosticsService(
        catalogService: StubCatalogService(
          stubCatalog:
              diagnosticsCatalog(identity: 'REV-MUSIC-NULL', itemCount: 1),
        ),
        artworkService: ArtworkService(fileExists: (_) => true),
        searchService: SearchService(),
        playbackService: PlaybackService(),
        mediaProviderConfigService: MediaProviderConfigService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
      )..snapshotFactory = (_) => minimalSnapshot(omitMusicListening: true);

      await tester.pumpWidget(diagnosticsScreenHarness(service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_section_music_listening')),
          findsOneWidget);
      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    test('copy diagnostics includes music listening once', () async {
      final repository = await initializedMusicListeningRepository();
      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-MUSIC-COPY', itemCount: 1),
        musicListeningRepository: repository,
      );
      final clipboard = FakeClipboardWriter();
      final coordinator = DiagnosticsExportCoordinator(
        diagnosticsService: service,
        clipboardWriter: clipboard,
      );

      final result = await coordinator.copyDiagnostics();

      expect(result, isA<DiagnosticsExportSuccess>());
      final export = clipboard.lastWrittenText!;
      expect(export.split('=== Music Listening ===').length, 2);
      expect(export, contains('Repository loaded: true'));
    });
  });
}
