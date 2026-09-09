import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_entry.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_last_error_category.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'support/diagnostics_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late SettingsRepository settings;
  late MetadataEnrichmentRepository enrichment;
  late MetadataArtworkCacheRepository artwork;
  late DiagnosticsService diagnostics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('enrichment_diagnostics_');
    settings = SettingsRepository();
    await settings.initialize();
    enrichment = MetadataEnrichmentRepository();
    await enrichment.initialize();
    artwork = MetadataArtworkCacheRepository(
      filesystem: MetadataArtworkFilesystem(cacheRoot: tempRoot),
    );
    await artwork.initialize();
    diagnostics = await buildDiagnosticsHarness(
      settingsRepository: settings,
      metadataEnrichmentRepository: enrichment,
      metadataArtworkCacheRepository: artwork,
    );
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('defaults are disabled and operational counters are unavailable',
      () async {
    final value = (await diagnostics.captureSnapshot()).metadataEnrichment!;
    expect(value.externalMetadataEnabled, false);
    expect(value.enabledProviderIds, isEmpty);
    expect(value.credentialConfiguredByProvider['open_library'], false);
    expect(value.pendingOperationCount, isNull);
    expect(value.inFlightOperationCount, isNull);
    expect(value.artworkCacheEntryCount, 0);
    expect(value.artworkCacheIndexedBytes, 0);
  });

  test('aggregates safe states, error, provider and indexed artwork', () async {
    await settings.saveMetadataProviders(
      const MetadataProvidersSettings(
        externalMetadataEnabled: true,
        enabledProviderIds: {'open_library'},
      ),
    );
    await enrichment.upsert(
      const MetadataEnrichmentRecord(
        itemId: r'C:\Secret\private-book.epub',
        matchState: EnrichmentMatchState.linkedManual,
        lastErrorCategory: EnrichmentLastErrorCategory.rateLimited,
        fields: {
          'title': EnrichmentFieldValue(
            value: 'Secret Title ISBN 9780140449136 by Secret Author',
            source: EnrichmentFieldSource.provider,
          ),
        },
      ),
    );
    final now = DateTime.utc(2026, 9, 8);
    await artwork.upsertEntry(
      MetadataArtworkCacheEntry(
        cacheKey: 'secret-token-key',
        providerId: 'open_library',
        providerRecordId: 'raw-response-id',
        artworkId: 'secret-artwork',
        relativePath: 'cache/cover.jpg',
        contentType: 'image/jpeg',
        byteSize: 4096,
        createdAt: now,
        lastValidatedAt: now,
        lastAccessedAt: now,
        cacheState: MetadataArtworkCacheState.downloaded,
      ),
    );

    final snapshot = await diagnostics.captureSnapshot();
    final value = snapshot.metadataEnrichment!;
    expect(value.recordCountsByState['linked_manual'], 1);
    expect(value.lastSafeErrorCategory, 'rate_limited');
    expect(value.credentialConfiguredByProvider['open_library'], false);
    expect(value.artworkCacheEntryCount, 1);
    expect(value.artworkCacheIndexedBytes, 4096);
    expect(value.lastSuccessfulRefreshAt, isNull);

    final export = diagnostics.formatExport(snapshot);
    expect(export, contains('=== Metadata Enrichment ==='));
    expect(export, contains('Credential configured (open_library): false'));
    for (final prohibited in [
      'Secret Title',
      '9780140449136',
      'Secret Author',
      r'C:\Secret',
      'private-book.epub',
      'secret-token-key',
      'raw-response-id',
      'Authorization',
      'stack trace',
    ]) {
      expect(export, isNot(contains(prohibited)));
    }
  });

  testWidgets('screen renders read-only metadata enrichment section',
      (tester) async {
    await tester.pumpWidget(
      Provider<DiagnosticsService>.value(
        value: diagnostics,
        child: const MaterialApp(home: DiagnosticsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('diagnostics_section_metadata_enrichment')),
      findsOneWidget,
    );
    expect(find.text('Metadata Enrichment'), findsOneWidget);
  });
}
