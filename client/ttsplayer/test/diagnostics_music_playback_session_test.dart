import 'package:flutter_test/flutter_test.dart';import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_playback_session.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_queue.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'support/diagnostics_test_harness.dart';

MediaItem _audioTrack(String id, {String title = 'Secret Title'}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
    artist: 'Secret Artist',
    album: 'Secret Album',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Music playback session diagnostics capture', () {
    test('21 section is present when repository loaded', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final service = await buildDiagnosticsHarness(
        withInitializedMusicPlaybackSession: true,
        musicPlaybackSessionRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession, isNotNull);
      expect(snapshot.musicPlaybackSession?.status,
          DiagnosticSectionStatus.complete);
    });

    test('22 persisted queue count is correct', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      await repository.save(
        MusicPlaybackSession(
          queueTrackIds: const ['a', 'b', 'c'],
          activeTrackId: 'b',
          playbackPosition: const Duration(seconds: 10),
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.persistedQueueCount, 3);
    });

    test('23 live queue count is correct', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      queue.replaceQueue([_audioTrack('a'), _audioTrack('b')]);
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackQueueController: queue,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.liveQueueCount, 2);
    });

    test('24 active-track presence is boolean', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      queue.replaceQueue([_audioTrack('a')]);
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackQueueController: queue,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.activeTrackPresent, isTrue);
    });

    test('26 cold-start restoration status is represented', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      await repository.save(
        MusicPlaybackSession(
          queueTrackIds: const ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: 5),
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = musicPlaybackSessionCoordinatorHarness(
        repository: repository,
        playbackService: playback,
        queueController: queue,
        deferPersistence: true,
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

      final before = await service.captureSnapshot();
      expect(before.musicPlaybackSession?.restoredOnColdStart, isFalse);

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-22T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {
          'id': 'CAT-1',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'root',
            'name': 'Root',
            'path': r'Y:\Media',
            'item_count': 1,
            'items': [
              {
                'id': 'a',
                'title': 'Track A',
                'file_path': r'Y:\Media\a.mp3',
                'status': 'available',
                'media_kind': 'audio',
              },
            ],
            'subfolders': [],
          },
        ],
      });
      await restorer.restoreOnColdStart(catalog);

      final after = await service.captureSnapshot();
      expect(after.musicPlaybackSession?.restoredOnColdStart, isTrue);
    });

    test('27 persistence-enabled status is represented', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final coordinator = musicPlaybackSessionCoordinatorHarness(
        repository: repository,
        deferPersistence: true,
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackSessionCoordinator: coordinator,
      );

      final before = await service.captureSnapshot();
      expect(before.musicPlaybackSession?.persistenceEnabled, isFalse);

      coordinator.enablePersistenceAfterColdStartRestore();
      final after = await service.captureSnapshot();
      expect(after.musicPlaybackSession?.persistenceEnabled, isTrue);
    });

    test('28 warning presence is represented without raw details', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final coordinator = musicPlaybackSessionCoordinatorHarness(
        repository: repository,
        playbackService: playback,
        queueController: queue,
      );
      coordinator.enablePersistenceAfterColdStartRestore();
      repository.simulatePersistFailure = true;
      queue.replaceQueue([_audioTrack('a')]);
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackSessionCoordinator: coordinator,
        musicPlaybackQueueController: queue,
      );

      await coordinator.onAppLifecyclePaused();
      await coordinator.drainPendingWrites();
      final snapshot = await service.captureSnapshot();
      final export = service.formatExport(snapshot);

      expect(snapshot.musicPlaybackSession?.persistenceWarningPresent, isTrue);
      expect(snapshot.musicPlaybackSession?.lastPersistenceWarningSummary,
          isNotNull);
      expect(export, contains('Persistence warning present: true'));
      expect(export, isNot(contains('simulatePersistFailure')));
    });

    test('25 stored-position presence is safe aggregate', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      await repository.save(
        MusicPlaybackSession(
          queueTrackIds: const ['a'],
          activeTrackId: 'a',
          playbackPosition: const Duration(seconds: 45),
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.storedPositionAvailable, isTrue);
    });

    test('29 empty session produces deterministic zero values', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.persistedQueueCount, 0);
      expect(snapshot.musicPlaybackSession?.persistedSessionPresent, isFalse);
      expect(snapshot.musicPlaybackSession?.activeTrackPresent, isFalse);
    });

    test('30 unavailable repository yields null section', () async {
      final repository = MusicPlaybackSessionRepository();
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession, isNull);
    });
  });

  group('Music playback session diagnostics export', () {
    test('31 export includes playback-session heading', () {
      final export = formatDiagnosticsExport(
        minimalSnapshot(
          musicPlaybackSession: const MusicPlaybackSessionDiagnostics(
            status: DiagnosticSectionStatus.complete,
            repositoryLoaded: true,
            persistedQueueCount: 2,
            liveQueueCount: 2,
            activeTrackPresent: true,
            storedPositionAvailable: true,
          ),
        ),
      );
      expect(export, contains('=== Music Playback Session ==='));
    });

    test('32 export contains no track IDs', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      await repository.save(
        MusicPlaybackSession(
          queueTrackIds: const ['74b8-secret-track-id'],
          activeTrackId: '74b8-secret-track-id',
          playbackPosition: Duration.zero,
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      queue.replaceQueue([_audioTrack('74b8-secret-track-id')]);
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackQueueController: queue,
      );
      final export = service.formatExport(await service.captureSnapshot());

      expect(export, isNot(contains('74b8-secret-track-id')));
      expect(export, isNot(contains('74b8')));
    });

    test('33 export contains no titles artists or albums', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final playback = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: playback);
      queue.replaceQueue([_audioTrack('track-a', title: 'My Song.mp3')]);
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackQueueController: queue,
      );
      final export = service.formatExport(await service.captureSnapshot());

      expect(export, isNot(contains('My Song.mp3')));
      expect(export, isNot(contains('Secret Artist')));
      expect(export, isNot(contains('Secret Album')));
    });

    test('34 export contains no file paths or URIs', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );
      final export = service.formatExport(await service.captureSnapshot());

      expect(export, isNot(contains(r'Y:\Media')));
      expect(export, isNot(contains('file://')));
    });

    test('35 export contains no raw persisted JSON', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      await repository.save(
        MusicPlaybackSession(
          queueTrackIds: const ['a'],
          activeTrackId: 'a',
          playbackPosition: Duration.zero,
          updatedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
      );
      final export = service.formatExport(await service.captureSnapshot());

      expect(export, isNot(contains('stateVersion')));
      expect(export, isNot(contains('queueTrackIds')));
    });

    test('40 export formatting remains deterministic', () {
      final snapshot = minimalSnapshot(
        musicPlaybackSession: const MusicPlaybackSessionDiagnostics(
          status: DiagnosticSectionStatus.complete,
          stateVersion: 1,
          repositoryLoaded: true,
          persistedSessionPresent: true,
          persistedQueueCount: 4,
          liveQueueCount: 4,
          activeTrackPresent: true,
          storedPositionAvailable: false,
          restoredOnColdStart: true,
          persistenceEnabled: true,
          pendingQueueDebounce: false,
          pendingWrite: false,
          recoveryWarningPresent: false,
          persistenceWarningPresent: false,
          coordinatorAttached: true,
        ),
      );
      final first = formatDiagnosticsExport(snapshot);
      final second = formatDiagnosticsExport(snapshot);
      expect(first, equals(second));
      expect(first, contains('Persisted queue items: 4'));
      expect(first, contains('Active track selected: true'));
    });

    test('36 export passes existing redaction helper', () {
      final export = formatDiagnosticsExport(
        minimalSnapshot(
          musicPlaybackSession: const MusicPlaybackSessionDiagnostics(
            status: DiagnosticSectionStatus.complete,
            repositoryLoaded: true,
            persistedQueueCount: 2,
            liveQueueCount: 2,
            activeTrackPresent: true,
          ),
        ),
      );
      expect(exportContainsSensitiveData(export), isFalse);
    });
  });

  group('Music playback session diagnostics isolation', () {
    test('37 listening-history diagnostics remain available', () async {
      final listening = await initializedMusicListeningRepository();
      final session = await initializedMusicPlaybackSessionRepository();
      final service = await buildDiagnosticsHarness(
        withInitializedMusicListening: true,
        musicListeningRepository: listening,
        musicPlaybackSessionRepository: session,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicListening, isNotNull);
      expect(snapshot.musicPlaybackSession, isNotNull);
    });

    test('38 video resume keys unchanged by diagnostics capture', () async {
      const initialPrefs = {
        'position_video-a': 120000,
        'duration_video-a': 3600000,
      };
      final repository = await initializedMusicPlaybackSessionRepository(
        initialPrefs: initialPrefs,
      );
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        initialPrefs: initialPrefs,
      );

      await service.captureSnapshot();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_video-a'), 120000);
      expect(prefs.getInt('duration_video-a'), 3600000);
    });

    test('39 aggregation failure returns unavailable section safely', () async {
      final repository = await initializedMusicPlaybackSessionRepository();
      final queue = _ThrowingQueueController();
      final service = await buildDiagnosticsHarness(
        musicPlaybackSessionRepository: repository,
        musicPlaybackQueueController: queue,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.musicPlaybackSession?.status,
          DiagnosticSectionStatus.unavailable);
    });
  });
}

class _ThrowingQueueController extends MusicPlaybackQueueController {
  _ThrowingQueueController() : super(playbackService: PlaybackService());

  @override
  PlaybackQueue get queue => throw StateError('diagnostics probe failure');
}
