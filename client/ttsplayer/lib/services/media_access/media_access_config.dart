/// How [MediaLocationResolver] chooses between local file and HTTP providers.
enum MediaAccessMode {
  /// Windows desktop: map filesystem paths to file URIs when possible.
  localPreferred,

  /// Network / mobile: require HTTP base URL for filesystem paths.
  httpRequired,
}

/// Configuration for [MediaLocationResolver].
class MediaAccessConfig {
  /// Known media library roots (drive, UNC, TNAS path).
  final List<String> mediaRoots;

  /// HTTP media base including `/media/` suffix, e.g. `https://nas:8443/media/`.
  final String? httpMediaBaseUrl;

  final MediaAccessMode mode;

  const MediaAccessConfig({
    required this.mediaRoots,
    this.httpMediaBaseUrl,
    this.mode = MediaAccessMode.localPreferred,
  });

  /// Default roots aligned with [path-mapping.md] and `ttsplayer.config.json`.
  static const defaultMediaRoots = [
    r'Y:\Media',
    r'\\MEDIATNAS-B725\Media',
    '/volume1/Media',
  ];

  factory MediaAccessConfig.development({
    String? httpMediaBaseUrl,
    MediaAccessMode mode = MediaAccessMode.localPreferred,
  }) {
    return MediaAccessConfig(
      mediaRoots: defaultMediaRoots,
      httpMediaBaseUrl: httpMediaBaseUrl,
      mode: mode,
    );
  }
}
