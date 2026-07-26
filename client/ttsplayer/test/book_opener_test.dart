import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/books/archive/book_opener.dart';
import 'package:ttsplayer/features/books/archive/book_reader_errors.dart';
import 'package:ttsplayer/features/books/models/book_format.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';

import 'support/book_test_fixtures.dart';

void main() {
  late Directory tmp;
  late MediaLocationResolver resolver;
  late BookOpener opener;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_book_opener_');
    resolver = MediaLocationResolver(
      config: MediaAccessConfig.defaults(),
      isWindowsDesktop: true,
    );
    opener = BookOpener(mediaLocationResolver: resolver);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  MediaItem bookItem(String path, {String ext = 'pdf'}) => MediaItem(
        id: 'book-$ext',
        title: 'Test Book',
        filePath: path,
        mediaKindRaw: MediaKind.book.name,
        status: MediaItemStatus.available,
      );

  test('opens local PDF with detected format', () {
    final file = writePdf(tmp, 'sample.pdf', pages: 3);
    final target = opener.openItem(bookItem(file.path));
    expect(target.format, BookFormat.pdf);
    expect(target.localPath, file.path);
    expect(target.documentId, 'book-pdf');
  });

  test('opens local EPUB with detected format', () {
    final file = writeEpub(
      tmp,
      'sample.epub',
      chapters: [
        MapEntry('ch1.xhtml', '<html><body><p>One</p></body></html>'),
      ],
    );
    final target = opener.openItem(bookItem(file.path, ext: 'epub'));
    expect(target.format, BookFormat.epub);
  });

  test('rejects comic items', () {
    final file = writePdf(tmp, 'not-comic.pdf');
    final comic = MediaItem(
      id: 'c1',
      title: 'Comic',
      filePath: file.path,
      mediaKindRaw: MediaKind.comic.name,
      status: MediaItemStatus.available,
    );
    expect(
      () => opener.openItem(comic),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.unsupportedFormat,
      )),
    );
  });

  test('rejects missing files', () {
    final missing = bookItem('${tmp.path}${Platform.pathSeparator}gone.pdf');
    expect(
      () => opener.openItem(missing),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.fileMissing,
      )),
    );
  });

  test('rejects unsupported extensions', () {
    final file = File('${tmp.path}${Platform.pathSeparator}notes.txt');
    file.writeAsStringSync('hello');
    expect(
      () => opener.openItem(bookItem(file.path, ext: 'txt')),
      throwsA(isA<BookReaderException>().having(
        (e) => e.kind,
        'kind',
        BookReaderErrorKind.unsupportedFormat,
      )),
    );
  });
}
