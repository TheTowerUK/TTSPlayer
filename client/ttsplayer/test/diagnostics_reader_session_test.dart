import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';

import 'support/diagnostics_test_harness.dart';

void main() {
  test('Reader session diagnostics export is redaction-safe', () {
    const session = ReaderSessionDiagnostics(
      status: DiagnosticSectionStatus.complete,
      lastReaderFormat: 'cbz',
      lastReaderOpenDurationMs: 120,
      lastFirstContentDurationMs: 15,
      lastCleanupResult: 'comic_reader_disposed',
      comicCacheMaxEntries: 5,
      comicCacheMaxBytes: 24 * 1024 * 1024,
      comicCacheEntryCount: 2,
      comicCacheEstimatedBytes: 8192,
      epubCacheMaxEntries: 32,
      epubCacheMaxBytes: 16 * 1024 * 1024,
      epubCacheEntryCount: 1,
      epubCacheEstimatedBytes: 512,
      pdfLimitRenderingCache: true,
      pdfMaxImageBytesCachedOnMemory: 48 * 1024 * 1024,
      cbrProcessInvocations: 3,
      cbrTempDirectoryResidueCount: 0,
    );

    final export = formatDiagnosticsExport(
      minimalSnapshot(readerSession: session),
    );

    expect(export, contains('=== Reader session ==='));
    expect(export, contains('Last reader format: cbz'));
    expect(export, contains('Comic cache max entries: 5'));
    expect(export, contains('PDF max image bytes cached on memory: 50331648'));
    expect(export, isNot(contains('.cbz')));
    expect(export, isNot(contains('.epub')));
  });
}
