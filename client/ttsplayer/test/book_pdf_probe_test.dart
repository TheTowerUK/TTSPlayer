import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/books/archive/book_reader_errors.dart';
import 'package:ttsplayer/features/books/reader/book_pdf_probe.dart';

import 'support/book_test_fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_pdf_probe_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('probe opens valid multi-page PDF', () async {
    final file = writePdf(tmp, 'ok.pdf', pages: 5);
    await probePdfFile(file.path);
  });

  test('maps corrupt PDF to classified error', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}bad.pdf');
    file.writeAsBytesSync([0, 1, 2]);
    expect(
      () => probePdfFile(file.path),
      throwsA(isA<BookReaderException>()),
    );
  });

  test('maps empty PDF to classified error', () async {
    final file = File('${tmp.path}${Platform.pathSeparator}empty.pdf');
    file.writeAsBytesSync([]);
    expect(
      () => probePdfFile(file.path),
      throwsA(isA<BookReaderException>()),
    );
  });
}
