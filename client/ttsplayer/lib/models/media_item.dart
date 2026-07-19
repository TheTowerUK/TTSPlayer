import 'package:flutter/foundation.dart';

import '../utils/media_kind_inference.dart';
import 'media_kind.dart';

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
// ---------------------------------------------------------------------------

enum MediaItemStatus {
  available,
  unavailable,
  missing,
  restricted,
  unsupported,
  skipped;

  static MediaItemStatus fromString(String? value) {
    return MediaItemStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MediaItemStatus.available,
    );
  }

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
  final MediaItemStatus status;
  final DateTime? addedAt;

  /// Raw `media_kind` from catalog.json; null on legacy catalogues.
  final String? mediaKindRaw;

  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNumber;
  final int? discNumber;
  final String? genre;
  final String? artistGroupKey;
  final String? albumGroupKey;

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
    this.mediaKindRaw,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.discNumber,
    this.genre,
    this.artistGroupKey,
    this.albumGroupKey,
  });

  /// Resolved kind — explicit catalogue value or extension inference (v2).
  MediaKind get mediaKind =>
      inferMediaKind(filePath: filePath, rawKind: mediaKindRaw);

  bool get isVideo => mediaKind == MediaKind.video;

  bool get isAudio => mediaKind == MediaKind.audio;

  bool get isImage => mediaKind == MediaKind.image;

  /// Audio items are excluded from video Continue Watching (M5.1).
  bool get isContinueWatchingEligible => isVideo;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final filePath = _cast<String>(json['file_path'], 'MediaItem', 'file_path');
    return MediaItem(
      id: _cast<String>(json['id'], 'MediaItem', 'id'),
      title: _cast<String>(json['title'], 'MediaItem', 'title'),
      year: _parseOptionalInt(json['year']),
      durationSeconds: _parseOptionalInt(json['duration_seconds']),
      filePath: filePath,
      thumbnailPath: json['thumbnail_path'] as String?,
      sizeBytes: _parseOptionalInt(json['size_bytes']),
      status: MediaItemStatus.fromString(json['status'] as String?),
      addedAt: _parseAddedAt(json['added_at']),
      mediaKindRaw: json['media_kind'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      albumArtist: json['album_artist'] as String?,
      trackNumber: _parseOptionalInt(json['track_number']),
      discNumber: _parseOptionalInt(json['disc_number']),
      genre: json['genre'] as String?,
      artistGroupKey: json['artist_group_key'] as String?,
      albumGroupKey: json['album_group_key'] as String?,
    );
  }

  static int? _parseOptionalInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
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
        if (mediaKindRaw != null) 'media_kind': mediaKindRaw,
        if (artist != null) 'artist': artist,
        if (album != null) 'album': album,
        if (albumArtist != null) 'album_artist': albumArtist,
        if (trackNumber != null) 'track_number': trackNumber,
        if (discNumber != null) 'disc_number': discNumber,
        if (genre != null) 'genre': genre,
        if (artistGroupKey != null) 'artist_group_key': artistGroupKey,
        if (albumGroupKey != null) 'album_group_key': albumGroupKey,
      };

  String? get formattedDuration {
    if (durationSeconds == null) return null;
    final h = durationSeconds! ~/ 3600;
    final m = (durationSeconds! % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String get extension => filePath.split('.').last.toLowerCase();
}
