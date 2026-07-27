import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';

import 'support/reading_progress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({ReadingProgressRepository repository, ReadingProgressCoordinator coordinator, Phase65TestClock clock})>
      setupCoordinator() async {
    SharedPreferences.setMockInitialValues({});
    final repository = await initializedReadingProgressRepository();
    final clock = Phase65TestClock();
    final coordinator = ReadingProgressCoordinator(
      repository: repository,
      now: clock.fn,
    );
    return (repository: repository, coordinator: coordinator, clock: clock);
  }

  group('ReadingProgressCoordinator debounce', () {
    test('does not persist before debounce elapses', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      phase65BeginPdfSession(ctx.coordinator, item: item);
      expect(ctx.repository.allRecords, isEmpty);
      expect(ctx.coordinator.pendingWrite, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(ctx.repository.allRecords, isEmpty);

      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.getByMediaId(item.id), isNotNull);
      ctx.coordinator.dispose();
    });

    test('coalesces rapid location changes into one write', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 120,
        ),
        progressFraction: 0,
      );
      ctx.coordinator.markLayoutReady();

      for (var page = 2; page <= 6; page++) {
        ctx.clock.advance(const Duration(milliseconds: 200));
        ctx.coordinator.onLocationChanged(
          location: PdfReadingLocationPayload(
            pageIndex: page,
            pageCountAtSave: 120,
          ),
          progressFraction: page / 120,
        );
      }

      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.allRecords, hasLength(1));
      expect(
        (ctx.repository.getByMediaId(item.id)!.location
                as PdfReadingLocationPayload)
            .pageIndex,
        6,
      );
      ctx.coordinator.dispose();
    });
  });

  group('ReadingProgressCoordinator duplicate suppression', () {
    test('identical location and fraction skip redundant writes', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();
      final location = PdfReadingLocationPayload(
        pageIndex: 4,
        pageCountAtSave: 120,
      );

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 120,
        ),
        progressFraction: 0,
      );
      ctx.coordinator.markLayoutReady();
      ctx.coordinator.onLocationChanged(
        location: location,
        progressFraction: 0.04,
      );

      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      final firstWriteAt = ctx.repository.lastSuccessfulWriteAt;
      expect(firstWriteAt, isNotNull);

      ctx.coordinator.onLocationChanged(
        location: location,
        progressFraction: 0.04,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.lastSuccessfulWriteAt, firstWriteAt);
      ctx.coordinator.dispose();
    });
  });

  group('ReadingProgressCoordinator flush', () {
    test('reader close flushes pending progress', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      phase65BeginPdfSession(
        ctx.coordinator,
        item: item,
        pageIndex: 8,
        progressFraction: 0.07,
      );

      await ctx.coordinator.onReaderClosed();

      final record = ctx.repository.getByMediaId(item.id);
      expect(record, isNotNull);
      expect(
        (record!.location as PdfReadingLocationPayload).pageIndex,
        8,
      );
      expect(ctx.coordinator.sessionActive, isFalse);
      ctx.coordinator.dispose();
    });

    test('completion at threshold flushes immediately', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 100,
        ),
        progressFraction: 0,
      );
      ctx.coordinator.markLayoutReady();
      ctx.coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 94,
          pageCountAtSave: 100,
        ),
        progressFraction: ReadingProgressPolicy.completionThreshold,
      );

      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isTrue);
      expect(record.progressFraction, 1.0);
      expect(record.completedAt, ctx.clock.now);
      ctx.coordinator.dispose();
    });

    test('onReaderCompleted marks record completed', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 10,
          pageCountAtSave: 100,
        ),
        progressFraction: 0.5,
      );
      ctx.coordinator.markLayoutReady();

      await ctx.coordinator.onReaderCompleted();
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isTrue);
      expect(record.progressFraction, 1.0);
      ctx.coordinator.dispose();
    });

    test('restart resets progress and persists incomplete record', () async {
      final ctx = await setupCoordinator();
      final item = phase65EpubItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.epub,
        initialLocation: EpubReadingLocationPayload(
          spineIndex: 4,
          spineHref: 'chapter3.xhtml',
          spineCountAtSave: 12,
          sectionRelativeOffset: 80,
        ),
        progressFraction: 0.35,
      );
      ctx.coordinator.markLayoutReady();

      await ctx.coordinator.onReaderRestarted();
      await ctx.coordinator.waitForIdleForTest();

      final record = ctx.repository.getByMediaId(item.id)!;
      expect(record.completed, isFalse);
      expect(record.progressFraction, 0);
      final location = record.location as EpubReadingLocationPayload;
      expect(location.spineIndex, 0);
      expect(location.sectionRelativeOffset, 0);
      ctx.coordinator.dispose();
    });

    test('drainPendingWrites awaits in-flight completion write', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 100,
        ),
        progressFraction: 0,
      );
      ctx.coordinator.markLayoutReady();
      ctx.coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 94,
          pageCountAtSave: 100,
        ),
        progressFraction: ReadingProgressPolicy.completionThreshold,
      );

      await ctx.coordinator.drainPendingWrites();

      expect(ctx.repository.getByMediaId(item.id)?.completed, isTrue);
      ctx.coordinator.dispose();
    });
  });

  group('ReadingProgressCoordinator disposal', () {
    test('dispose cancels pending debounced write', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      phase65BeginPdfSession(ctx.coordinator, item: item, pageIndex: 5);
      expect(ctx.coordinator.pendingWrite, isTrue);

      ctx.coordinator.dispose();
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);

      expect(ctx.repository.allRecords, isEmpty);
    });

    test('no writes after disposal', () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      ctx.coordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 50,
        ),
        progressFraction: 0,
      );
      ctx.coordinator.markLayoutReady();
      ctx.coordinator.dispose();

      ctx.coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 3,
          pageCountAtSave: 50,
        ),
        progressFraction: 0.06,
        force: true,
      );
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.allRecords, isEmpty);
    });
  });

  group('ReadingProgressCoordinator failure isolation', () {
    test('repository failure surfaces warning and later write succeeds',
        () async {
      final ctx = await setupCoordinator();
      final item = phase65BookItem();

      ctx.repository.simulatePersistFailure = true;
      phase65BeginPdfSession(ctx.coordinator, item: item, pageIndex: 4);
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.coordinator.lastPersistenceWarning, isNotNull);

      ctx.repository.simulatePersistFailure = false;
      ctx.coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 6,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.05,
      );
      ctx.clock.advancePastDebounce();
      await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
      await ctx.coordinator.waitForIdleForTest();

      expect(ctx.repository.getByMediaId(item.id), isNotNull);
      ctx.coordinator.dispose();
    });
  });
}
