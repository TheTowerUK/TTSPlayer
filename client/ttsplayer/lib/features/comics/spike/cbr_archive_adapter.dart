import 'cbr_gate0_models.dart';

/// Implementation-neutral CBR archive port for Gate 0 and later candidates.
///
/// Not tied to `package:unrar` or any specific native stack. Not connected to
/// browse, search, detail, or reader UI.
abstract class CbrArchiveAdapter {
  /// Lists archive entries without extracting file contents to the library tree.
  Future<CbrArchiveListing> listEntries(String archivePath);

  /// Extracts a single named entry. Must enforce path-traversal rejection.
  Future<CbrExtractedPage> extractEntry(
    String archivePath,
    String entryName,
  );

  /// Best-effort integrity probe (may decompress for TEST).
  Future<void> testArchive(String archivePath);

  /// Releases any adapter-held resources (caches, open handles).
  Future<void> dispose();
}
