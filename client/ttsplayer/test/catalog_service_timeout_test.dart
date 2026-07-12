import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalogUrl = 'http://192.168.178.130:8443/catalog.json';

  Map<String, dynamic> minimalCatalogJson() => {
        'catalogue': {
          'id': 'TIMEOUT-TEST',
          'scanner_version': '0.3.0',
          'catalogue_version': 2,
        },
        'scan': {
          'started': '2026-07-01T10:00:00+00:00',
          'completed': '2026-07-01T10:00:05+00:00',
          'duration_seconds': 5,
          'sources': 1,
          'folders': 0,
          'items': 0,
          'warnings': 0,
        },
        'generated_at': '2026-07-01T10:00:05+00:00',
        'sources': [],
        'total_items': 0,
        'folders': [],
      };

  group('CatalogService catalogue fetch timeout', () {
    test('defaults to 15 seconds without SettingsRepository', () {
      final service = CatalogService();
      expect(
        service.catalogFetchTimeout.inSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );
    });

    test('reads configured timeout from SettingsRepository.networkSettings',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 5),
      );

      final service = CatalogService(settingsRepository: repository);
      expect(service.catalogFetchTimeout.inSeconds, 5);

      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 120),
      );
      expect(service.catalogFetchTimeout.inSeconds, 120);
    });

    test('startup uses persisted timeout after repository initialize',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 45),
      );
      await repository.initialize();

      final service = CatalogService(settingsRepository: repository);
      expect(service.catalogFetchTimeout.inSeconds, 45);
    });

    test('migration preserves network timeout in runtime consumer', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: jsonEncode({
          'settingsVersion': 1,
          'general': {},
          'libraryProviders': {
            'providerConfig': ApplicationSettings.defaults()
                .libraryProviders
                .providerConfig
                .toJson(),
          },
          'network': {'catalogueFetchTimeoutSeconds': 60},
          'playback': {},
          'diagnostics': {},
        }),
      });

      final repository = SettingsRepository();
      await repository.initialize();

      final service = CatalogService(settingsRepository: repository);
      expect(service.catalogFetchTimeout.inSeconds, 60);
    });

    test('invalid stored network timeout never reaches runtime', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: jsonEncode({
          'settingsVersion': 1,
          'general': {},
          'libraryProviders': {
            'providerConfig': ApplicationSettings.defaults()
                .libraryProviders
                .providerConfig
                .toJson(),
          },
          'network': {'catalogueFetchTimeoutSeconds': 999},
          'playback': {},
          'diagnostics': {},
        }),
      });

      final repository = SettingsRepository();
      await repository.initialize();

      final service = CatalogService(settingsRepository: repository);
      expect(
        service.catalogFetchTimeout.inSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );
    });

    test('timeout change after save applies on next HTTP fetch', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();

      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          await Future<void>.delayed(const Duration(seconds: 6));
        }
        return http.Response(
          jsonEncode(minimalCatalogJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CatalogService(
        httpClient: client,
        settingsRepository: repository,
      );

      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 5),
      );
      await service.loadFromUrl(catalogUrl);
      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!.toLowerCase(), contains('timed out'));

      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 120),
      );
      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, isNull);
      expect(service.catalog?.catalogueIdentity, 'TIMEOUT-TEST');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('HTTP fetch honours 5 second repository timeout', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 5),
      );

      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 6));
        return http.Response(jsonEncode(minimalCatalogJson()), 200);
      });

      final service = CatalogService(
        httpClient: client,
        settingsRepository: repository,
      );

      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!.toLowerCase(), contains('timed out'));
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('HTTP fetch succeeds within 120 second repository timeout', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 120),
      );

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(minimalCatalogJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CatalogService(
        httpClient: client,
        settingsRepository: repository,
      );

      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, isNull);
      expect(service.catalog?.catalogueIdentity, 'TIMEOUT-TEST');
    });
  });
}
