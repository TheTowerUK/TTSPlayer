import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_presentation_metrics.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/library/folder_presentation_metrics.dart';
import 'package:ttsplayer/library/library_folder_view.dart';
import 'package:ttsplayer/models/library_filter.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';

import 'support/large_catalog_factory.dart';
import 'support/performance_benchmark_report.dart';

/// Opt-in micro-benchmarks for M4 Phase 4.5 performance characteristics.
///
/// Run manually:
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_45_BENCHMARK='1'
/// flutter test test/performance_microbenchmarks_test.dart
/// ```
void main() {
  if (Platform.environment['PHASE_45_BENCHMARK'] != '1') {
    test(
      'skipped — set PHASE_45_BENCHMARK=1 to run Phase 4.5 micro-benchmarks',
      () {},
      skip: true,
    );
    return;
  }

  group('Phase 4.5 micro-benchmarks', () {
    late PerformanceBenchmarkReport report;

    setUp(() {
      report = PerformanceBenchmarkReport(suiteName: 'M4 Phase 4.5');
      FolderPresentationMetrics.reset();
      SearchPresentationMetrics.reset();
    });

    tearDown(() {
      report.printReport();
    });

    test('search index lifecycle timings', () {
      final catalog = buildLargeCatalog(itemCount: mediumCatalogItemCount);
      final replacement = buildLargeCatalog(
        itemCount: smallCatalogItemCount,
        catalogueIdentity: 'bench-replace',
      );

      report.measure(
        operation: 'search_index_first_build',
        fixtureSize: mediumCatalogItemCount,
        run: () {
          final local = SearchService();
          local.buildIndex(catalog);
        },
      );

      final search = SearchService()..buildIndex(catalog);
      report.measure(
        operation: 'search_query_warm_index',
        fixtureSize: mediumCatalogItemCount,
        warmupIterations: 5,
        run: () {
          search.search('Title', const SearchFilters.empty());
        },
        extra: {'indexBuildCount': search.indexBuildCount},
      );

      search.onCatalogReplaced(replacement);
      report.measure(
        operation: 'search_invalidate_only',
        fixtureSize: mediumCatalogItemCount,
        run: () {},
        extra: {'hasIndex': search.hasIndex},
      );

      report.measure(
        operation: 'search_index_rebuild_after_replace',
        fixtureSize: smallCatalogItemCount,
        run: () {
          final local = SearchService();
          local.buildIndex(replacement);
        },
      );
    });

    test('folder view preparation timings', () {
      final catalog = buildLargeCatalog(itemCount: mediumCatalogItemCount);
      final folder = largeCatalogFolder(catalog);

      report.measure(
        operation: 'folder_view_prepare',
        fixtureSize: mediumCatalogItemCount,
        run: () {
          buildLibraryFolderView(
            folder: folder,
            sortMode: LibrarySortMode.defaultOrder,
            filter: LibraryFilter.all,
            catalogSupportedExtensions: catalog.supportedExtensions,
          );
        },
      );

      final memoFolder = folder;
      LibraryFolderView? cached;
      report.measure(
        operation: 'folder_view_memoized_reuse',
        fixtureSize: mediumCatalogItemCount,
        run: () {
          cached ??= buildLibraryFolderView(
            folder: memoFolder,
            sortMode: LibrarySortMode.defaultOrder,
            filter: LibraryFilter.all,
            catalogSupportedExtensions: catalog.supportedExtensions,
          );
          expect(cached!.items.length, mediumCatalogItemCount);
        },
      );

      report.measure(
        operation: 'folder_view_filter_change',
        fixtureSize: mediumCatalogItemCount,
        run: () {
          buildLibraryFolderView(
            folder: folder,
            sortMode: LibrarySortMode.defaultOrder,
            filter: LibraryFilter.video,
            catalogSupportedExtensions: catalog.supportedExtensions,
          );
        },
      );
    });

    test('artwork cache sustained insertion', () {
      final catalog = buildLargeCatalog(itemCount: 600);
      final service = ArtworkService(fileExists: (_) => false);

      report.measure(
        operation: 'artwork_populate_beyond_capacity',
        fixtureSize: 600,
        warmupIterations: 1,
        measureIterations: 3,
        run: () {
          final local = ArtworkService(fileExists: (_) => false);
          for (final item in catalog.allItems) {
            local.forMediaItem(item);
          }
          expect(local.cacheEntryCount, lessThanOrEqualTo(500));
        },
        extra: {'capacity': ArtworkService.defaultCacheCapacity},
      );

      for (final item in catalog.allItems) {
        service.forMediaItem(item);
      }

      report.measure(
        operation: 'artwork_cache_hit',
        fixtureSize: 600,
        run: () {
          service.forMediaItem(catalog.allItems.first);
        },
        extra: {
          'cacheEntryCount': service.cacheEntryCount,
          'evictions': service.cacheEvictionCount,
        },
      );

      report.measure(
        operation: 'artwork_cache_clear',
        fixtureSize: service.cacheEntryCount,
        run: service.clearCache,
      );
    });

    test('large fixture index build (10k informational)', () {
      final catalog = buildLargeCatalog(itemCount: largeCatalogItemCount);

      report.measure(
        operation: 'search_index_build_large',
        fixtureSize: largeCatalogItemCount,
        warmupIterations: 1,
        measureIterations: 3,
        run: () {
          final local = SearchService();
          local.buildIndex(catalog);
        },
      );
    });
  });
}
