import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/models/music_playback_session.dart';
import 'package:ttsplayer/features/music/models/music_playback_session_policy.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/features/search/search_service.dart';

import 'playback_service_extensions_test.dart';
import 'support/catalog_cache_test_support.dart';

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

Future<String?> _storedEnvelopeRaw() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(MusicPlaybackSessionRepository.storageKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlaybackSessionRepository validateAgainstCatalog', () {
    test('1 empty persisted session remains empty', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.changed, isFalse);
      expect(repository.session.isEmpty, isTrue);
    });

    test('2 missing persisted key remains empty', () async {
      final repository = MusicPlaybackSessionRepository();
      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.changed, isFalse);
      expect(repository.session.isEmpty, isTrue);
    });

    test('3 unchanged catalogue causes no persistence write', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());
      final before = await _storedEnvelopeRaw();

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
          'c': {'title': 'C'},
        }),
      );
      final after = await _storedEnvelopeRaw();

      expect(result.changed, isFalse);
      expect(result.persisted, isFalse);
      expect(after, before);
    });

    test('4 all queue IDs survive unchanged', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
          'c': {'title': 'C'},
        }),
      );

      expect(result.retainedCount, 3);
      expect(result.removedCount, 0);
      expect(repository.session.queueTrackIds, ['a', 'b', 'c']);
      expect(repository.session.activeTrackId, 'b');
      expect(repository.session.playbackPosition.inMilliseconds, 9000);
    });

    test('5 one missing track is removed', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'c': {'title': 'C'},
        }),
      );

      expect(result.changed, isTrue);
      expect(result.removedCount, 1);
      expect(repository.session.queueTrackIds, ['a', 'c']);
    });

    test('6 several missing tracks are removed', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'c': {'title': 'C'}
        }),
      );

      expect(result.removedCount, 2);
      expect(repository.session.queueTrackIds, ['c']);
    });

    test('7 surviving queue order is preserved', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(queueTrackIds: ['x', 'y', 'z', 'w'], activeTrackId: 'y'),
      );

      await repository.validateAgainstCatalog(
        _catalog({
          'x': {'title': 'X'},
          'y': {'title': 'Y'},
          'w': {'title': 'W'},
        }),
      );

      expect(repository.session.queueTrackIds, ['x', 'y', 'w']);
    });

    test('8 active track survives and position is preserved', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(
          queueTrackIds: ['a', 'b'],
          activeTrackId: 'b',
          playbackPosition: const Duration(milliseconds: 12345),
        ),
      );

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );

      expect(result.activeTrackRetained, isTrue);
      expect(repository.session.activeTrackId, 'b');
      expect(repository.session.playbackPosition.inMilliseconds, 12345);
    });

    test('9 active track is removed', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(queueTrackIds: ['a', 'b'], activeTrackId: 'b'),
      );

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(repository.session.activeTrackId, 'a');
    });

    test('10 first surviving item becomes active', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(queueTrackIds: ['gone', 'keep'], activeTrackId: 'gone'),
      );

      await repository.validateAgainstCatalog(
        _catalog({
          'keep': {'title': 'Keep'}
        }),
      );

      expect(repository.session.activeTrackId, 'keep');
    });

    test('11 position resets to zero when active track changes', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(
          queueTrackIds: ['a', 'b'],
          activeTrackId: 'b',
          playbackPosition: const Duration(minutes: 2),
        ),
      );

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(repository.session.playbackPosition, Duration.zero);
    });

    test('12 entire queue is removed', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'other': {'title': 'Other'}
        }),
      );

      expect(result.sessionCleared, isTrue);
      expect(repository.session.isEmpty, isTrue);
    });

    test('13 empty canonical session is persisted', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      await repository.validateAgainstCatalog(_catalog({}));

      final raw = await _storedEnvelopeRaw();
      expect(raw, isNotNull);
      final envelope = jsonDecode(raw!) as Map<String, dynamic>;
      final session = envelope['session'] as Map<String, dynamic>;
      expect(session['queueTrackIds'], isEmpty);
      expect(session['activeTrackId'], isNull);
      expect(session['playbackPositionMs'], 0);
    });

    test('14 IDs resolving to video items are removed', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository
          .save(_session(queueTrackIds: ['a', 'vid'], activeTrackId: 'a'));

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'Audio', 'media_kind': 'audio'},
          'vid': {'title': 'Video', 'media_kind': 'video'},
        }),
      );

      expect(repository.session.queueTrackIds, ['a']);
    });

    test('15 IDs resolving to image items are removed', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository
          .save(_session(queueTrackIds: ['a', 'img'], activeTrackId: 'a'));

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'Audio', 'media_kind': 'audio'},
          'img': {'title': 'Image', 'media_kind': 'image'},
        }),
      );

      expect(repository.session.queueTrackIds, ['a']);
    });

    test('16 audio IDs remain valid', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository
          .save(_session(queueTrackIds: ['audio-1'], activeTrackId: 'audio-1'));

      await repository.validateAgainstCatalog(
        _catalog({
          'audio-1': {'title': 'Song', 'media_kind': 'audio'}
        }),
      );

      expect(repository.session.queueTrackIds, ['audio-1']);
    });

    test('17 duplicate persisted IDs remain deterministically normalised',
        () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(queueTrackIds: ['a', 'a', 'b'], activeTrackId: 'a'),
      );

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'b': {'title': 'B'},
        }),
      );

      expect(repository.session.queueTrackIds, ['a', 'b']);
    });

    test('18 large queue reconciliation respects 500-item session policy',
        () async {
      final ids = List<String>.generate(505, (i) => 'track-$i');
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        _session(
          queueTrackIds: ids,
          activeTrackId: 'track-0',
          playbackPosition: Duration.zero,
        ),
      );

      final catalogItems = {
        for (final id in ids) id: {'title': id},
      };
      await repository.validateAgainstCatalog(_catalog(catalogItems));

      expect(
        repository.session.queueTrackIds.length,
        MusicPlaybackSessionPolicy.maxPersistedTrackIds,
      );
      expect(repository.session.queueTrackIds.first, 'track-0');
    });

    test('19 reconciliation is idempotent', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      final first = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'c': {'title': 'C'}
        }),
      );
      final second = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'c': {'title': 'C'}
        }),
      );

      expect(first.changed, isTrue);
      expect(second.changed, isFalse);
    });

    test('20 reconciliation run twice produces no second write', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'c': {'title': 'C'}
        }),
      );
      final afterFirst = await _storedEnvelopeRaw();

      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'},
          'c': {'title': 'C'}
        }),
      );
      final afterSecond = await _storedEnvelopeRaw();

      expect(afterSecond, afterFirst);
    });

    test('21 corrupt persisted session follows repository recovery behaviour',
        () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: '{bad json',
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.load();
      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.changed, isFalse);
      expect(repository.session.isEmpty, isTrue);
    });

    test('22 unsupported session version remains safely handled', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: jsonEncode({
          'stateVersion': 99,
          'session': _session().toSessionJson(),
        }),
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.load();
      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.changed, isFalse);
      expect(repository.session.isEmpty, isTrue);
    });

    test('23 persistence failure does not block catalogue replacement result',
        () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());
      repository.simulatePersistFailure = true;

      final result = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(result.persistenceFailed, isTrue);
      expect(result.changed, isFalse);
      expect(repository.session.queueTrackIds, ['a', 'b', 'c']);
    });

    test('24 later catalogue replacement retries after persistence failure',
        () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());

      repository.simulatePersistFailure = true;
      expect(
        (await repository.validateAgainstCatalog(
          _catalog({
            'a': {'title': 'A'}
          }),
        ))
            .persistenceFailed,
        isTrue,
      );
      expect(repository.session.queueTrackIds, ['a', 'b', 'c']);

      repository.simulatePersistFailure = false;
      final retry = await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      expect(retry.changed, isTrue);
      expect(repository.session.queueTrackIds, ['a']);
    });

    test('28 video resume keys remain unchanged', () async {
      SharedPreferences.setMockInitialValues({
        'position_video-1': 120,
        'duration_video-1': 3600,
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(_session());
      await repository.validateAgainstCatalog(
        _catalog({
          'a': {'title': 'A'}
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_video-1'), 120);
      expect(prefs.getInt('duration_video-1'), 3600);
    });
  });

  group('CatalogCacheCoordinator playback session reconciliation', () {
    test('25 listening-history reconciliation still runs', () async {
      final listening = MusicListeningRepository();
      await listening.initialize();
      await listening.upsert(
        MusicListeningRecord(
          trackId: 'track-a',
          title: 'Old',
          artist: 'Artist',
          album: 'Album',
          lastPosition: const Duration(seconds: 45),
          completed: false,
          lastPlayedAt: DateTime.utc(2026, 7, 22),
        ),
      );

      final session = MusicPlaybackSessionRepository();
      await session.initialize();
      await session.save(_session(queueTrackIds: ['track-a', 'track-b']));

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: SearchService(),
        musicLibraryService: MusicLibraryService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        musicListeningRepository: listening,
        musicPlaybackSessionRepository: session,
      );

      coordinator.onCatalogReplaced(
        _catalog({
          'track-a': {'title': 'Fresh'}
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(listening.getByTrackId('track-a')?.title, 'Fresh');
      expect(session.session.queueTrackIds, ['track-a']);
    });

    test('26 playback-session failure does not corrupt listening history',
        () async {
      final listening = MusicListeningRepository();
      await listening.initialize();
      await listening.upsert(
        MusicListeningRecord(
          trackId: 'track-a',
          title: 'Keep',
          artist: 'Artist',
          album: 'Album',
          lastPosition: const Duration(seconds: 45),
          completed: false,
          lastPlayedAt: DateTime.utc(2026, 7, 22),
        ),
      );

      final session = MusicPlaybackSessionRepository();
      await session.initialize();
      await session.save(_session(queueTrackIds: ['track-a', 'track-b']));
      session.simulatePersistFailure = true;

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: SearchService(),
        musicLibraryService: MusicLibraryService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        musicListeningRepository: listening,
        musicPlaybackSessionRepository: session,
      );

      coordinator.onCatalogReplaced(
        _catalog({
          'track-a': {'title': 'Fresh'}
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(listening.getByTrackId('track-a')?.title, 'Fresh');
      expect(session.session.queueTrackIds, ['track-a', 'track-b']);
    });

    test('27 listening-history failure does not prevent session reconciliation',
        () async {
      final listening = MusicListeningRepository();
      await listening.initialize();
      await listening.upsert(
        MusicListeningRecord(
          trackId: 'track-a',
          title: 'Old',
          artist: 'Artist',
          album: 'Album',
          lastPosition: const Duration(seconds: 45),
          completed: false,
          lastPlayedAt: DateTime.utc(2026, 7, 22),
        ),
      );
      listening.simulatePersistFailure = true;

      final session = MusicPlaybackSessionRepository();
      await session.initialize();
      await session.save(_session(queueTrackIds: ['track-a', 'track-b']));

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: SearchService(),
        musicLibraryService: MusicLibraryService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        musicListeningRepository: listening,
        musicPlaybackSessionRepository: session,
      );

      coordinator.onCatalogReplaced(
        _catalog({
          'track-a': {'title': 'Fresh'}
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(listening.getByTrackId('track-a')?.title, 'Old');
      expect(session.session.queueTrackIds, ['track-a']);
    });

    test('29 live playback queue is not hydrated or restored', () async {
      final playback = PlaybackService(
        mediaKitInitOverride: (service, uri, generation) async {
          service.attachSessionControlsForTest(FakePlaybackSessionControls());
        },
      );
      final queue = MusicPlaybackQueueController(playbackService: playback);
      queue.replaceQueue([
        MediaItem(
          id: 'live-a',
          title: 'Live A',
          filePath: r'Y:\a.mp3',
          mediaKindRaw: 'audio',
        ),
        MediaItem(
          id: 'live-b',
          title: 'Live B',
          filePath: r'Y:\b.mp3',
          mediaKindRaw: 'audio',
        ),
      ]);

      final session = MusicPlaybackSessionRepository();
      await session.initialize();
      await session.save(
        _session(
            queueTrackIds: ['stored-a', 'stored-b'], activeTrackId: 'stored-b'),
      );

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: SearchService(),
        musicLibraryService: MusicLibraryService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        musicPlaybackSessionRepository: session,
        playbackService: playback,
        musicPlaybackQueueController: queue,
      );

      coordinator.onCatalogReplaced(
        _catalog({
          'live-a': {'title': 'Live A'},
          'live-b': {'title': 'Live B'},
          'stored-a': {'title': 'Stored A'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(queue.queue.length, 2);
      expect(queue.currentTrack?.id, 'live-a');
      expect(session.session.queueTrackIds, ['stored-a']);
    });

    test('30 no autoplay or player navigation occurs', () async {
      final playback = PlaybackService(
        mediaKitInitOverride: (service, uri, generation) async {
          service.attachSessionControlsForTest(FakePlaybackSessionControls());
        },
      );
      final queue = MusicPlaybackQueueController(playbackService: playback);
      final session = MusicPlaybackSessionRepository();
      await session.initialize();
      await session.save(_session(queueTrackIds: ['a'], activeTrackId: 'a'));

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: SearchService(),
        musicLibraryService: MusicLibraryService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        musicPlaybackSessionRepository: session,
        playbackService: playback,
        musicPlaybackQueueController: queue,
      );

      coordinator.onCatalogReplaced(_catalog({
        'a': {'title': 'A'}
      }));
      await Future<void>.delayed(Duration.zero);

      expect(playback.currentItem, isNull);
      expect(queue.isEmpty, isTrue);
    });
  });
}
