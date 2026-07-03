import 'package:flutter/foundation.dart';

import '../constants/supported_extensions.dart';
import 'media_folder.dart';
import 'media_item.dart';

// Intercepts a hard cast, logs the failing field, then rethrows.
T _cast<T>(dynamic value, String model, String field) {
  try {
    return value as T;
  } catch (e) {
    debugPrint(
      '[fromJson] $model.$field — expected $T, '
      'got ${value.runtimeType} = $value',
    );
    rethrow;
  }
}

// ---------------------------------------------------------------------------
// CatalogueInfo — identity of the catalogue file itself
// ---------------------------------------------------------------------------

class CatalogueInfo {
  /// Unique identity for this catalogue file.
  /// Format: <ISO-8601-UTC-second>-<6 uppercase hex chars>
  /// Example: "2026-07-01T20:14:53Z-8F2A1B"
  ///
  /// The app can compare this against a cached value to detect whether
  /// the catalog.json on disk has been replaced by a new scan.
  final String id;

  /// Semantic version of the indexer that produced this file, e.g. "0.3.0".
  final String scannerVersion;

  /// Integer schema version of catalog.json.
  /// The app should warn or refuse to parse if this exceeds the version
  /// it was compiled to understand.
  final int catalogueVersion;

  /// Lowercase extensions (without dot) the scanner indexes, e.g. ["mp4", "mkv"].
  final List<String> supportedExtensions;

  const CatalogueInfo({
    required this.id,
    required this.scannerVersion,
    required this.catalogueVersion,
    this.supportedExtensions = SupportedExtensions.all,
  });

  factory CatalogueInfo.fromJson(Map<String, dynamic> json) {
    return CatalogueInfo(
      id: json['id'] as String? ?? 'unknown',
      // Accept both field names: new schema uses scanner_version,
      // old scanner block used version.
      scannerVersion: (json['scanner_version'] ?? json['version']) as String? ?? 'unknown',
      catalogueVersion: json['catalogue_version'] as int? ?? 1,
      supportedExtensions: _parseSupportedExtensions(json['supported_extensions']),
    );
  }

  static List<String> _parseSupportedExtensions(dynamic raw) {
    if (raw is! List<dynamic> || raw.isEmpty) {
      return SupportedExtensions.all;
    }
    return raw.map((e) => e.toString()).toList();
  }

  /// Comma-separated extension list for display.
  String get supportedExtensionsLabel => supportedExtensions.join(', ');
}

// ---------------------------------------------------------------------------
// ScanStats — metrics for the scan run that produced this catalogue
// ---------------------------------------------------------------------------

class ScanStats {
  final String started;
  final String completed;
  final int durationSeconds;
  final int sources;
  final int folders;
  final int items;
  final int warnings;

  const ScanStats({
    required this.started,
    required this.completed,
    required this.durationSeconds,
    required this.sources,
    required this.folders,
    required this.items,
    required this.warnings,
  });

  factory ScanStats.fromJson(Map<String, dynamic> json) {
    return ScanStats(
      started: json['started'] as String? ?? '',
      completed: json['completed'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      sources: json['sources'] as int? ?? 0,
      folders: json['folders'] as int? ?? 0,
      items: json['items'] as int? ?? 0,
      warnings: json['warnings'] as int? ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// MediaSource — one entry per configured media root
// ---------------------------------------------------------------------------

class MediaSource {
  final String name;
  final String rootPath;
  final String type;
  final bool accessible;

  const MediaSource({
    required this.name,
    required this.rootPath,
    required this.type,
    required this.accessible,
  });

  factory MediaSource.fromJson(Map<String, dynamic> json) {
    return MediaSource(
      name: _cast<String>(json['name'], 'MediaSource', 'name'),
      rootPath: _cast<String>(json['root_path'], 'MediaSource', 'root_path'),
      type: json['type'] as String? ?? 'local',
      accessible: json['accessible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'root_path': rootPath,
        'type': type,
        'accessible': accessible,
      };
}

// ---------------------------------------------------------------------------
// ScanWarning — one entry per skipped path
// ---------------------------------------------------------------------------

/// Severity of a scan warning.
///
/// [info]    — informational; the path changed during the scan (e.g. deleted).
/// [warning] — needs attention; access was denied or an unexpected error occurred.
enum ScanWarningSeverity { info, warning }

/// Human-readable reason codes matching the Python _classify_exc() output.
enum ScanWarningReason { removed, permission, access, error }

class ScanWarning {
  final String path;

  /// Raw Python exception class name (e.g. "FileNotFoundError").
  final String error;

  /// Raw exception message — shown only in technical details expansion.
  final String detail;

  final ScanWarningSeverity severity;
  final ScanWarningReason reason;

  const ScanWarning({
    required this.path,
    required this.error,
    required this.detail,
    this.severity = ScanWarningSeverity.warning,
    this.reason = ScanWarningReason.error,
  });

  factory ScanWarning.fromJson(Map<String, dynamic> json) {
    return ScanWarning(
      path: _cast<String>(json['path'], 'ScanWarning', 'path'),
      error: _cast<String>(json['error'], 'ScanWarning', 'error'),
      detail: json['detail'] as String? ?? '',
      severity: _parseSeverity(json['severity'] as String?),
      reason: _parseReason(json['reason'] as String?),
    );
  }

  /// One-line human-readable reason shown in the details dialog.
  String get friendlyReason {
    switch (reason) {
      case ScanWarningReason.removed:
        return 'Folder was removed, renamed, or unavailable during scan.';
      case ScanWarningReason.permission:
        return 'Folder access denied.';
      case ScanWarningReason.access:
        return 'Folder could not be accessed (network or OS error).';
      case ScanWarningReason.error:
        return 'An unexpected error occurred while scanning this folder.';
    }
  }

  bool get isInformational => severity == ScanWarningSeverity.info;

  static ScanWarningSeverity _parseSeverity(String? s) {
    if (s == 'info') return ScanWarningSeverity.info;
    return ScanWarningSeverity.warning;
  }

  static ScanWarningReason _parseReason(String? s) {
    switch (s) {
      case 'removed':    return ScanWarningReason.removed;
      case 'permission': return ScanWarningReason.permission;
      case 'access':     return ScanWarningReason.access;
      default:           return ScanWarningReason.error;
    }
  }
}

// ---------------------------------------------------------------------------
// Catalog — top-level object decoded from catalog.json
// ---------------------------------------------------------------------------

class Catalog {
  /// Identity block — unique ID, scanner version, schema version.
  /// Null when parsing a pre-v2 catalogue that predates this block.
  final CatalogueInfo? catalogueInfo;

  /// Metrics for the scan run. Null for pre-v2 catalogues.
  final ScanStats? scan;

  final String generatedAt;
  final List<MediaSource> sources;
  final int totalItems;
  final List<MediaFolder> folders;
  final List<ScanWarning> scanWarnings;

  const Catalog({
    this.catalogueInfo,
    this.scan,
    required this.generatedAt,
    required this.sources,
    required this.totalItems,
    required this.folders,
    this.scanWarnings = const [],
  });

  factory Catalog.fromJson(Map<String, dynamic> json) {
    // Catalogue identity block. Current schema uses the "catalogue" key.
    // Fall back to the old "scanner" key for files produced before this change.
    final catalogueRaw =
        (json['catalogue'] ?? json['scanner']) as Map<String, dynamic>?;
    final scanRaw = json['scan'] as Map<String, dynamic>?;

    // sources — v1.1+ has array; v1.0 had single root_path string
    final List<MediaSource> sources;
    if (json.containsKey('sources')) {
      sources = (json['sources'] as List<dynamic>)
          .map((e) => MediaSource.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json.containsKey('root_path')) {
      sources = [
        MediaSource(
          name: 'Media',
          rootPath: json['root_path'] as String,
          type: 'local',
          accessible: true,
        ),
      ];
    } else {
      sources = [];
    }

    final scan = scanRaw != null ? ScanStats.fromJson(scanRaw) : null;

    return Catalog(
      catalogueInfo: catalogueRaw != null ? CatalogueInfo.fromJson(catalogueRaw) : null,
      scan: scan,
      generatedAt: json['generated_at'] as String? ?? scan?.completed ?? '',
      sources: sources,
      totalItems: _cast<int>(json['total_items'], 'Catalog', 'total_items'),
      folders: (_cast<List<dynamic>>(json['folders'], 'Catalog', 'folders'))
          .map((e) => MediaFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      scanWarnings: ((json['scan_warnings'] as List<dynamic>?) ?? [])
          .map((e) => ScanWarning.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Top-level library folders — direct children of configured media roots.
  /// Does not include scan history; only the folder tree from catalog.json.
  List<MediaFolder> get libraryFolders {
    if (sources.isEmpty) return List.unmodifiable(folders);

    final normalizedRoots =
        sources.map((s) => _normalizePath(s.rootPath)).toSet();

    return folders
        .where((folder) {
          final folderPath = _normalizePath(folder.path);
          if (normalizedRoots.contains(folderPath)) return true;
          final parent = _parentPath(folder.path);
          return normalizedRoots.contains(_normalizePath(parent));
        })
        .toList(growable: false);
  }

  static String _parentPath(String path) {
    final normalized = path.replaceAll('/', '\\');
    final i = normalized.lastIndexOf('\\');
    if (i <= 0) return normalized;
    return normalized.substring(0, i);
  }

  /// Every indexed media item in the catalogue tree (all folders, all depths).
  /// Used by search, Continue Watching, artwork, and future library types.
  List<MediaItem> get allItems {
    final items = <MediaItem>[];
    void collect(MediaFolder folder) {
      items.addAll(folder.items);
      for (final sub in folder.subfolders) {
        collect(sub);
      }
    }
    for (final folder in folders) {
      collect(folder);
    }
    return List.unmodifiable(items);
  }

  /// Find a media item by catalogue id across the full tree.
  MediaItem? findItemById(String itemId) {
    for (final item in allItems) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  bool get isEmpty => folders.isEmpty;
  bool get hasOfflineSources => sources.any((s) => !s.accessible);
  bool get hasScanWarnings => scanWarnings.isNotEmpty;

  /// Extensions the scanner indexes for this catalogue revision.
  List<String> get supportedExtensions =>
      catalogueInfo?.supportedExtensions ?? SupportedExtensions.all;

  /// Comma-separated extension list for UI.
  String get supportedExtensionsLabel => supportedExtensions.join(', ');

  /// Stable identity for app UI state keyed to this catalogue revision.
  /// Prefer [CatalogueInfo.id]; falls back to [generatedAt] for pre-v2 files.
  String get catalogueIdentity =>
      catalogueInfo?.id ?? 'legacy:$generatedAt';

  /// Find a folder node by filesystem path in the current catalogue tree.
  MediaFolder? findFolderByPath(String targetPath) {
    final normalized = _normalizePath(targetPath);
    for (final folder in folders) {
      final found = _findFolderInTree(folder, normalized);
      if (found != null) return found;
    }
    return null;
  }

  static String _normalizePath(String path) =>
      path.replaceAll('/', '\\').toLowerCase();

  MediaFolder? _findFolderInTree(MediaFolder folder, String normalizedTarget) {
    if (_normalizePath(folder.path) == normalizedTarget) return folder;
    for (final sub in folder.subfolders) {
      final found = _findFolderInTree(sub, normalizedTarget);
      if (found != null) return found;
    }
    return null;
  }
}
