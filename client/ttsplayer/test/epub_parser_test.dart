import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/books/archive/book_reader_errors.dart';
import 'package:ttsplayer/features/books/epub/epub_parser.dart';

import 'support/book_test_fixtures.dart';

void main() {
  late Directory tmp;
  late EpubParser parser;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_epub_parser_');
    parser = EpubParser();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('parses minimal EPUB 3 with spine order', () async {
    final file = writeEpub(
      tmp,
      'mini.epub',
      version: '3.0',
      chapters: [
        MapEntry('a.xhtml', '<html><body><p>A</p></body></html>'),
        MapEntry('b.xhtml', '<html><body><p>B</p></body></html>'),
      ],
    );
    final doc = await parser.parseFile(file.path);
    expect(doc.spine, hasLength(2));
    expect(doc.spine.first.href, 'OEBPS/a.xhtml');
    expect(doc.toc, hasLength(2));
    expect(doc.title, 'Fixture Book');
  });

  test('parses EPUB 2 package version', () async {
    final file = writeEpub(
      tmp,
      'v2.epub',
      version: '2.0',
      chapters: [MapEntry('one.xhtml', '<html><body>v2</body></html>')],
    );
    final doc = await parser.parseFile(file.path);
    expect(doc.spine, hasLength(1));
  });

  test('handles unicode fixture content', () async {
    final file = writeEpub(
      tmp,
      'unicode.epub',
      title: 'Unicode — 日本語',
      chapters: [MapEntry('u.xhtml', unicodeChapterHtml())],
    );
    final doc = await parser.parseFile(file.path);
    expect(doc.title, contains('日本語'));
    final html = await doc.loadChapterHtml(0);
    expect(html, contains('世界'));
  });

  test('rejects unsafe archive traversal', () async {
    final file = writeEpub(
      tmp,
      'unsafe.epub',
      chapters: [MapEntry('a.xhtml', '<html><body>x</body></html>')],
      unsafeEntry: true,
    );
    expect(
      () => parser.parseFile(file.path),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.epubUnsafePath,
      )),
    );
  });

  test('rejects script-bearing content', () async {
    final file = writeEpub(
      tmp,
      'script.epub',
      chapters: [MapEntry('a.xhtml', '<html><body>ok</body></html>')],
      includeScript: true,
    );
    expect(
      () => parser.parseFile(file.path),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.epubUnsupportedActiveContent,
      )),
    );
  });

  test('rejects non-epub bytes', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}bad.epub');
    file.writeAsBytesSync([1, 2, 3, 4]);
    expect(
      () => parser.parseFile(file.path),
      throwsA(
        isA<BookReaderException>().having(
          (e) => e.kind,
          'kind',
          isIn([
            BookReaderErrorKind.epubInvalidZip,
            BookReaderErrorKind.epubMissingContainer,
          ]),
        ),
      ),
    );
  });

  test('rejects empty file', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}empty.epub');
    file.writeAsBytesSync([]);
    expect(
      () => parser.parseFile(file.path),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.epubInvalidZip,
      )),
    );
  });

  test('rejects missing spine resource', () async {
    final file = writeEpub(
      tmp,
      'missing.epub',
      chapters: [MapEntry('ghost.xhtml', '<html><body>x</body></html>')],
      missingSpineResource: true,
    );
    expect(
      () => parser.parseFile(file.path),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.epubMissingResource,
      )),
    );
  });
}
