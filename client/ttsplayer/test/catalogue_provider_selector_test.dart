import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/media_access/catalogue_provider_selector.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';

void main() {
  group('CatalogueProviderSelector', () {
    test('localPreferred preserves provider list order after legacy locals',
        () {
      const legacyPath = r'D:\Custom\catalog.json';
      final config = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(
            r'Y:\Media\catalog.json',
          ),
          MediaCatalogueProviderDefinition.http(
            'http://192.168.0.10:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      final ordered = CatalogueProviderSelector.orderedProviders(
        config: config,
        legacyLocalProviders: const [
          MediaCatalogueProviderDefinition.localFile(legacyPath),
        ],
      );

      expect(ordered.map((p) => p.location).toList(), [
        legacyPath,
        r'Y:\Media\catalog.json',
        'http://192.168.0.10:8443/catalog.json',
      ]);
    });

    test('httpRequired skips local providers and legacy locals', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(
            r'Y:\Media\catalog.json',
          ),
          MediaCatalogueProviderDefinition.http(
            'http://192.168.0.10:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          mode: MediaAccessMode.httpRequired,
        ),
      );

      final ordered = CatalogueProviderSelector.orderedProviders(
        config: config,
        legacyLocalProviders: const [
          MediaCatalogueProviderDefinition.localFile(r'D:\Legacy\catalog.json'),
        ],
      );

      expect(ordered.length, 1);
      expect(ordered.single.kind, MediaCatalogueProviderKind.http);
    });

    test('httpRequired with no HTTP providers returns empty list', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(
            r'Y:\Media\catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          mode: MediaAccessMode.httpRequired,
        ),
      );

      final ordered = CatalogueProviderSelector.orderedProviders(
        config: config,
      );

      expect(ordered, isEmpty);
    });

    test('dedupes case-insensitive local paths', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(
            r'Y:\Media\catalog.json',
          ),
          MediaCatalogueProviderDefinition.localFile(
            r'y:\media\catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      final ordered = CatalogueProviderSelector.orderedProviders(config: config);

      expect(ordered.length, 1);
    });
  });
}
