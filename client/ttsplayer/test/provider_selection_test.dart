import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const httpCatalogUrl = 'http://192.168.0.10:8443/catalog.json';
  const httpBase = 'http://192.168.0.10:8443/media/';
  const httpsCatalogUrl = 'https://192.168.0.10:8443/catalog.json';
  const httpsBase = 'https://192.168.0.10:8443/media/';

  Map<String, dynamic> minimalCatalogJson({String id = 'PROVIDER-CAT-1'}) => {
        'catalogue': {
          'id': id,
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

  Map<String, dynamic> catalogJsonWithUniqueTitle({
    required String id,
    required String title,
  }) {
    final json = minimalCatalogJson(id: id);
    json['total_items'] = 1;
    json['scan'] = {
      ...(json['scan'] as Map<String, dynamic>),
      'folders': 1,
      'items': 1,
    };
    json['folders'] = [
      {
        'id': 'lib-test',
        'name': 'Test Library',
        'path': r'D:\TTSPlayer-Test',
        'item_count': 1,
        'items': [
          {
            'id': 'item-unique-epub',
            'title': title,
            'file_path': r'D:\TTSPlayer-Test\unique.epub',
            'status': 'unavailable',
            'media_kind': 'book',
          },
        ],
        'subfolders': [],
      },
    ];
    return json;
  }

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ttsplayer_provider_44_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('startup provider config', () {
    test('load() applies saved config before catalogue startup', () async {
      final custom = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http(httpsCatalogUrl),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: httpsBase,
          mode: MediaAccessMode.httpRequired,
        ),
      );

      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: jsonEncode(custom.toJson()),
      });

      final configService = MediaProviderConfigService();
      await configService.load();

      expect(configService.config.toJson(), custom.toJson());
      expect(configService.mediaAccess.httpMediaBaseUrl, httpsBase);
    });
  });

  group('CatalogService provider selection', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('localPreferred tries local file before HTTP fallback', () async {
      final localFile = File('${tempDir.path}/local-first.json');
      await localFile
          .writeAsString(jsonEncode(minimalCatalogJson(id: 'LOCAL')));

      var httpCalled = false;
      final client = MockClient((request) async {
        httpCalled = true;
        return http.Response(jsonEncode(minimalCatalogJson(id: 'HTTP')), 200);
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            MediaCatalogueProviderDefinition.localFile(localFile.path),
            const MediaCatalogueProviderDefinition.http(httpCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      expect(service.isUsingFallback, isFalse);
      expect(service.catalogPath, localFile.path);
      expect(service.catalog?.catalogueIdentity, 'LOCAL');
      expect(httpCalled, isFalse);

      final snapshot = service.providerSnapshot;
      expect(service.activeCatalogueProvider?.location, localFile.path);
      expect(snapshot.isDegradedLoad, isFalse);
      expect(
        snapshot.providers
            .firstWhere((r) => r.definition.location == localFile.path)
            .health,
        CatalogueProviderHealth.success,
      );
      final httpRecord = snapshot.providers
          .where((r) => r.definition.kind == MediaCatalogueProviderKind.http);
      if (httpRecord.isNotEmpty) {
        expect(httpRecord.first.health, CatalogueProviderHealth.idle);
      }
      expect(service.lastCatalogueLoadAt, isNotNull);
      expect(service.lastLoadStartedAt, isNotNull);
    });

    test('localPreferred falls back to HTTP when local files missing',
        () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), httpCatalogUrl);
        return http.Response(
          jsonEncode(minimalCatalogJson(id: 'HTTP-FALLBACK')),
          200,
        );
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
            MediaCatalogueProviderDefinition.http(httpCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      expect(service.isUsingFallback, isFalse);
      expect(service.catalogPath, httpCatalogUrl);
      expect(service.catalog?.catalogueIdentity, 'HTTP-FALLBACK');
      expect(service.errorMessage, isNull);

      final snapshot = service.providerSnapshot;
      expect(snapshot.isDegradedLoad, isTrue);
      expect(
        snapshot.providers
            .firstWhere((r) => r.definition.location == httpCatalogUrl)
            .health,
        CatalogueProviderHealth.degraded,
      );
    });

    test('localPreferred with legacy prefs tries HTTP before bundled demo',
        () async {
      const missingLocal = r'Z:\TTSPlayerTestMissing\catalog.json';
      SharedPreferences.setMockInitialValues({
        'catalog_path': missingLocal,
      });

      final client = MockClient((request) async {
        expect(request.url.toString(), httpsCatalogUrl);
        return http.Response(
          jsonEncode(minimalCatalogJson(id: 'HTTP-WITH-LEGACY')),
          200,
        );
      });

      final service = CatalogService(httpClient: client)
        ..includeScannerConfigCataloguePath = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(missingLocal),
            MediaCatalogueProviderDefinition.http(httpsCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            httpMediaBaseUrl: httpsBase,
          ),
        ),
      );

      expect(service.isUsingFallback, isFalse);
      expect(service.catalogPath, httpsCatalogUrl);
      expect(service.catalog?.catalogueIdentity, 'HTTP-WITH-LEGACY');
    });

    test('localPreferred surfaces HTTP failure instead of silent demo fallback',
        () async {
      final client = MockClient((request) async {
        throw HandshakeException('CERTIFICATE_VERIFY_FAILED');
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
            MediaCatalogueProviderDefinition.http(httpsCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            httpMediaBaseUrl: httpsBase,
          ),
        ),
      );

      expect(service.isUsingFallback, isTrue);
      expect(service.catalogPath, 'bundled');
      expect(service.errorMessage, isNotNull);
      expect(
          service.errorMessage!.toLowerCase(), contains('secure connection'));
      expect(
        service.fallbackBannerMessage,
        contains('configured remote catalogue'),
      );
      expect(
        service.fallbackBannerMessage,
        isNot(contains(r'Y:\Media\catalog.json')),
      );
    });

    test('saved provider config loads remote URL before demo fallback',
        () async {
      const missingLocal = r'Z:\TTSPlayerTestMissing\catalog.json';
      final custom = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.localFile(missingLocal),
          MediaCatalogueProviderDefinition.http(httpsCatalogUrl),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: httpsBase,
        ),
      );

      SharedPreferences.setMockInitialValues({
        MediaProviderConfigService.prefKey: jsonEncode(custom.toJson()),
        'catalog_path': missingLocal,
      });

      final configService = MediaProviderConfigService();
      await configService.load();

      expect(configService.config.httpCatalogueUrl, httpsCatalogUrl);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(minimalCatalogJson(id: 'SAVED-REMOTE')),
          200,
        );
      });

      final service = CatalogService(httpClient: client)
        ..includeScannerConfigCataloguePath = false;
      await service.loadOnStartup(providerConfig: configService.config);

      expect(service.isUsingFallback, isFalse);
      expect(service.catalogPath, httpsCatalogUrl);
      expect(service.catalog?.catalogueIdentity, 'SAVED-REMOTE');
    });

    test('httpRequired loads HTTP provider only', () async {
      final localFile = File('${tempDir.path}/ignored-local.json');
      await localFile
          .writeAsString(jsonEncode(minimalCatalogJson(id: 'LOCAL')));

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(minimalCatalogJson(id: 'HTTP-ONLY')),
          200,
        );
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            MediaCatalogueProviderDefinition.localFile(localFile.path),
            const MediaCatalogueProviderDefinition.http(httpCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            mode: MediaAccessMode.httpRequired,
          ),
        ),
      );

      expect(service.catalogPath, httpCatalogUrl);
      expect(service.catalog?.catalogueIdentity, 'HTTP-ONLY');
    });

    test('httpRequired with no HTTP provider falls back to bundled demo',
        () async {
      SharedPreferences.setMockInitialValues({});

      final service = CatalogService()..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            mode: MediaAccessMode.httpRequired,
          ),
        ),
      );

      expect(service.isUsingFallback, isTrue);
      expect(service.catalogPath, 'bundled');
    });

    test('rescan failure retains active catalogue', () async {
      final goodFile = File('${tempDir.path}/good.json');
      await goodFile.writeAsString(jsonEncode(minimalCatalogJson(id: 'GOOD')));

      final service = CatalogService()..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            MediaCatalogueProviderDefinition.localFile(goodFile.path),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );
      expect(service.catalog?.catalogueIdentity, 'GOOD');

      service.setProviderConfig(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      await service.rescan();
      expect(service.catalog?.catalogueIdentity, 'GOOD');
      expect(service.errorMessage, isNotNull);
      expect(service.lastCatalogueLoadAt, isNotNull);
      expect(
        service.providerSnapshot.providers.every(
          (r) => r.health == CatalogueProviderHealth.failed,
        ),
        isTrue,
      );
    });

    test('refreshCatalogue retries full provider chain in order', () async {
      final first = File('${tempDir.path}/first.json');
      final second = File('${tempDir.path}/second.json');
      await first.writeAsString(jsonEncode(minimalCatalogJson(id: 'FIRST')));
      await second.writeAsString(jsonEncode(minimalCatalogJson(id: 'SECOND')));

      final service = CatalogService()..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            MediaCatalogueProviderDefinition.localFile(first.path),
            MediaCatalogueProviderDefinition.localFile(second.path),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );
      expect(service.catalog?.catalogueIdentity, 'FIRST');

      await first.delete();
      await service.refreshCatalogue();

      expect(service.catalog?.catalogueIdentity, 'SECOND');
      final snapshot = service.providerSnapshot;
      expect(
        snapshot.providers
            .firstWhere((r) => r.definition.location == first.path)
            .health,
        CatalogueProviderHealth.failed,
      );
      expect(
        snapshot.providers
            .firstWhere((r) => r.definition.location == second.path)
            .health,
        CatalogueProviderHealth.degraded,
      );
    });

    test(
        'startup demo fallback snapshot records failed providers and demo flags',
        () async {
      final client = MockClient((request) async {
        throw HandshakeException('CERTIFICATE_VERIFY_FAILED');
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
            MediaCatalogueProviderDefinition.http(httpsCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            httpMediaBaseUrl: httpsBase,
          ),
        ),
      );

      expect(service.isUsingFallback, isTrue);
      expect(service.catalogPath, 'bundled');
      expect(service.activeCatalogueProvider, isNull);

      final snapshot = service.providerSnapshot;
      expect(snapshot.isDemoFallback, isTrue);
      expect(snapshot.demoActiveWithoutProvider, isTrue);
      expect(snapshot.isDegradedLoad, isFalse);
      expect(snapshot.activeProvider, isNull);
      expect(snapshot.activeRecord, isNull);
      expect(
        snapshot.providers.every(
          (r) => r.health == CatalogueProviderHealth.failed,
        ),
        isTrue,
      );
    });

    test('httpRequired demo fallback includes skipped local providers',
        () async {
      SharedPreferences.setMockInitialValues({});

      final service = CatalogService()..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            mode: MediaAccessMode.httpRequired,
          ),
        ),
      );

      expect(service.isUsingFallback, isTrue);
      final snapshot = service.providerSnapshot;
      expect(snapshot.isDemoFallback, isTrue);
      expect(snapshot.demoActiveWithoutProvider, isTrue);
      expect(snapshot.activeProvider, isNull);
      expect(
        snapshot.providers.any(
          (r) => r.health == CatalogueProviderHealth.skipped,
        ),
        isTrue,
      );
    });

    test('httpRequired marks local providers skipped in snapshot', () async {
      final localFile = File('${tempDir.path}/skipped-local.json');
      await localFile
          .writeAsString(jsonEncode(minimalCatalogJson(id: 'LOCAL')));

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(minimalCatalogJson(id: 'HTTP-ONLY')),
          200,
        );
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;
      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            MediaCatalogueProviderDefinition.localFile(localFile.path),
            const MediaCatalogueProviderDefinition.http(httpCatalogUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            mode: MediaAccessMode.httpRequired,
          ),
        ),
      );

      final skipped = service.providerSnapshot.providers
          .where((r) => r.health == CatalogueProviderHealth.skipped)
          .toList();
      expect(skipped, isNotEmpty);
      expect(
        skipped.every(
          (r) => r.definition.kind == MediaCatalogueProviderKind.localFile,
        ),
        isTrue,
      );
    });
  });

  group('CatalogService manual load snapshot sync', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'manual load replaces active provider; failed load and refresh preserve chain',
        () async {
      const uniqueTitle = 'TEST — Unavailable NAS EPUB';
      final primary = File('${tempDir.path}/primary.json');
      final manual = File('${tempDir.path}/manual.json');
      await primary.writeAsString(
        jsonEncode(minimalCatalogJson(id: 'PRIMARY-CAT')),
      );
      await manual.writeAsString(
        jsonEncode(
          catalogJsonWithUniqueTitle(id: 'MANUAL-CAT', title: uniqueTitle),
        ),
      );

      final search = SearchService();
      final service = CatalogService(
        onCatalogReplaced: search.onCatalogReplaced,
      )..includeLegacyCataloguePaths = false;
      final config = MediaProviderConfig(
        catalogueProviders: [
          MediaCatalogueProviderDefinition.localFile(primary.path),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      );

      await service.loadOnStartup(providerConfig: config);

      expect(service.catalog?.catalogueIdentity, 'PRIMARY-CAT');
      expect(service.catalogPath, primary.path);
      expect(service.activeCatalogueProvider?.location, primary.path);
      expect(
        service.providerSnapshot.providers
            .firstWhere((r) => r.definition.location == primary.path)
            .health,
        CatalogueProviderHealth.success,
      );
      expect(
        service.providerSnapshot.loadedCatalogueIdentity,
        'PRIMARY-CAT',
      );
      final loadAtAfterStartup = service.lastCatalogueLoadAt;
      expect(loadAtAfterStartup, isNotNull);

      await service.loadFromFile(manual.path);

      expect(service.errorMessage, isNull);
      expect(service.catalog?.catalogueIdentity, 'MANUAL-CAT');
      expect(service.catalogPath, manual.path);
      expect(service.activeCatalogueProvider?.location, manual.path);
      expect(service.providerSnapshot.catalogPath, manual.path);
      expect(
        service.providerSnapshot.loadedCatalogueIdentity,
        'MANUAL-CAT',
      );
      expect(service.providerSnapshot.activeProvider?.location, manual.path);
      expect(service.lastCatalogueLoadAt, isNotNull);
      expect(
        service.lastCatalogueLoadAt!.isAfter(loadAtAfterStartup!) ||
            service.lastCatalogueLoadAt == loadAtAfterStartup,
        isTrue,
      );

      final primaryRecord = service.providerSnapshot.providers.firstWhere(
        (r) => r.definition.location == primary.path,
      );
      expect(primaryRecord.isActive, isFalse);
      expect(primaryRecord.health, CatalogueProviderHealth.idle);

      final manualRecord = service.providerSnapshot.providers.firstWhere(
        (r) => r.definition.location == manual.path,
      );
      expect(manualRecord.health, CatalogueProviderHealth.success);
      expect(manualRecord.isActive, isTrue);

      final hits = await search.searchCatalog(
        service.catalog!,
        uniqueTitle,
        const SearchFilters.empty(),
      );
      expect(hits, isNotEmpty);
      expect(hits.single.item.title, uniqueTitle);

      final snapshotBeforeFailure = service.providerSnapshot;
      final catalogBeforeFailure = service.catalog;
      final pathBeforeFailure = service.catalogPath;
      final activeBeforeFailure = service.activeCatalogueProvider?.location;
      final loadAtBeforeFailure = service.lastCatalogueLoadAt;

      await service.loadFromFile('${tempDir.path}/missing.json');

      expect(service.errorMessage, isNotNull);
      expect(service.catalog, catalogBeforeFailure);
      expect(service.catalogPath, pathBeforeFailure);
      expect(service.activeCatalogueProvider?.location, activeBeforeFailure);
      expect(
        service.providerSnapshot.loadedCatalogueIdentity,
        snapshotBeforeFailure.loadedCatalogueIdentity,
      );
      expect(service.providerSnapshot.catalogPath, pathBeforeFailure);
      expect(
        service.providerSnapshot.activeProvider?.location,
        activeBeforeFailure,
      );
      expect(service.lastCatalogueLoadAt, loadAtBeforeFailure);

      await service.refreshCatalogue();

      expect(service.errorMessage, isNull);
      expect(service.catalog?.catalogueIdentity, 'PRIMARY-CAT');
      expect(service.catalogPath, primary.path);
      expect(service.activeCatalogueProvider?.location, primary.path);
      expect(service.providerSnapshot.catalogPath, primary.path);
      expect(
        service.providerSnapshot.loadedCatalogueIdentity,
        'PRIMARY-CAT',
      );
      expect(
        service.providerSnapshot.providers
            .where((r) => r.definition.location == primary.path)
            .single
            .health,
        CatalogueProviderHealth.success,
      );
      expect(
        service.providerSnapshot.providers
            .where((r) => r.definition.location == manual.path),
        isEmpty,
      );
    });
  });

  group('MediaLocationResolver saved media access', () {
    test('uses saved custom media roots and HTTP base', () {
      const customRoots = [r'D:\Library\Media'];
      const customBase = 'http://192.168.0.10:8443/media/';

      final resolver = MediaLocationResolver(
        config: MediaAccessConfig(
          mediaRoots: customRoots,
          httpMediaBaseUrl: customBase,
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(r'D:\Library\Media\Movies\film.mp4');
      expect(result.isPlayable, isTrue);
      expect(
        result.uri,
        'http://192.168.0.10:8443/media/Movies/film.mp4',
      );
    });

    test('localPreferred on non-Windows falls back from local to HTTP', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.defaults(
          httpMediaBaseUrl: httpBase,
          mode: MediaAccessMode.localPreferred,
        ),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(r'Y:\Media\Movies\film.mp4');
      expect(result.isPlayable, isTrue);
      expect(
        result.uri,
        'http://192.168.0.10:8443/media/Movies/film.mp4',
      );
    });
  });
}
