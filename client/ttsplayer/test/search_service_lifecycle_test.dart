import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';

import 'support/catalog_cache_test_support.dart';

Catalog _catalogWithItems({
  required String identity,
  required List<String> itemIds,
  String libraryName = 'Videos',
}) {
  return Catalog.fromJson({
    'generated_at': '2026-07-14T10:00:00+00:00',
    'total_items': itemIds.length,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
    },
    'folders': [
      {
        'id': 'lib-main',
        'name': libraryName,
        'path': r'Y:\Media\Videos',
        'item_count': itemIds.length,
        'items': [
          for (final id in itemIds)
            {
              'id': id,
              'title': id,
              'file_path': 'Y:\\Media\\Videos\\$id.mp4',
              'status': 'available',
            },
        ],
        'subfolders': [],
      },
    ],
  });
}

Catalog _emptyCatalog({required String identity}) {
  return Catalog.fromJson({
    'generated_at': '2026-07-14T10:00:00+00:00',
    'total_items': 0,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
    },
    'folders': [],
  });
}

void main() {
  group('SearchService startup deferral', () {
    test('constructor does not build an index', () {
      final search = SearchService();
      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 0);
      expect(search.indexedItemCount, 0);
    });

    test('onCatalogReplaced does not eagerly build', () {
      final search = SearchService();
      search.onCatalogReplaced(
        _catalogWithItems(identity: 'REV-1', itemIds: ['a', 'b']),
      );

      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 0);
      expect(search.catalogueIdentity, isNull);
    });
  });

  group('SearchService first use and reuse', () {
    late SearchService search;
    late Catalog catalog;

    setUp(() {
      search = SearchService();
      catalog = _catalogWithItems(
        identity: 'USE-1',
        itemIds: ['alpha', 'beta'],
      );
    });

    test('first valid search builds index once', () async {
      final results = await search.searchCatalog(
        catalog,
        'alpha',
        const SearchFilters.empty(),
      );

      expect(search.indexBuildCount, 1);
      expect(search.hasIndex, isTrue);
      expect(search.catalogueIdentity, 'USE-1');
      expect(results.single.item.id, 'alpha');
    });

    test('second query reuses index without additional build', () async {
      await search.searchCatalog(catalog, 'alpha', const SearchFilters.empty());
      await search.searchCatalog(catalog, 'beta', const SearchFilters.empty());

      expect(search.indexBuildCount, 1);
      expect(search.indexedItemCount, 2);
    });

    test('empty query does not build index', () async {
      final results = await search.searchCatalog(
        catalog,
        '   ',
        const SearchFilters.empty(),
      );

      expect(results, isEmpty);
      expect(search.indexBuildCount, 0);
      expect(search.hasIndex, isFalse);
    });

    test('filter metadata available from catalog before first search', () {
      expect(search.libraryNamesFor(catalog), ['Videos']);
      expect(search.extensionsFor(catalog), contains('mp4'));
      expect(search.indexBuildCount, 0);
    });

    test('repeated catalogue object with same identity does not rebuild', () async {
      await search.searchCatalog(catalog, 'alpha', const SearchFilters.empty());
      final again = _catalogWithItems(identity: 'USE-1', itemIds: ['alpha', 'beta']);
      await search.searchCatalog(again, 'beta', const SearchFilters.empty());

      expect(search.indexBuildCount, 1);
    });
  });

  group('SearchService catalogue replacement', () {
    test('successful replacement invalidates without eager rebuild', () {
      final search = SearchService();
      final first = _catalogWithItems(identity: 'OLD', itemIds: ['one']);
      search.buildIndex(first);
      expect(search.indexBuildCount, 1);

      search.onCatalogReplaced(
        _catalogWithItems(identity: 'NEW', itemIds: ['two']),
      );

      expect(search.hasIndex, isFalse);
      expect(search.catalogueIdentity, isNull);
      expect(search.indexBuildCount, 1);
    });

    test('first search after replacement builds once for new catalogue', () async {
      final search = SearchService();
      final first = _catalogWithItems(identity: 'OLD', itemIds: ['old-item']);
      final second = _catalogWithItems(identity: 'NEW', itemIds: ['new-item']);

      search.buildIndex(first);
      search.onCatalogReplaced(second);

      final results = await search.searchCatalog(
        second,
        'new',
        const SearchFilters.empty(),
      );

      expect(search.indexBuildCount, 2);
      expect(search.catalogueIdentity, 'NEW');
      expect(results.single.item.id, 'new-item');
      expect(
        search.search('old', const SearchFilters.empty()),
        isEmpty,
      );
    });

    test('empty to populated replacement defers build until search', () async {
      final search = SearchService();
      search.onCatalogReplaced(_emptyCatalog(identity: 'EMPTY'));
      expect(search.indexBuildCount, 0);

      final populated = _catalogWithItems(identity: 'FULL', itemIds: ['x']);
      search.onCatalogReplaced(populated);

      await search.searchCatalog(populated, 'x', const SearchFilters.empty());
      expect(search.indexBuildCount, 1);
      expect(search.catalogueIdentity, 'FULL');
    });
  });

  group('SearchService concurrency', () {
    test('concurrent first searches share one build', () async {
      final search = SearchService();
      final catalog = _catalogWithItems(
        identity: 'CONC',
        itemIds: ['one', 'two'],
      );

      final futures = [
        search.searchCatalog(catalog, 'one', const SearchFilters.empty()),
        search.searchCatalog(catalog, 'two', const SearchFilters.empty()),
        search.searchCatalog(catalog, 'one', const SearchFilters.empty()),
      ];

      final results = await Future.wait(futures);
      expect(search.indexBuildCount, 1);
      expect(results[0].single.item.id, 'one');
      expect(results[1].single.item.id, 'two');
    });

    test('failed build clears in-flight state and allows retry', () async {
      final search = SearchService()..simulateBuildFailure = true;
      final catalog = _catalogWithItems(identity: 'FAIL', itemIds: ['a']);

      await expectLater(
        search.searchCatalog(catalog, 'a', const SearchFilters.empty()),
        throwsA(isA<SearchIndexBuildException>()),
      );
      expect(search.isBuildInFlight, isFalse);
      expect(search.hasIndex, isFalse);

      search.simulateBuildFailure = false;
      final results = await search.searchCatalog(
        catalog,
        'a',
        const SearchFilters.empty(),
      );
      expect(results.single.item.id, 'a');
      expect(search.indexBuildCount, 1);
    });

    test('replacement during in-flight build does not publish stale index', () async {
      final search = SearchService();
      final oldCatalog = _catalogWithItems(identity: 'OLD', itemIds: ['old']);
      final newCatalog = _catalogWithItems(identity: 'NEW', itemIds: ['new']);

      final buildFuture = search.ensureIndex(oldCatalog);
      search.onCatalogReplaced(newCatalog);
      await buildFuture;

      expect(search.catalogueIdentity, isNull);
      expect(search.hasIndex, isFalse);

      await search.searchCatalog(newCatalog, 'new', const SearchFilters.empty());
      expect(search.catalogueIdentity, 'NEW');
      expect(
        search.search('old', const SearchFilters.empty()),
        isEmpty,
      );
    });
  });

  group('CatalogCacheCoordinator search regression', () {
    test('successful replacement invalidates search once without eager rebuild', () {
      final artwork = ArtworkService(fileExists: (_) => false);
      final search = SearchService();
      final metadata = LibraryMetadataRepository();

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: metadata,
        musicLibraryService: MusicLibraryService(),
      );

      final first = _catalogWithItems(identity: 'REV-1', itemIds: ['a']);
      search.buildIndex(first);

      coordinator.onCatalogReplaced(
        _catalogWithItems(identity: 'REV-2', itemIds: ['c']),
      );

      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 1);
    });
  });
}
