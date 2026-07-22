import 'music_playback_session_policy.dart';

/// Persisted music playback session snapshot (M5.5 Step 1).
///
/// [queueTrackIds] and [activeTrackId] are catalogue track identities only —
/// never file paths or catalogue metadata.
class MusicPlaybackSession {
  const MusicPlaybackSession({
    required this.queueTrackIds,
    required this.activeTrackId,
    required this.playbackPosition,
    required this.updatedAt,
  });

  final List<String> queueTrackIds;
  final String? activeTrackId;
  final Duration playbackPosition;
  final DateTime updatedAt;

  bool get isEmpty => queueTrackIds.isEmpty;

  MusicPlaybackSession copyWith({
    List<String>? queueTrackIds,
    String? activeTrackId,
    Duration? playbackPosition,
    DateTime? updatedAt,
    bool clearActiveTrackId = false,
  }) {
    return MusicPlaybackSession(
      queueTrackIds: queueTrackIds ?? this.queueTrackIds,
      activeTrackId:
          clearActiveTrackId ? null : (activeTrackId ?? this.activeTrackId),
      playbackPosition: playbackPosition ?? this.playbackPosition,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a validated copy suitable for persistence.
  MusicPlaybackSession normalized({DateTime? updatedAtOverride}) {
    final queue = _normalizeQueueTrackIds(queueTrackIds);
    final updated = (updatedAtOverride ?? updatedAt).toUtc();

    if (queue.isEmpty) {
      return MusicPlaybackSession(
        queueTrackIds: const [],
        activeTrackId: null,
        playbackPosition: Duration.zero,
        updatedAt: updated,
      );
    }

    final resolvedActive = _resolveActiveTrackId(queue, activeTrackId);
    final position = resolvedActive == null
        ? Duration.zero
        : (playbackPosition.isNegative ? Duration.zero : playbackPosition);

    return MusicPlaybackSession(
      queueTrackIds: List<String>.unmodifiable(queue),
      activeTrackId: resolvedActive,
      playbackPosition: position,
      updatedAt: updated,
    );
  }

  /// Parses the nested `session` object from a versioned envelope.
  static MusicPlaybackSession? fromSessionJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final queueTrackIds = _parseQueueTrackIds(
      json['queueTrackIds'],
      warnings: warnings,
    );

    String? activeTrackId;
    final activeRaw = json['activeTrackId'];
    if (activeRaw == null) {
      activeTrackId = null;
    } else if (activeRaw is String && activeRaw.trim().isNotEmpty) {
      activeTrackId = activeRaw.trim();
    } else {
      warnings?.add('Ignored invalid activeTrackId in playback session.');
      activeTrackId = null;
    }

    final playbackPosition =
        _durationFromMilliseconds(json['playbackPositionMs']) ?? Duration.zero;

    final updatedAt = _parseUpdatedAt(json['updatedAt'], warnings: warnings);

    try {
      return MusicPlaybackSession(
        queueTrackIds: queueTrackIds,
        activeTrackId: activeTrackId,
        playbackPosition: playbackPosition,
        updatedAt: updatedAt,
      ).normalized(updatedAtOverride: updatedAt);
    } catch (_) {
      warnings?.add('Skipped malformed playback session.');
      return null;
    }
  }

  Map<String, dynamic> toSessionJson() {
    final value = normalized();
    return {
      'queueTrackIds': value.queueTrackIds,
      'activeTrackId': value.activeTrackId,
      'playbackPositionMs': value.playbackPosition.inMilliseconds,
      'updatedAt': value.updatedAt.toUtc().toIso8601String(),
    };
  }

  static List<String> _normalizeQueueTrackIds(List<String> source) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final raw in source) {
      final trackId = raw.trim();
      if (trackId.isEmpty || seen.contains(trackId)) {
        continue;
      }
      seen.add(trackId);
      normalized.add(trackId);
      if (normalized.length >=
          MusicPlaybackSessionPolicy.maxPersistedTrackIds) {
        break;
      }
    }
    return normalized;
  }

  static String? _resolveActiveTrackId(
    List<String> queue,
    String? activeTrackId,
  ) {
    if (queue.isEmpty) return null;
    if (activeTrackId != null && queue.contains(activeTrackId)) {
      return activeTrackId;
    }
    return queue.first;
  }

  static List<String> _parseQueueTrackIds(
    dynamic raw, {
    List<String>? warnings,
  }) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List<dynamic>) {
      warnings?.add('Session queueTrackIds list was invalid.');
      return const [];
    }

    final parsed = <String>[];
    for (final entry in raw) {
      if (entry is! String || entry.trim().isEmpty) {
        warnings?.add('Skipped invalid session trackId.');
        continue;
      }
      parsed.add(entry.trim());
    }
    return parsed;
  }

  static Duration? _durationFromMilliseconds(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      if (raw < 0) return Duration.zero;
      return Duration(milliseconds: raw);
    }
    return null;
  }

  static DateTime _parseUpdatedAt(
    dynamic raw, {
    List<String>? warnings,
  }) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw)?.toUtc();
      if (parsed != null) {
        return parsed;
      }
    }
    warnings?.add('Playback session updatedAt was invalid; using fallback.');
    return DateTime.utc(1970, 1, 1);
  }

  @override
  bool operator ==(Object other) {
    return other is MusicPlaybackSession &&
        _listEquals(other.queueTrackIds, queueTrackIds) &&
        other.activeTrackId == activeTrackId &&
        other.playbackPosition == playbackPosition &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(queueTrackIds),
        activeTrackId,
        playbackPosition,
        updatedAt,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
