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
  List<String> validate({required String fieldPrefix}) {
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
        if (!_isHttpUrl(trimmed)) {
          errors.add('$fieldPrefix: HTTP catalogue URL must use http or https.');
        }
    }
    return errors;
  }

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}
