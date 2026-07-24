import '../media_item.dart';

/// Whether the active playback session expects a video surface (M5.3 Gate 0).
enum PlaybackSessionMode {
  /// Video output required — `VideoController` / `VideoPlayerController`.
  video,

  /// Audio-only — `media_kit` `Player` without mandatory video surface.
  audio,
}

/// Derives session mode from catalogue media kind (M5.1).
///
/// Books and comics must not open an A/V session (M6.1) — callers should
/// gate with [MediaItem.canStartAvPlayback] before invoking playback.
PlaybackSessionMode playbackSessionModeFor(MediaItem item) {
  if (item.isAudio) {
    return PlaybackSessionMode.audio;
  }
  return PlaybackSessionMode.video;
}
