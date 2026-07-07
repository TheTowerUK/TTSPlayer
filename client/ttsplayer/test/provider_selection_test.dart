import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      await localFile.writeAsString(jsonEncode(minimalCatalogJson(id: 'LOCAL')));

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
    });

    test('localPreferred falls back to HTTP when local files missing', () async {
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
    });

    test(
        'localPreferred with legacy prefs tries HTTP before bundled demo',
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
      expect(service.errorMessage!.toLowerCase(), contains('secure connection'));
      expect(
        service.fallbackBannerMessage,
        contains('configured remote catalogue'),
      );
      expect(
        service.fallbackBannerMessage,
        isNot(contains(r'Y:\Media\catalog.json')),
      );
    });

    test('saved provider config loads remote URL before demo fallback', () async {
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
      await localFile.writeAsString(jsonEncode(minimalCatalogJson(id: 'LOCAL')));

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

      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;
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

      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;
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
