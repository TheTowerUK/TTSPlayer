import '../media_item.dart';

/// Whether the active playback session expects a video surface (M5.3 Gate 0).
enum PlaybackSessionMode {
  /// Video output required — `VideoController` / `VideoPlayerController`.
  video,

  /// Audio-only — `media_kit` `Player` without mandatory video surface.
  audio,
}

/// Derives session mode from catalogue media kind (M5.1).
PlaybackSessionMode playbackSessionModeFor(MediaItem item) {
  return item.isAudio ? PlaybackSessionMode.audio : PlaybackSessionMode.video;
}
