import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/services/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalogUrl = 'http://192.168.178.130:8443/catalog.json';

  Map<String, dynamic> minimalCatalogJson(String catalogueId) => {
        'catalogue': {
          'id': catalogueId,
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
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ttsplayer_catalog_http_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> seedLocalCatalog(CatalogService service, String catalogueId) async {
    final file = File('${tempDir.path}/local.json');
    await file.writeAsString(jsonEncode(minimalCatalogJson(catalogueId)));
    await service.loadFromFile(file.path);
    expect(service.errorMessage, isNull);
    expect(service.catalog?.catalogueIdentity, catalogueId);
  }

  group('CatalogService.loadFromUrl', () {
    test('HTTP 200 with valid JSON loads catalogue', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), catalogUrl);
        return http.Response(
          jsonEncode(minimalCatalogJson('HTTP-CAT-1')),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CatalogService(httpClient: client);
      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, isNull);
      expect(service.catalogPath, catalogUrl);
      expect(service.catalog?.catalogueIdentity, 'HTTP-CAT-1');
    });

    test('non-200 fails gracefully and preserves previous catalogue', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = CatalogService(httpClient: client);
      await seedLocalCatalog(service, 'LOCAL-BEFORE-404');

      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, contains('404'));
      expect(service.catalogPath, isNot(catalogUrl));
      expect(service.catalog?.catalogueIdentity, 'LOCAL-BEFORE-404');
    });

    test('invalid JSON fails gracefully and preserves previous catalogue',
        () async {
      final client = MockClient((request) async {
        return http.Response('{not json', 200);
      });

      final service = CatalogService(httpClient: client);
      await seedLocalCatalog(service, 'LOCAL-BEFORE-JSON');

      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, contains('JSON'));
      expect(service.catalog?.catalogueIdentity, 'LOCAL-BEFORE-JSON');
    });

    test('timeout fails gracefully and preserves previous catalogue', () async {
      const shortTimeout = Duration(milliseconds: 50);
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      });

      final service = CatalogService(
        httpClient: client,
        catalogFetchTimeout: shortTimeout,
      );
      await seedLocalCatalog(service, 'LOCAL-BEFORE-TIMEOUT');

      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!.toLowerCase(), contains('timed out'));
      expect(service.catalog?.catalogueIdentity, 'LOCAL-BEFORE-TIMEOUT');
    });

    test('network error fails gracefully and preserves previous catalogue',
        () async {
      final client = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final service = CatalogService(httpClient: client);
      await seedLocalCatalog(service, 'LOCAL-BEFORE-NET');

      await service.loadFromUrl(catalogUrl);

      expect(service.errorMessage, contains('Network error'));
      expect(service.catalog?.catalogueIdentity, 'LOCAL-BEFORE-NET');
    });
  });

  group('CatalogService local loading unchanged', () {
    test('loadFromFile still loads local catalogue', () async {
      final service = CatalogService(httpClient: MockClient((_) async {
        fail('HTTP client must not be used for loadFromFile');
      }));

      final file = File('${tempDir.path}/local-only.json');
      await file.writeAsString(jsonEncode(minimalCatalogJson('LOCAL-ONLY')));

      await service.loadFromFile(file.path);

      expect(service.errorMessage, isNull);
      expect(service.catalogPath, file.path);
      expect(service.catalog?.catalogueIdentity, 'LOCAL-ONLY');
    });
  });
}
