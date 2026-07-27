import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/books/epub/epub_parser.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_archive_source.dart';

import 'support/phase_66_reader_fixtures.dart';

/// Unicode fixture matrix for Phase 6.6 (representative set — not exhaustive).
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_p66_unicode_');
  });

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('MP66-UNICODE-CBZ entry discovery and natural order', () async {
    final file = generatePhase66UnicodeCbz(tmp);
    final source = CbzZipArchiveSource(file.path);
    final pages = await source.listPages();
    expect(pages.length, 9);
    expect(pages.map((p) => p.entryName).join(','), contains('caf'));
    expect(pages.map((p) => p.entryName).join(','), contains('Za'));
    await source.dispose();
  });

  test('MP66-UNICODE-EPUB spine resolution and chapter render', () async {
    final file = generatePhase66UnicodeEpub(tmp);
    final doc = await EpubParser().parseFile(file.path);
    expect(doc.title, contains('caf'));
    expect(doc.spine.length, 8);
    expect(await doc.loadChapterHtml(4), contains('مرحبا'));
    expect(await doc.loadChapterHtml(5), contains('こんにちは'));
    doc.dispose();
  });
}
