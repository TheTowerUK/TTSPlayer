import 'dart:convert';

import '../../comics/archive/cbz_zip_lazy_reader.dart';
import '../../reading/services/reader_session_telemetry.dart';

/// On-demand EPUB ZIP resource access with bounded in-memory cache (M6.6).
abstract class EpubResourceLoader {
  Future<List<int>?> loadBytes(String archiveRelativePath);
  Future<String?> loadText(String archiveRelativePath);
  void releaseChapterCache({int? keepSpineIndex});
  void dispose();
}

/// Lazy EPUB resource loader backed by [CbzZipLazyReader].
class EpubLazyResourceLoader implements EpubResourceLoader {
  EpubLazyResourceLoader({
    required this.archivePath,
    this.maxCachedBytes = 16 * 1024 * 1024,
    this.maxCachedEntries = 32,
    CbzZipLazyReader? reader,
  }) : _reader = reader ?? CbzZipLazyReader(archivePath);

  final String archivePath;
  final int maxCachedBytes;
  final int maxCachedEntries;
  final CbzZipLazyReader _reader;

  Map<String, ZipCentralEntry>? _entries;
  final _cache = <String, List<int>>{};
  final _order = <String>[];

  Future<Map<String, ZipCentralEntry>> _entryMap() async {
    if (_entries != null) return _entries!;
    final central = await _reader.centralEntries();
    _entries = {for (final e in central) e.name: e};
    return _entries!;
  }

  @override
  Future<List<int>?> loadBytes(String archiveRelativePath) async {
    final normalized = archiveRelativePath.replaceAll('\\', '/');
    final cached = _cache[normalized];
    if (cached != null) return cached;

    final entry = (await _entryMap())[normalized];
    if (entry == null) return null;
    final bytes = await _reader.readEntryBytes(entry);
    _store(normalized, bytes);
    return bytes;
  }

  @override
  Future<String?> loadText(String archiveRelativePath) async {
    final bytes = await loadBytes(archiveRelativePath);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  void _store(String key, List<int> bytes) {
    if (_cache.containsKey(key)) {
      _order.remove(key);
    }
    _cache[key] = bytes;
    _order.add(key);
    while (_cache.length > maxCachedEntries && _order.isNotEmpty) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    while (_estimatedBytes > maxCachedBytes && _order.isNotEmpty) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
  }

  int get _estimatedBytes =>
      _cache.values.fold<int>(0, (sum, b) => sum + b.length);

  int get cachedEntryCount => _cache.length;
  int get estimatedCachedBytes => _estimatedBytes;

  void publishTelemetrySnapshot() {
    ReaderSessionTelemetry.instance.updateEpubResourceCache(
      maxEntries: maxCachedEntries,
      maxBytes: maxCachedBytes,
      entryCount: cachedEntryCount,
      estimatedBytes: estimatedCachedBytes,
    );
  }

  @override
  void releaseChapterCache({int? keepSpineIndex}) {
    // Caller may pass spine index for future chapter-aware eviction; for now
    // bounded LRU across all resources is sufficient for M6.6.
  }

  @override
  void dispose() {
    publishTelemetrySnapshot();
    _cache.clear();
    _order.clear();
    _entries = null;
    ReaderSessionTelemetry.instance.recordCleanupResult('epub_loader_disposed');
  }
}

/// In-memory loader for unit tests.
class EpubMemoryResourceLoader implements EpubResourceLoader {
  EpubMemoryResourceLoader(this.resources);

  final Map<String, List<int>> resources;

  @override
  Future<List<int>?> loadBytes(String archiveRelativePath) async {
    final normalized = archiveRelativePath.replaceAll('\\', '/');
    return resources[normalized];
  }

  @override
  Future<String?> loadText(String archiveRelativePath) async {
    final bytes = await loadBytes(archiveRelativePath);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  void releaseChapterCache({int? keepSpineIndex}) {}

  @override
  void dispose() {}
}
