import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:ttsplayer/features/books/reader/book_pdf_viewer_params.dart';

import 'support/book_test_fixtures.dart';
import 'support/phase_66_reader_fixtures.dart';

/// Default-suite PDF resource/disposal regression tests (MP66-PDF-*).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_p66_pdf_');
  });

  tearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('MP66-PDF-1 opens 120-page lightweight PDF', () async {
    final file = generatePhase66PdfLightweight(tmp, pages: 120);
    final doc = await PdfDocument.openFile(file.path);
    expect(doc.pages.length, 120);
    await doc.dispose();
  });

  test('MP66-PDF-2 reopen after dispose starts fresh document', () async {
    final file = writePdf(tmp, 'reopen.pdf', pages: 5);
    for (var i = 0; i < 5; i++) {
      final doc = await PdfDocument.openFile(file.path);
      final image = await doc.pages.first.render(fullWidth: 200);
      image?.dispose();
      await doc.dispose();
    }
  });

  test('MP66-PDF-3 mixed dimensions and image-heavy fixtures open', () async {
    for (final file in [
      generatePhase66PdfMixedDimensions(tmp),
      generatePhase66PdfLargePage(tmp),
      generatePhase66PdfImageHeavy(tmp),
    ]) {
      final doc = await PdfDocument.openFile(file.path);
      expect(doc.pages, isNotEmpty);
      await doc.dispose();
    }
  });

  test('MP66-PDF-4 TTSPlayer PDF viewer policy documents bounded cache', () {
    final params = ttsPlayerPdfViewerParams();
    expect(params.limitRenderingCache, isTrue);
    expect(
      params.maxImageBytesCachedOnMemory,
      TtsPlayerPdfViewerPolicy.maxImageBytesCachedOnMemory,
    );
    expect(TtsPlayerPdfViewerPolicy.maxImageBytesCachedOnMemory, lessThan(100 * 1024 * 1024));
  });
}
