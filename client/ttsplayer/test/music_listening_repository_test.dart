import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_listening_policy.dart';
import 'package:ttsplayer/features/music/models/music_listening_record.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/models/catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const trackA = 'track-a';
  const trackB = 'track-b';
  const trackC = 'track-c';

  DateTime utc(int year, int month, int day, [int hour = 12, int minute = 0]) {
    return DateTime.utc(year, month, day, hour, minute);
  }

  MusicListeningRecord testRecord({
    String trackId = trackA,
    String title = 'Oh Yeah',
    String artist = 'Example Artist',
    String album = 'Singles',
    Duration? duration = const Duration(minutes: 5),
    Duration lastPosition = const Duration(seconds: 45),
    bool completed = false,
    DateTime? completedAt,
    DateTime? lastPlayedAt,
  }) {
    final playedAt = lastPlayedAt ?? utc(2026, 7, 21);
    return MusicListeningRecord(
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      lastPosition: lastPosition,
      completed: completed,
      completedAt: completed ? (completedAt ?? playedAt) : null,
      lastPlayedAt: playedAt,
    );
  }

  Catalog audioCatalog(
    Map<String, Map<String, dynamic>> tracks, {
    String identity = 'CAT-1',
  }) {
    return Catalog.fromJson({
      'generated_at': '2026-07-21T12:00:00+00:00',
      'total_items': tracks.length,
      'catalogue': {
        'id': identity,
        'scanner_version': '0.4.0',
        'catalogue_version': 3,
      },
      'folders': [
        {
          'id': 'music-root',
          'name': 'Music',
          'path': r'Y:\Media\Music',
          'item_count': tracks.length,
          'items': [
            for (final entry in tracks.entries)
              {
                'id': entry.key,
                'title': entry.value['title'] ?? entry.key,
                'file_path': entry.value['file_path'] ??
                    'Y:\\Media\\Music\\${entry.key}.mp3',
                'status': 'available',
                'media_kind': 'audio',
                if (entry.value['artist'] != null)
                  'artist': entry.value['artist'],
                if (entry.value['album'] != null) 'album': entry.value['album'],
                if (entry.value['duration_seconds'] != null)
                  'duration_seconds': entry.value['duration_seconds'],
              },
          ],
          'subfolders': [],
        },
      ],
    });
  }

  group('MusicListeningRecord', () {
    test('constructs with required fields', () {
      final record = testRecord();
      expect(record.trackId, trackA);
      expect(record.title, 'Oh Yeah');
      expect(record.replayPosition, const Duration(seconds: 45));
    });

    test('round-trips through JSON', () {
      final original = testRecord(
        lastPosition: const Duration(seconds: 90),
        completedAt: utc(2026, 7, 21, 13),
      );
      final restored = MusicListeningRecord.fromJsonWithRecovery(
        original.toJson(),
      );

      expect(restored, original.normalized());
    });

    test('copyWith updates fields immutably', () {
      final original = testRecord();
      final updated =
          original.copyWith(lastPosition: const Duration(seconds: 60));

      expect(original.lastPosition, const Duration(seconds: 45));
      expect(updated.lastPosition, const Duration(seconds: 60));
    });

    test('equality and hashCode match normalized values', () {
      final a = testRecord(lastPlayedAt: utc(2026, 7, 21, 10));
      final b = testRecord(lastPlayedAt: utc(2026, 7, 21, 10));

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('nullable duration survives JSON round trip', () {
      final record = testRecord(duration: null);
      final restored =
          MusicListeningRecord.fromJsonWithRecovery(record.toJson());

      expect(restored?.duration, isNull);
    });

    test('negative position clamps to zero', () {
      final normalized =
          testRecord(lastPosition: const Duration(seconds: -5)).normalized();

      expect(normalized.lastPosition, Duration.zero);
    });

    test('negative duration clamps to null', () {
      final normalized =
          testRecord(duration: const Duration(seconds: -1)).normalized();

      expect(normalized.duration, isNull);
    });

    test('position greater than duration clamps to duration', () {
      final normalized = testRecord(
        duration: const Duration(minutes: 3),
        lastPosition: const Duration(minutes: 4),
      ).normalized();

      expect(normalized.lastPosition, const Duration(minutes: 3));
    });

    test('completed clears completedAt when false', () {
      final normalized = testRecord(
        completed: false,
        completedAt: utc(2026, 7, 21, 14),
      ).normalized();

      expect(normalized.completed, isFalse);
      expect(normalized.completedAt, isNull);
    });

    test('completed sets lastPosition to zero and replayPosition to zero', () {
      final normalized = testRecord(
        completed: true,
        lastPosition: const Duration(minutes: 4),
      ).normalized();

      expect(normalized.lastPosition, Duration.zero);
      expect(normalized.replayPosition, Duration.zero);
      expect(normalized.completedAt, isNotNull);
    });

    test('incomplete replayPosition returns lastPosition', () {
      final record = testRecord(lastPosition: const Duration(seconds: 75));

      expect(record.replayPosition, const Duration(seconds: 75));
    });

    test('fromJsonWithRecovery skips malformed records', () {
      final warnings = <String>[];
      final record = MusicListeningRecord.fromJsonWithRecovery(
        {'trackId': '', 'lastPlayedAt': 'bad'},
        warnings: warnings,
      );

      expect(record, isNull);
      expect(warnings, isNotEmpty);
    });
  });

  group('MusicListeningRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('missing storage returns empty history', () async {
      final repository = MusicListeningRepository();
      final result = await repository.initialize();

      expect(result.source, MusicListeningLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(repository.isLoaded, isTrue);
    });

    test('valid envelope loads', () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [testRecord().toJson()],
        }),
      });

      final repository = MusicListeningRepository();
      final result = await repository.load();

      expect(result.source, MusicListeningLoadSource.envelope);
      expect(repository.allRecords, hasLength(1));
      expect(repository.getByTrackId(trackA)?.title, 'Oh Yeah');
    });

    test('invalid JSON recovers to empty history', () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: '{not json',
      });

      final repository = MusicListeningRepository();
      final result = await repository.load();

      expect(result.source, MusicListeningLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(result.recoveryWarnings, isNotEmpty);
    });

    test('unsupported stateVersion returns empty history', () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: jsonEncode({
          'stateVersion': 99,
          'records': [testRecord(trackId: trackB).toJson()],
        }),
      });

      final repository = MusicListeningRepository();
      final result = await repository.load();

      expect(result.source, MusicListeningLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(
        result.recoveryWarnings,
        contains(
          'Unsupported stateVersion 99; stored music listening history was not loaded.',
        ),
      );
    });

    test('unsupported envelope remains unchanged in storage after load',
        () async {
      final raw = jsonEncode({
        'stateVersion': 99,
        'records': [testRecord(trackId: trackB).toJson()],
      });
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: raw,
      });

      final repository = MusicListeningRepository();
      await repository.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MusicListeningRepository.storageKey), raw);
    });

    test('missing stateVersion returns empty history with warning', () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: jsonEncode({
          'records': [testRecord(trackId: trackB).toJson()],
        }),
      });

      final repository = MusicListeningRepository();
      final result = await repository.load();

      expect(result.source, MusicListeningLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(
        result.recoveryWarnings,
        contains(
          'Missing stateVersion; stored music listening history was not loaded.',
        ),
      );
    });

    test('supported v1 malformed records are skipped while valid remain',
        () async {
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [
            {'trackId': '', 'lastPlayedAt': '2026-07-21T12:00:00.000Z'},
            testRecord(trackId: trackB).toJson(),
          ],
        }),
      });

      final repository = MusicListeningRepository();
      final result = await repository.load();

      expect(result.recoveryWarnings, isNotEmpty);
      expect(repository.allRecords, hasLength(1));
      expect(repository.getByTrackId(trackB), isNotNull);
    });

    test('upsert creates a record', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      final result = await repository.upsert(testRecord());

      expect(result.success, isTrue);
      expect(repository.allRecords, hasLength(1));
    });

    test('upsert updates existing trackId without duplication', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(
        testRecord(lastPosition: const Duration(seconds: 40)),
      );
      await repository.upsert(
        testRecord(
          lastPosition: const Duration(seconds: 55),
          lastPlayedAt: utc(2026, 7, 21, 13),
        ),
      );

      expect(repository.allRecords, hasLength(1));
      expect(
        repository.getByTrackId(trackA)?.lastPosition,
        const Duration(seconds: 55),
      );
    });

    test('orders by lastPlayedAt descending', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(
        testRecord(trackId: trackA, lastPlayedAt: utc(2026, 7, 21, 10)),
      );
      await repository.upsert(
        testRecord(trackId: trackB, lastPlayedAt: utc(2026, 7, 21, 12)),
      );
      await repository.upsert(
        testRecord(trackId: trackC, lastPlayedAt: utc(2026, 7, 21, 11)),
      );

      expect(
        repository.allRecords.map((record) => record.trackId).toList(),
        [trackB, trackC, trackA],
      );
    });

    test('uses deterministic tie ordering by trackId', () async {
      final at = utc(2026, 7, 21, 12);
      final records = [
        testRecord(trackId: 'track-z', lastPlayedAt: at),
        testRecord(trackId: 'track-a', lastPlayedAt: at),
        testRecord(trackId: 'track-m', lastPlayedAt: at),
      ];

      records.sort(MusicListeningRepository.compareRecords);

      expect(
        records.map((record) => record.trackId).toList(),
        ['track-a', 'track-m', 'track-z'],
      );
    });

    test('remove deletes one record', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(testRecord(trackId: trackA));
      await repository.upsert(testRecord(trackId: trackB));
      await repository.remove(trackA);

      expect(repository.allRecords, hasLength(1));
      expect(repository.getByTrackId(trackB), isNotNull);
    });

    test('clear removes all records', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(testRecord(trackId: trackA));
      await repository.upsert(testRecord(trackId: trackB));
      await repository.clearAll();

      expect(repository.allRecords, isEmpty);
    });

    test('continueListening excludes completed records', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(
        testRecord(
          trackId: trackA,
          completed: true,
          lastPosition: Duration.zero,
        ),
      );
      await repository.upsert(
        testRecord(
          trackId: trackB,
          lastPosition: const Duration(seconds: 45),
        ),
      );

      expect(repository.continueListening(), hasLength(1));
      expect(repository.continueListening().single.trackId, trackB);
    });

    test('continueListening excludes records below 30 seconds', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(
        testRecord(
          trackId: trackA,
          lastPosition: const Duration(seconds: 20),
        ),
      );
      await repository.upsert(
        testRecord(
          trackId: trackB,
          lastPosition: const Duration(seconds: 45),
        ),
      );

      expect(repository.continueListening(), hasLength(1));
      expect(repository.continueListening().single.trackId, trackB);
    });

    test('continueListening excludes near-end incomplete records', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(
        testRecord(
          trackId: trackA,
          duration: const Duration(minutes: 5),
          lastPosition: const Duration(minutes: 4, seconds: 30),
        ),
      );

      expect(repository.continueListening(), isEmpty);
    });

    test('recentlyPlayed includes completed and incomplete records', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      await repository.upsert(
        testRecord(
            trackId: trackA, completed: true, lastPosition: Duration.zero),
      );
      await repository.upsert(
        testRecord(trackId: trackB, lastPosition: const Duration(seconds: 20)),
      );

      expect(repository.recentlyPlayed(limit: 10), hasLength(2));
    });

    test('recentlyPlayed default query cap is 20', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      for (var i = 0; i < 25; i++) {
        await repository.upsert(
          testRecord(
            trackId: 'track-$i',
            lastPlayedAt: utc(2026, 7, 21, 12, i),
          ),
        );
      }

      expect(repository.recentlyPlayed(), hasLength(20));
      expect(repository.storedRecordCount, 25);
    });

    test('retention cap keeps 100 newest records', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();

      for (var i = 0; i < 105; i++) {
        await repository.upsert(
          testRecord(
            trackId: 'track-$i',
            lastPlayedAt: utc(2026, 1, 1, 0, i),
          ),
        );
      }

      expect(repository.storedRecordCount, 100);
      expect(repository.getByTrackId('track-0'), isNull);
      expect(repository.getByTrackId('track-4'), isNull);
      expect(repository.getByTrackId('track-104'), isNotNull);
    });

    test('save and reload round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository
          .upsert(testRecord(lastPosition: const Duration(seconds: 88)));

      final reloaded = MusicListeningRepository();
      await reloaded.load();

      expect(
        reloaded.getByTrackId(trackA)?.lastPosition,
        const Duration(seconds: 88),
      );
    });

    test('storage failure returns unsuccessful result without throwing',
        () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      repository.simulatePersistFailure = true;

      final result = await repository.upsert(testRecord());

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('video keys remain untouched when music history mutates', () async {
      const videoItemId = 'video-item-1';
      SharedPreferences.setMockInitialValues({
        'position_$videoItemId': 120,
        'duration_$videoItemId': 3600,
      });

      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord());
      await repository.upsert(
        testRecord(
          trackId: trackB,
          lastPosition: const Duration(seconds: 50),
          lastPlayedAt: utc(2026, 7, 21, 13),
        ),
      );
      await repository.remove(trackA);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoItemId'), 120);
      expect(prefs.getInt('duration_$videoItemId'), 3600);
      expect(prefs.containsKey(MusicListeningRepository.storageKey), isTrue);
      expect(prefs.getString('position_$trackA'), isNull);
    });

    test('corrupt envelope does not overwrite storage on read', () async {
      const corrupt = '{bad json';
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: corrupt,
      });

      final repository = MusicListeningRepository();
      await repository.load();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MusicListeningRepository.storageKey), corrupt);
    });
  });

  group('MusicListeningRepository validateAgainstCatalog', () {
    test('identical catalogue makes no changes or persistence writes',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord(trackId: trackA));

      final catalog = audioCatalog({
        trackA: {
          'title': 'Oh Yeah',
          'artist': 'Example Artist',
          'album': 'Singles'
        },
      });
      final first = await repository.validateAgainstCatalog(catalog);
      final prefsAfterFirst = (await SharedPreferences.getInstance())
          .getString(MusicListeningRepository.storageKey);

      final second = await repository.validateAgainstCatalog(catalog);
      final prefsAfterSecond = (await SharedPreferences.getInstance())
          .getString(MusicListeningRepository.storageKey);

      expect(first.changed, isFalse);
      expect(first.persisted, isFalse);
      expect(second.changed, isFalse);
      expect(second.persisted, isFalse);
      expect(prefsAfterSecond, prefsAfterFirst);
      expect(repository.storedRecordCount, 1);
    });

    test('removed trackId is pruned', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord(trackId: trackA));
      await repository.upsert(testRecord(trackId: trackB));

      final result = await repository.validateAgainstCatalog(
        audioCatalog({
          trackA: {'title': 'Kept'}
        }),
      );

      expect(result.changed, isTrue);
      expect(result.removedCount, 1);
      expect(result.retainedCount, 1);
      expect(result.persisted, isTrue);
      expect(repository.getByTrackId(trackA), isNotNull);
      expect(repository.getByTrackId(trackB), isNull);
    });

    test('retained record preserves listening state', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      final playedAt = utc(2026, 7, 20, 9, 30);
      final completedAt = utc(2026, 7, 20, 10);
      await repository.upsert(
        testRecord(
          trackId: trackA,
          title: 'Old Title',
          lastPosition: const Duration(seconds: 142),
          completed: true,
          completedAt: completedAt,
          lastPlayedAt: playedAt,
        ),
      );

      await repository.validateAgainstCatalog(
        audioCatalog({
          trackA: {
            'title': 'Fresh Title',
            'artist': 'New Artist',
            'album': 'New Album',
            'duration_seconds': 300,
          },
        }),
      );

      final record = repository.getByTrackId(trackA)!;
      expect(record.title, 'Fresh Title');
      expect(record.artist, 'New Artist');
      expect(record.album, 'New Album');
      expect(record.duration, const Duration(minutes: 5));
      expect(record.lastPosition, Duration.zero);
      expect(record.completed, isTrue);
      expect(record.completedAt, completedAt);
      expect(record.lastPlayedAt, playedAt);
    });

    test('duplicate catalogue audio ids resolve deterministically', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord(trackId: 'dup-id', title: 'Stored'));

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-21T12:00:00+00:00',
        'total_items': 2,
        'catalogue': {
          'id': 'DUP',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'music-a',
            'name': 'A',
            'path': r'Y:\A',
            'item_count': 1,
            'items': [
              {
                'id': 'dup-id',
                'title': 'First Match',
                'file_path': r'Y:\A\first.mp3',
                'status': 'available',
                'media_kind': 'audio',
              },
            ],
            'subfolders': [],
          },
          {
            'id': 'music-b',
            'name': 'B',
            'path': r'Y:\B',
            'item_count': 1,
            'items': [
              {
                'id': 'dup-id',
                'title': 'Second Match',
                'file_path': r'Y:\B\second.mp3',
                'status': 'available',
                'media_kind': 'audio',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.changed, isTrue);
      expect(result.retainedCount, 1);
      expect(repository.getByTrackId('dup-id')?.title, 'First Match');
    });

    test('does not remap pruned records by title or artist', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(
        testRecord(
          trackId: 'old-id',
          title: 'Shared Title',
          artist: 'Shared Artist',
        ),
      );

      await repository.validateAgainstCatalog(
        audioCatalog({
          'new-id': {
            'title': 'Shared Title',
            'artist': 'Shared Artist',
          },
        }),
      );

      expect(repository.getByTrackId('old-id'), isNull);
      expect(repository.getByTrackId('new-id'), isNull);
      expect(repository.allRecords, isEmpty);
    });

    test('non-audio catalogue ids do not retain listening records', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord(trackId: trackA));

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-21T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {
          'id': 'VIDEO',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [
          {
            'id': 'videos',
            'name': 'Videos',
            'path': r'Y:\Videos',
            'item_count': 1,
            'items': [
              {
                'id': trackA,
                'title': 'Same Id Video',
                'file_path': r'Y:\Videos\clip.mp4',
                'status': 'available',
                'media_kind': 'video',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.removedCount, 1);
      expect(repository.allRecords, isEmpty);
    });

    test('persistence failure leaves in-memory history unchanged', () async {
      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord(trackId: trackA));
      await repository.upsert(testRecord(trackId: trackB));

      repository.simulatePersistFailure = true;
      final result = await repository.validateAgainstCatalog(
        audioCatalog({
          trackA: {'title': 'Kept'}
        }),
      );

      expect(result.changed, isFalse);
      expect(result.persistenceFailed, isTrue);
      expect(result.persisted, isFalse);
      expect(repository.storedRecordCount, 2);
      expect(repository.getByTrackId(trackB), isNotNull);
    });

    test('video Continue Watching keys remain unchanged during reconciliation',
        () async {
      const videoId = 'video-1';
      SharedPreferences.setMockInitialValues({
        'position_$videoId': 90,
        'duration_$videoId': 3600,
      });

      final repository = MusicListeningRepository();
      await repository.initialize();
      await repository.upsert(testRecord(trackId: trackA));
      await repository.upsert(testRecord(trackId: trackB));

      await repository.validateAgainstCatalog(
        audioCatalog({
          trackA: {'title': 'Kept'}
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoId'), 90);
      expect(prefs.getInt('duration_$videoId'), 3600);
    });
  });
}
