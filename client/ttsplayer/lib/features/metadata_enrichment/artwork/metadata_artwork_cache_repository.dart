import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'metadata_artwork_cache_entry.dart';
import 'metadata_artwork_filesystem.dart';

/// Lookup result for a cache entry including absolute file path when valid.
class MetadataArtworkCacheLookup {
  const MetadataArtworkCacheLookup({
    required this.entry,
    required this.absoluteFilePath,
  });

  final MetadataArtworkCacheEntry entry;
  final String absoluteFilePath;
}

/// Owns artwork cache metadata, lookup, persistence, and eviction (M7.4.3).
///
/// Never performs HTTP downloads.
class MetadataArtworkCacheRepository {
  MetadataArtworkCacheRepository({
    MetadataArtworkFilesystem? filesystem,
    Directory? cacheRootOverride,
    this.maxTotalBytes = 256 * 1024 * 1024,
    this.evictionTargetRatio = 0.8,
    DateTime Function()? clock,
  })  : _filesystemOverride = filesystem,
        _cacheRootOverride = cacheRootOverride,
        _clock = clock ?? DateTime.now;

  static const indexVersion = 1;

  final MetadataArtworkFilesystem? _filesystemOverride;
  final Directory? _cacheRootOverride;
  final int maxTotalBytes;
  final double evictionTargetRatio;
  final DateTime Function() _clock;

  MetadataArtworkFilesystem? _filesystem;
  final Map<String, MetadataArtworkCacheEntry> _entries = {};

  int get entryCount => _entries.length;

  int get totalBytes =>
      _entries.values.fold<int>(0, (sum, entry) => sum + entry.byteSize);

  Future<MetadataArtworkFilesystem> filesystem() async {
    if (_filesystem != null) {
      return _filesystem!;
    }
    if (_filesystemOverride != null) {
      _filesystem = _filesystemOverride;
      return _filesystem!;
    }
    final root = _cacheRootOverride ?? await _defaultCacheRoot();
    _filesystem = MetadataArtworkFilesystem(cacheRoot: root);
    return _filesystem!;
  }

  Future<void> initialize() async {
    final fs = await filesystem();
    await fs.ensureReady();
    await _loadIndex(fs);
    await _recoverMissingFiles(fs);
    await _sweepOrphans(fs);
    await _enforceQuotaIfNeeded(fs);
  }

  MetadataArtworkCacheEntry? entryForKey(String cacheKey) {
    return _entries[cacheKey];
  }

  Future<MetadataArtworkCacheLookup?> lookup(String cacheKey) async {
    final fs = await filesystem();
    final entry = _entries[cacheKey];
    if (entry == null) {
      return null;
    }
    final file = fs.fileForRelativePath(entry.relativePath);
    if (!await file.exists()) {
      await _removeEntry(fs, cacheKey, deleteFile: false);
      return null;
    }
    final touched = entry.copyWith(lastAccessedAt: _clock());
    _entries[cacheKey] = touched.normalized();
    await _persistIndex(fs);
    return MetadataArtworkCacheLookup(
      entry: touched,
      absoluteFilePath: file.path,
    );
  }

  Future<MetadataArtworkCacheEntry> upsertEntry(
    MetadataArtworkCacheEntry entry,
  ) async {
    final fs = await filesystem();
    final normalized = entry.normalized();
    _entries[normalized.cacheKey] = normalized;
    await _persistIndex(fs);
    await _enforceQuotaIfNeeded(fs);
    return normalized;
  }

  Future<void> remove(String cacheKey) async {
    final fs = await filesystem();
    await _removeEntry(fs, cacheKey, deleteFile: true);
    await _persistIndex(fs);
  }

  Future<void> invalidate(String cacheKey) async {
    final fs = await filesystem();
    await _removeEntry(fs, cacheKey, deleteFile: true);
    await _persistIndex(fs);
  }

  Future<void> cleanup() async {
    final fs = await filesystem();
    await _recoverMissingFiles(fs);
    await _sweepOrphans(fs);
    await _enforceQuotaIfNeeded(fs);
    await _persistIndex(fs);
  }

  Future<void> _removeEntry(
    MetadataArtworkFilesystem fs,
    String cacheKey, {
    required bool deleteFile,
  }) async {
    final existing = _entries.remove(cacheKey);
    if (existing != null && deleteFile) {
      await fs.deleteRelativeFile(existing.relativePath);
    }
  }

  Future<void> _loadIndex(MetadataArtworkFilesystem fs) async {
    _entries.clear();
    final file = fs.indexFile;
    if (!await file.exists()) {
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final version = decoded['indexVersion'];
      if (version is! int || version != indexVersion) {
        return;
      }
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) {
        return;
      }
      final warnings = <String>[];
      for (final raw in rawEntries) {
        if (raw is! Map<String, dynamic>) continue;
        final entry = MetadataArtworkCacheEntry.fromJsonWithRecovery(
          raw,
          warnings: warnings,
        );
        if (entry != null) {
          _entries[entry.cacheKey] = entry;
        }
      }
    } catch (_) {
      _entries.clear();
    }
  }

  Future<void> _persistIndex(MetadataArtworkFilesystem fs) async {
    final sorted = _entries.values.toList()
      ..sort((a, b) => a.cacheKey.compareTo(b.cacheKey));
    final envelope = {
      'indexVersion': indexVersion,
      'entries': sorted.map((entry) => entry.toJson()).toList(growable: false),
    };
    await fs.writeIndexAtomically(jsonEncode(envelope));
  }

  Future<void> _recoverMissingFiles(MetadataArtworkFilesystem fs) async {
    final staleKeys = <String>[];
    for (final entry in _entries.entries) {
      final file = fs.fileForRelativePath(entry.value.relativePath);
      if (!await file.exists()) {
        staleKeys.add(entry.key);
      }
    }
    for (final key in staleKeys) {
      _entries.remove(key);
    }
  }

  Future<void> _sweepOrphans(MetadataArtworkFilesystem fs) async {
    final indexedPaths = {
      for (final entry in _entries.values) entry.relativePath,
    };
    final files = await fs.listCachedFiles();
    for (final file in files) {
      final relative = fs.relativePathFromAbsolute(file);
      if (!indexedPaths.contains(relative)) {
        await file.delete();
      }
    }
  }

  Future<void> _enforceQuotaIfNeeded(MetadataArtworkFilesystem fs) async {
    if (totalBytes <= maxTotalBytes) {
      return;
    }
    final targetBytes = (maxTotalBytes * evictionTargetRatio).floor();
    final ordered = _entries.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
    for (final entry in ordered) {
      if (totalBytes <= targetBytes) {
        break;
      }
      await _removeEntry(fs, entry.cacheKey, deleteFile: true);
    }
    await _persistIndex(fs);
  }

  static Future<Directory> _defaultCacheRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}${MetadataArtworkFilesystem.cacheDirectoryName}',
    );
  }
}
