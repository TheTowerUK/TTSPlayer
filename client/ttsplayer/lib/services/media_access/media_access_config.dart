import 'remote_url_security.dart';

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

  /// Default resolver configuration for desktop development.
  factory MediaAccessConfig.defaults({
    String? httpMediaBaseUrl,
    MediaAccessMode mode = MediaAccessMode.localPreferred,
  }) {
    return MediaAccessConfig(
      mediaRoots: defaultMediaRoots,
      httpMediaBaseUrl: httpMediaBaseUrl,
      mode: mode,
    );
  }

  /// Alias retained for existing tests and call sites.
  factory MediaAccessConfig.development({
    String? httpMediaBaseUrl,
    MediaAccessMode mode = MediaAccessMode.localPreferred,
  }) {
    return MediaAccessConfig.defaults(
      httpMediaBaseUrl: httpMediaBaseUrl,
      mode: mode,
    );
  }

  factory MediaAccessConfig.fromJson(Map<String, dynamic> json) {
    final rootsRaw = json['mediaRoots'] as List<dynamic>? ?? defaultMediaRoots;
    final mediaRoots = rootsRaw.map((e) => e.toString()).toList();

    final modeName = json['mode'] as String?;
    MediaAccessMode mode = MediaAccessMode.localPreferred;
    if (modeName != null) {
      for (final candidate in MediaAccessMode.values) {
        if (candidate.name == modeName) {
          mode = candidate;
          break;
        }
      }
    }

    final httpBase = json['httpMediaBaseUrl'] as String?;
    return MediaAccessConfig(
      mediaRoots: mediaRoots,
      httpMediaBaseUrl: httpBase?.trim().isEmpty == true ? null : httpBase,
      mode: mode,
    );
  }

  Map<String, dynamic> toJson() => {
        'mediaRoots': mediaRoots,
        if (httpMediaBaseUrl != null) 'httpMediaBaseUrl': httpMediaBaseUrl,
        'mode': mode.name,
      };

  /// Validation errors; empty when valid.
  List<String> validate() {
    final errors = <String>[];
    if (mediaRoots.isEmpty) {
      errors.add('mediaAccess.mediaRoots must not be empty.');
    }
    for (var i = 0; i < mediaRoots.length; i++) {
      if (mediaRoots[i].trim().isEmpty) {
        errors.add('mediaAccess.mediaRoots[$i] must not be empty.');
      }
    }

    final base = httpMediaBaseUrl?.trim();
    if (base != null && base.isNotEmpty) {
      errors.addAll(
        RemoteUrlSecurity.validateRemoteUrl(
          base,
          fieldPrefix: 'mediaAccess.httpMediaBaseUrl',
          mode: mode,
        ).errors,
      );
    }
    return errors;
  }

  /// Non-blocking security warnings for the configured media base URL.
  List<String> securityWarnings() {
    final base = httpMediaBaseUrl?.trim();
    if (base == null || base.isEmpty) return const [];
    return RemoteUrlSecurity.validateRemoteUrl(
      base,
      fieldPrefix: 'mediaAccess.httpMediaBaseUrl',
      mode: mode,
    ).warnings;
  }
}
