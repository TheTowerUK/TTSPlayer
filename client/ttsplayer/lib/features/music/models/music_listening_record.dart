/// One persisted music listening-history entry (M5.4).
///
/// Immutable value type. [trackId] is the sole identity key. [title], [artist],
/// and [album] are display snapshots only — never used to rematch catalogue items.
class MusicListeningRecord {
  const MusicListeningRecord({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.lastPosition,
    required this.completed,
    required this.lastPlayedAt,
    this.duration,
    this.completedAt,
  });

  final String trackId;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final Duration lastPosition;
  final bool completed;
  final DateTime? completedAt;
  final DateTime lastPlayedAt;

  /// Position to pass when starting playback from this record.
  ///
  /// Completed tracks always replay from zero. Incomplete tracks use
  /// [lastPosition]. On completion the repository stores [lastPosition] as zero
  /// per Phase 5.4 spec; [replayPosition] remains the single query surface.
  Duration get replayPosition => completed ? Duration.zero : lastPosition;

  MusicListeningRecord copyWith({
    String? trackId,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? lastPosition,
    bool? completed,
    DateTime? completedAt,
    DateTime? lastPlayedAt,
    bool clearDuration = false,
    bool clearCompletedAt = false,
  }) {
    return MusicListeningRecord(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: clearDuration ? null : (duration ?? this.duration),
      lastPosition: lastPosition ?? this.lastPosition,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  /// Returns a validated copy suitable for persistence.
  MusicListeningRecord normalized() {
    final normalizedDuration = _normalizeOptionalDuration(duration);
    var position = lastPosition.isNegative ? Duration.zero : lastPosition;
    position = _clampPosition(position, normalizedDuration);

    final isCompleted = completed;
    final playedAt = lastPlayedAt.toUtc();

    if (isCompleted) {
      return MusicListeningRecord(
        trackId: trackId.trim(),
        title: title,
        artist: artist,
        album: album,
        duration: normalizedDuration,
        lastPosition: Duration.zero,
        completed: true,
        completedAt: (completedAt ?? playedAt).toUtc(),
        lastPlayedAt: playedAt,
      );
    }

    return MusicListeningRecord(
      trackId: trackId.trim(),
      title: title,
      artist: artist,
      album: album,
      duration: normalizedDuration,
      lastPosition: position,
      completed: false,
      completedAt: null,
      lastPlayedAt: playedAt,
    );
  }

  static MusicListeningRecord? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final trackId = json['trackId'];
    if (trackId is! String || trackId.trim().isEmpty) {
      warnings?.add('Skipped listening record with missing trackId.');
      return null;
    }

    final lastPlayedRaw = json['lastPlayedAt'];
    if (lastPlayedRaw is! String) {
      warnings?.add('Skipped listening record with invalid lastPlayedAt.');
      return null;
    }
    final lastPlayedAt = DateTime.tryParse(lastPlayedRaw)?.toUtc();
    if (lastPlayedAt == null) {
      warnings?.add('Skipped listening record with invalid lastPlayedAt.');
      return null;
    }

    final title = json['title'];
    final artist = json['artist'];
    final album = json['album'];
    if (title is! String || artist is! String || album is! String) {
      warnings?.add('Skipped listening record with missing display metadata.');
      return null;
    }

    final completed = json['completed'] == true;
    DateTime? completedAt;
    final completedAtRaw = json['completedAt'];
    if (completedAtRaw is String) {
      completedAt = DateTime.tryParse(completedAtRaw)?.toUtc();
    }
    if (completed && completedAt == null) {
      completedAt = lastPlayedAt;
    }

    final duration = _durationFromJson(json['duration']);
    final lastPosition =
        _durationFromJson(json['lastPosition']) ?? Duration.zero;

    try {
      return MusicListeningRecord(
        trackId: trackId.trim(),
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        lastPosition: lastPosition,
        completed: completed,
        completedAt: completed ? completedAt : null,
        lastPlayedAt: lastPlayedAt,
      ).normalized();
    } catch (_) {
      warnings?.add('Skipped malformed listening record.');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    final value = normalized();
    return {
      'trackId': value.trackId,
      'title': value.title,
      'artist': value.artist,
      'album': value.album,
      if (value.duration != null) 'duration': value.duration!.inSeconds,
      'lastPosition': value.lastPosition.inSeconds,
      'completed': value.completed,
      if (value.completedAt != null)
        'completedAt': value.completedAt!.toUtc().toIso8601String(),
      'lastPlayedAt': value.lastPlayedAt.toUtc().toIso8601String(),
    };
  }

  static Duration? _durationFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      if (raw <= 0) return null;
      return Duration(seconds: raw);
    }
    return null;
  }

  static Duration? _normalizeOptionalDuration(Duration? value) {
    if (value == null || value.isNegative || value == Duration.zero) {
      return null;
    }
    return value;
  }

  static Duration _clampPosition(Duration position, Duration? duration) {
    if (duration != null && duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }

  @override
  bool operator ==(Object other) {
    return other is MusicListeningRecord &&
        other.trackId == trackId &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.duration == duration &&
        other.lastPosition == lastPosition &&
        other.completed == completed &&
        other.completedAt == completedAt &&
        other.lastPlayedAt == lastPlayedAt;
  }

  @override
  int get hashCode => Object.hash(
        trackId,
        title,
        artist,
        album,
        duration,
        lastPosition,
        completed,
        completedAt,
        lastPlayedAt,
      );
}
