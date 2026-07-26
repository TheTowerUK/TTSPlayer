import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/books/epub/epub_book_controller.dart';
import 'package:ttsplayer/features/books/models/book_location.dart';

import 'support/book_test_fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_epub_ctrl_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('navigates chapters and exposes stable location', () async {
    final file = writeEpub(
      tmp,
      'nav.epub',
      chapters: [
        MapEntry('c1.xhtml', '<html><body><p>One</p></body></html>'),
        MapEntry('c2.xhtml', '<html><body><p>Two</p></body></html>'),
        MapEntry('c3.xhtml', '<html><body><p>Three</p></body></html>'),
      ],
    );
    final controller = EpubBookController(
      documentId: 'doc-1',
      filePath: file.path,
    );
    await controller.open();
    expect(controller.state, EpubReaderLoadState.ready);
    expect(controller.chapterCount, 3);
    expect(controller.location, isA<EpubBookLocation>());
    expect(controller.location!.spineIndex, 0);

    await controller.nextChapter();
    expect(controller.spineIndex, 1);
    expect(controller.location!.spineHref, contains('c2.xhtml'));

    await controller.lastChapter();
    expect(controller.spineIndex, 2);
    expect(controller.canGoNext, isFalse);

    await controller.firstChapter();
    expect(controller.spineIndex, 0);
    expect(controller.canGoPrevious, isFalse);

    controller.increaseTextScale();
    expect(controller.textScale, greaterThan(1.0));
    controller.resetTextScale();
    expect(controller.textScale, 1.0);

    controller.disposeDocument();
    expect(controller.document, isNull);
  });
}
