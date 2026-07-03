import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/services/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late CatalogService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ttsplayer_warnings_');
    service = CatalogService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> writeCatalog(
    String filename,
    String catalogueId, {
    List<Map<String, dynamic>> warnings = const [],
  }) async {
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(jsonEncode({
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
        'warnings': warnings.length,
      },
      'generated_at': '2026-07-01T10:00:05+00:00',
      'sources': [],
      'total_items': 0,
      'folders': [],
      'scan_warnings': warnings,
    }));
  }

  test('shows warnings when catalogue has scan_warnings', () async {
    await writeCatalog(
      'catalog.json',
      'CAT-A',
      warnings: [
        {
          'path': '/media/Missing',
          'error': 'PermissionError',
          'detail': 'Access denied',
          'severity': 'warning',
          'reason': 'permission',
        },
      ],
    );

    await service.loadFromFile('${tempDir.path}/catalog.json');

    expect(service.shouldShowScanWarnings, isTrue);
  });

  test('dismiss hides warnings for current catalogue id only', () async {
    await writeCatalog(
      'catalog.json',
      'CAT-A',
      warnings: [
        {
          'path': '/media/Missing',
          'error': 'PermissionError',
          'detail': 'Access denied',
          'severity': 'warning',
          'reason': 'permission',
        },
      ],
    );

    await service.loadFromFile('${tempDir.path}/catalog.json');
    expect(service.shouldShowScanWarnings, isTrue);

    await service.dismissScanWarnings();
    expect(service.shouldShowScanWarnings, isFalse);

    // Same catalogue reloaded — still dismissed.
    await service.loadFromFile('${tempDir.path}/catalog.json');
    expect(service.shouldShowScanWarnings, isFalse);
  });

  test('new catalogue id re-evaluates dismissed warnings', () async {
    await writeCatalog(
      'catalog-a.json',
      'CAT-A',
      warnings: [
        {
          'path': '/media/Missing',
          'error': 'PermissionError',
          'detail': 'Access denied',
          'severity': 'warning',
          'reason': 'permission',
        },
      ],
    );
    await writeCatalog(
      'catalog-b.json',
      'CAT-B',
      warnings: [
        {
          'path': '/media/Other',
          'error': 'PermissionError',
          'detail': 'Access denied',
          'severity': 'warning',
          'reason': 'permission',
        },
      ],
    );

    await service.loadFromFile('${tempDir.path}/catalog-a.json');
    await service.dismissScanWarnings();
    expect(service.shouldShowScanWarnings, isFalse);

    await service.loadFromFile('${tempDir.path}/catalog-b.json');
    expect(service.shouldShowScanWarnings, isTrue);
  });

  test('no warnings means banner is not shown', () async {
    await writeCatalog('catalog.json', 'CAT-CLEAN');

    await service.loadFromFile('${tempDir.path}/catalog.json');

    expect(service.shouldShowScanWarnings, isFalse);
  });

  test('resolved scan with no warnings does not reappear after dismiss',
      () async {
    await writeCatalog(
      'catalog-warn.json',
      'CAT-WARN',
      warnings: [
        {
          'path': '/media/Missing',
          'error': 'PermissionError',
          'detail': 'Access denied',
          'severity': 'warning',
          'reason': 'permission',
        },
      ],
    );
    await writeCatalog('catalog-clean.json', 'CAT-CLEAN');

    await service.loadFromFile('${tempDir.path}/catalog-warn.json');
    await service.dismissScanWarnings();

    await service.loadFromFile('${tempDir.path}/catalog-clean.json');
    expect(service.shouldShowScanWarnings, isFalse);
  });
}
