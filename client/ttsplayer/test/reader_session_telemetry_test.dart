import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/services/reader_session_telemetry.dart';

void main() {
  setUp(() => ReaderSessionTelemetry.instance.resetForTest());

  test('records reader open and cache aggregates without paths', () {
    ReaderSessionTelemetry.instance.recordReaderOpen(
      format: ReadingReaderFormat.cbz,
      openDuration: const Duration(milliseconds: 42),
      firstContentDuration: const Duration(milliseconds: 7),
    );
    ReaderSessionTelemetry.instance.updateComicPageCache(
      maxEntries: 5,
      maxBytes: 24 * 1024 * 1024,
      entryCount: 3,
      estimatedBytes: 4096,
    );
    ReaderSessionTelemetry.instance.recordCleanupResult('comic_reader_disposed');

    final snap = ReaderSessionTelemetry.instance.snapshot();
    expect(snap.lastReaderFormat, 'cbz');
    expect(snap.lastReaderOpenDurationMs, 42);
    expect(snap.lastFirstContentDurationMs, 7);
    expect(snap.comicCacheEntryCount, 3);
    expect(snap.lastCleanupResult, 'comic_reader_disposed');
  });
}
