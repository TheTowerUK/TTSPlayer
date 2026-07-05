import 'dart:io';

import '../../models/media_folder.dart';
import '../../models/media_item.dart';
import 'artwork_candidate.dart';
import 'artwork_kind.dart';
import 'library_visual_kind.dart';

/// Local/UNC artwork resolution — no network providers, no catalogue mutation.
class ArtworkService {
  ArtworkService({bool Function(String path)? fileExists})
      : _fileExists = fileExists ?? _defaultFileExists;

  final bool Function(String path) _fileExists;
  final Map<String, ArtworkCandidate> _cache = {};

  static bool _defaultFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  void clearCache() => _cache.clear();

  ArtworkCandidate forLibrary(MediaFolder folder) =>
      _cached('library:${folder.id}', () => _forFolder(folder, ArtworkKind.library));

  ArtworkCandidate forFolder(MediaFolder folder) =>
      _cached('folder:${folder.id}', () => _forFolder(folder, ArtworkKind.folder));

  ArtworkCandidate forMediaItem(
    MediaItem item, {
    MediaFolder? parentFolder,
  }) =>
      _cached('media:${item.id}', () => _forMediaItem(item, parentFolder));

  ArtworkCandidate _cached(String key, ArtworkCandidate Function() resolve) {
    return _cache.putIfAbsent(key, resolve);
  }

  ArtworkCandidate _forFolder(MediaFolder folder, ArtworkKind kind) {
    final visualKind = visualKindForFolderName(folder.name);
    final path = _firstExistingInDirectory(folder.path, _folderArtworkNames);
    if (path != null) {
      return ArtworkCandidate(
        kind: kind,
        source: ArtworkSource.folderArt,
        filePath: path,
        visualKind: visualKind,
      );
    }
    return ArtworkCandidate(
      kind: kind,
      source: ArtworkSource.placeholder,
      filePath: null,
      visualKind: visualKind,
    );
  }

  ArtworkCandidate _forMediaItem(MediaItem item, MediaFolder? parentFolder) {
    final visualKind = visualKindForExtension(item.extension);

    if (item.thumbnailPath != null && _fileExists(item.thumbnailPath!)) {
      return ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.catalogThumbnail,
        filePath: item.thumbnailPath,
        visualKind: visualKind,
      );
    }

    final mediaDir = _dirname(item.filePath);
    final stem = _stem(item.filePath);

    final sidecarCandidates = <String>[
      for (final ext in _sidecarImageExtensions) _join(mediaDir, '$stem.$ext'),
      for (final name in _namedSidecars) _join(mediaDir, name),
    ];

    final sidecar = _firstExisting(sidecarCandidates);
    if (sidecar != null) {
      return ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.sidecar,
        filePath: sidecar,
        visualKind: visualKind,
      );
    }

    final folderPath = parentFolder?.path ?? mediaDir;
    final folderArt = _firstExistingInDirectory(folderPath, _folderArtworkNames);
    if (folderArt != null) {
      return ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.folderArt,
        filePath: folderArt,
        visualKind: visualKind,
      );
    }

    return ArtworkCandidate(
      kind: ArtworkKind.mediaItem,
      source: ArtworkSource.placeholder,
      filePath: null,
      visualKind: visualKind,
    );
  }

  /// Cosmetic hint from folder name — not used for business logic.
  LibraryVisualKind visualKindForFolderName(String folderName) {
    final lower = folderName.toLowerCase();
    if (_containsAny(lower, ['video', 'movie', 'film', 'tv'])) {
      return LibraryVisualKind.videos;
    }
    if (_containsAny(lower, ['music', 'audio', 'album'])) {
      return LibraryVisualKind.music;
    }
    if (_containsAny(lower, ['image', 'photo', 'picture'])) {
      return LibraryVisualKind.images;
    }
    if (_containsAny(lower, ['document', 'doc'])) {
      return LibraryVisualKind.documents;
    }
    if (_containsAny(lower, ['book', 'literature', 'comic'])) {
      return LibraryVisualKind.literature;
    }
    if (_containsAny(lower, ['game'])) {
      return LibraryVisualKind.games;
    }
    if (_containsAny(lower, ['archive', 'backup'])) {
      return LibraryVisualKind.archives;
    }
    return LibraryVisualKind.unknown;
  }

  LibraryVisualKind visualKindForExtension(String extension) {
    switch (extension) {
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'm4v':
      case 'avi':
        return LibraryVisualKind.videos;
      case 'mp3':
      case 'flac':
      case 'wav':
      case 'aac':
      case 'ogg':
        return LibraryVisualKind.music;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return LibraryVisualKind.images;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
        return LibraryVisualKind.documents;
      case 'epub':
      case 'mobi':
        return LibraryVisualKind.literature;
      default:
        return LibraryVisualKind.unknown;
    }
  }

  // Keep aligned with indexer._ARTWORK_BASENAMES and _SIDECAR_IMAGE_EXTENSIONS.
  static const _sidecarBasenames = [
    'poster',
    'folder',
    'cover',
    'thumb',
    'artwork',
  ];
  static const _sidecarImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  static List<String> get _namedSidecars => [
        for (final base in _sidecarBasenames)
          for (final ext in _sidecarImageExtensions) '$base.$ext',
      ];

  static List<String> get _folderArtworkNames => _namedSidecars;

  String? _firstExisting(List<String> paths) {
    for (final path in paths) {
      if (_fileExists(path)) return path;
    }
    return null;
  }

  String? _firstExistingInDirectory(String directory, List<String> names) {
    for (final name in names) {
      final path = _join(directory, name);
      if (_fileExists(path)) return path;
    }
    return null;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }

  static String _dirname(String path) {
    final normalized = path.replaceAll('/', '\\');
    final i = normalized.lastIndexOf('\\');
    if (i <= 0) {
      final i2 = path.lastIndexOf('/');
      if (i2 <= 0) return path;
      return path.substring(0, i2);
    }
    return normalized.substring(0, i);
  }

  static String _stem(String path) {
    final base = path.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    if (dot <= 0) return base;
    return base.substring(0, dot);
  }

  static String _join(String directory, String name) {
    if (directory.isEmpty) return name;
    final sep = directory.contains('\\') ? '\\' : '/';
    if (directory.endsWith(sep) || directory.endsWith('/')) {
      return '$directory$name';
    }
    return '$directory$sep$name';
  }
}
