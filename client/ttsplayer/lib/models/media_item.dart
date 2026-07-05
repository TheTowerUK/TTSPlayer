import 'package:flutter/foundation.dart';

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
// MediaItemStatus
//
// Represents the accessibility state of a single media file as recorded by
// the scanner. The client uses this to decide how to present the item —
// it must never silently hide an item whose status is non-available.
//
// Values are stored as lowercase strings in catalog.json.
// Unknown future values default to [available] via fromString().
// ---------------------------------------------------------------------------

enum MediaItemStatus {
  /// File was accessible and indexed successfully.
  available,

  /// File exists but could not be accessed (e.g. permissions, SMB error).
  unavailable,

  /// File was in a previous catalogue but is no longer found on the filesystem.
  missing,

  /// File exists but access is explicitly denied by folder restrictions.
  restricted,

  /// File extension is not in the supported set.
  unsupported,

  /// File was deliberately excluded from this scan run.
  skipped;

  static MediaItemStatus fromString(String? value) {
    return MediaItemStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MediaItemStatus.available,
    );
  }

  /// True if the item can be offered to the player.
  bool get isPlayable => this == MediaItemStatus.available;
}

// ---------------------------------------------------------------------------
// MediaItem
// ---------------------------------------------------------------------------

class MediaItem {
  final String id;
  final String title;
  final int? year;
  final int? durationSeconds;
  final String filePath;
  final String? thumbnailPath;
  final int? sizeBytes;

  /// Accessibility state set by the scanner.
  /// Defaults to [MediaItemStatus.available] when absent from catalog.json.
  final MediaItemStatus status;

  /// First time this item appeared in a successful catalogue write (ISO-8601).
  final DateTime? addedAt;

  const MediaItem({
    required this.id,
    required this.title,
    this.year,
    this.durationSeconds,
    required this.filePath,
    this.thumbnailPath,
    this.sizeBytes,
    this.status = MediaItemStatus.available,
    this.addedAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: _cast<String>(json['id'], 'MediaItem', 'id'),
      title: _cast<String>(json['title'], 'MediaItem', 'title'),
      year: json['year'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      filePath: _cast<String>(json['file_path'], 'MediaItem', 'file_path'),
      thumbnailPath: json['thumbnail_path'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      status: MediaItemStatus.fromString(json['status'] as String?),
      addedAt: _parseAddedAt(json['added_at']),
    );
  }

  static DateTime? _parseAddedAt(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'duration_seconds': durationSeconds,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'size_bytes': sizeBytes,
        'status': status.name,
        if (addedAt != null) 'added_at': addedAt!.toUtc().toIso8601String(),
      };

  /// Human-readable duration, e.g. "1h 54m" or "43m".
  String? get formattedDuration {
    if (durationSeconds == null) return null;
    final h = durationSeconds! ~/ 3600;
    final m = (durationSeconds! % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// File extension in lower-case, e.g. "mp4".
  String get extension => filePath.split('.').last.toLowerCase();
}
