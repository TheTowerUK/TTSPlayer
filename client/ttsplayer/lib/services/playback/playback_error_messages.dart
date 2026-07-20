import '../../models/playback/playback_error_kind.dart';

/// User-facing playback-layer copy (ADR-013).
class PlaybackErrorMessages {
  PlaybackErrorMessages._();

  static const playbackFailedNote =
      'Some formats, codecs, or large NAS files may not be supported '
      'by the current playback engine.';

  static String forKind(PlaybackErrorKind kind) {
    return switch (kind) {
      PlaybackErrorKind.fileMissing =>
        'This item is no longer available. It may have been moved or deleted since the last scan.',
      PlaybackErrorKind.resolverFailed =>
        'This item could not be prepared for playback. Check your media access settings.',
      PlaybackErrorKind.network =>
        'A network error occurred while opening this media. Check your connection to the NAS.',
      PlaybackErrorKind.tls =>
        'A secure connection to the media server could not be established.',
      PlaybackErrorKind.httpNotFound =>
        'This media could not be found on the media server.',
      PlaybackErrorKind.timeout =>
        'This media took too long to open. Try again or check the file on your NAS.',
      PlaybackErrorKind.permission =>
        'Access was denied. Check that the NAS share is mounted and accessible.',
      PlaybackErrorKind.unsupportedFormat =>
        'This media could not be played. The format may not be supported.',
      PlaybackErrorKind.unknown =>
        'Playback failed.',
    };
  }
}
