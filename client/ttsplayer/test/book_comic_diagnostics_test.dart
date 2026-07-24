import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';

import 'support/book_comic_catalog_fixtures.dart';
import 'support/diagnostics_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalogue diagnostics include schema version and kind counts', () async {
    final catalog = Catalog.fromJson(
      jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
    );
    final service = await buildDiagnosticsHarness(catalog: catalog);
    final snapshot = await service.captureSnapshot();

    expect(snapshot.catalogue?.status, DiagnosticSectionStatus.complete);
    expect(snapshot.catalogue?.catalogueVersion, 4);
    expect(snapshot.catalogue?.scannerVersion, '0.5.0');
    expect(snapshot.catalogue?.bookItemCount, 3);
    expect(snapshot.catalogue?.comicItemCount, 3);
    expect(snapshot.catalogue?.videoItemCount, 2);
    expect(snapshot.catalogue?.audioItemCount, 2);
    expect(snapshot.catalogue?.supportedExtensionCount, greaterThan(20));

    final export = formatDiagnosticsExport(snapshot);
    expect(export, contains('Catalogue version'));
    expect(export, contains('Book items'));
    expect(export, contains('Comic items'));
    expect(export, isNot(contains(r'Y:\Media')));
  });
}
