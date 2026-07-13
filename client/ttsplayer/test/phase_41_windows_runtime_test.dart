@Tags(['phase41-runtime'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_candidate.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';

/// Windows runtime validation harness for M4 Phase 4.1.
///
/// Run manually:
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_41_RUNTIME='1'
/// flutter test test/phase_41_windows_runtime_test.dart --tags phase41-runtime
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _LiveHttpOverrides();

  if (Platform.environment['PHASE_41_RUNTIME'] != '1') {
    test('skipped — set PHASE_41_RUNTIME=1 to run Windows runtime validation',
        () {}, skip: true);
    return;
  }

  const localCatalog = r'Y:\Media\catalog.json';
  const httpsCatalog = 'https://ttsplayer.local:8443/catalog.json';
  const missingLocal = r'Z:\TTSPlayerPhase41Missing\catalog.json';
  const badTlsUrl = 'https://expired.badssl.com/catalog.json';

  Map<String, dynamic> minimalCatalogJson({String id = 'PHASE41-RUNTIME'}) => {
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

  group('Phase 4.1 Windows runtime validation', () {
    late bool localCatalogExists;
    late bool httpsReachable;

    setUpAll(() async {
      localCatalogExists = await File(localCatalog).exists();
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(httpsCatalog));
        request.followRedirects = false;
        final response = await request.close().timeout(const Duration(seconds: 15));
        httpsReachable = response.statusCode == 200;
        await response.drain();
        client.close();
      } catch (_) {
        httpsReachable = false;
      }
    });

    test('V1 local provider succeeds first', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({});
      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(localCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      expect(service.isUsingFallback, isFalse);
      expect(service.catalogPath, localCatalog);
      expect(service.isDegradedLoad, isFalse);
      expect(
        service.providerSnapshot.providers.first.health,
        CatalogueProviderHealth.success,
      );
      expect(service.catalog?.allItems.isNotEmpty ?? false, isTrue);
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V2 configured fallback succeeds (HTTPS after local miss)', () async {
      if (!httpsReachable) {
        fail('BLOCKED: $httpsCatalog not reachable with trusted TLS');
      }

      SharedPreferences.setMockInitialValues({});
      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(missingLocal),
            MediaCatalogueProviderDefinition.http(httpsCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            httpMediaBaseUrl: 'https://ttsplayer.local:8443/media/',
          ),
        ),
      );

      expect(service.isUsingFallback, isFalse);
      expect(service.catalogPath, httpsCatalog);
      expect(service.isDegradedLoad, isTrue);
      expect(service.providerSnapshot.isDegradedLoad, isTrue);
      final snapshot = service.providerSnapshot;
      expect(
        snapshot.providers.firstWhere((r) => r.definition.location == missingLocal).health,
        CatalogueProviderHealth.failed,
      );
      expect(
        snapshot.providers.firstWhere((r) => r.definition.location == httpsCatalog).health,
        CatalogueProviderHealth.degraded,
      );
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V3 failed refresh retains last-good catalogue', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({});
      var cacheClears = 0;
      final service = CatalogService(
        onCatalogReplaced: (_) => cacheClears++,
      )..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(localCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );
      final identityBefore = service.catalog?.catalogueIdentity;
      final lastLoadBefore = service.lastCatalogueLoadAt;
      expect(identityBefore, isNotNull);
      expect(lastLoadBefore, isNotNull);
      expect(cacheClears, 1);

      service.setProviderConfig(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(missingLocal),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      await service.refreshCatalogue();

      expect(service.catalog?.catalogueIdentity, identityBefore);
      expect(service.lastCatalogueLoadAt, lastLoadBefore);
      expect(cacheClears, 1);
      expect(service.errorMessage, isNotNull);
      expect(
        service.providerSnapshot.providers.every(
          (r) => r.health == CatalogueProviderHealth.failed,
        ),
        isTrue,
      );
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V4 cold-start demo fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(missingLocal),
            MediaCatalogueProviderDefinition.http(
              'https://127.0.0.1:59999/catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      expect(service.isUsingFallback, isTrue);
      expect(service.catalogPath, 'bundled');
      expect(service.isDegradedLoad, isFalse);
      expect(service.activeCatalogueProvider, isNull);
      final snapshot = service.providerSnapshot;
      expect(snapshot.isDemoFallback, isTrue);
      expect(snapshot.demoActiveWithoutProvider, isTrue);
      expect(snapshot.activeProvider, isNull);
      expect(
        snapshot.providers.every(
          (r) => r.health == CatalogueProviderHealth.failed,
        ),
        isTrue,
      );
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V5 httpRequired skips locals', () async {
      if (!httpsReachable) {
        fail('BLOCKED: $httpsCatalog not reachable');
      }
      if (!localCatalogExists) {
        fail('BLOCKED: local path needed for skip verification');
      }

      SharedPreferences.setMockInitialValues({});
      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(localCatalog),
            const MediaCatalogueProviderDefinition.http(httpsCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            mode: MediaAccessMode.httpRequired,
            httpMediaBaseUrl: 'https://ttsplayer.local:8443/media/',
          ),
        ),
      );

      expect(service.catalogPath, httpsCatalog);
      expect(
        service.providerSnapshot.providers.any(
          (r) => r.health == CatalogueProviderHealth.skipped,
        ),
        isTrue,
      );
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V6 refresh while loading exposes isLoading guard', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({});
      final completer = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.toString() == httpsCatalog) {
          return completer.future;
        }
        return http.Response('not found', 404);
      });

      final service = CatalogService(httpClient: client)
        ..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(missingLocal),
            const MediaCatalogueProviderDefinition.http(httpsCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      final refreshFuture = service.refreshCatalogue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.isLoading, isTrue);

      completer.complete(http.Response(jsonEncode(minimalCatalogJson()), 200));
      await refreshFuture;
      expect(service.isLoading, isFalse);
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V7 artwork sidecar after catalogue refresh', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({});
      var cacheClears = 0;
      final artwork = ArtworkService(fileExists: (path) => File(path).existsSync());
      final service = CatalogService(
        onCatalogReplaced: (_) {
          cacheClears++;
          artwork.clearCache();
        },
      )..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(localCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      MediaItem? item;
      for (final candidate in service.catalog!.allItems.take(500)) {
        final mediaFile = File(candidate.filePath);
        if (!mediaFile.existsSync()) continue;
        if (artwork.forMediaItem(candidate).source == ArtworkSource.placeholder) {
          item = candidate;
          break;
        }
      }
      if (item == null) {
        fail('BLOCKED: no catalogued item without existing artwork sidecar');
      }
      final mediaFile = File(item.filePath);
      final stem = mediaFile.uri.pathSegments.last.split('.').first;
      final sidecar = File('${mediaFile.parent.path}${Platform.pathSeparator}$stem.jpg');
      final createdSidecar = !await sidecar.exists();
      if (createdSidecar) {
        await sidecar.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);
      }

      try {
        expect(artwork.forMediaItem(item).source, ArtworkSource.placeholder);

        await service.refreshCatalogue();
        expect(cacheClears, 2);

        expect(artwork.forMediaItem(item).source, ArtworkSource.sidecar);
      } finally {
        if (createdSidecar && await sidecar.exists()) {
          await sidecar.delete();
        }
      }
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V8 legacy catalog_path pref compatibility', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({
        'catalog_path': localCatalog,
      });

      final service = CatalogService()
        ..includeScannerConfigCataloguePath = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(missingLocal),
            MediaCatalogueProviderDefinition.http(httpsCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      expect(service.catalogPath, localCatalog);
      expect(service.isUsingFallback, isFalse);
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V9 full scan integration (library rescan + catalogue reload)', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      // Indexer library rescan on Y:\Media\Music was executed immediately before
      // this closure pass (2026-07-12); this test verifies catalogue reload only.
      final service = CatalogService()..includeLegacyCataloguePaths = false;
      await service.refreshCatalogue();
      expect(service.catalogPath, localCatalog);
      expect(
        service.providerSnapshot.providers.first.health,
        CatalogueProviderHealth.success,
      );
      expect(service.catalog?.allItems.isNotEmpty ?? false, isTrue);
      expect(service.activeCatalogueProvider?.location, localCatalog);
    }, skip: !Platform.isWindows ? 'Windows only' : false);

    test('V10 TLS failure readable and retains catalogue', () async {
      if (!localCatalogExists) {
        fail('BLOCKED: $localCatalog not reachable');
      }

      SharedPreferences.setMockInitialValues({});
      final service = CatalogService()
        ..includeLegacyCataloguePaths = false;

      await service.loadOnStartup(
        providerConfig: MediaProviderConfig(
          catalogueProviders: [
            const MediaCatalogueProviderDefinition.localFile(localCatalog),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );
      final identityBefore = service.catalog?.catalogueIdentity;

      service.setProviderConfig(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.http(badTlsUrl),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            httpMediaBaseUrl: 'https://expired.badssl.com/',
          ),
        ),
      );

      await service.refreshCatalogue();

      expect(service.catalog?.catalogueIdentity, identityBefore);
      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!.toLowerCase(), anyOf(
        contains('secure connection'),
        contains('certificate'),
        contains('tls'),
        contains('handshake'),
      ));
      expect(
        service.providerSnapshot.providers.first.health,
        CatalogueProviderHealth.failed,
      );
      expect(service.isUsingFallback, isFalse);
    }, skip: !Platform.isWindows ? 'Windows only' : false);
  });
}

/// Restores real platform HTTP when flutter_test would otherwise return HTTP 400.
class _LiveHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
