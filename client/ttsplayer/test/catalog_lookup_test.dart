import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_source_kind.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/catalog_service.dart';

MediaFolder _folder({
  required String id,
  required String path,
  required String name,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
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

MediaFolder _folderFromPath({
  required String path,
  required String name,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  return _folder(
    id: path,
    path: path,
    name: name,
    subfolders: subfolders,
    items: items,
  );
}

MediaItem _item({
  required String id,
  required String title,
  String? filePath,
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath ?? r'Y:\Media\Videos\$title.mp4',
  );
}

Catalog _deepCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-01T10:00:00+00:00',
    'total_items': 3,
    'sources': [
      {
        'name': 'NAS Media',
        'root_path': r'Y:\Media',
        'type': 'smb',
        'accessible': true,
      },
    ],
    'folders': [
      _folder(
        id: 'folder-films',
        path: r'Y:\Media\Films',
        name: 'Films',
        subfolders: [
          _folder(
            id: 'folder-scifi',
            path: r'Y:\Media\Films\Science Fiction',
            name: 'Science Fiction',
            items: [
              _item(
                id: 'item-nested',
                title: 'Arrival',
                filePath: r'Y:\Media\Films\Science Fiction\Arrival.mp4',
              ),
            ],
          ),
        ],
        items: [
          _item(
            id: 'item-root',
            title: 'Local Hero',
            filePath: r'Y:\Media\Films\Local Hero.mp4',
          ),
        ],
      ).toJson(),
      _folder(
        id: 'folder-archives',
        path: r'Y:\Media\Archives',
        name: 'Archives',
      ).toJson(),
    ],
  });
}

String _snapshotCatalog(Catalog catalog) => jsonEncode({
      'folders': catalog.folders.map((f) => f.toJson()).toList(),
      'total_items': catalog.totalItems,
    });

void main() {
  test('findFolderByPath locates nested folders with path normalization', () {
    final catalog = Catalog.fromJson({
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 0,
      'folders': [
        _folderFromPath(
          path: r'Y:\Media\Videos',
          name: 'Videos',
          subfolders: [
            _folderFromPath(path: r'Y:\Media\Videos\Action', name: 'Action'),
          ],
        ).toJson(),
      ],
    });

    expect(
      catalog.findFolderByPath(r'y:/media/videos/action')?.name,
      'Action',
    );
    expect(catalog.findFolderByPath(r'Y:\Media\Missing'), isNull);
  });

  test('libraryFolders returns only direct children of media roots', () {
    final catalog = Catalog.fromJson({
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 0,
      'sources': [
        {
          'name': 'NAS Media',
          'root_path': r'Y:\Media',
          'type': 'smb',
          'accessible': true,
        },
      ],
      'folders': [
        _folderFromPath(path: r'Y:\Media\Archives', name: 'Archives').toJson(),
        _folderFromPath(path: r'Y:\Media\Videos', name: 'Videos').toJson(),
        _folderFromPath(
          path: r'Y:\Media\Videos\Action',
          name: 'Action',
        ).toJson(),
      ],
    });

    final names = catalog.libraryFolders.map((f) => f.name).toList();
    expect(names, containsAll(['Archives', 'Videos']));
    expect(names, isNot(contains('Action')));
  });

  test('allItems collects nested media items', () {
    final catalog = Catalog.fromJson({
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 2,
      'folders': [
        _folderFromPath(
          path: r'Y:\Media\Videos',
          name: 'Videos',
          items: [_item(id: 'a', title: 'Alpha')],
          subfolders: [
            _folderFromPath(
              path: r'Y:\Media\Videos\Action',
              name: 'Action',
              items: [_item(id: 'b', title: 'Beta')],
            ),
          ],
        ).toJson(),
      ],
    });

    expect(catalog.allItems.length, 2);
    expect(catalog.findItemById('b')?.title, 'Beta');
  });

  test('classifyCataloguePath distinguishes live, fallback, and demo', () {
    expect(
      CatalogService.classifyCataloguePath(
        catalogPath: r'Y:\Media\catalog.json',
        isDemoFallback: false,
      ),
      CatalogueSourceKind.liveNas,
    );
    expect(
      CatalogService.classifyCataloguePath(
        catalogPath: r'\\MEDIATNAS-B725\Media\catalog.json',
        isDemoFallback: false,
      ),
      CatalogueSourceKind.fallbackNas,
    );
    expect(
      CatalogService.classifyCataloguePath(
        catalogPath: 'bundled',
        isDemoFallback: true,
      ),
      CatalogueSourceKind.demo,
    );
  });

  group('Catalog hierarchy lookup helpers (M4.3 Step 2)', () {
    late Catalog catalog;

    setUp(() {
      catalog = _deepCatalog();
    });

    test('1 find root-level folder by id', () {
      expect(catalog.findFolderById('folder-films')?.name, 'Films');
      expect(catalog.findFolderById('folder-archives')?.name, 'Archives');
    });

    test('2 find deeply nested folder by id', () {
      expect(
        catalog.findFolderById('folder-scifi')?.name,
        'Science Fiction',
      );
    });

    test('3 unknown folder returns null', () {
      expect(catalog.findFolderById('missing-folder'), isNull);
      expect(catalog.findFolderById(''), isNull);
    });

    test('4 find root-level item by id', () {
      expect(catalog.findItemById('item-root')?.title, 'Local Hero');
    });

    test('5 find deeply nested item by id', () {
      expect(catalog.findItemById('item-nested')?.title, 'Arrival');
    });

    test('6 unknown item returns null', () {
      expect(catalog.findItemById('missing-item'), isNull);
      expect(catalog.findItemById(''), isNull);
    });

    test('7 ancestor chain for root folder is single segment', () {
      final chain = catalog.ancestorChainForFolder('folder-archives');
      expect(chain.length, 1);
      expect(chain.single.name, 'Archives');
    });

    test('8 ancestor chain for nested folder is root to target', () {
      final chain = catalog.ancestorChainForFolder('folder-scifi');
      expect(chain.map((f) => f.name).toList(), [
        'Films',
        'Science Fiction',
      ]);
    });

    test('9 ancestor chain includes target exactly once', () {
      final chain = catalog.ancestorChainForFolder('folder-scifi');
      expect(chain.where((f) => f.id == 'folder-scifi').length, 1);
      expect(chain.last.id, 'folder-scifi');
    });

    test('10 unknown folder ancestor chain is empty', () {
      expect(catalog.ancestorChainForFolder('missing-folder'), isEmpty);
      expect(catalog.ancestorChainForFolder(''), isEmpty);
    });

    test('11 similar names do not affect id-based lookup', () {
      final withSimilarNames = Catalog.fromJson({
        'generated_at': '2026-07-01T10:00:00+00:00',
        'total_items': 0,
        'folders': [
          _folder(
            id: 'alpha-id',
            path: r'Y:\Media\Alpha',
            name: 'Science Fiction',
          ).toJson(),
          _folder(
            id: 'beta-id',
            path: r'Y:\Media\Beta',
            name: 'Science Fiction',
          ).toJson(),
        ],
      });

      expect(withSimilarNames.findFolderById('beta-id')?.path, r'Y:\Media\Beta');
    });

    test('12 folder and item ids remain separate identity spaces', () {
      final sharedId = 'shared-identity';
      final mixed = Catalog.fromJson({
        'generated_at': '2026-07-01T10:00:00+00:00',
        'total_items': 1,
        'folders': [
          _folder(
            id: sharedId,
            path: r'Y:\Media\SharedFolder',
            name: 'Shared Folder',
            items: [
              _item(
                id: sharedId,
                title: 'Shared Item',
                filePath: r'Y:\Media\SharedFolder\clip.mp4',
              ),
            ],
          ).toJson(),
        ],
      });

      expect(mixed.findFolderById(sharedId)?.name, 'Shared Folder');
      expect(mixed.findItemById(sharedId)?.title, 'Shared Item');
      expect(mixed.parentFolderOfItemId(sharedId)?.id, sharedId);
    });

    test('13 catalogue lists and objects unchanged after lookups', () {
      final before = _snapshotCatalog(catalog);

      catalog.findFolderById('folder-scifi');
      catalog.findItemById('item-nested');
      catalog.ancestorChainForFolder('folder-scifi');
      catalog.parentFolderOfItemId('item-nested');

      expect(_snapshotCatalog(catalog), before);
    });

    test('14 file_path style does not affect hierarchy lookups', () {
      final httpStyle = Catalog.fromJson({
        'generated_at': '2026-07-01T10:00:00+00:00',
        'total_items': 1,
        'folders': [
          _folder(
            id: 'http-root',
            path: '/volume1/media/Films',
            name: 'Films',
            subfolders: [
              _folder(
                id: 'http-nested',
                path: '/volume1/media/Films/SciFi',
                name: 'SciFi',
                items: [
                  _item(
                    id: 'http-item',
                    title: 'HTTP Item',
                    filePath: 'https://nas.example/media/Films/SciFi/item.mp4',
                  ),
                ],
              ),
            ],
          ).toJson(),
        ],
      });

      expect(httpStyle.findItemById('http-item')?.title, 'HTTP Item');
      expect(httpStyle.parentFolderOfItemId('http-item')?.id, 'http-nested');
      expect(
        httpStyle.ancestorChainForFolder('http-nested').map((f) => f.id).toList(),
        ['http-root', 'http-nested'],
      );
    });

    test('15 deep hierarchy works without path parsing', () {
      MediaFolder nested = _folder(
        id: 'level-5',
        path: r'Y:\Media\L1\L2\L3\L4\L5',
        name: 'Level 5',
      );
      for (var level = 4; level >= 1; level--) {
        final segments = List.generate(level, (_) => 'L').join(r'\');
        nested = _folder(
          id: 'level-$level',
          path: 'Y:\\Media\\$segments',
          name: 'Level $level',
          subfolders: [nested],
        );
      }

      final deep = Catalog.fromJson({
        'generated_at': '2026-07-01T10:00:00+00:00',
        'total_items': 0,
        'folders': [nested.toJson()],
      });

      final chain = deep.ancestorChainForFolder('level-5');
      expect(chain.length, 5);
      expect(chain.first.id, 'level-1');
      expect(chain.last.id, 'level-5');
    });

    test('16 containing-folder lookup by item id', () {
      expect(catalog.parentFolderOfItemId('item-root')?.id, 'folder-films');
      expect(catalog.parentFolderOfItemId('item-nested')?.id, 'folder-scifi');
      expect(catalog.parentFolderOfItemId('missing-item'), isNull);
    });

    test('17 duplicate ids return first dfs match', () {
      final duplicate = Catalog.fromJson({
        'generated_at': '2026-07-01T10:00:00+00:00',
        'total_items': 2,
        'folders': [
          _folder(
            id: 'dup-folder',
            path: r'Y:\Media\First',
            name: 'First Branch',
            items: [
              _item(
                id: 'dup-item',
                title: 'First Item',
                filePath: r'Y:\Media\First\a.mp4',
              ),
            ],
          ).toJson(),
          _folder(
            id: 'other-root',
            path: r'Y:\Media\SecondRoot',
            name: 'Second Root',
            subfolders: [
              _folder(
                id: 'dup-folder',
                path: r'Y:\Media\SecondRoot\Nested',
                name: 'Second Branch',
                items: [
                  _item(
                    id: 'dup-item',
                    title: 'Second Item',
                    filePath: r'Y:\Media\SecondRoot\Nested\b.mp4',
                  ),
                ],
              ),
            ],
          ).toJson(),
        ],
      });

      expect(duplicate.findFolderById('dup-folder')?.name, 'First Branch');
      expect(duplicate.findItemById('dup-item')?.title, 'First Item');
      expect(duplicate.parentFolderOfItemId('dup-item')?.name, 'First Branch');
      expect(
        duplicate.ancestorChainForFolder('dup-folder').map((f) => f.name).toList(),
        ['First Branch'],
      );
    });
  });
}
