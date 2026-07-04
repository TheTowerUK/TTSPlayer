import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/constants/supported_extensions.dart';
import 'package:ttsplayer/models/catalog.dart';

void main() {
  test('CatalogueInfo parses supported_extensions from catalogue block', () {
    final info = CatalogueInfo.fromJson({
      'id': 'TEST-ID',
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
      'supported_extensions': ['mp4', 'mkv'],
    });

    expect(info.supportedExtensions, ['mp4', 'mkv']);
    expect(info.supportedExtensionsLabel, 'mp4, mkv');
  });

  test('CatalogueInfo falls back when supported_extensions is absent', () {
    final info = CatalogueInfo.fromJson({
      'id': 'TEST-ID',
      'scanner_version': '0.3.1',
      'catalogue_version': 2,
    });

    expect(info.supportedExtensions, SupportedExtensions.all);
    expect(info.supportedExtensions, contains('jpg'));
  });

  test('Catalog exposes supported extension label from catalogue block', () {
    final catalog = Catalog.fromJson({
      'catalogue': {
        'id': 'TEST-ID',
        'scanner_version': '0.3.0',
        'catalogue_version': 2,
        'supported_extensions': ['avi', 'mp4'],
      },
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 0,
      'folders': [],
    });

    expect(catalog.supportedExtensions, ['avi', 'mp4']);
    expect(catalog.supportedExtensionsLabel, 'avi, mp4');
  });
}
