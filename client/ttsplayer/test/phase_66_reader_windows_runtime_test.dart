@Tags(['phase66-reader'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:ttsplayer/features/books/epub/epub_parser.dart';
import 'package:ttsplayer/features/books/reader/book_pdf_viewer_params.dart';
import 'package:ttsplayer/features/comics/archive/cbr_cli_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_archive_source.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/comics/spike/unrar_cli_cbr_adapter.dart';
import 'package:ttsplayer/features/reading/services/reader_session_telemetry.dart';

import 'support/phase_66_long_session_harness.dart';
import 'support/phase_66_performance_baseline.dart';
import 'support/phase_66_reader_fixtures.dart';

/// Opt-in Phase 6.6 reader hardening Windows runtime harness.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_66_READER_HARDENING='1'
/// flutter test test/phase_66_reader_windows_runtime_test.dart --tags phase66-reader
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_66_READER_HARDENING'] != '1') {
    test('skipped — set PHASE_66_READER_HARDENING=1', () {}, skip: true);
    return;
  }

  if (!Platform.isWindows) {
    test('skipped — Windows only', () {}, skip: true);
    return;
  }

  late Directory tmp;
  final baseline = Phase66PerformanceBaseline();
  final unrarExe = Platform.environment['PHASE_63_UNRAR_EXE'];
  final cbrFixture = File('test/support/cbr_gate0_fixtures/rar5_pages.cbr');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_p66_rt_');
    ReaderSessionTelemetry.instance.resetForTest();
  });

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDownAll(() {
    baseline.printReport();
  });

  test('P66-RT-CBZ large open, navigate, close', () async {
    final file = generatePhase66Cbz(tmp, profile: Phase66CbzProfile.large);
    final source = CbzZipArchiveSource(file.path);
    final controller = ComicReaderController(source: source);

    final rssBefore = currentProcessRssKb() ?? 0;
    final openMs = await baseline.measureAsyncMedianMs(() async {
      await controller.open(initialPageIndex: 0);
    });
    final rssAfterOpen = currentProcessRssKb() ?? 0;

    for (var i = 0; i < 5; i++) {
      await controller.goToIndex(i * 17);
    }

    controller.dispose();
    await Phase66LongSessionHarness.allowCleanupPause();
    final rssAfterClose = currentProcessRssKb() ?? 0;

    baseline.observe('p66_cbz_large_rss_before_kb', rssBefore);
    baseline.observe('p66_cbz_large_rss_after_open_kb', rssAfterOpen);
    baseline.observe('p66_cbz_large_rss_after_close_kb', rssAfterClose);
    baseline.add(
      Phase66BaselineResult(
        scenarioId: 'P66-RT-CBZ-1',
        fixtureLabel: 'CBZ large',
        operation: 'open_first_page',
        medianMs: openMs,
      ),
    );
  });

  test('P66-RT-CBZ long session 20x open/close + 100 navigations', () async {
    final file = generatePhase66Cbz(tmp, profile: Phase66CbzProfile.medium);
    await Phase66LongSessionHarness.assertCbzLazyListingOnly(file);

    final rssBefore = currentProcessRssKb() ?? 0;
    await Phase66LongSessionHarness.runCbzOpenCloseCycle(
      archive: file,
      cycles: 20,
      navigationSteps: 100,
      randomNavigation: true,
    );
    await Phase66LongSessionHarness.runCbzOpenCloseCycle(
      archive: file,
      cycles: 3,
      navigationSteps: 20,
      closeDuringNavigation: true,
    );
    await Phase66LongSessionHarness.allowCleanupPause();
    final rssAfter = currentProcessRssKb() ?? 0;

    baseline.observe('p66_cbz_long_session_rss_before_kb', rssBefore);
    baseline.observe('p66_cbz_long_session_rss_after_kb', rssAfter);
  });

  test('P66-RT-EPUB lazy open and chapter load', () async {
    final file = generatePhase66Epub(tmp, chapterCount: 60);
    final parser = EpubParser();
    final doc = await parser.parseFile(file.path);
    expect(doc.spine.length, 60);
    final html = await doc.loadChapterHtml(5);
    expect(html, contains('Chapter 5'));
    doc.dispose();
  });

  test('P66-RT-EPUB long session 20x open/close', () async {
    final file = generatePhase66Epub(tmp, chapterCount: 40);
    await Phase66LongSessionHarness.runEpubOpenCloseCycle(
      epub: file,
      cycles: 20,
      alternateChapterLengths: true,
    );
  });

  test('P66-RT-PDF open/render/dispose and RSS observation', () async {
    final file = generatePhase66PdfLightweight(tmp, pages: 120);
    final rssBefore = currentProcessRssKb() ?? 0;

    final doc = await PdfDocument.openFile(file.path);
    expect(doc.pages.length, 120);
    final rssAfterOpen = currentProcessRssKb() ?? 0;

    var peakRss = rssAfterOpen;
    for (var i = 0; i < 10; i++) {
      final page = doc.pages[i * 11];
      final image = await page.render(fullWidth: 800, fullHeight: 1000);
      image?.dispose();
      final rss = currentProcessRssKb() ?? 0;
      if (rss > peakRss) peakRss = rss;
    }
    await doc.dispose();
    await Phase66LongSessionHarness.allowCleanupPause();
    final rssAfterClose = currentProcessRssKb() ?? 0;

    baseline.observe('p66_pdf_rss_before_kb', rssBefore);
    baseline.observe('p66_pdf_rss_after_open_kb', rssAfterOpen);
    baseline.observe('p66_pdf_rss_peak_kb', peakRss);
    baseline.observe('p66_pdf_rss_after_close_kb', rssAfterClose);
    expect(TtsPlayerPdfViewerPolicy.maxImageBytesCachedOnMemory, 48 * 1024 * 1024);
  });

  test('P66-RT-PDF 20x reopen clean native state', () async {
    final file = generatePhase66PdfMixedDimensions(tmp);
    await Phase66LongSessionHarness.runPdfOpenCloseCycle(
      pdf: file,
      cycles: 20,
      renderWidth: 512,
    );
  });

  test('P66-RT-PDF mixed/large/image-heavy fixtures open', () async {
    for (final generator in [
      () => generatePhase66PdfLargePage(tmp),
      () => generatePhase66PdfImageHeavy(tmp),
    ]) {
      final file = generator();
      final doc = await PdfDocument.openFile(file.path);
      final image = await doc.pages.first.render(fullWidth: 400);
      image?.dispose();
      await doc.dispose();
    }
  });

  test('P66-RT-Unicode CBZ and EPUB', () async {
    final cbz = generatePhase66UnicodeCbz(tmp);
    final source = CbzZipArchiveSource(cbz.path);
    final pages = await source.listPages();
    expect(pages.length, 9);
    expect(pages.first.entryName, contains('caf'));

    final epub = generatePhase66UnicodeEpub(tmp);
    final doc = await EpubParser().parseFile(epub.path);
    expect(doc.spine.length, 8);
    expect(await doc.loadChapterHtml(0), contains('caf'));
    doc.dispose();
    await source.dispose();
  });

  test('P66-RT-CBR when UnRAR configured', () async {
    if (unrarExe == null || !File(unrarExe).existsSync()) {
      print('P66-RT-CBR skip — PHASE_63_UNRAR_EXE not set');
      return;
    }
    if (!cbrFixture.existsSync()) {
      print('P66-RT-CBR skip — rar5_pages.cbr missing');
      return;
    }

    Platform.environment['PHASE_63_UNRAR_EXE'] = unrarExe;
    final adapter = UnrarCliCbrAdapter();
    final source = CbrCliArchiveSource(
      archivePath: cbrFixture.path,
      adapter: adapter,
    );
    final controller = ComicReaderController(source: source);

    final invocationsBefore = adapter.processInvocations;
    await controller.open();
    expect(controller.pageCount, greaterThan(0));

    for (var i = 0; i < 20; i++) {
      await controller.goToIndex(i % controller.pageCount);
    }
    await controller.goToIndex(0);

    expect(adapter.processInvocations, greaterThan(invocationsBefore));
    expect(adapter.sessionTempResidueCount, 0);

    controller.dispose();
    await source.dispose();
    await adapter.dispose();

    expect(adapter.sessionTempResidueCount, 0);
    ReaderSessionTelemetry.instance.updateCbrSession(
      processInvocations: adapter.processInvocations,
      tempDirectoryCount: adapter.sessionTempResidueCount,
    );
  }, skip: unrarExe == null ? 'UnRAR not configured' : false);

  test('P66-RT-CBR unavailable retains controlled failure', () async {
    if (unrarExe != null && File(unrarExe).existsSync()) {
      return;
    }
    final source = CbrCliArchiveSource(
      archivePath: cbrFixture.path,
    );
    expect(
      () => source.listPages(),
      throwsA(isA<ComicArchiveException>()),
    );
  });

  test('P66-RT-Mixed format session alternation', () async {
    final cbz = generatePhase66Cbz(tmp, profile: Phase66CbzProfile.small);
    final epub = generatePhase66Epub(tmp, chapterCount: 10);
    final pdf = generatePhase66PdfLightweight(tmp, pages: 20);

    final rssStart = currentProcessRssKb() ?? 0;
    for (var round = 0; round < 5; round++) {
      await Phase66LongSessionHarness.runCbzOpenCloseCycle(
        archive: cbz,
        cycles: 2,
        navigationSteps: 10,
      );
      await Phase66LongSessionHarness.runEpubOpenCloseCycle(epub: epub, cycles: 2);
      await Phase66LongSessionHarness.runPdfOpenCloseCycle(pdf: pdf, cycles: 2);
    }
    await Phase66LongSessionHarness.allowCleanupPause();
    final rssEnd = currentProcessRssKb() ?? 0;
    baseline.observe('p66_mixed_session_rss_start_kb', rssStart);
    baseline.observe('p66_mixed_session_rss_end_kb', rssEnd);
  });
}
