import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_archive_source.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/books/epub/epub_parser.dart';

import 'support/phase_66_performance_baseline.dart';
import 'support/phase_66_reader_fixtures.dart';

/// Default-suite Phase 6.6 informational baselines (MP66-*).
void main() {
  late Directory tmp;
  final baseline = Phase66PerformanceBaseline();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_p66_baseline_');
  });

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  tearDownAll(() {
    baseline.printReport();
  });

  test('MP66-CBZ-1 medium CBZ list + first page (lazy zip)', () async {
    final file = generatePhase66Cbz(tmp, profile: Phase66CbzProfile.medium);
    final source = CbzZipArchiveSource(file.path);

    final listSw = Stopwatch()..start();
    final pages = await source.listPages();
    listSw.stop();

    final loadSw = Stopwatch()..start();
    await source.loadPageBytes(pages.first.entryName);
    loadSw.stop();

    baseline.observe('mp66_cbz_medium_pages', pages.length);
    baseline.observe('mp66_cbz_list_ms', listSw.elapsedMilliseconds);
    baseline.observe('mp66_cbz_first_page_ms', loadSw.elapsedMilliseconds);
    baseline.observe('mp66_process_rss_kb_after_first_page', currentProcessRssKb());

    baseline.add(
      Phase66BaselineResult(
        scenarioId: 'MP66-CBZ-1',
        fixtureLabel: 'CBZ medium (${Phase66CbzProfile.medium.pageCount} pages)',
        operation: 'list_pages',
        medianMs: listSw.elapsedMilliseconds,
      ),
    );
    baseline.add(
      Phase66BaselineResult(
        scenarioId: 'MP66-CBZ-1',
        fixtureLabel: 'CBZ medium',
        operation: 'first_page_bytes',
        medianMs: loadSw.elapsedMilliseconds,
      ),
    );

    expect(pages.length, Phase66CbzProfile.medium.pageCount);
    await source.dispose();
  });

  test('MP66-CBZ-2 sequential navigation median', () async {
    final file = generatePhase66Cbz(tmp, profile: Phase66CbzProfile.small);
    final source = CbzZipArchiveSource(file.path);
    final controller = ComicReaderController(source: source);
    await controller.open();

    final median = await baseline.measureAsyncMedianMs(() async {
      await controller.nextPage();
      await controller.previousPage();
    });

    baseline.add(
      Phase66BaselineResult(
        scenarioId: 'MP66-CBZ-2',
        fixtureLabel: 'CBZ small',
        operation: 'next_previous_page',
        medianMs: median,
      ),
    );

    controller.dispose();
  });

  test('MP66-EPUB-1 lazy parse medium chapter count', () async {
    final file = generatePhase66Epub(tmp, chapterCount: 40);
    final parser = EpubParser();

    final sw = Stopwatch()..start();
    final doc = await parser.parseFile(file.path);
    sw.stop();

    final chapterSw = Stopwatch()..start();
    final html = await doc.loadChapterHtml(0);
    chapterSw.stop();

    baseline.observe('mp66_epub_chapters', doc.spine.length);
    baseline.add(
      Phase66BaselineResult(
        scenarioId: 'MP66-EPUB-1',
        fixtureLabel: 'EPUB 40 chapters',
        operation: 'parse_metadata',
        medianMs: sw.elapsedMilliseconds,
      ),
    );
    baseline.add(
      Phase66BaselineResult(
        scenarioId: 'MP66-EPUB-1',
        fixtureLabel: 'EPUB 40 chapters',
        operation: 'load_first_chapter',
        medianMs: chapterSw.elapsedMilliseconds,
      ),
    );

    expect(doc.spine.length, 40);
    expect(html, contains('Chapter 0'));
    doc.dispose();
  });
}
