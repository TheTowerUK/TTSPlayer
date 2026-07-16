import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'support/diagnostics_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('integrated capture matches source services without mutation', () async {
    final artwork = ArtworkService(fileExists: (_) => true);
    final search = SearchService();
    final metadata = LibraryMetadataRepository();
    await metadata.initialize();

    final catalog = diagnosticsCatalog(
      identity: 'REV-INTEGRATED',
      itemCount: 3,
    );
    final catalogService = StubCatalogService(
      stubCatalog: catalog,
      catalogPathValue: 'bundled',
      demo: true,
    );

    final config = MediaProviderConfigService();
    await config.load();

    artwork.forMediaItem(catalog.allItems.first);
    search.buildIndex(catalog);

    final beforeSearchBuilds = search.indexBuildCount;
    final beforeCacheCount = artwork.cacheEntryCount;
    final beforeHasIndex = search.hasIndex;

    final service = DiagnosticsService(
      catalogService: catalogService,
      artworkService: artwork,
      searchService: search,
      playbackService: PlaybackService(),
      mediaProviderConfigService: config,
      libraryMetadataRepository: metadata,
      applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
      packageInfoLoader: () async {
        PackageInfo.setMockInitialValues(
          appName: 'TTSPlayer',
          packageName: 'ttsplayer',
          version: '0.5.0-dev',
          buildNumber: '42',
          buildSignature: 'sig',
          installerStore: null,
        );
        return PackageInfo.fromPlatform();
      },
      platformNameProvider: () => 'windows',
      imageCacheAvailableProvider: () => false,
    );

    final snapshot = await service.captureSnapshot();

    expect(snapshot.catalogue?.itemCount, catalog.totalItems);
    expect(snapshot.search.indexBuildCount, beforeSearchBuilds);
    expect(snapshot.search.hasIndex, beforeHasIndex);
    expect(snapshot.cache.artworkCandidateCount, beforeCacheCount);
    expect(search.indexBuildCount, beforeSearchBuilds);
    expect(artwork.cacheEntryCount, beforeCacheCount);
    expect(snapshot.library?.favouriteItemCount, 0);
    expect(snapshot.provider.status, DiagnosticSectionStatus.complete);
    expect(snapshot.application.status, DiagnosticSectionStatus.complete);
  });

  test('catalogue replacement reflected in next snapshot', () async {
    final search = SearchService();
    final artwork = ArtworkService(fileExists: (_) => true);
    final metadata = LibraryMetadataRepository();
    await metadata.initialize();
    final config = MediaProviderConfigService();
    await config.load();

    final first = diagnosticsCatalog(identity: 'REV-ONE', itemCount: 1);
    final second = diagnosticsCatalog(identity: 'REV-TWO', itemCount: 2);

    final catalogService = StubCatalogService(stubCatalog: first);
    final service = DiagnosticsService(
      catalogService: catalogService,
      artworkService: artwork,
      searchService: search,
      playbackService: PlaybackService(),
      mediaProviderConfigService: config,
      libraryMetadataRepository: metadata,
      applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
      packageInfoLoader: () async {
        PackageInfo.setMockInitialValues(
          appName: 'TTSPlayer',
          packageName: 'ttsplayer',
          version: '0.5.0-dev',
          buildNumber: '42',
          buildSignature: 'sig',
          installerStore: null,
        );
        return PackageInfo.fromPlatform();
      },
      platformNameProvider: () => 'windows',
      imageCacheAvailableProvider: () => false,
    );

    search.buildIndex(first);
    final firstSnapshot = await service.captureSnapshot();
    expect(firstSnapshot.catalogue?.itemCount, 1);
    expect(firstSnapshot.search.indexMatchesActiveCatalogue, isTrue);

    search.onCatalogReplaced(second);
    catalogService.stubCatalog = second;

    final secondSnapshot = await service.captureSnapshot();
    expect(secondSnapshot.catalogue?.itemCount, 2);
    expect(secondSnapshot.search.indexMatchesActiveCatalogue, isFalse);
    expect(secondSnapshot.search.hasIndex, isFalse);
  });
}
