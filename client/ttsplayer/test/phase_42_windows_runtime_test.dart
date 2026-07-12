@Tags(['phase42-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/widgets/provider_status_section.dart';
import 'package:ttsplayer/features/settings/settings_screen.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';

/// Windows runtime validation harness for M4 Phase 4.2 closure scenarios.
///
/// Run manually:
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_42_RUNTIME='1'
/// flutter test test/phase_42_windows_runtime_test.dart --tags phase42-runtime
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PackageInfo.setMockInitialValues(
    appName: 'TTSPlayer',
    packageName: 'ttsplayer',
    version: '0.4.0-dev.1',
    buildNumber: '1',
    buildSignature: '',
  );

  if (Platform.environment['PHASE_42_RUNTIME'] != '1') {
    test('skipped — set PHASE_42_RUNTIME=1 to run Phase 4.2 runtime validation',
        () {}, skip: true);
    return;
  }

  const localCatalog = r'Y:\Media\catalog.json';

  Map<String, dynamic> minimalCatalogJson({String id = 'PHASE42-RUNTIME'}) => {
        'catalogue': {
          'id': id,
          'scanner_version': '0.3.0',
          'catalogue_version': 2,
        },
        'scan': {
          'started': '2026-07-12T10:00:00+00:00',
          'completed': '2026-07-12T10:00:05+00:00',
          'duration_seconds': 5,
          'sources': 1,
          'folders': 0,
          'items': 0,
          'warnings': 0,
        },
        'generated_at': '2026-07-12T10:00:05+00:00',
        'sources': [],
        'total_items': 0,
        'folders': [],
      };

  group('Phase 4.2 Windows runtime validation', () {
    test('S1 fresh install loads defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      final result = await repository.initialize();

      expect(result.source, SettingsLoadSource.defaults);
      expect(
        result.settings.libraryProviders.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
      expect(
        result.settings.network.catalogueFetchTimeoutSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );
    });

    test('S2 legacy migration creates envelope', () async {
      final legacy = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http(
            'https://192.168.178.130:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'https://192.168.178.130:8443/media/',
        ),
      );
      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: jsonEncode(legacy.toJson()),
      });

      final repository = SettingsRepository();
      final result = await repository.initialize();

      expect(result.source, SettingsLoadSource.legacyMigration);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SettingsRepository.storageKey), isNotNull);
      expect(
        result.settings.libraryProviders.providerConfig.toJson(),
        legacy.toJson(),
      );
    });

    testWidgets('S3 provider configuration edits in Settings screen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final providerService = MediaProviderConfigService();
      final repository = SettingsRepository();
      await repository.initialize();
      await providerService.load();

      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: providerService),
            ChangeNotifierProvider.value(value: repository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const SettingsScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('http_catalogue_url')).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text('Library & Providers'), findsOneWidget);
      expect(find.byKey(const Key('http_catalogue_url')), findsOneWidget);
      expect(find.byKey(const Key('save_settings')), findsOneWidget);
      expect(find.byKey(const Key('open_provider_settings')), findsNothing);
    });

    test('S4 timeout persists across restart simulation', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 45),
      );

      final restarted = SettingsRepository();
      await restarted.initialize();
      expect(restarted.networkSettings.catalogueFetchTimeoutSeconds, 45);
    });

    testWidgets('S5 invalid timeout rejected in Settings UI', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final providerService = MediaProviderConfigService();
      final repository = SettingsRepository();
      await repository.initialize();

      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: providerService),
            ChangeNotifierProvider.value(value: repository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const SettingsScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('catalogue_fetch_timeout')).evaluate().isNotEmpty) {
          break;
        }
      }

      await tester.enterText(find.byKey(const Key('catalogue_fetch_timeout')), '999');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save_network_settings')));
      await tester.tap(find.byKey(const Key('save_network_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('network_validation_errors')), findsOneWidget);
      expect(restartedTimeout(repository), NetworkSettings.defaultCatalogueFetchTimeoutSeconds);
    });

    test('S6 reset provider restores provider defaults only', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 60),
      );

      final providerService = MediaProviderConfigService();
      await providerService.save(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.http(
              'https://192.168.178.130:8443/catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      await repository.resetProviderToDefaults();

      expect(
        repository.providerConfig.toJson(),
        MediaProviderConfig.defaults().toJson(),
      );
      expect(repository.networkSettings.catalogueFetchTimeoutSeconds, 60);
    });

    test('S7 reset all restores envelope defaults and preserves resume keys',
        () async {
      SharedPreferences.setMockInitialValues({
        'position_item-demo': 120,
        'duration_item-demo': 600,
      });
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 60),
      );

      final providerService = MediaProviderConfigService();
      await providerService.resetToDefaults();

      await repository.resetAllToDefaults();

      expect(
        repository.settings.toJson(),
        ApplicationSettings.defaults().toJson(),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_item-demo'), 120);
      expect(prefs.getInt('duration_item-demo'), 600);
    });

    test('S8 provider and network settings survive restart', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveProviderConfig(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(localCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 30),
      );

      final restarted = SettingsRepository();
      final result = await restarted.initialize();
      expect(result.source, SettingsLoadSource.envelope);
      expect(restarted.networkSettings.catalogueFetchTimeoutSeconds, 30);
      expect(restarted.providerConfig.localCataloguePaths, [localCatalog]);
    });

    testWidgets('S9 unsaved network changes show dialog on close', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final providerService = MediaProviderConfigService();
      final repository = SettingsRepository();
      await repository.initialize();

      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: providerService),
            ChangeNotifierProvider.value(value: repository),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const SettingsScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('catalogue_fetch_timeout')).evaluate().isNotEmpty) {
          break;
        }
      }

      await tester.enterText(find.byKey(const Key('catalogue_fetch_timeout')), '30');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets('S10 dashboard Provider Status unaffected by settings work',
        (tester) async {
      const definition =
          MediaCatalogueProviderDefinition.localFile(localCatalog);
      final snapshot = CatalogueProviderSnapshot(
        providers: const [
          CatalogueProviderAttemptRecord(
            definition: definition,
            health: CatalogueProviderHealth.success,
          ),
        ],
        activeProvider: definition,
        catalogPath: localCatalog,
        accessMode: MediaAccessMode.localPreferred,
        lastCatalogueLoadAt: DateTime.utc(2026, 7, 12, 12),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<CatalogService>.value(
          value: _StubCatalogService(snapshot: snapshot),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(
              body: SingleChildScrollView(child: ProviderStatusSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROVIDER STATUS'), findsOneWidget);
      expect(find.text('Refresh catalogue'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    test('S11 provider save does not auto-refresh catalogue', () async {
      if (!await File(localCatalog).exists()) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({});
      final providerService = MediaProviderConfigService();
      await providerService.load();

      final service = CatalogService()..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(providerConfig: providerService.config);
      final pathBefore = service.catalogPath;
      final refreshedBefore = service.lastRefreshedAt;

      await providerService.save(
        MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(localCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      expect(service.catalogPath, pathBefore);
      expect(service.lastRefreshedAt, refreshedBefore);
      expect(service.isLoading, isFalse);
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('S12 timeout change applies on next catalogue refresh', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 5),
      );

      var requestCount = 0;
      const catalogUrl = 'http://127.0.0.1:9/catalog.json';
      final client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          await Future<void>.delayed(const Duration(seconds: 6));
        }
        return http.Response(jsonEncode(minimalCatalogJson()), 200);
      });

      final service = CatalogService(
        httpClient: client,
        settingsRepository: repository,
      )..includeLegacyCataloguePaths = false;

      service.setProviderConfig(
        MediaProviderConfig(
          catalogueProviders: [
            MediaCatalogueProviderDefinition.http(catalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      await service.refreshCatalogue();
      expect(service.errorMessage, isNotNull);

      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 120),
      );

      await service.refreshCatalogue();
      expect(service.catalog?.catalogueIdentity, 'PHASE42-RUNTIME');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('S13 corrupt envelope JSON recovers to defaults without crash', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: '{not valid json',
      });

      final repository = SettingsRepository();
      final result = await repository.initialize();

      expect(result.source, SettingsLoadSource.defaults);
      expect(result.recoveryWarnings, isNotEmpty);
      expect(
        repository.networkSettings.catalogueFetchTimeoutSeconds,
        NetworkSettings.defaultCatalogueFetchTimeoutSeconds,
      );

      final saveResult = await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 20),
      );
      expect(saveResult.success, isTrue);
    });
  });
}

int restartedTimeout(SettingsRepository repository) =>
    repository.networkSettings.catalogueFetchTimeoutSeconds;

class _StubCatalogService extends CatalogService {
  _StubCatalogService({required this.snapshot});

  final CatalogueProviderSnapshot snapshot;

  @override
  CatalogueProviderSnapshot get providerSnapshot => snapshot;

  @override
  Catalog? get catalog => Catalog.fromJson({
        'generated_at': '2026-07-12T00:00:00+00:00',
        'total_items': 0,
        'folders': [],
      });

  @override
  String? get catalogPath => snapshot.catalogPath;

  @override
  bool get isLoading => false;

  @override
  Future<void> refreshCatalogue() async {}
}
