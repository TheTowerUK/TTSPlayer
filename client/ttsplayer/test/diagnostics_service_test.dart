import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';

import 'support/diagnostics_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Application diagnostics', () {
    test('startup elapsed is non-negative and stable across snapshots', () async {
      final startedAt = DateTime.utc(2026, 7, 16, 9, 0);
      final service = await buildDiagnosticsHarness(
        applicationStartedAt: startedAt,
      );

      final first = await service.captureSnapshot();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = await service.captureSnapshot();

      expect(first.application.status, DiagnosticSectionStatus.complete);
      expect(first.application.startupElapsed, isNotNull);
      expect(first.application.startupElapsed!.inMilliseconds, greaterThanOrEqualTo(0));
      expect(second.application.startupElapsed!.inMicroseconds,
          greaterThanOrEqualTo(first.application.startupElapsed!.inMicroseconds));
      expect(service.applicationStartedAt, startedAt);
      expect(second.capturedAt.isAfter(first.capturedAt) ||
          second.capturedAt.isAtSameMomentAs(first.capturedAt), isTrue);
      expect(first.application.platform, 'windows');
      expect(first.application.appVersion, '0.5.0-dev');
    });

    test('failed package info yields unavailable application section', () async {
      final service = await buildDiagnosticsHarness(
        packageInfoLoader: () async => throw StateError('package info failed'),
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.application.status, DiagnosticSectionStatus.unavailable);
      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
    });
  });

  group('Provider and catalogue diagnostics', () {
    test('maps healthy provider and catalogue aggregates', () async {
      final catalog = diagnosticsCatalog(identity: 'REV-HEALTHY', itemCount: 3);
      final service = await buildDiagnosticsHarness(catalog: catalog);

      final snapshot = await service.captureSnapshot();
      final export = service.formatExport(snapshot);

      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
      expect(snapshot.provider.activeProviderKindLabel, 'Local file');
      expect(snapshot.provider.providers, isNotEmpty);
      expect(snapshot.catalogue?.status, DiagnosticSectionStatus.complete);
      expect(snapshot.catalogue?.itemCount, 3);
      expect(snapshot.catalogue?.libraryCount, 1);
      expect(snapshot.catalogue?.folderCount, 2);
      expect(containsSensitivePatterns(export), isFalse);
    });

    test('null catalogue yields null catalogue section', () async {
      final service = await buildDiagnosticsHarness(catalog: null);
      final snapshot = await service.captureSnapshot();

      expect(snapshot.catalogue, isNull);
      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
    });

    test('redacts provider and catalogue errors with paths', () async {
      final catalog = diagnosticsCatalog(identity: 'REV-ERR', itemCount: 1);
      final service = await buildDiagnosticsHarness(
        catalog: catalog,
        providerSnapshot: diagnosticsProviderSnapshot(
          lastError: r'Failed to read Y:\Media\catalog.json',
        ),
      );

      final snapshot = await service.captureSnapshot();
      final summary = snapshot.provider.providers.first.lastErrorSummary;
      expect(summary, isNotNull);
      expect(summary!.contains(r'Y:\Media'), isFalse);
      expect(containsSensitivePatterns(summary), isFalse);
    });
  });

  group('Cache diagnostics', () {
    test('reports artwork cache counters without mutation', () async {
      final artwork = ArtworkService(fileExists: (_) => true);
      final catalog = diagnosticsCatalog(identity: 'REV-CACHE', itemCount: 1);
      final item = catalog.allItems.first;
      artwork.forMediaItem(item);

      final service = await buildDiagnosticsHarness(
        catalog: catalog,
        artworkService: artwork,
      );

      final beforeCount = artwork.cacheEntryCount;
      final beforeEvictions = artwork.cacheEvictionCount;
      final snapshot = await service.captureSnapshot();

      expect(snapshot.cache.status, DiagnosticSectionStatus.complete);
      expect(snapshot.cache.artworkCandidateCount, beforeCount);
      expect(snapshot.cache.artworkCandidateCapacity, 500);
      expect(snapshot.cache.artworkEvictionCount, beforeEvictions);
      expect(artwork.cacheEntryCount, beforeCount);
      expect(artwork.cacheEvictionCount, beforeEvictions);
    });

    test('reports flutter image cache budget when available', () async {
      configureArtworkFlutterImageCache();
      final service = await buildDiagnosticsHarness(
        imageCacheAvailableProvider: () => true,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.cache.imageCacheBudgetBytes, kArtworkFlutterImageCacheMaxBytes);
    });
  });

  group('Search diagnostics', () {
    test('observes index state without building', () async {
      final search = SearchService();
      final catalog = diagnosticsCatalog(identity: 'REV-SEARCH', itemCount: 2);
      final service = await buildDiagnosticsHarness(
        catalog: catalog,
        searchService: search,
      );

      final beforeBuildCount = search.indexBuildCount;
      final snapshot = await service.captureSnapshot();

      expect(snapshot.search.status, DiagnosticSectionStatus.complete);
      expect(snapshot.search.hasIndex, isFalse);
      expect(snapshot.search.indexBuildCount, beforeBuildCount);
      expect(search.indexBuildCount, beforeBuildCount);
      expect(search.hasIndex, isFalse);
    });

    test('maps built index metadata', () async {
      final search = SearchService();
      final catalog = diagnosticsCatalog(identity: 'REV-BUILT', itemCount: 2);
      search.buildIndex(catalog);

      final service = await buildDiagnosticsHarness(
        catalog: catalog,
        searchService: search,
      );
      final snapshot = await service.captureSnapshot();

      expect(snapshot.search.hasIndex, isTrue);
      expect(snapshot.search.indexBuildCount, 1);
      expect(snapshot.search.indexedItemCount, 2);
      expect(snapshot.search.indexMatchesActiveCatalogue, isTrue);
      expect(snapshot.search.indexedCatalogueIdentity, isNotEmpty);
    });
  });

  group('Playback diagnostics', () {
    test('no-session state uses null session fields', () async {
      final service = await buildDiagnosticsHarness();
      final snapshot = await service.captureSnapshot();

      expect(snapshot.playback.hasActiveSession, isFalse);
      expect(snapshot.playback.isPlaying, isNull);
      expect(snapshot.playback.audioTrackCount, isNull);
      expect(snapshot.playback.sessionItemId, isNull);
    });
  });

  group('Library diagnostics', () {
    test('maps favourite counts as zero when empty', () async {
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      final catalog = diagnosticsCatalog(identity: 'REV-LIB', itemCount: 1);
      final service = await buildDiagnosticsHarness(
        catalog: catalog,
        libraryMetadataRepository: metadata,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.library?.status, DiagnosticSectionStatus.complete);
      expect(snapshot.library?.favouriteItemCount, 0);
      expect(snapshot.library?.favouriteFolderCount, 0);
    });

    test('unloaded metadata repository yields null library section', () async {
      final metadata = LibraryMetadataRepository();
      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-NOMETA', itemCount: 1),
        libraryMetadataRepository: metadata,
        withInitializedLibrary: false,
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.library, isNull);
      expect(snapshot.catalogue, isNotNull);
    });
  });

  group('Failure isolation', () {
    test('artwork failure does not suppress provider diagnostics', () async {
      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-FAIL', itemCount: 1),
        artworkService: ThrowingArtworkService(),
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.cache.status, DiagnosticSectionStatus.unavailable);
      expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
    });

    test('search failure does not suppress cache diagnostics', () async {
      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-FAIL2', itemCount: 1),
        searchService: ThrowingSearchService(),
      );

      final snapshot = await service.captureSnapshot();
      expect(snapshot.search.status, DiagnosticSectionStatus.unavailable);
      expect(snapshot.cache.status, DiagnosticSectionStatus.complete);
    });

    test('formatExport succeeds for partially unavailable snapshot', () async {
      final service = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-FMT', itemCount: 1),
        artworkService: ThrowingArtworkService(),
      );
      final snapshot = await service.captureSnapshot();
      final export = service.formatExport(snapshot);

      expect(export, contains('=== Cache ==='));
      expect(export, contains('Unavailable'));
      expect(exportContainsSensitiveData(export), isFalse);
    });
  });
}
