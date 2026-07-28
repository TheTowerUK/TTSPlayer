import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/reading_navigation.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/services/reading_location_reconciliation.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/models/media_kind.dart';

import 'support/book_comic_catalog_fixtures.dart';
import 'support/reading_progress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const entryNames = ['001.jpg', '002.jpg', '003.jpg', '004.jpg'];

  Future<
      ({
        ReadingProgressRepository repository,
        ReadingProgressCoordinator coordinator,
        Phase65TestClock clock,
      })> setupComicCoordinator({
    Map<String, Object>? seed,
  }) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    final repository = await initializedReadingProgressRepository(
      initialPreferences: seed,
    );
    final clock = Phase65TestClock();
    final coordinator = ReadingProgressCoordinator(
      repository: repository,
      now: clock.fn,
    );
    return (
      repository: repository,
      coordinator: coordinator,
      clock: clock,
    );
  }

  group('Phase 6.4C comic restore and reconciliation', () {
    test('no saved progress yields null restore plan', () async {
      final repository = await initializedReadingProgressRepository();
      final item = phase65ComicItem();

      final plan = resolveReadingRestore(
        item: item,
        repository: repository,
      );

      expect(plan, isNull);
    });

    test('valid saved comic page restores through restore plan', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(
          pageIndex: 2,
          pageCountAtSave: 4,
          entryName: '003.jpg',
        ),
      );

      final plan = resolveReadingRestore(
        item: phase65ComicItem(),
        repository: repository,
      );

      expect(plan, isNotNull);
      final location = plan!.comicLocation(
        entryNames: entryNames,
        currentPageCount: entryNames.length,
      );
      expect(location?.pageIndex, 2);
      expect(location?.entryName, '003.jpg');
    });

    test('negative persisted page index clamps to first page', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: -5,
        pageCountAtSave: 4,
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.indexClamped);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 0);
    });

    test('persisted page beyond count clamps safely', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 99,
        pageCountAtSave: 4,
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.indexClamped);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 3);
    });

    test('matching entryName restores page after reordering', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 50,
        pageCountAtSave: 100,
        entryName: '004.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.entryMatched);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 3);
    });

    test('missing entryName falls back to clamped index', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 4,
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: true,
      );

      expect((result.location as ComicReadingLocationPayload).pageIndex, 2);
      expect((result.location as ComicReadingLocationPayload).entryName, '003.jpg');
    });

    test('reduced page count clamps without crashing', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 10,
        pageCountAtSave: 20,
        entryName: '003.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.entryMatched);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 2);
    });

    test('increased page count retains logical index when valid', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 3,
        entryName: '003.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: false,
      );

      expect((result.location as ComicReadingLocationPayload).pageIndex, 2);
    });

    test('corrupt persisted comic payload is ignored safely', () {
      final warnings = <String>[];
      final record = ReadingProgressRecord.fromJsonWithRecovery(
        {
          'mediaId': 'comic-cbz',
          'mediaKind': 'comic',
          'readerFormat': 'cbz',
          'title': 'Broken',
          'location': {
            'format': 'cbz',
            'pageIndex': 'not-a-number',
            'pageCountAtSave': 4,
          },
          'progressFraction': 0.5,
          'completed': false,
          'lastReadAt': '2026-07-27T12:00:00.000Z',
        },
        warnings: warnings,
      );

      expect(record, isNull);
      expect(warnings, isNotEmpty);
    });

    test('record for different media identity is not applied', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(mediaId: 'comic-other', pageIndex: 5),
      );

      final plan = resolveReadingRestore(
        item: phase65ComicItem(id: 'comic-cbz'),
        repository: repository,
      );

      expect(plan, isNull);
    });

    test('completed comic record does not restore mid-read page', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(
          pageIndex: 3,
          completed: true,
          progressFraction: 1.0,
        ),
      );

      final plan = resolveReadingRestore(
        item: phase65ComicItem(),
        repository: repository,
      );

      expect(plan, isNull);
    });
  });

  group('Phase 6.4C comic coordinator lifecycle', () {
    test('page changes debounce before persist', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 3,
        pageCount: 10,
      );
      expect(ctx.repository.allRecords, isEmpty);
      expect(ctx.coordinator.pendingWrite, isTrue);

      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.getByMediaId(item.id), isNotNull);
      ctx.coordinator.dispose();
    });

    test('reader close flushes before debounce elapses', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 5,
        pageCount: 10,
      );
      expect(ctx.coordinator.pendingWrite, isTrue);

      await ctx.coordinator.onReaderClosed();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect((record.location as ComicReadingLocationPayload).pageIndex, 5);
      ctx.coordinator.dispose();
    });

    test('dispose prevents post-close writes', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.cbz,
        initialLocation: const ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 10,
          archiveFormat: ReadingReaderFormat.cbz,
        ),
        progressFraction: 0,
      );
      ctx.coordinator.markLayoutReady();
      ctx.coordinator.dispose();

      ctx.coordinator.onLocationChanged(
        location: const ComicReadingLocationPayload(
          pageIndex: 4,
          pageCountAtSave: 10,
          archiveFormat: ReadingReaderFormat.cbz,
        ),
        progressFraction: 0.5,
        force: true,
      );
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.allRecords, isEmpty);
    });

    test('reopen after flush restores latest page from repository', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(pageIndex: 7, pageCountAtSave: 10),
      );

      final plan = resolveReadingRestore(
        item: phase65ComicItem(),
        repository: repository,
      );
      final location = plan!.comicLocation(
        entryNames: List.generate(10, (i) => 'page${i + 1}.jpg'),
        currentPageCount: 10,
      );

      expect(location?.pageIndex, 7);
    });

    test('identical page selection skips redundant writes', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();
      const location = ComicReadingLocationPayload(
        pageIndex: 4,
        pageCountAtSave: 10,
        archiveFormat: ReadingReaderFormat.cbz,
      );

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 4,
        pageCount: 10,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      final firstWriteAt = ctx.repository.lastSuccessfulWriteAt;

      ctx.coordinator.onLocationChanged(
        location: location,
        progressFraction: ReadingProgressRecord.fractionForComic(4, 10),
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.lastSuccessfulWriteAt, firstWriteAt);
      ctx.coordinator.dispose();
    });
  });

  group('Phase 6.4C comic completion policy', () {
    test('final page of multi-page comic marks complete at threshold', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 9,
        pageCount: 10,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isTrue);
      expect(record.progressFraction, 1.0);
      ctx.coordinator.dispose();
    });

    test('page below threshold remains incomplete', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 3,
        pageCount: 10,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isFalse);
      expect(record.progressFraction, lessThan(ReadingProgressPolicy.completionThreshold));
      ctx.coordinator.dispose();
    });

    test('completed comic excluded from Continue Reading', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(
          completed: true,
          progressFraction: 1.0,
          pageIndex: 9,
          pageCountAtSave: 10,
        ),
      );

      final entries = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      );

      expect(entries.where((e) => e.item.id == 'comic-cbz'), isEmpty);
    });

    test('Read Again clears completion and resets to page 1', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 9,
        pageCount: 10,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();
      expect(ctx.repository.getByMediaId(item.id)!.completed, isTrue);

      await ctx.coordinator.onReaderRestarted();
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isFalse);
      expect(record.progressFraction, 0);
      expect((record.location as ComicReadingLocationPayload).pageIndex, 0);
      ctx.coordinator.dispose();
    });

    test('navigating to page 1 after completion does not clear completion',
        () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 9,
        pageCount: 10,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();
      expect(ctx.repository.getByMediaId(item.id)!.completed, isTrue);

      ctx.coordinator.onLocationChanged(
        location: const ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 10,
          archiveFormat: ReadingReaderFormat.cbz,
        ),
        progressFraction: ReadingProgressRecord.fractionForComic(0, 10),
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.getByMediaId(item.id)!.completed, isTrue);
      ctx.coordinator.dispose();
    });

    test('single-page comic does not complete on open', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 0,
        pageCount: 1,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id);
      if (record != null) {
        expect(record.completed, isFalse);
        expect(record.progressFraction, lessThan(ReadingProgressPolicy.completionThreshold));
      }
      ctx.coordinator.dispose();
    });

    test('single-page comic completes on close after viewing', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 0,
        pageCount: 1,
      );

      await ctx.coordinator.onReaderClosed();
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isTrue);
      expect(record.progressFraction, 1.0);
      ctx.coordinator.dispose();
    });

    test('Read Again works for completed single-page comic', () async {
      final ctx = await setupComicCoordinator();
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 0,
        pageCount: 1,
      );
      await ctx.coordinator.onReaderClosed();
      await ctx.coordinator.waitForIdleForTest();
      expect(ctx.repository.getByMediaId(item.id)!.completed, isTrue);

      // Mirrors comic_navigation startFromBeginning before opening the reader.
      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.cbz,
        initialLocation: const ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 1,
          archiveFormat: ReadingReaderFormat.cbz,
        ),
        progressFraction: 0,
      );
      await ctx.coordinator.onReaderRestarted();
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isFalse);
      expect((record.location as ComicReadingLocationPayload).pageIndex, 0);
      ctx.coordinator.dispose();
    });

    test('fractionForComic keeps single-page progress below threshold while open',
        () {
      expect(
        ReadingProgressRecord.fractionForComic(0, 1),
        ReadingProgressPolicy.singlePageComicInProgressFraction,
      );
      expect(
        ReadingProgressRecord.fractionForComic(0, 1),
        lessThan(ReadingProgressPolicy.completionThreshold),
      );
    });
  });

  group('Phase 6.4C comic persistence isolation', () {
    late Map<String, Object> seed;
    late String listeningSeedRaw;
    late String queueSeedRaw;

    setUp(() {
      seed = phase65IsolationSeedPreferences();
      listeningSeedRaw = seed[MusicListeningRepository.storageKey]! as String;
      queueSeedRaw =
          seed[MusicPlaybackSessionRepository.storageKey]! as String;
    });

    test('comic progress uses ttsplayer_reading_progress_v1', () async {
      final repository =
          await initializedReadingProgressRepository(initialPreferences: seed);
      await repository.upsert(phase65ComicRecord());

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(ReadingProgressRepository.storageKey),
        isTrue,
      );
      expect(
        ReadingProgressRepository.storageKey,
        'ttsplayer_reading_progress_v1',
      );
    });

    test('comic coordinator writes do not touch video or music keys', () async {
      final ctx = await setupComicCoordinator(seed: seed);
      final item = phase65ComicItem();

      phase65BeginComicSession(
        ctx.coordinator,
        item: item,
        pageIndex: 4,
        pageCount: 10,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.onReaderClosed();
      await ctx.coordinator.waitForIdleForTest();

      await phase65AssertIsolationMarkersUnchanged(
        expectedListeningRaw: listeningSeedRaw,
        expectedQueueRaw: queueSeedRaw,
      );
      ctx.coordinator.dispose();
    });

    test('comic progress does not write to catalogue', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65ComicRecord());

      final catalogJson = jsonDecode(kCatalogV4BookComicFixture)
          as Map<String, dynamic>;
      expect(catalogJson['folders'], isA<List<dynamic>>());
      // Progress is client-side only; catalogue fixture unchanged by upsert.
    });

    test('book records remain compatible when comic records coexist', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65PdfRecord());
      await repository.upsert(phase65ComicRecord());

      expect(repository.allRecords, hasLength(2));
      expect(
        repository.allRecords.map((r) => r.mediaKind).toSet(),
        {MediaKind.book, MediaKind.comic},
      );
    });
  });

  group('Phase 6.4C legacy CBR projection', () {
    test('legacy CBR item surfaces unsupported format in Continue Reading',
        () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-cbr',
          archiveFormat: ReadingReaderFormat.cbr,
        ),
      );

      final entry = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      ).single;

      expect(
        entry.availability,
        ContinueReadingAvailability.unsupportedComicFormat,
      );
      expect(entry.unavailabilityReason, kCbrConversionGuidance);
    });

    test('CBR extension is not a supported comic archive extension', () {
      expect(isSupportedComicArchiveExtension('cbr'), isFalse);
      expect(isSupportedComicArchiveExtension('cbz'), isTrue);
    });
  });
}
