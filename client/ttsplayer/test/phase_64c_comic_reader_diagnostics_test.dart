import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/comic_page_ref.dart';
import 'package:ttsplayer/features/comics/reader/comic_fit_mode.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_cache.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_failure.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/reading/services/reader_session_telemetry.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';

import 'support/diagnostics_test_harness.dart';

class _DiagFakeSource implements ComicArchiveSource {
  _DiagFakeSource(this.pages, {this.failOn});

  final List<ComicPageRef> pages;
  String? failOn;
  int loadCount = 0;

  @override
  Future<List<ComicPageRef>> listPages() async => pages;

  @override
  Future<List<int>> loadPageBytes(String entryName) async {
    loadCount++;
    if (failOn != null && entryName == failOn) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.pageExtractFailed,
        userMessage: 'This page could not be displayed.',
      );
    }
    return [entryName.hashCode & 0xff];
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() => ReaderSessionTelemetry.instance.resetForTest());

  group('Phase 6.4C comic reader telemetry', () {
    test('inactive when no reader session registered', () {
      expect(ReaderSessionTelemetry.instance.comicReaderSnapshot(), isNull);
    });

    test('active session exposes redacted identity and page numbers', () {
      final sessionId = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: '2026-07-01T20:14:53Z-8F2A1B',
        pageIndex: 13,
        pageCount: 132,
        fitMode: ComicFitMode.fitWidth.label,
        chromeVisible: true,
        zoomedBeyondBase: false,
        failedPagesTracked: 0,
        progressSessionActive: true,
        sessionCompleted: false,
      );
      ReaderSessionTelemetry.instance.updateComicPageCache(
        maxEntries: 5,
        maxBytes: 24 * 1024 * 1024,
        entryCount: 2,
        estimatedBytes: 8192,
      );

      final snap = ReaderSessionTelemetry.instance.comicReaderSnapshot()!;
      expect(snap.pageIndex, 13);
      expect(snap.pageCount, 132);
      expect(snap.fitMode, 'Fit width');
      expect(snap.cacheEntryCount, 2);
      expect(snap.cacheEstimatedBytes, 8192);
    });

    test('clearing session removes active snapshot', () {
      final sessionId = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: 'abc',
        pageIndex: 0,
        pageCount: 1,
      );
      ReaderSessionTelemetry.instance.clearComicReaderSession(sessionId);
      expect(ReaderSessionTelemetry.instance.comicReaderSnapshot(), isNull);
    });

    test('stale session clear does not remove newer reader diagnostics', () {
      final sessionA = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionA,
        active: true,
        itemIdentity: 'reader-a',
        pageIndex: 0,
        pageCount: 5,
      );
      final sessionB = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionB,
        active: true,
        itemIdentity: 'reader-b',
        pageIndex: 2,
        pageCount: 10,
      );

      ReaderSessionTelemetry.instance.clearComicReaderSession(sessionA);

      final snap = ReaderSessionTelemetry.instance.comicReaderSnapshot()!;
      expect(snap.itemIdentity, 'reader-b');
      expect(snap.pageIndex, 2);
      expect(snap.pageCount, 10);
    });

    test('stale session update is ignored after newer reader begins', () {
      final sessionA = ReaderSessionTelemetry.instance.beginComicReaderSession();
      final sessionB = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionB,
        active: true,
        itemIdentity: 'reader-b',
        pageIndex: 1,
        pageCount: 3,
      );
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionA,
        active: true,
        itemIdentity: 'stale-a',
        pageIndex: 99,
        pageCount: 99,
      );

      expect(ReaderSessionTelemetry.instance.comicReaderSnapshot()!.pageIndex, 1);
    });

    test('double clear is idempotent', () {
      final sessionId = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: 'once',
        pageIndex: 0,
        pageCount: 1,
      );
      ReaderSessionTelemetry.instance.clearComicReaderSession(sessionId);
      expect(() => ReaderSessionTelemetry.instance.clearComicReaderSession(sessionId),
          returnsNormally);
      expect(ReaderSessionTelemetry.instance.comicReaderSnapshot(), isNull);
    });
  });

  group('Phase 6.4C comic reader diagnostics export', () {
    test('inactive reader exports Active false only', () {
      final export = formatDiagnosticsExport(
        minimalSnapshot(
          comicReader: const ComicReaderDiagnostics(
            status: DiagnosticSectionStatus.complete,
            active: false,
          ),
        ),
      );
      expect(export, contains('=== Comic reader ==='));
      expect(export, contains('Active: false'));
      expect(export, isNot(contains('Fit mode')));
      expect(exportContainsSensitiveData(export), isFalse);
    });

    test('active reader exports safe fields without paths', () {
      const comic = ComicReaderDiagnostics(
        status: DiagnosticSectionStatus.complete,
        active: true,
        archiveType: 'cbz',
        itemIdentity: '2026-07-01T2…',
        pageNumber: 14,
        pageCount: 132,
        fitMode: 'Fit width',
        chromeVisible: true,
        viewState: 'Base',
        cacheEntryCount: 5,
        cacheEstimatedBytes: 19333120,
        cacheMaxEntries: 5,
        cacheMaxBytes: 24 * 1024 * 1024,
        failedPagesTracked: 1,
        currentPageFailureCategory: 'Decode failure',
        retryAvailable: true,
        lastSafeErrorCategory: 'Decode failure',
        progressSessionActive: true,
        sessionCompleted: false,
      );
      final export = formatDiagnosticsExport(minimalSnapshot(comicReader: comic));
      expect(export, contains('Archive type: cbz'));
      expect(export, contains('Page: 14 / 132'));
      expect(export, contains('Fit mode: Fit width'));
      expect(export, contains('View state: Base'));
      expect(export, contains('Failed pages tracked: 1'));
      expect(export, contains('Current page failure: Decode failure'));
      expect(export, contains('Retry available: true'));
      expect(export, isNot(contains(r'Y:\Media')));
      expect(export, isNot(contains('Exception')));
      expect(exportContainsSensitiveData(export), isFalse);
    });
  });

  group('Phase 6.4C comic reader diagnostics service', () {
    test('capture reflects telemetry without loading pages', () async {
      final sessionId = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: 'comic-id-1234567890',
        pageIndex: 0,
        pageCount: 3,
        fitMode: 'Contain',
        chromeVisible: false,
        zoomedBeyondBase: true,
        failedPagesTracked: 1,
        currentPageFailureCategory: 'Corrupt image data',
        retryAvailable: true,
        progressSessionActive: true,
        sessionCompleted: false,
      );

      final harness = await buildDiagnosticsHarness();
      final snapshot = await harness.captureSnapshot();
      final comic = snapshot.comicReader!;
      expect(comic.active, isTrue);
      expect(comic.pageNumber, 1);
      expect(comic.pageCount, 3);
      expect(comic.viewState, 'Zoomed');
      expect(comic.itemIdentity, redactIdentity('comic-id-1234567890'));
      expect(comic.itemIdentity!.length, lessThanOrEqualTo(13));
    });
  });

  group('Phase 6.4C comic reader controller diagnostics side effects', () {
    test('capture does not trigger additional page loads', () async {
      final source = _DiagFakeSource(
        [
          const ComicPageRef(entryName: 'bad.png', index: 0),
          const ComicPageRef(entryName: 'good.png', index: 1),
        ],
        failOn: 'bad.png',
      );
      final controller = ComicReaderController(
        source: source,
        prefetchAdjacent: false,
      );
      await controller.open();
      expect(source.loadCount, 1);

      final sessionId = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: 'test-comic',
        pageIndex: controller.pageIndex,
        pageCount: controller.pageCount,
        failedPagesTracked: controller.pageFailures.length,
        currentPageFailureCategory:
            controller.currentPageFailure?.category.diagnosticLabel,
        retryAvailable: controller.currentPageFailure?.canRetry,
      );

      final harness = await buildDiagnosticsHarness();
      final before = source.loadCount;
      await harness.captureSnapshot();
      expect(source.loadCount, before);

      ReaderSessionTelemetry.instance.clearComicReaderSession(sessionId);
      controller.dispose();
      expect(ReaderSessionTelemetry.instance.comicReaderSnapshot(), isNull);
    });

    test('retry updates failure diagnostics state', () async {
      final source = _DiagFakeSource(
        [const ComicPageRef(entryName: 'flip.png', index: 0)],
        failOn: 'flip.png',
      );
      final controller = ComicReaderController(source: source);
      await controller.open();
      expect(controller.currentPageFailure, isNotNull);

      final sessionId = ReaderSessionTelemetry.instance.beginComicReaderSession();
      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: 'retry-test',
        pageIndex: 0,
        pageCount: 1,
        failedPagesTracked: 1,
        currentPageFailureCategory: 'Corrupt image data',
        retryAvailable: true,
      );

      source.failOn = null;
      await controller.retryCurrentPage();
      expect(controller.currentPageFailure, isNull);

      ReaderSessionTelemetry.instance.updateComicReaderSession(
        sessionId: sessionId,
        active: true,
        itemIdentity: 'retry-test',
        pageIndex: 0,
        pageCount: 1,
        failedPagesTracked: 0,
        currentPageFailureCategory: null,
        retryAvailable: null,
      );

      final snap = ReaderSessionTelemetry.instance.comicReaderSnapshot()!;
      expect(snap.failedPagesTracked, 0);
      expect(snap.currentPageFailureCategory, isNull);
      controller.dispose();
    });

    test('failed pages are not counted in cache telemetry', () async {
      final cache = ComicPageCache(maxEntries: 5);
      final source = _DiagFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: 'bad.png',
      );
      final controller = ComicReaderController(source: source, cache: cache);
      await controller.open();
      expect(cache.length, 0);
      expect(ReaderSessionTelemetry.instance.snapshot().comicCacheEntryCount, 0);
      controller.dispose();
    });
  });
}
