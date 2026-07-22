/// Persistence limits for music playback session state (M5.5).
abstract final class MusicPlaybackSessionPolicy {
  /// Maximum track IDs written to the session envelope.
  ///
  /// When exceeded, trailing IDs are dropped on normalize/save — current index
  /// and leading context are preserved.
  static const maxPersistedTrackIds = 500;
}
