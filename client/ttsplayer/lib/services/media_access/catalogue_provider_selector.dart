import 'media_access_config.dart';
import 'media_catalogue_provider.dart';
import 'media_provider_config.dart';

/// Builds ordered catalogue provider attempts for [CatalogService].
abstract final class CatalogueProviderSelector {
  /// Legacy local paths (scanner config, last-good pref) prepended for
  /// [MediaAccessMode.localPreferred] only — preserves pre-4.4 startup order.
  static List<MediaCatalogueProviderDefinition> orderedProviders({
    required MediaProviderConfig config,
    Iterable<MediaCatalogueProviderDefinition> legacyLocalProviders =
        const [],
  }) {
    final attempts = <MediaCatalogueProviderDefinition>[];

    if (config.mediaAccess.mode == MediaAccessMode.localPreferred) {
      attempts.addAll(legacyLocalProviders);
      attempts.addAll(config.catalogueProviders);
    } else {
      attempts.addAll(
        config.catalogueProviders.where(
          (provider) => provider.kind == MediaCatalogueProviderKind.http,
        ),
      );
    }

    return _dedupe(attempts);
  }

  static List<MediaCatalogueProviderDefinition> _dedupe(
    List<MediaCatalogueProviderDefinition> providers,
  ) {
    final seen = <String>{};
    final result = <MediaCatalogueProviderDefinition>[];
    for (final provider in providers) {
      final key = _dedupeKey(provider);
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(provider);
    }
    return result;
  }

  static String _dedupeKey(MediaCatalogueProviderDefinition provider) {
    final location = provider.location.trim();
    if (provider.kind == MediaCatalogueProviderKind.localFile) {
      return 'local:${location.replaceAll('/', '\\').toLowerCase()}';
    }
    return 'http:${location.toLowerCase()}';
  }
}
