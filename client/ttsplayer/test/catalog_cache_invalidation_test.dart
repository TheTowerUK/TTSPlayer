import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_cache_coordinator.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';

class _CountingArtworkService extends ArtworkService {
  _CountingArtworkService({super.fileExists});

  int clearInvocations = 0;

  @override
  void clearCache() {
    clearInvocations++;
    super.clearCache();
  }
}

Catalog _catalogWithItems({
  required String identity,
  required List<String> itemIds,
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
        'name': 'Videos',
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

Map<String, dynamic> _minimalCatalogJson({required String id}) => {
      'catalogue': {
        'id': id,
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

Future<String> _writeCatalogFile(
  Directory dir,
  Map<String, dynamic> json,
) async {
  final file = File('${dir.path}/catalog.json');
  await file.writeAsString(jsonEncode(json));
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ttsplayer_cache_inv_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('CatalogCacheCoordinator', () {
    test('onCatalogReplaced clears artwork and invalidates search index', () {
      final artwork = _CountingArtworkService(fileExists: (_) => true);
      final search = SearchService();
      final metadata = LibraryMetadataRepository();

      final coordinator = CatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: metadata,
        musicLibraryService: MusicLibraryService(),
      );

      final first = _catalogWithItems(identity: 'REV-1', itemIds: ['a', 'b']);
      final second = _catalogWithItems(identity: 'REV-2', itemIds: ['c']);

      artwork.forMediaItem(first.allItems.first);
      search.buildIndex(first);

      coordinator.onCatalogReplaced(second);

      expect(artwork.clearInvocations, 1);
      expect(search.catalogueIdentity, isNull);
      expect(search.indexedItemCount, 0);
      expect(search.indexBuildCount, 1);
    });
  });

  group('SearchService catalogue revision', () {
    test('invalidateIndex clears identity and entries', () {
      final search = SearchService();
      final catalog = _catalogWithItems(identity: 'REV-A', itemIds: ['x']);
      search.buildIndex(catalog);

      search.invalidateIndex();

      expect(search.catalogueIdentity, isNull);
      expect(search.indexedItemCount, 0);
      expect(search.libraryNames, isEmpty);
    });

    test('onCatalogReplaced invalidates without eager rebuild', () {
      final search = SearchService();
      search.buildIndex(
        _catalogWithItems(identity: 'OLD', itemIds: ['one', 'two']),
      );
      expect(search.indexedItemCount, 2);

      search.onCatalogReplaced(
        _catalogWithItems(identity: 'NEW', itemIds: ['solo']),
      );

      expect(search.catalogueIdentity, isNull);
      expect(search.indexedItemCount, 0);
    });

    test('search after onCatalogReplaced builds for new identity', () async {
      final search = SearchService();
      search.onCatalogReplaced(
        _catalogWithItems(identity: 'NEW', itemIds: ['solo']),
      );

      final results = await search.searchCatalog(
        _catalogWithItems(identity: 'NEW', itemIds: ['solo']),
        'solo',
        const SearchFilters.empty(),
      );

      expect(search.catalogueIdentity, 'NEW');
      expect(search.indexedItemCount, 1);
      expect(results.single.item.id, 'solo');
    });
  });

  group('CatalogService + CatalogCacheCoordinator integration', () {
    Future<({
      CatalogService catalogService,
      _CountingArtworkService artwork,
      SearchService search,
      LibraryMetadataRepository metadata,
    })> createWiredServices() async {
      final artwork = _CountingArtworkService(fileExists: (_) => false);
      final search = SearchService();
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();

      final coordinator = CatalogCacheCoordinator(
        artworkService: artwork,
        searchService: search,
        libraryMetadataRepository: metadata,
        musicLibraryService: MusicLibraryService(),
      );

      final catalogService = CatalogService(
        onCatalogReplaced: coordinator.onCatalogReplaced,
      )..includeLegacyCataloguePaths = false;

      return (
        catalogService: catalogService,
        artwork: artwork,
        search: search,
        metadata: metadata,
      );
    }

    test('successful replacement invalidates caches exactly once', () async {
      final wired = await createWiredServices();
      final goodPath = await _writeCatalogFile(
        tempDir,
        _minimalCatalogJson(id: 'GOOD-1'),
      );

      await wired.catalogService.loadFromFile(goodPath);

      expect(wired.artwork.clearInvocations, 1);
      expect(wired.search.catalogueIdentity, isNull);
      expect(wired.search.indexBuildCount, 0);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'GOOD-1');
    });

    test('failed refresh preserves catalogue identity and skips invalidation',
        () async {
      final wired = await createWiredServices();
      final goodPath = await _writeCatalogFile(
        tempDir,
        _minimalCatalogJson(id: 'KEPT'),
      );

      await wired.catalogService.loadFromFile(goodPath);
      expect(wired.artwork.clearInvocations, 1);

      wired.search.buildIndex(wired.catalogService.catalog!);
      final identityBefore = wired.search.catalogueIdentity;
      final indexedBefore = wired.search.indexedItemCount;

      await wired.metadata.addItemFavourite('stale-item');
      await wired.metadata.validateAgainstCatalog(
        _catalogWithItems(identity: 'KEPT', itemIds: ['stale-item']),
      );
      expect(wired.metadata.isItemFavourited('stale-item'), isTrue);

      await wired.catalogService.loadFromFile(
        '${tempDir.path}/missing-catalog.json',
      );

      expect(wired.artwork.clearInvocations, 1);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'KEPT');
      expect(wired.search.catalogueIdentity, identityBefore);
      expect(wired.search.indexedItemCount, indexedBefore);
      expect(wired.metadata.isItemFavourited('stale-item'), isTrue);
    });

    test('successful rescan advances identity and invalidates again', () async {
      final wired = await createWiredServices();
      final firstPath = await _writeCatalogFile(
        tempDir,
        _minimalCatalogJson(id: 'FIRST'),
      );
      final rev2Dir = Directory('${tempDir.path}/rev2');
      await rev2Dir.create();
      final secondPath = await _writeCatalogFile(
        rev2Dir,
        _minimalCatalogJson(id: 'SECOND'),
      );

      await wired.catalogService.loadFromFile(firstPath);
      expect(wired.artwork.clearInvocations, 1);
      expect(wired.search.catalogueIdentity, isNull);

      await wired.catalogService.loadFromFile(secondPath);

      expect(wired.artwork.clearInvocations, 2);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'SECOND');
      expect(wired.search.catalogueIdentity, isNull);
      expect(wired.search.indexBuildCount, 0);
    });

    test('failed rescan retains last-good catalogue without extra invalidation',
        () async {
      final wired = await createWiredServices();
      final goodPath = await _writeCatalogFile(
        tempDir,
        _minimalCatalogJson(id: 'KEPT-RESCAN'),
      );

      await wired.catalogService.loadFromFile(goodPath);
      expect(wired.artwork.clearInvocations, 1);

      wired.catalogService.setProviderConfig(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.localFile(
              r'Z:\Missing\catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(),
        ),
      );

      await wired.catalogService.rescan();

      expect(wired.artwork.clearInvocations, 1);
      expect(wired.catalogService.catalog?.catalogueIdentity, 'KEPT-RESCAN');
      expect(wired.search.catalogueIdentity, isNull);
      expect(wired.search.indexBuildCount, 0);
      expect(wired.catalogService.errorMessage, isNotNull);
    });

    test('favourites reconcile only after successful replacement', () async {
      final wired = await createWiredServices();
      await wired.metadata.addItemFavourite('item-a');
      await wired.metadata.addItemFavourite('item-b');

      final firstPath = await _writeCatalogFile(
        tempDir,
        {
          ..._minimalCatalogJson(id: 'FAV-1'),
          'total_items': 2,
          'folders': [
            const MediaFolder(
              id: 'lib',
              name: 'Videos',
              path: r'Y:\Videos',
              itemCount: 2,
              items: [
                MediaItem(
                  id: 'item-a',
                  title: 'A',
                  filePath: r'Y:\Videos\a.mp4',
                ),
                MediaItem(
                  id: 'item-b',
                  title: 'B',
                  filePath: r'Y:\Videos\b.mp4',
                ),
              ],
              subfolders: [],
            ).toJson(),
          ],
        },
      );

      await wired.catalogService.loadFromFile(firstPath);
      await Future<void>.delayed(Duration.zero);
      expect(wired.metadata.isItemFavourited('item-b'), isTrue);

      final fav2Dir = Directory('${tempDir.path}/fav2');
      await fav2Dir.create();
      final secondPath = await _writeCatalogFile(
        fav2Dir,
        {
          ..._minimalCatalogJson(id: 'FAV-2'),
          'total_items': 1,
          'folders': [
            const MediaFolder(
              id: 'lib',
              name: 'Videos',
              path: r'Y:\Videos',
              itemCount: 1,
              items: [
                MediaItem(
                  id: 'item-a',
                  title: 'A',
                  filePath: r'Y:\Videos\a.mp4',
                ),
              ],
              subfolders: [],
            ).toJson(),
          ],
        },
      );

      await wired.catalogService.loadFromFile(secondPath);
      await Future<void>.delayed(Duration.zero);

      expect(wired.metadata.isItemFavourited('item-a'), isTrue);
      expect(wired.metadata.isItemFavourited('item-b'), isFalse);
    });
  });
}
