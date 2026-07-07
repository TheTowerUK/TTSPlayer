import 'media_access_config.dart';
import 'remote_url_security.dart';

/// How a catalogue is loaded — local filesystem path or HTTP URL.
enum MediaCatalogueProviderKind {
  localFile,
  http,
}

/// One catalogue source definition (local path or remote URL).
class MediaCatalogueProviderDefinition {
  final MediaCatalogueProviderKind kind;
  final String location;

  const MediaCatalogueProviderDefinition({
    required this.kind,
    required this.location,
  });

  const MediaCatalogueProviderDefinition.localFile(String path)
      : kind = MediaCatalogueProviderKind.localFile,
        location = path;

  const MediaCatalogueProviderDefinition.http(String url)
      : kind = MediaCatalogueProviderKind.http,
        location = url;

  factory MediaCatalogueProviderDefinition.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? '';
    final location = json['location'] as String? ?? '';
    final kind = _kindFromString(kindName);
    return MediaCatalogueProviderDefinition(kind: kind, location: location);
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'location': location,
      };

  static MediaCatalogueProviderKind _kindFromString(String value) {
    for (final kind in MediaCatalogueProviderKind.values) {
      if (kind.name == value) return kind;
    }
    return MediaCatalogueProviderKind.localFile;
  }

  /// Validation errors for this definition; empty when valid.
  List<String> validate({
    required String fieldPrefix,
    MediaAccessMode mode = MediaAccessMode.localPreferred,
  }) {
    final errors = <String>[];
    final trimmed = location.trim();
    if (trimmed.isEmpty) {
      errors.add('$fieldPrefix: location is required.');
      return errors;
    }

    switch (kind) {
      case MediaCatalogueProviderKind.localFile:
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          errors.add('$fieldPrefix: local file path must not be a URL.');
        }
      case MediaCatalogueProviderKind.http:
        errors.addAll(
          RemoteUrlSecurity.validateRemoteUrl(
            trimmed,
            fieldPrefix: fieldPrefix,
            mode: mode,
          ).errors,
        );
    }
    return errors;
  }

  /// Non-blocking security warnings for remote HTTP catalogue URLs.
  List<String> securityWarnings({
    required String fieldPrefix,
    MediaAccessMode mode = MediaAccessMode.localPreferred,
  }) {
    if (kind != MediaCatalogueProviderKind.http) return const [];
    return RemoteUrlSecurity.validateRemoteUrl(
      location,
      fieldPrefix: fieldPrefix,
      mode: mode,
    ).warnings;
  }
}
