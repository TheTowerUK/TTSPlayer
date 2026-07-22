/// Persistence limits and coordinator timing for music playback session (M5.5).
abstract final class MusicPlaybackSessionPolicy {
  /// Maximum track IDs written to the session envelope.
  ///
  /// When exceeded, trailing IDs are dropped on normalize/save — current index
  /// and leading context are preserved.
  static const maxPersistedTrackIds = 500;

  /// Minimum interval between position-only persistence writes during playback.
  static const positionPersistInterval = Duration(seconds: 5);

  /// Debounce window for closely grouped queue mutations.
  static const queueMutationDebounce = Duration(milliseconds: 250);

  /// Position jump at or above this threshold is treated as a seek (immediate persist).
  static const seekDetectionThreshold = Duration(seconds: 2);
}
