import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'metadata_artwork_mime_types.dart';

/// App-owned filesystem helpers for provider artwork disk cache (M7.4.3).
class MetadataArtworkFilesystem {
  MetadataArtworkFilesystem({
    required Directory cacheRoot,
    this.indexFileName = 'cache_index_v1.json',
  }) : _cacheRoot = cacheRoot;

  static const cacheDirectoryName = 'metadata_artwork_cache';

  final Directory _cacheRoot;
  final String indexFileName;

  Directory get cacheRoot => _cacheRoot;

  File get indexFile => File(p.join(_cacheRoot.path, indexFileName));

  Future<void> ensureReady() async {
    await _cacheRoot.create(recursive: true);
  }

  File fileForRelativePath(String relativePath) {
    final safeRelative = _sanitizeRelativePath(relativePath);
    final absolute = p.normalize(p.join(_cacheRoot.path, safeRelative));
    if (!_isInsideRoot(_cacheRoot.path, absolute)) {
      throw ArgumentError('relativePath escapes cache root.');
    }
    return File(absolute);
  }

  File tempFileForRelativePath(String relativePath) {
    return File('${fileForRelativePath(relativePath).path}.part');
  }

  String relativePathForCacheKey(String cacheKey, String contentType) {
    final extension = MetadataArtworkMimeTypes.extensionForMime(contentType);
    return '$cacheKey$extension';
  }

  Future<void> writeTempBytes(File tempFile, Uint8List bytes) async {
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(bytes, flush: true);
  }

  Future<File> promoteTempFile(File tempFile, File targetFile) async {
    if (!await tempFile.exists()) {
      throw MetadataArtworkFilesystemException('Temp file missing.');
    }
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    try {
      await tempFile.rename(targetFile.path);
      return targetFile;
    } on FileSystemException {
      await targetFile.writeAsBytes(await tempFile.readAsBytes(), flush: true);
      await tempFile.delete();
      return targetFile;
    }
  }

  Future<void> deleteTempFile(File tempFile) async {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }

  Future<void> deleteRelativeFile(String relativePath) async {
    final file = fileForRelativePath(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
    await deleteTempFile(tempFileForRelativePath(relativePath));
  }

  Future<List<File>> listCachedFiles() async {
    if (!await _cacheRoot.exists()) {
      return const [];
    }
    final files = <File>[];
    await for (final entity in _cacheRoot.list(recursive: true)) {
      if (entity is File &&
          !entity.path.endsWith('.part') &&
          !entity.path.endsWith(indexFileName) &&
          !entity.path.endsWith('$indexFileName.part')) {
        files.add(entity);
      }
    }
    return files;
  }

  String relativePathFromAbsolute(File file) {
    final relative = p.relative(file.path, from: _cacheRoot.path);
    return _sanitizeRelativePath(relative.replaceAll('\\', '/'));
  }

  Future<void> writeIndexAtomically(String jsonContent) async {
    final target = indexFile;
    final temp = File('${target.path}.part');
    await target.parent.create(recursive: true);
    await temp.writeAsString(jsonContent, flush: true);
    try {
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    } on FileSystemException {
      await target.writeAsString(jsonContent, flush: true);
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  static String _sanitizeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('..')) {
      throw ArgumentError('relativePath must stay within cache root.');
    }
    return normalized;
  }

  static bool _isInsideRoot(String root, String candidate) {
    final normalizedRoot = p.normalize(root);
    final normalizedCandidate = p.normalize(candidate);
    if (p.equals(normalizedRoot, normalizedCandidate)) {
      return true;
    }
    final prefix = normalizedRoot.endsWith(Platform.pathSeparator)
        ? normalizedRoot
        : '${normalizedRoot}${Platform.pathSeparator}';
    return normalizedCandidate.startsWith(prefix);
  }
}

class MetadataArtworkFilesystemException implements Exception {
  MetadataArtworkFilesystemException(this.message);

  final String message;

  @override
  String toString() => 'MetadataArtworkFilesystemException: $message';
}
