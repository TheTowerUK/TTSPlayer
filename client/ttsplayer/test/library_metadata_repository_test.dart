import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/library_metadata.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const itemA = 'item-a';
  const itemB = 'item-b';
  const folderA = 'folder-a';
  const folderB = 'folder-b';
  const sharedId = 'shared-id';

  MediaItem testItem({
    String id = itemA,
    String title = 'Alpha',
    String path = r'Y:\Media\alpha.mp4',
  }) {
    return MediaItem(
      id: id,
      title: title,
      filePath: path,
    );
  }

  MediaFolder testFolder({
    String id = folderA,
    String name = 'Movies',
    String path = r'Y:\Media\Movies',
    List<MediaItem> items = const [],
    List<MediaFolder> subfolders = const [],
  }) {
    return MediaFolder(
      id: id,
      name: name,
      path: path,
      itemCount: items.length,
      items: items,
      subfolders: subfolders,
    );
  }

  Catalog testCatalog({
    List<MediaFolder> folders = const [],
    String identity = 'CAT-TEST',
  }) {
    return Catalog(
      catalogueInfo: CatalogueInfo(
        id: identity,
        scannerVersion: '0.3.3',
        catalogueVersion: 2,
      ),
      generatedAt: '2026-07-13T10:00:00+00:00',
      sources: const [],
      totalItems: folders.fold<int>(
        0,
        (sum, f) => sum + f.totalItems,
      ),
      folders: folders,
    );
  }

  Catalog defaultCatalog() {
    return testCatalog(
      folders: [
        testFolder(
          id: folderA,
          items: [testItem(id: itemA), testItem(id: itemB, title: 'Beta')],
          subfolders: [
            testFolder(
              id: folderB,
              name: 'Nested',
              path: r'Y:\Media\Movies\Nested',
              items: [testItem(id: 'item-nested', title: 'Nested Item')],
            ),
          ],
        ),
      ],
    );
  }

  group('LibraryMetadata model', () {
    test('defaults are empty favourites', () {
      final metadata = LibraryMetadata.defaults();
      expect(metadata.metadataVersion, LibraryMetadata.currentMetadataVersion);
      expect(metadata.favourites.items, isEmpty);
      expect(metadata.favourites.folders, isEmpty);
    });

    test('dedupes duplicate favourite records on load', () {
      final warnings = <String>[];
      final metadata = LibraryMetadata.fromJsonWithRecovery(
        {
          'metadataVersion': 1,
          'favourites': {
            'items': [
              {
                'id': itemA,
                'favouritedAt': '2026-07-01T10:00:00+00:00',
              },
              {
                'id': itemA,
                'favouritedAt': '2026-07-02T10:00:00+00:00',
              },
            ],
            'folders': [],
          },
        },
        warnings: warnings,
      );

      expect(metadata.favourites.items, hasLength(1));
      expect(
        metadata.favourites.items.single.favouritedAt,
        DateTime.parse('2026-07-02T10:00:00+00:00').toUtc(),
      );
    });
  });

  group('LibraryMetadataRepository', () {
    test('1 fresh repository loads empty metadata', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      final result = await repository.initialize();

      expect(result.source, LibraryMetadataLoadSource.defaults);
      expect(repository.favouriteItems, isEmpty);
      expect(repository.favouriteFolders, isEmpty);
      expect(repository.isLoaded, isTrue);
    });

    test('2 valid metadata survives reload', () async {
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: jsonEncode({
          'metadataVersion': 1,
          'favourites': {
            'items': [
              {
                'id': itemA,
                'favouritedAt': '2026-07-13T09:00:00+00:00',
              },
            ],
            'folders': [
              {
                'id': folderA,
                'favouritedAt': '2026-07-13T08:00:00+00:00',
              },
            ],
          },
        }),
      });

      final repository = LibraryMetadataRepository();
      await repository.initialize();

      final reloaded = LibraryMetadataRepository();
      final result = await reloaded.load();

      expect(result.source, LibraryMetadataLoadSource.envelope);
      expect(reloaded.isItemFavourited(itemA), isTrue);
      expect(reloaded.isFolderFavourited(folderA), isTrue);
    });

    test('3 folder favourite add remove toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();

      expect(await repository.addFolderFavourite(folderA), isTrue);
      expect(repository.isFolderFavourited(folderA), isTrue);

      expect(await repository.toggleFolderFavourite(folderA), isFalse);
      expect(repository.isFolderFavourited(folderA), isFalse);

      expect(await repository.toggleFolderFavourite(folderA), isTrue);
      expect(await repository.removeFolderFavourite(folderA), isTrue);
      expect(repository.isFolderFavourited(folderA), isFalse);
    });

    test('4 item favourite add remove toggle', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();

      expect(await repository.addItemFavourite(itemA), isTrue);
      expect(repository.isItemFavourited(itemA), isTrue);

      expect(await repository.toggleItemFavourite(itemA), isFalse);
      expect(repository.isItemFavourited(itemA), isFalse);

      expect(await repository.toggleItemFavourite(itemA), isTrue);
      expect(await repository.removeItemFavourite(itemA), isTrue);
      expect(repository.isItemFavourited(itemA), isFalse);
    });

    test('5 duplicate additions are idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();

      expect(await repository.addItemFavourite(itemA), isTrue);
      expect(await repository.addItemFavourite(itemA), isTrue);
      expect(repository.favouriteItems, hasLength(1));
    });

    test('6 folder and item identities remain distinct', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();

      await repository.addItemFavourite(sharedId);
      await repository.addFolderFavourite(sharedId);

      expect(repository.isItemFavourited(sharedId), isTrue);
      expect(repository.isFolderFavourited(sharedId), isTrue);
      expect(repository.favouriteItems.single.id, sharedId);
      expect(repository.favouriteFolders.single.id, sharedId);
    });

    test('7 corrupt JSON recovers safely', () async {
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: '{not-json',
      });

      final repository = LibraryMetadataRepository();
      final result = await repository.initialize();

      expect(result.source, LibraryMetadataLoadSource.defaults);
      expect(result.recoveryWarnings, isNotEmpty);
      expect(repository.favouriteItems, isEmpty);
    });

    test('8 partially malformed records preserve valid entries', () async {
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: jsonEncode({
          'metadataVersion': 1,
          'favourites': {
            'items': [
              {
                'id': itemA,
                'favouritedAt': '2026-07-13T09:00:00+00:00',
              },
              {'id': '', 'favouritedAt': 'bad'},
              {'id': 'item-bad', 'favouritedAt': 'not-a-date'},
            ],
            'folders': 'invalid-list',
          },
        }),
      });

      final repository = LibraryMetadataRepository();
      final result = await repository.load();

      expect(result.recoveryWarnings, isNotEmpty);
      expect(repository.isItemFavourited(itemA), isTrue);
      expect(repository.favouriteFolders, isEmpty);
    });

    test('9 unsupported version recovers with warnings', () async {
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: jsonEncode({
          'metadataVersion': 99,
          'favourites': {
            'items': [
              {
                'id': itemA,
                'favouritedAt': '2026-07-13T09:00:00+00:00',
              },
            ],
            'folders': [],
          },
        }),
      });

      final repository = LibraryMetadataRepository();
      final result = await repository.load();

      expect(result.recoveryWarnings, isNotEmpty);
      expect(repository.isItemFavourited(itemA), isTrue);
      expect(
        repository.metadata.metadataVersion,
        LibraryMetadata.currentMetadataVersion,
      );
    });

    test('10 failed save leaves prior persisted data intact', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite(itemA);

      repository.simulatePersistFailure = true;
      final added = await repository.addItemFavourite(itemB);
      expect(added, isFalse);
      expect(repository.isItemFavourited(itemB), isFalse);

      repository.simulatePersistFailure = false;
      final restarted = LibraryMetadataRepository();
      await restarted.load();
      expect(restarted.isItemFavourited(itemA), isTrue);
      expect(restarted.isItemFavourited(itemB), isFalse);
    });

    test('11 initialize is idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      var notifications = 0;
      repository.addListener(() => notifications++);

      await repository.initialize();
      await repository.addItemFavourite(itemA);
      final countAfterFirstInit = notifications;

      final second = await repository.initialize();
      expect(second.source, LibraryMetadataLoadSource.defaults);
      expect(notifications, countAfterFirstInit);
    });

    test('12 explicit load re-reads storage', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LibraryMetadataRepository.storageKey,
        jsonEncode({
          'metadataVersion': 1,
          'favourites': {
            'items': [
              {
                'id': itemB,
                'favouritedAt': '2026-07-13T10:00:00+00:00',
              },
            ],
            'folders': [],
          },
        }),
      );

      await repository.load();
      expect(repository.isItemFavourited(itemB), isTrue);
      expect(repository.isItemFavourited(itemA), isFalse);
    });
  });

  group('LibraryMetadataRepository catalogue validation', () {
    late Catalog catalog;

    setUp(() {
      catalog = defaultCatalog();
    });

    Future<LibraryMetadataRepository> seededRepository() async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite(itemA);
      await repository.addItemFavourite(itemB);
      await repository.addFolderFavourite(folderA);
      await repository.addFolderFavourite(folderB);
      return repository;
    }

    test('13 validation preserves favourites when ids still exist', () async {
      final repository = await seededRepository();

      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.changed, isFalse);
      expect(repository.isItemFavourited(itemA), isTrue);
      expect(repository.isItemFavourited(itemB), isTrue);
      expect(repository.isFolderFavourited(folderA), isTrue);
      expect(repository.isFolderFavourited(folderB), isTrue);
    });

    test('14 validation removes stale folder favourites', () async {
      final repository = await seededRepository();
      final slimCatalog = testCatalog(
        folders: [
          testFolder(
            id: folderA,
            items: [testItem(id: itemA)],
          ),
        ],
      );

      final result = await repository.validateAgainstCatalog(slimCatalog);

      expect(result.changed, isTrue);
      expect(result.prunedFolderCount, 1);
      expect(repository.isFolderFavourited(folderB), isFalse);
      expect(repository.isFolderFavourited(folderA), isTrue);
    });

    test('15 validation removes stale item favourites', () async {
      final repository = await seededRepository();
      final slimCatalog = testCatalog(
        folders: [
          testFolder(
            id: folderA,
            items: [testItem(id: itemA)],
          ),
        ],
      );

      final result = await repository.validateAgainstCatalog(slimCatalog);

      expect(result.changed, isTrue);
      expect(result.prunedItemCount, 1);
      expect(repository.isItemFavourited(itemB), isFalse);
      expect(repository.isItemFavourited(itemA), isTrue);
    });

    test('16 validation removes multiple stale entries with one notification',
        () async {
      final repository = await seededRepository();
      var notifications = 0;
      repository.addListener(() => notifications++);

      final emptyCatalog = testCatalog(folders: const []);
      final result = await repository.validateAgainstCatalog(emptyCatalog);

      expect(result.changed, isTrue);
      expect(result.prunedItemCount, 2);
      expect(result.prunedFolderCount, 2);
      expect(notifications, 1);
    });

    test('17 validation with no changes does not write or notify', () async {
      final repository = await seededRepository();
      var notifications = 0;
      repository.addListener(() => notifications++);

      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(LibraryMetadataRepository.storageKey);

      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.changed, isFalse);
      expect(notifications, 0);
      expect(prefs.getString(LibraryMetadataRepository.storageKey), before);
    });

    test('validation persistence failure preserves in-memory favourites',
        () async {
      final repository = await seededRepository();
      repository.simulatePersistFailure = true;

      final slimCatalog = testCatalog(
        folders: [
          testFolder(
            id: folderA,
            items: [testItem(id: itemA)],
          ),
        ],
      );

      final result = await repository.validateAgainstCatalog(slimCatalog);

      expect(result.changed, isFalse);
      expect(result.persistenceFailed, isTrue);
      expect(result.warning, isNotNull);
      expect(repository.isItemFavourited(itemB), isTrue);
      expect(repository.isFolderFavourited(folderB), isTrue);
    });

    test('20 catalogue objects remain unchanged after validation', () async {
      final repository = await seededRepository();
      final itemIdsBefore = catalog.allItems.map((i) => i.id).toList();
      final folderIdsBefore = catalog.folders.map((f) => f.id).toList();

      await repository.validateAgainstCatalog(
        testCatalog(
          folders: [
            testFolder(id: folderA, items: [testItem(id: itemA)]),
          ],
        ),
      );

      expect(catalog.allItems.map((i) => i.id).toList(), itemIdsBefore);
      expect(catalog.folders.map((f) => f.id).toList(), folderIdsBefore);
    });
  });

  group('CatalogService integration', () {
    test('18 failed catalogue replacement does not invoke validation', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite(itemA);

      var validationCalls = 0;
      final catalogPath = await _writeTempCatalog(
        identity: 'GOOD',
        itemIds: [itemA],
      );

      final service = CatalogService(
        onCatalogReplaced: (_) => validationCalls++,
      )..includeLegacyCataloguePaths = false;

      await service.loadFromFile(catalogPath);
      expect(validationCalls, 1);

      final missingPath = r'Z:\TTSPlayerMissingCatalog\catalog.json';
      await service.loadFromFile(missingPath);
      expect(validationCalls, 1);
      expect(repository.isItemFavourited(itemA), isTrue);
    });

    test('19 successful catalogue replacement invokes validation once', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LibraryMetadataRepository();
      await repository.initialize();
      await repository.addItemFavourite(itemA);
      await repository.addItemFavourite(itemB);

      final firstPath = await _writeTempCatalog(
        identity: 'FIRST',
        itemIds: [itemA, itemB],
      );
      final secondPath = await _writeTempCatalog(
        identity: 'SECOND',
        itemIds: [itemA],
      );

      final service = CatalogService(
        onCatalogReplaced: (catalog) {
          unawaited(repository.validateAgainstCatalog(catalog));
        },
      )..includeLegacyCataloguePaths = false;

      await service.loadFromFile(firstPath);
      await Future<void>.delayed(Duration.zero);
      expect(repository.isItemFavourited(itemB), isTrue);

      await service.loadFromFile(secondPath);
      await Future<void>.delayed(Duration.zero);
      expect(repository.isItemFavourited(itemB), isFalse);
      expect(repository.isItemFavourited(itemA), isTrue);
    });
  });
}

Future<String> _writeTempCatalog({
  required String identity,
  required List<String> itemIds,
}) async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_libmeta_');
  final file = File('${dir.path}/catalog.json');
  final items = itemIds
      .map(
        (id) => {
          'id': id,
          'title': id,
          'file_path': '${dir.path}\\$id.mp4',
          'status': 'available',
        },
      )
      .toList();

  await file.writeAsString(
    jsonEncode({
      'catalogue': {
        'id': identity,
        'scanner_version': '0.3.3',
        'catalogue_version': 2,
      },
      'generated_at': '2026-07-13T10:00:00+00:00',
      'sources': [],
      'total_items': items.length,
      'folders': [
        {
          'id': 'root-folder',
          'name': 'Root',
          'path': dir.path,
          'item_count': items.length,
          'items': items,
          'subfolders': [],
        },
      ],
    }),
  );
  return file.path;
}
