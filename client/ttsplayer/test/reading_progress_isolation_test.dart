import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';

import 'support/reading_progress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reading progress isolation', () {
    late Map<String, Object> seed;
    late String listeningSeedRaw;
    late String queueSeedRaw;

    setUp(() {
      seed = phase65IsolationSeedPreferences();
      listeningSeedRaw = seed[MusicListeningRepository.storageKey]! as String;
      queueSeedRaw =
          seed[MusicPlaybackSessionRepository.storageKey]! as String;
      SharedPreferences.setMockInitialValues(seed);
    });

    test('repository upsert does not mutate music or video keys', () async {
      final repository =
          await initializedReadingProgressRepository(initialPreferences: seed);
      await repository.upsert(phase65PdfRecord(pageIndex: 6));
      await repository.upsert(phase65EpubRecord(mediaId: 'book-epub'));
      await repository.remove('book-epub');

      await phase65AssertIsolationMarkersUnchanged(
        expectedListeningRaw: listeningSeedRaw,
        expectedQueueRaw: queueSeedRaw,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(ReadingProgressRepository.storageKey),
        isTrue,
      );
    });

    test('repository validateAgainstCatalog leaves foreign keys untouched',
        () async {
      final repository =
          await initializedReadingProgressRepository(initialPreferences: seed);
      await repository.upsert(phase65PdfRecord());
      await repository.upsert(
        phase65ComicRecord(mediaId: 'comic-cbz'),
      );

      await repository.validateAgainstCatalog(
        phase65ReadingCatalog(),
      );

      await phase65AssertIsolationMarkersUnchanged(
        expectedListeningRaw: listeningSeedRaw,
        expectedQueueRaw: queueSeedRaw,
      );
    });

    test('coordinator writes do not touch music listening or queue keys',
        () async {
      final repository =
          await initializedReadingProgressRepository(initialPreferences: seed);
      final clock = Phase65TestClock();
      final coordinator = ReadingProgressCoordinator(
        repository: repository,
        now: clock.fn,
      );
      final item = phase65BookItem();

      phase65BeginPdfSession(
        coordinator,
        item: item,
        pageIndex: 10,
        progressFraction: 0.08,
      );
      clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await coordinator.onReaderClosed();
      await coordinator.waitForIdleForTest();

      await phase65AssertIsolationMarkersUnchanged(
        expectedListeningRaw: listeningSeedRaw,
        expectedQueueRaw: queueSeedRaw,
      );

      coordinator.dispose();
    });

    test('reading progress envelope is separate from music envelopes',
        () async {
      final repository =
          await initializedReadingProgressRepository(initialPreferences: seed);
      await repository.upsert(phase65PdfRecord());

      final prefs = await SharedPreferences.getInstance();
      final readingRaw = prefs.getString(ReadingProgressRepository.storageKey);
      expect(readingRaw, isNotNull);

      final readingEnvelope = jsonDecode(readingRaw!) as Map<String, dynamic>;
      expect(readingEnvelope['stateVersion'],
          ReadingProgressRepository.currentStateVersion);
      expect(readingEnvelope['records'], isA<List<dynamic>>());

      expect(
        prefs.getString(MusicListeningRepository.storageKey),
        listeningSeedRaw,
      );
      expect(
        prefs.getString(MusicPlaybackSessionRepository.storageKey),
        queueSeedRaw,
      );
      expect(prefs.getInt('position_phase65-video-probe'), 456);
      expect(prefs.getInt('duration_phase65-video-probe'), 7200);
    });
  });
}
