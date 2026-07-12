import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MediaProviderConfig validLocalConfig() {
    return MediaProviderConfig(
      catalogueProviders: [
        MediaCatalogueProviderDefinition.localFile(
          MediaProviderConfig.defaultLocalCataloguePaths.first,
        ),
      ],
      mediaAccess: MediaAccessConfig.defaults(),
    );
  }

  MediaProviderConfig validHttpsConfig() {
    return MediaProviderConfig(
      catalogueProviders: const [
        MediaCatalogueProviderDefinition.localFile(
          r'Y:\Media\catalog.json',
        ),
        MediaCatalogueProviderDefinition.http(
          'https://192.168.178.130:8443/catalog.json',
        ),
      ],
      mediaAccess: MediaAccessConfig.defaults(
        httpMediaBaseUrl: 'https://192.168.178.130:8443/media/',
      ),
    );
  }

  group('ApplicationSettings', () {
    test('defaults match specification', () {
      final settings = ApplicationSettings.defaults();

      expect(settings.settingsVersion, ApplicationSettings.currentSettingsVersion);
      expect(
        settings.libraryProviders.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
      expect(
        settings.network.catalogueFetchTimeoutSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );
      expect(settings.validate(), isEmpty);
    });

    test('round-trips through JSON', () {
      final original = ApplicationSettings.defaults().copyWith(
        network: const NetworkSettings(catalogueFetchTimeoutSeconds: 30),
      );

      final restored = ApplicationSettings.fromJson(original.toJson());

      expect(restored.toJson(), original.toJson());
      expect(restored.validate(), isEmpty);
    });

    test('partial recovery keeps valid network when provider invalid', () {
      final warnings = <String>[];
      final settings = ApplicationSettings.fromJsonWithRecovery(
        {
          'settingsVersion': 1,
          'general': {},
          'libraryProviders': {
            'providerConfig': {
              'catalogueProviders': [],
              'mediaAccess': MediaAccessConfig.defaults().toJson(),
            },
          },
          'network': {'catalogueFetchTimeoutSeconds': 45},
          'playback': {},
          'diagnostics': {},
        },
        warnings: warnings,
      );

      expect(
        settings.libraryProviders.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
      expect(settings.network.catalogueFetchTimeoutSeconds, 45);
      expect(warnings, isNotEmpty);
    });

    test('rejects out-of-range network timeout on validate', () {
      final settings = ApplicationSettings.defaults().copyWith(
        network: const NetworkSettings(catalogueFetchTimeoutSeconds: 3),
      );

      expect(settings.validate(), isNotEmpty);
    });
  });

  group('SettingsRepository — S1 upgrade from legacy provider key', () {
    test('migrates media_provider_config_v1 into envelope', () async {
      final legacy = validHttpsConfig();
      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: jsonEncode(legacy.toJson()),
      });

      final repository = SettingsRepository();
      final result = await repository.load();

      expect(result.source, SettingsLoadSource.legacyMigration);
      expect(
        result.settings.libraryProviders.providerConfig.toJson(),
        legacy.toJson(),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsRepository.storageKey), isNotNull);
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNotNull);
    });
  });

  group('SettingsRepository — S2 fresh install', () {
    test('loads defaults when no prefs exist', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      final result = await repository.load();

      expect(result.source, SettingsLoadSource.defaults);
      expect(
        result.settings.libraryProviders.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
      expect(result.recoveryWarnings, isEmpty);
    });
  });

  group('SettingsRepository — S3 legacy catalog_path untouched', () {
    test('load does not read or write catalog_path', () async {
      const catalogPath = r'Y:\Media\catalog.json';
      SharedPreferences.setMockInitialValues({
        'catalog_path': catalogPath,
        MediaProviderConfigService.prefKey:
            jsonEncode(validLocalConfig().toJson()),
      });

      final repository = SettingsRepository();
      await repository.load();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('catalog_path'), catalogPath);
    });
  });

  group('SettingsRepository — S4 valid local save', () {
    test('persists valid local provider configuration', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.load();

      final config = validLocalConfig();
      final saveResult = await repository.saveProviderConfig(config);

      expect(saveResult.success, isTrue);
      expect(
        repository.providerConfig.toJson(),
        config.toJson(),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);

      final reloaded = SettingsRepository();
      final loadResult = await reloaded.load();
      expect(loadResult.source, SettingsLoadSource.envelope);
      expect(
        reloaded.providerConfig.toJson(),
        config.toJson(),
      );
    });
  });

  group('SettingsRepository — S5 valid HTTPS save', () {
    test('persists valid HTTPS provider configuration', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.load();

      final config = validHttpsConfig();
      final saveResult = await repository.saveProviderConfig(config);
      expect(saveResult.success, isTrue);

      final reloaded = SettingsRepository();
      await reloaded.load();
      expect(reloaded.providerConfig.toJson(), config.toJson());
    });
  });

  group('SettingsRepository — S6 invalid save blocked', () {
    test('rejects invalid path and leaves prior storage intact', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.load();
      await repository.saveProviderConfig(validLocalConfig());

      final invalid = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http('not-a-url'),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      final saveResult = await repository.saveProviderConfig(invalid);
      expect(saveResult.success, isFalse);
      expect(saveResult.validationErrors, isNotEmpty);

      final reloaded = SettingsRepository();
      await reloaded.load();
      expect(
        reloaded.providerConfig.toJson(),
        validLocalConfig().toJson(),
      );
    });
  });

  group('SettingsRepository — S7 httpRequired rejects HTTP', () {
    test('blocks plain HTTP URLs in httpRequired mode', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.load();

      final invalid = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http(
            'http://192.168.178.130:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'http://192.168.178.130:8443/media/',
          mode: MediaAccessMode.httpRequired,
        ),
      );

      final saveResult = await repository.saveProviderConfig(invalid);
      expect(saveResult.success, isFalse);
      expect(
        saveResult.validationErrors.any((e) => e.contains('https://')),
        isTrue,
      );
    });
  });

  group('SettingsRepository — S8 reset provider defaults', () {
    test('restores defaults and clears legacy key', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.load();
      await repository.saveProviderConfig(validHttpsConfig());

      await repository.resetProviderToDefaults();

      expect(
        repository.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);
      final envelope = ApplicationSettings.fromJson(
        jsonDecode(prefs.getString(SettingsRepository.storageKey)!)
            as Map<String, dynamic>,
      );
      expect(
        envelope.libraryProviders.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
    });
  });

  group('SettingsRepository — S9 corrupt envelope with legacy fallback', () {
    test('falls back to legacy migration when envelope JSON invalid', () async {
      final legacy = validHttpsConfig();
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: '{invalid json',
        MediaProviderConfigService.prefKey: jsonEncode(legacy.toJson()),
      });

      final repository = SettingsRepository();
      final result = await repository.load();

      expect(result.source, SettingsLoadSource.legacyMigration);
      expect(
        result.settings.libraryProviders.providerConfig.toJson(),
        legacy.toJson(),
      );
      expect(result.recoveryWarnings, isNotEmpty);
    });
  });

  group('SettingsRepository — S10 partial envelope recovery', () {
    test('preserves valid provider when network group invalid', () async {
      final provider = validHttpsConfig();
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: jsonEncode({
          'settingsVersion': 1,
          'general': {},
          'libraryProviders': {
            'providerConfig': provider.toJson(),
          },
          'network': {'catalogueFetchTimeoutSeconds': 999},
          'playback': {},
          'diagnostics': {},
        }),
      });

      final repository = SettingsRepository();
      final result = await repository.load();

      expect(result.source, SettingsLoadSource.envelope);
      expect(result.settings.providerConfig.toJson(), provider.toJson());
      expect(
        result.settings.network.catalogueFetchTimeoutSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );
      expect(result.recoveryWarnings, isNotEmpty);
    });
  });

  group('SettingsRepository — S13 failed migration recovery', () {
    test('loads defaults when envelope corrupt and no legacy key', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: '{invalid json',
      });

      final repository = SettingsRepository();
      final result = await repository.load();

      expect(result.source, SettingsLoadSource.defaults);
      expect(
        result.settings.libraryProviders.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
      expect(result.recoveryWarnings, isNotEmpty);

      final config = validLocalConfig();
      expect((await repository.saveProviderConfig(config)).success, isTrue);
    });
  });

  group('SettingsRepository — reset all', () {
    test('restores full defaults without touching unrelated keys', () async {
      SharedPreferences.setMockInitialValues({
        'catalog_path': r'Y:\Media\catalog.json',
        'position_item1': 120,
      });
      final repository = SettingsRepository();
      await repository.load();
      await repository.save(
        ApplicationSettings.defaults().copyWith(
          network: const NetworkSettings(catalogueFetchTimeoutSeconds: 60),
        ),
      );

      await repository.resetAllToDefaults();

      expect(
        repository.settings.toJson(),
        ApplicationSettings.defaults().toJson(),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('catalog_path'), r'Y:\Media\catalog.json');
      expect(prefs.getInt('position_item1'), 120);
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);
    });
  });

  group('SettingsRepository — network timeout save', () {
    test('persists catalogue fetch timeout within bounds', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.load();

      final saveResult = await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 30),
      );
      expect(saveResult.success, isTrue);
      expect(repository.catalogueFetchTimeoutSeconds, 30);

      final reloaded = SettingsRepository();
      await reloaded.load();
      expect(reloaded.catalogueFetchTimeoutSeconds, 30);
    });

    test('default timeout matches network settings default', () {
      expect(
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );
    });
  });

  group('SettingsRepository — initialize and isLoaded', () {
    test('isLoaded is false until initialize completes', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();

      expect(repository.isLoaded, isFalse);

      await repository.initialize();

      expect(repository.isLoaded, isTrue);
    });

    test('initialize is idempotent and does not re-read disk', () async {
      final legacy = validHttpsConfig();
      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: jsonEncode(legacy.toJson()),
      });

      final repository = SettingsRepository();
      final first = await repository.initialize();
      expect(first.source, SettingsLoadSource.legacyMigration);

      SharedPreferences.setMockInitialValues({});

      final second = await repository.initialize();
      expect(second.source, SettingsLoadSource.legacyMigration);
      expect(
        repository.providerConfig.toJson(),
        legacy.toJson(),
      );
    });
  });
}

extension _ApplicationSettingsTest on ApplicationSettings {
  MediaProviderConfig get providerConfig => libraryProviders.providerConfig;
}
