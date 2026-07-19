import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'support/diagnostics_test_harness.dart';
import 'support/music_catalog_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Music catalogue service compatibility', () {
    late Catalog catalog;

    setUp(() {
      catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );
    });

    test('search indexes music artist and album fields', () {
      final search = SearchService();
      search.buildIndex(catalog);
      final results = search.search('Beatles', const SearchFilters.empty());
      expect(results.any((r) => r.item.id == 'track-complete'), isTrue);
    });

    test('continue watching excludes audio items', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = PlaybackService();
      await playback.persistResumeStateForTest(
        'track-complete',
        const Duration(seconds: 120),
        duration: const Duration(seconds: 3600),
      );
      await playback.persistResumeStateForTest(
        'video-1',
        const Duration(seconds: 120),
        duration: const Duration(seconds: 3600),
      );

      final entries = await playback.getContinueWatching(catalog);
      expect(entries.map((e) => e.item.id).toList(), ['video-1']);
      expect(entries.every((e) => e.item.mediaKind == MediaKind.video), isTrue);
    });

    test('artwork lookup accepts music item without artwork', () {
      final artwork = ArtworkService(fileExists: (_) => false);
      final candidate = artwork.forMediaItem(musicTrackComplete());
      expect(candidate.kind.name, isNotEmpty);
    });

    test('favourites reconciliation preserves music item ids', () async {
      SharedPreferences.setMockInitialValues({});
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      await metadata.addItemFavourite('track-complete');
      await metadata.addItemFavourite('video-1');

      final result = await metadata.validateAgainstCatalog(catalog);

      expect(result.prunedItemCount, 0);
      expect(metadata.isItemFavourited('track-complete'), isTrue);
      expect(metadata.isItemFavourited('video-1'), isTrue);
    });

    test('diagnostics snapshot accepts mixed-media catalogue', () async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'TTSPlayer',
        packageName: 'ttsplayer',
        version: '0.5.0-dev',
        buildNumber: '42',
        buildSignature: 'sig',
        installerStore: null,
      );
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      final config = MediaProviderConfigService();
      await config.load();
      final search = SearchService()..buildIndex(catalog);

      final service = DiagnosticsService(
        catalogService: StubCatalogService(stubCatalog: catalog),
        artworkService: ArtworkService(fileExists: (_) => false),
        searchService: search,
        playbackService: PlaybackService(),
        mediaProviderConfigService: config,
        libraryMetadataRepository: metadata,
        applicationStartedAt: DateTime.utc(2026, 7, 19, 12),
        packageInfoLoader: PackageInfo.fromPlatform,
        platformNameProvider: () => 'windows',
        imageCacheAvailableProvider: () => false,
      );

      final snapshot = await service.captureSnapshot();

      expect(snapshot.catalogue?.itemCount, catalog.totalItems);
      expect(search.indexedItemCount, catalog.allItems.length);
    });
  });
}
