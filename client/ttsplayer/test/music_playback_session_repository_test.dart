import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_playback_session.dart';
import 'package:ttsplayer/features/music/models/music_playback_session_policy.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const trackA = 'track-a';
  const trackB = 'track-b';
  const trackC = 'track-c';

  DateTime utc(int year, int month, int day, [int hour = 12, int minute = 0]) {
    return DateTime.utc(year, month, day, hour, minute);
  }

  MusicPlaybackSession testSession({
    List<String> queueTrackIds = const [trackA, trackB, trackC],
    String? activeTrackId = trackB,
    Duration playbackPosition = const Duration(milliseconds: 142000),
    DateTime? updatedAt,
  }) {
    return MusicPlaybackSession(
      queueTrackIds: queueTrackIds,
      activeTrackId: activeTrackId,
      playbackPosition: playbackPosition,
      updatedAt: updatedAt ?? utc(2026, 7, 22),
    );
  }

  Map<String, dynamic> envelopeJson(MusicPlaybackSession session) {
    return {
      'stateVersion': MusicPlaybackSessionRepository.currentStateVersion,
      'session': session.toSessionJson(),
    };
  }

  group('MusicPlaybackSession', () {
    test('1 empty initial state', () {
      final session = MusicPlaybackSession(
        queueTrackIds: const [],
        activeTrackId: null,
        playbackPosition: Duration.zero,
        updatedAt: utc(1970, 1, 1),
      );

      expect(session.isEmpty, isTrue);
      expect(session.normalized().activeTrackId, isNull);
      expect(session.normalized().playbackPosition, Duration.zero);
    });

    test('7 negative position normalisation', () {
      final normalized = testSession(
        playbackPosition: const Duration(milliseconds: -500),
      ).normalized();

      expect(normalized.playbackPosition, Duration.zero);
    });

    test('8 blank queue identities removed', () {
      final normalized = testSession(
        queueTrackIds: ['', '  ', trackA, trackB],
        activeTrackId: trackA,
      ).normalized();

      expect(normalized.queueTrackIds, [trackA, trackB]);
    });

    test('9 duplicate queue identities removed deterministically', () {
      final normalized = testSession(
        queueTrackIds: [trackA, trackB, trackA, trackC, trackB],
        activeTrackId: trackC,
      ).normalized();

      expect(normalized.queueTrackIds, [trackA, trackB, trackC]);
      expect(normalized.activeTrackId, trackC);
    });

    test('10 empty queue clears active track and position', () {
      final normalized = testSession(
        queueTrackIds: const [],
        activeTrackId: trackA,
        playbackPosition: const Duration(seconds: 30),
      ).normalized();

      expect(normalized.isEmpty, isTrue);
      expect(normalized.activeTrackId, isNull);
      expect(normalized.playbackPosition, Duration.zero);
    });

    test('11 active track missing from queue falls back to first item', () {
      final normalized = testSession(
        queueTrackIds: [trackA, trackB, trackC],
        activeTrackId: 'missing-id',
      ).normalized();

      expect(normalized.activeTrackId, trackA);
    });

    test('round-trips through session JSON', () {
      final original = testSession(
        playbackPosition: const Duration(milliseconds: 90000),
      );
      final restored = MusicPlaybackSession.fromSessionJsonWithRecovery(
        original.toSessionJson(),
      );

      expect(restored, original.normalized());
    });

    test('equality and hashCode match normalized values', () {
      final a = testSession(updatedAt: utc(2026, 7, 22, 10));
      final b = testSession(updatedAt: utc(2026, 7, 22, 10));

      expect(a.normalized(), equals(b.normalized()));
      expect(a.normalized().hashCode, b.normalized().hashCode);
    });

    test('caps queueTrackIds at policy max', () {
      final ids = List<String>.generate(
        MusicPlaybackSessionPolicy.maxPersistedTrackIds + 10,
        (index) => 'track-$index',
      );
      final normalized = testSession(queueTrackIds: ids).normalized();

      expect(
        normalized.queueTrackIds.length,
        MusicPlaybackSessionPolicy.maxPersistedTrackIds,
      );
      expect(normalized.queueTrackIds.first, 'track-0');
    });
  });

  group('MusicPlaybackSessionRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1 empty initial state before load', () {
      final repository = MusicPlaybackSessionRepository();
      expect(repository.session.isEmpty, isTrue);
    });

    test('2 missing storage key returns empty session', () async {
      final repository = MusicPlaybackSessionRepository();
      final result = await repository.initialize();

      expect(result.source, MusicPlaybackSessionLoadSource.defaults);
      expect(repository.session.isEmpty, isTrue);
      expect(result.recoveryWarnings, isEmpty);
      expect(repository.isLoaded, isTrue);
    });

    test('3 valid save and load', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();

      await repository.save(testSession(activeTrackId: trackA));
      final reloaded = MusicPlaybackSessionRepository();
      final result = await reloaded.load();

      expect(result.source, MusicPlaybackSessionLoadSource.envelope);
      expect(reloaded.session.queueTrackIds, [trackA, trackB, trackC]);
      expect(reloaded.session.activeTrackId, trackA);
    });

    test('4 queue order preservation', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        testSession(
          queueTrackIds: [trackC, trackA, trackB],
          activeTrackId: trackA,
        ),
      );

      final reloaded = MusicPlaybackSessionRepository();
      await reloaded.load();

      expect(reloaded.session.queueTrackIds, [trackC, trackA, trackB]);
    });

    test('5 active track preservation', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(testSession(activeTrackId: trackC));

      final reloaded = MusicPlaybackSessionRepository();
      await reloaded.load();

      expect(reloaded.session.activeTrackId, trackC);
    });

    test('6 playback position preservation', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(
        testSession(playbackPosition: const Duration(milliseconds: 88123)),
      );

      final reloaded = MusicPlaybackSessionRepository();
      await reloaded.load();

      expect(
        reloaded.session.playbackPosition,
        const Duration(milliseconds: 88123),
      );
    });

    test('12 invalid JSON recovery', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: '{not json',
      });

      final repository = MusicPlaybackSessionRepository();
      final result = await repository.load();

      expect(result.source, MusicPlaybackSessionLoadSource.defaults);
      expect(repository.session.isEmpty, isTrue);
      expect(result.recoveryWarnings, isNotEmpty);
    });

    test('13 invalid envelope recovery', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'session': 'not-an-object',
        }),
      });

      final repository = MusicPlaybackSessionRepository();
      final result = await repository.load();

      expect(result.source, MusicPlaybackSessionLoadSource.defaults);
      expect(repository.session.isEmpty, isTrue);
      expect(result.recoveryWarnings, isNotEmpty);
    });

    test('14 unsupported version handling', () async {
      final raw = jsonEncode({
        'stateVersion': 99,
        'session': testSession(
          queueTrackIds: [trackB],
          activeTrackId: trackB,
        ).toSessionJson(),
      });
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: raw,
      });

      final repository = MusicPlaybackSessionRepository();
      final result = await repository.load();

      expect(result.source, MusicPlaybackSessionLoadSource.defaults);
      expect(repository.session.isEmpty, isTrue);
      expect(
        result.recoveryWarnings,
        contains(
          'Unsupported stateVersion 99; stored music playback session was not loaded.',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MusicPlaybackSessionRepository.storageKey), raw);
    });

    test('15 partially malformed queue recovery', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'session': {
            'queueTrackIds': ['', trackA, 42, trackB],
            'activeTrackId': trackB,
            'playbackPositionMs': 5000,
            'updatedAt': '2026-07-22T12:00:00.000Z',
          },
        }),
      });

      final repository = MusicPlaybackSessionRepository();
      final result = await repository.load();

      expect(result.source, MusicPlaybackSessionLoadSource.envelope);
      expect(repository.session.queueTrackIds, [trackA, trackB]);
      expect(repository.session.activeTrackId, trackB);
      expect(result.recoveryWarnings, isNotEmpty);
    });

    test('16 clear operation', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(testSession());

      final result = await repository.clear();

      expect(result.outcome, MusicPlaybackSessionClearOutcome.cleared);
      expect(repository.session.isEmpty, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(MusicPlaybackSessionRepository.storageKey);
      expect(raw, isNotNull);
      final envelope = jsonDecode(raw!) as Map<String, dynamic>;
      expect(envelope['stateVersion'],
          MusicPlaybackSessionRepository.currentStateVersion);
      expect(
        (envelope['session'] as Map<String, dynamic>)['queueTrackIds'],
        isEmpty,
      );
    });

    test('17 clear affects only session storage key', () async {
      const videoItemId = 'video-item-1';
      SharedPreferences.setMockInitialValues({
        'position_$videoItemId': 120,
        'duration_$videoItemId': 3600,
        MusicListeningRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [],
        }),
        LibraryMetadataRepository.storageKey: jsonEncode({
          'metadataVersion': 1,
          'favourites': {'items': [], 'folders': []},
        }),
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(testSession());
      await repository.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoItemId'), 120);
      expect(prefs.getInt('duration_$videoItemId'), 3600);
      expect(prefs.containsKey(MusicListeningRepository.storageKey), isTrue);
      expect(prefs.containsKey(LibraryMetadataRepository.storageKey), isTrue);
      expect(
        prefs.containsKey(MusicPlaybackSessionRepository.storageKey),
        isTrue,
      );
    });

    test('18 listening-history key remains unchanged', () async {
      final listeningRaw = jsonEncode({
        'stateVersion': 1,
        'records': [
          {
            'trackId': trackA,
            'title': 'Song',
            'artist': 'Artist',
            'album': 'Album',
            'lastPosition': 45,
            'completed': false,
            'lastPlayedAt': '2026-07-22T12:00:00.000Z',
          },
        ],
      });
      SharedPreferences.setMockInitialValues({
        MusicListeningRepository.storageKey: listeningRaw,
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(testSession());
      await repository.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(MusicListeningRepository.storageKey),
        listeningRaw,
      );
    });

    test('19 video resume keys remain unchanged', () async {
      const videoId = 'video-1';
      SharedPreferences.setMockInitialValues({
        'position_$videoId': 90,
        'duration_$videoId': 3600,
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      await repository.save(testSession());
      await repository.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_$videoId'), 90);
      expect(prefs.getInt('duration_$videoId'), 3600);
    });

    test('20 repeated initialize remains deterministic', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey:
            jsonEncode(envelopeJson(testSession(activeTrackId: trackA))),
      });

      final repository = MusicPlaybackSessionRepository();
      final first = await repository.initialize();
      final second = await repository.initialize();

      expect(second.session, first.session);
      expect(second.source, first.source);
      expect(second.recoveryWarnings, first.recoveryWarnings);
    });

    test('21 save after recovery produces valid version 1 state', () async {
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: '{bad json',
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.load();
      expect(repository.session.isEmpty, isTrue);

      final saveResult =
          await repository.save(testSession(activeTrackId: trackB));
      expect(saveResult.success, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final envelope = jsonDecode(
        prefs.getString(MusicPlaybackSessionRepository.storageKey)!,
      ) as Map<String, dynamic>;
      expect(envelope['stateVersion'], 1);
      final session = envelope['session'] as Map<String, dynamic>;
      expect(session['queueTrackIds'], [trackA, trackB, trackC]);
      expect(session['activeTrackId'], trackB);
    });

    test('corrupt envelope does not overwrite storage on read', () async {
      const corrupt = '{bad json';
      SharedPreferences.setMockInitialValues({
        MusicPlaybackSessionRepository.storageKey: corrupt,
      });

      final repository = MusicPlaybackSessionRepository();
      await repository.load();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(MusicPlaybackSessionRepository.storageKey),
        corrupt,
      );
    });

    test('clear on empty session is a no-op', () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();

      final result = await repository.clear();
      expect(result.outcome, MusicPlaybackSessionClearOutcome.alreadyEmpty);
    });

    test('storage failure returns unsuccessful result without throwing',
        () async {
      final repository = MusicPlaybackSessionRepository();
      await repository.initialize();
      repository.simulatePersistFailure = true;

      final result = await repository.save(testSession());

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      expect(repository.session.isEmpty, isTrue);
    });
  });
}
