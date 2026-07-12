import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const httpCatalogUrl = 'http://192.168.0.10:8443/catalog.json';

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ttsplayer_artwork_cache_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Map<String, dynamic> minimalCatalogJson({String id = 'CACHE-TEST-1'}) => {
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

  test('onCatalogReplaced runs when catalogue loads from file', () async {
    var replaced = 0;
    final catalogFile = File('${tempDir.path}/catalog.json');
    await catalogFile.writeAsString(
      jsonEncode(minimalCatalogJson()),
    );

    final service = CatalogService(
      onCatalogReplaced: () => replaced++,
    );

    await service.loadFromFile(catalogFile.path);

    expect(replaced, 1);
    expect(service.catalog, isNotNull);
  });

  test('onCatalogReplaced does not run when catalogue load fails', () async {
    var replaced = 0;
    final service = CatalogService(
      onCatalogReplaced: () => replaced++,
    );

    await service.loadFromFile('${tempDir.path}/missing.json');

    expect(replaced, 0);
    expect(service.catalog, isNull);
  });

  test('onCatalogReplaced fires once when later provider succeeds', () async {
    var replaced = 0;
    final catalogFile = File('${tempDir.path}/local.json');
    await catalogFile.writeAsString(
      jsonEncode(minimalCatalogJson(id: 'LOCAL-ONLY')),
    );

    final client = MockClient((request) async {
      return http.Response('not found', 404);
    });

    final service = CatalogService(
      httpClient: client,
      onCatalogReplaced: () => replaced++,
    )..includeLegacyCataloguePaths = false;

    await service.loadOnStartup(
      providerConfig: MediaProviderConfig(
        catalogueProviders: [
          const MediaCatalogueProviderDefinition.http(httpCatalogUrl),
          MediaCatalogueProviderDefinition.localFile(catalogFile.path),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      ),
    );

    expect(replaced, 1);
    expect(service.catalog?.catalogueIdentity, 'LOCAL-ONLY');
  });

  test('onCatalogReplaced does not run when rescan fails and catalogue retained',
      () async {
    var replaced = 0;
    final catalogFile = File('${tempDir.path}/good.json');
    await catalogFile.writeAsString(
      jsonEncode(minimalCatalogJson(id: 'KEPT')),
    );

    final service = CatalogService(
      onCatalogReplaced: () => replaced++,
    )..includeLegacyCataloguePaths = false;

    await service.loadOnStartup(
      providerConfig: MediaProviderConfig(
        catalogueProviders: [
          MediaCatalogueProviderDefinition.localFile(catalogFile.path),
        ],
        mediaAccess: MediaAccessConfig.defaults(),
      ),
    );
    expect(replaced, 1);

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
    expect(replaced, 1);
    expect(service.catalog?.catalogueIdentity, 'KEPT');
    expect(service.errorMessage, isNotNull);
  });
}
