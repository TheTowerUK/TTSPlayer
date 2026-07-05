import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaProviderConfig.defaults', () {
    test('matches current local catalogue and media roots', () {
      final config = MediaProviderConfig.defaults();

      expect(
        config.localCataloguePaths,
        MediaProviderConfig.defaultLocalCataloguePaths,
      );
      expect(
        config.mediaAccess.mediaRoots,
        MediaAccessConfig.defaultMediaRoots,
      );
      expect(config.mediaAccess.mode, MediaAccessMode.localPreferred);
      expect(config.httpCatalogueUrl, isNull);
      expect(config.validate(), isEmpty);
    });
  });

  group('MediaProviderConfig validation', () {
    test('rejects empty catalogue provider list', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      expect(config.validate(), isNotEmpty);
    });

    test('rejects invalid HTTP catalogue URL', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http('not-a-url'),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      expect(
        config.validate().any((e) => e.contains('http or https')),
        isTrue,
      );
    });

    test('rejects local path that looks like URL', () {
      const definition = MediaCatalogueProviderDefinition.localFile(
        'https://example.com/catalog.json',
      );

      expect(
        definition.validate(fieldPrefix: 'test').any((e) => e.contains('URL')),
        isTrue,
      );
    });

    test('rejects invalid HTTP media base URL', () {
      final config = MediaProviderConfig(
        catalogueProviders: [
          MediaCatalogueProviderDefinition.localFile(
            MediaProviderConfig.defaultLocalCataloguePaths.first,
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'ftp://bad.example/media/',
        ),
      );

      expect(
        config.validate().any((e) => e.contains('httpMediaBaseUrl')),
        isTrue,
      );
    });

    test('accepts valid HTTP catalogue and media base URLs', () {
      final config = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(
            r'Y:\Media\catalog.json',
          ),
          MediaCatalogueProviderDefinition.http(
            'http://192.168.178.130:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'http://192.168.178.130:8443/media/',
        ),
      );

      expect(config.validate(), isEmpty);
      expect(
        config.httpCatalogueUrl,
        'http://192.168.178.130:8443/catalog.json',
      );
    });
  });

  group('MediaProviderConfig JSON', () {
    test('round-trips through toJson and fromJson', () {
      final original = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(
            r'Y:\Media\catalog.json',
          ),
          MediaCatalogueProviderDefinition.http(
            'http://nas.local:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'http://nas.local:8443/media/',
          mode: MediaAccessMode.httpRequired,
        ),
      );

      final restored = MediaProviderConfig.fromJson(original.toJson());

      expect(restored.toJson(), original.toJson());
      expect(restored.validate(), isEmpty);
    });
  });

  group('MediaProviderConfigService', () {
    test('starts with defaults when preferences empty', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();

      final loaded = await service.load();

      expect(loaded.localCataloguePaths,
          MediaProviderConfig.defaultLocalCataloguePaths);
      expect(service.mediaAccess.mediaRoots, MediaAccessConfig.defaultMediaRoots);
    });

    test('save and load round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();

      final custom = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http(
            'http://192.168.178.130:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'http://192.168.178.130:8443/media/',
        ),
      );

      expect(await service.save(custom), isTrue);

      final reloaded = MediaProviderConfigService();
      await reloaded.load();

      expect(reloaded.config.toJson(), custom.toJson());
    });

    test('save rejects invalid config without persisting', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();

      final invalid = MediaProviderConfig(
        catalogueProviders: const [],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      expect(await service.save(invalid), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);
    });

    test('load falls back to defaults when stored JSON is invalid', () async {
      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: '{not json',
      });

      final service = MediaProviderConfigService();
      final loaded = await service.load();

      expect(loaded.localCataloguePaths,
          MediaProviderConfig.defaultLocalCataloguePaths);
    });

    test('load falls back to defaults when stored config fails validation',
        () async {
      final bad = MediaProviderConfig(
        catalogueProviders: const [],
        mediaAccess: MediaAccessConfig.defaults(),
      );
      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: jsonEncode(bad.toJson()),
      });

      final service = MediaProviderConfigService();
      final loaded = await service.load();

      expect(loaded.validate(), isEmpty);
      expect(loaded.localCataloguePaths,
          MediaProviderConfig.defaultLocalCataloguePaths);
    });
  });
}
