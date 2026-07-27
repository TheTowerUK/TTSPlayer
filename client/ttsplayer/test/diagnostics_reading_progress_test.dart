import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';

import 'support/diagnostics_test_harness.dart';
import 'support/reading_progress_test_support.dart';

ReadingProgressCoordinator _readingCoordinatorHarness({
  required ReadingProgressRepository repository,
  Phase65TestClock? clock,
}) {
  return ReadingProgressCoordinator(
    repository: repository,
    now: clock?.fn ?? DateTime.now,
  );
}

Future<ReadingProgressRepository> _repositoryWithRecords(
  List<ReadingProgressRecord> records,
) async {
  SharedPreferences.setMockInitialValues({
    ReadingProgressRepository.storageKey: jsonEncode({
      'stateVersion': ReadingProgressRepository.currentStateVersion,
      'records': records.map((record) => record.toJson()).toList(),
    }),
  });
  final repository = ReadingProgressRepository();
  await repository.initialize();
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Reading progress diagnostics capture', () {
    test('maps empty initialized repository', () async {
      final repository = await initializedReadingProgressRepository();
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      final reading = snapshot.readingProgress;

      expect(reading?.status, DiagnosticSectionStatus.complete);
      expect(reading?.repositoryInitialized, isTrue);
      expect(reading?.schemaVersion, 1);
      expect(reading?.storedRecordCount, 0);
      expect(reading?.continueReadingCount, 0);
      expect(reading?.completedRecordCount, 0);
      expect(reading?.staleOrUnmatchedRecordCount, 0);
      expect(reading?.invalidSkippedRecordCount, 0);
      expect(reading?.pdfRecordCount, 0);
      expect(reading?.epubRecordCount, 0);
      expect(reading?.cbzRecordCount, 0);
      expect(reading?.legacyCbrRecordCount, 0);
      expect(reading?.unsupportedComicFormatRecordCount, 0);
    });

    test('maps mixed format aggregates and continue versus completed counts',
        () async {
      final repository = await _repositoryWithRecords([
        phase65PdfRecord(progressFraction: 0.12),
        phase65EpubRecord(progressFraction: 0.22),
        phase65ComicRecord(progressFraction: 0.32),
        phase65ComicRecord(
          mediaId: 'comic-cbr',
          title: 'Batman 01',
          archiveFormat: ReadingReaderFormat.cbr,
          entryName: 'page001.jpg',
          progressFraction: 0.18,
        ),
        phase65PdfRecord(
          mediaId: 'book-complete',
          progressFraction: 1.0,
          completed: true,
        ),
      ]);
      final coordinator = _readingCoordinatorHarness(repository: repository);
      final service = await buildDiagnosticsHarness(
        catalog: phase65ReadingCatalog(),
        readingProgressRepository: repository,
        readingProgressCoordinator: coordinator,
      );

      final snapshot = await service.captureSnapshot();
      final reading = snapshot.readingProgress;

      expect(reading?.storedRecordCount, 5);
      expect(reading?.continueReadingCount, 4);
      expect(reading?.completedRecordCount, 1);
      expect(reading?.pdfRecordCount, 2);
      expect(reading?.epubRecordCount, 1);
      expect(reading?.cbzRecordCount, 1);
      expect(reading?.legacyCbrRecordCount, 1);
      expect(reading?.coordinatorAttached, isTrue);
    });

    test('counts unsupported comic format records', () async {
      final repository = await _repositoryWithRecords([
        phase65ComicRecord(
          mediaId: 'comic-cbr',
          archiveFormat: ReadingReaderFormat.cbr,
          entryName: '001.jpg',
          progressFraction: 0.2,
        ),
      ]);
      final service = await buildDiagnosticsHarness(
        catalog: phase65ReadingCatalog(),
        readingProgressRepository: repository,
      );

      final reading = (await service.captureSnapshot()).readingProgress;

      expect(reading?.legacyCbrRecordCount, 1);
      expect(reading?.unsupportedComicFormatRecordCount, 1);
    });

    test('maps malformed-entry recovery count from last load', () async {
      final envelope = {
        'stateVersion': 1,
        'records': [
          {'mediaId': 'orphan', 'not-a-record': true},
          phase65PdfRecord().toJson(),
        ],
      };
      final repository = await initializedReadingProgressRepository(
        initialPreferences: {
          ReadingProgressRepository.storageKey: jsonEncode(envelope),
        },
      );
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
      );

      final reading = (await service.captureSnapshot()).readingProgress;

      expect(reading?.storedRecordCount, 1);
      expect(reading?.invalidSkippedRecordCount, greaterThan(0));
      expect(reading?.recoveryWarningPresent, isTrue);
    });

    test('maps pending debounced write state', () async {
      final repository = await _repositoryWithRecords([
        phase65PdfRecord(),
      ]);
      final coordinator = _readingCoordinatorHarness(repository: repository);
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
        readingProgressCoordinator: coordinator,
      );

      coordinator.beginSession(
        item: phase65BookItem(),
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.05,
      );
      coordinator.markLayoutReady();
      coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 5,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.06,
      );

      final reading = (await service.captureSnapshot()).readingProgress;

      expect(reading?.pendingWrite, isTrue);
      expect(reading?.pendingDebounceWrite, isTrue);
      expect(reading?.sessionActive, isTrue);
    });

    test('maps successful flush timestamp', () async {
      final clock = Phase65TestClock(DateTime.utc(2026, 7, 27, 14));
      final repository = await _repositoryWithRecords([
        phase65PdfRecord(),
      ]);
      final coordinator = _readingCoordinatorHarness(
        repository: repository,
        clock: clock,
      );
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
        readingProgressCoordinator: coordinator,
      );

      coordinator.beginSession(
        item: phase65BookItem(),
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.05,
      );
      coordinator.markLayoutReady();
      coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 5,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.06,
        force: true,
      );
      await coordinator.waitForIdleForTest();

      final reading = (await service.captureSnapshot()).readingProgress;

      expect(reading?.lastSuccessfulFlushAt, clock.now);
      expect(reading?.lastSuccessfulWriteAt, isNotNull);
    });

    test('maps repository write failure classification', () async {
      final repository = await _repositoryWithRecords([
        phase65PdfRecord(),
      ]);
      repository.simulatePersistFailure = true;
      final coordinator = _readingCoordinatorHarness(repository: repository);
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
        readingProgressCoordinator: coordinator,
      );

      coordinator.beginSession(
        item: phase65BookItem(),
        readerFormat: ReadingReaderFormat.pdf,
        initialLocation: const PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.05,
      );
      coordinator.markLayoutReady();
      coordinator.onLocationChanged(
        location: const PdfReadingLocationPayload(
          pageIndex: 5,
          pageCountAtSave: 120,
        ),
        progressFraction: 0.06,
        force: true,
      );
      await coordinator.waitForIdleForTest();

      final reading = (await service.captureSnapshot()).readingProgress;

      expect(reading?.lastRepositoryErrorClassification, isNotNull);
      expect(reading?.persistenceWarningPresent, isTrue);
      expect(
        reading?.lastPersistenceWarningSummary,
        contains('Could not save reading progress'),
      );
    });

    test('maps catalogue reconciliation summary', () async {
      final repository = await _repositoryWithRecords([
        phase65PdfRecord(mediaId: 'book-pdf'),
        phase65PdfRecord(
          mediaId: 'missing-item',
          title: 'Ghost Book',
        ),
        phase65PdfRecord(mediaId: 'comic-cbz'),
      ]);
      final catalog = phase65ReadingCatalog();
      await repository.validateAgainstCatalog(catalog);

      final service = await buildDiagnosticsHarness(
        catalog: catalog,
        readingProgressRepository: repository,
      );

      final reading = (await service.captureSnapshot()).readingProgress;

      expect(reading?.reconciliationRemovedMissingCount, 1);
      expect(reading?.reconciliationRemovedFormatMismatchCount, 1);
      expect(reading?.reconciliationRetainedCount, 1);
    });

    test('unloaded repository yields null section', () async {
      final repository = ReadingProgressRepository();
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.readingProgress, isNull);
    });
  });

  group('Reading progress diagnostics export', () {
    test('export contains section heading and aggregate values only', () async {
      final repository = await _repositoryWithRecords([
        phase65EpubRecord(
          spineHref: 'secret-chapter.xhtml',
          chapterTitle: 'Secret Chapter',
        ),
        phase65ComicRecord(entryName: 'secret-page.jpg'),
      ]);
      final service = await buildDiagnosticsHarness(
        readingProgressRepository: repository,
      );

      final export = service.formatExport(await service.captureSnapshot());

      expect(export, contains('=== Reading progress ==='));
      expect(export.split('=== Reading progress ===').length, 2);
      expect(export, contains('Repository schema version: 1'));
      expect(export, contains('Total stored record count: 2'));
      expect(export, contains('EPUB record count: 1'));
      expect(export, contains('CBZ record count: 1'));
      expect(export, isNot(contains('secret-chapter.xhtml')));
      expect(export, isNot(contains('secret-page.jpg')));
      expect(export, isNot(contains('novel.epub')));
      expect(export, isNot(contains('sourceBasename')));
      expect(exportContainsSensitiveData(export), isFalse);
    });

    test('section order places reading progress before library', () {
      final export = formatDiagnosticsExport(minimalSnapshot());
      final sessionIndex = export.indexOf('=== Music Playback Session ===');
      final readingIndex = export.indexOf('=== Reading progress ===');
      final libraryIndex = export.indexOf('=== Library ===');

      expect(readingIndex, greaterThan(sessionIndex));
      expect(libraryIndex, greaterThan(readingIndex));
    });

    test('unavailable reading section renders single status line', () {
      final export = formatDiagnosticsExport(
        minimalSnapshot(omitReadingProgress: true),
      );
      expect(export, contains('=== Reading progress ==='));
      expect(export.split('=== Reading progress ===').length, 2);
    });
  });

  group('DiagnosticsScreen reading progress', () {
    testWidgets('displays section and aggregate counts', (tester) async {
      final repository = await _repositoryWithRecords([
        phase65PdfRecord(progressFraction: 0.12),
        phase65ComicRecord(
          mediaId: 'comic-cbr',
          archiveFormat: ReadingReaderFormat.cbr,
          progressFraction: 0.2,
        ),
      ]);
      final service = await buildDiagnosticsHarness(
        catalog: phase65ReadingCatalog(),
        readingProgressRepository: repository,
      );

      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(diagnosticsScreenHarness(service));
      await tester.pumpAndSettle();

      expect(find.text('Reading progress'), findsOneWidget);
      expect(find.byKey(const Key('diagnostics_reading_progress_stored')),
          findsOneWidget);
      expect(find.byKey(const Key('diagnostics_reading_progress_continue')),
          findsOneWidget);
      expect(find.byKey(
          const Key('diagnostics_reading_progress_unsupported_comic_format')),
          findsOneWidget);

      final stored = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_reading_progress_stored')),
      );
      expect(stored.data, '2');
    });
  });

  group('Existing diagnostics section regression', () {
    test('music listening export unchanged when reading progress present',
        () async {
      final repository = await initializedReadingProgressRepository();
      final musicRepository = await initializedMusicListeningRepository();
      final service = await buildDiagnosticsHarness(
        withInitializedMusicListening: false,
        musicListeningRepository: musicRepository,
        readingProgressRepository: repository,
      );

      final export = service.formatExport(await service.captureSnapshot());

      expect(export.split('=== Music Listening ===').length, 2);
      expect(export, contains('Stored records: 0'));
      expect(export.split('=== Reading progress ===').length, 2);
    });
  });
}
