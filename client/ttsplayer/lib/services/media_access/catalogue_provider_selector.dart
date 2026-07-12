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

  static String providerKey(MediaCatalogueProviderDefinition provider) =>
      _dedupeKey(provider);

  /// Local catalogue providers excluded from the chain under [httpRequired].
  static List<MediaCatalogueProviderDefinition> configurationExcludedProviders({
    required MediaProviderConfig config,
    required List<MediaCatalogueProviderDefinition> attemptChain,
  }) {
    if (config.mediaAccess.mode != MediaAccessMode.httpRequired) {
      return const [];
    }
    final attemptKeys = attemptChain.map(_dedupeKey).toSet();
    return config.catalogueProviders
        .where((p) => p.kind == MediaCatalogueProviderKind.localFile)
        .where((p) => !attemptKeys.contains(_dedupeKey(p)))
        .toList();
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
