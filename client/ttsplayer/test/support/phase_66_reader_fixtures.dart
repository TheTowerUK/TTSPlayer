import 'dart:io';

import 'book_test_fixtures.dart';
import 'comic_test_fixtures.dart';

/// Phase 6.6 reader hardening fixture profiles (generated locally — not committed).
enum Phase66CbzProfile {
  small(pageCount: 10, pngBytes: 800),
  medium(pageCount: 100, pngBytes: 1200),
  large(pageCount: 200, pngBytes: 2400);

  const Phase66CbzProfile({
    required this.pageCount,
    required this.pngBytes,
  });

  final int pageCount;
  final int pngBytes;
}

/// Generates a synthetic CBZ with natural-order page names and mixed nesting.
File generatePhase66Cbz(
  Directory dir, {
  required Phase66CbzProfile profile,
  String name = 'phase66.cbz',
  Map<String, List<int>>? extraEntries,
}) {
  final entries = <String, List<int>>{};
  for (var i = 0; i < profile.pageCount; i++) {
    final folder = i.isEven ? '' : 'nested/';
    final label = (i + 1).toString().padLeft(3, '0');
    entries['${folder}page_$label.png'] = _syntheticPageBytes(profile.pngBytes, i);
  }
  entries['readme.txt'] = 'phase66 fixture'.codeUnits;
  if (extraEntries != null) {
    entries.addAll(extraEntries);
  }
  return writeCbz(dir, name, entries);
}

/// Unicode entry names for CBZ discovery/ordering validation.
File generatePhase66UnicodeCbz(Directory dir, {String name = 'unicode.cbz'}) {
  final entries = <String, List<int>>{
    '01_café.png': tinyPng(1),
    '02_Zażółć.png': tinyPng(2),
    '03_ελληνικά.png': tinyPng(3),
    '04_кириллица.png': tinyPng(4),
    '05_العربية.png': tinyPng(5),
    '06_日本語.png': tinyPng(6),
    '07_e\u0301_composed.png': tinyPng(7),
    '08_😀_emoji.png': tinyPng(8),
    '09_${'x' * 120}_long_name.png': tinyPng(9),
  };
  return writeCbz(dir, name, entries);
}

List<int> _syntheticPageBytes(int targetBytes, int seed) {
  final base = tinyPng(seed);
  if (base.length >= targetBytes) return base;
  return [...base, ...List.filled(targetBytes - base.length, seed & 0xff)];
}

/// Minimal EPUB with [chapterCount] spine items for hardening tests.
File generatePhase66Epub(
  Directory dir, {
  int chapterCount = 20,
  String name = 'phase66.epub',
  String title = 'Phase 6.6 EPUB',
  List<MapEntry<String, String>>? chapters,
}) {
  final spine = chapters ??
      [
        for (var i = 0; i < chapterCount; i++)
          MapEntry(
            'ch${i.toString().padLeft(2, '0')}.xhtml',
            '<html><body><p>Chapter $i — Phase 6.6</p></body></html>',
          ),
      ];
  return writeEpub(dir, name, chapters: spine, title: title);
}

/// Unicode EPUB content for Phase 6.6 validation.
///
/// Spine hrefs remain ASCII (ZIP central-directory compatibility on Windows test
/// host). Unicode is validated in package title and chapter HTML body.
File generatePhase66UnicodeEpub(Directory dir, {String name = 'unicode.epub'}) {
  return writeEpub(
    dir,
    name,
    title: 'café — Zażółć — 日本語',
    chapters: [
      MapEntry('ch01.xhtml', '<html><body><p>café naïve</p></body></html>'),
      MapEntry('ch02.xhtml', '<html><body><p>Zażółć gęślą jaźń</p></body></html>'),
      MapEntry('ch03.xhtml', '<html><body><p>Γειά σου κόσμε</p></body></html>'),
      MapEntry('ch04.xhtml', '<html><body><p>Привет мир</p></body></html>'),
      MapEntry('ch05.xhtml', '<html dir="rtl"><body><p>مرحبا بالعالم</p></body></html>'),
      MapEntry('ch06.xhtml', '<html><body><p>こんにちは世界</p></body></html>'),
      MapEntry('ch07.xhtml', '<html><body><p>e\u0301 combining</p></body></html>'),
      MapEntry('ch08.xhtml', '<html><body><p>😀 supplementary plane</p></body></html>'),
    ],
  );
}

/// 120+ page lightweight PDF for MP66/P66 PDF scenarios.
File generatePhase66PdfLightweight(
  Directory dir, {
  String name = 'phase66_light.pdf',
  int pages = 120,
}) {
  return writePhase66Pdf(dir, name, pages: pages);
}

File generatePhase66PdfMixedDimensions(Directory dir, {String name = 'mixed.pdf'}) {
  return writePhase66Pdf(
    dir,
    name,
    mixedSizes: [
      (200, 800),
      (800, 200),
      (1200, 1600),
      (4000, 3000),
      (300, 3000),
    ],
  );
}

File generatePhase66PdfLargePage(Directory dir, {String name = 'large_page.pdf'}) {
  return writePhase66Pdf(dir, name, pages: 3, width: 4000, height: 4000);
}

File generatePhase66PdfImageHeavy(Directory dir, {String name = 'image_heavy.pdf'}) {
  return writePhase66Pdf(dir, name, imageHeavyFirstPage: true);
}
