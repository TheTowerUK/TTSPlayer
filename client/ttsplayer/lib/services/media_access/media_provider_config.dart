import 'media_access_config.dart';
import 'media_catalogue_provider.dart';

/// Persisted provider configuration for catalogue loading and media access.
///
/// Phase 4.2 — model and persistence only. Startup and settings wiring come in
/// later sub-phases.
class MediaProviderConfig {
  final List<MediaCatalogueProviderDefinition> catalogueProviders;
  final MediaAccessConfig mediaAccess;

  const MediaProviderConfig({
    required this.catalogueProviders,
    required this.mediaAccess,
  });

  /// Local catalogue paths aligned with [CatalogService.liveCataloguePaths].
  static const defaultLocalCataloguePaths = [
    r'Y:\Media\catalog.json',
    r'\\MEDIATNAS-B725\Media\catalog.json',
  ];

  /// Defaults matching current Windows desktop + TNAS reference behaviour.
  factory MediaProviderConfig.defaults() {
    return MediaProviderConfig(
      catalogueProviders: [
        for (final path in defaultLocalCataloguePaths)
          MediaCatalogueProviderDefinition.localFile(path),
      ],
      mediaAccess: MediaAccessConfig.defaults(),
    );
  }

  factory MediaProviderConfig.fromJson(Map<String, dynamic> json) {
    final catalogueRaw = json['catalogueProviders'] as List<dynamic>? ?? [];
    final catalogueProviders = catalogueRaw
        .whereType<Map<String, dynamic>>()
        .map(MediaCatalogueProviderDefinition.fromJson)
        .toList();

    final mediaAccessJson =
        json['mediaAccess'] as Map<String, dynamic>? ?? const {};
    return MediaProviderConfig(
      catalogueProviders: catalogueProviders,
      mediaAccess: MediaAccessConfig.fromJson(mediaAccessJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'catalogueProviders':
            catalogueProviders.map((p) => p.toJson()).toList(),
        'mediaAccess': mediaAccess.toJson(),
      };

  /// Ordered local catalogue file paths (excludes HTTP definitions).
  List<String> get localCataloguePaths => catalogueProviders
      .where((p) => p.kind == MediaCatalogueProviderKind.localFile)
      .map((p) => p.location)
      .toList();

  /// First configured HTTP catalogue URL, if any.
  String? get httpCatalogueUrl {
    for (final provider in catalogueProviders) {
      if (provider.kind == MediaCatalogueProviderKind.http) {
        return provider.location;
      }
    }
    return null;
  }

  /// Validation errors; empty when the config is usable.
  List<String> validate() {
    final errors = <String>[];
    if (catalogueProviders.isEmpty) {
      errors.add('At least one catalogue provider is required.');
    }
    for (var i = 0; i < catalogueProviders.length; i++) {
      errors.addAll(
        catalogueProviders[i].validate(fieldPrefix: 'catalogueProviders[$i]'),
      );
    }
    errors.addAll(mediaAccess.validate());
    return errors;
  }
}
