import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_source_kind.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/catalog_service.dart';

MediaFolder _folder({
  required String path,
  required String name,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  return MediaFolder(
    id: path,
    name: name,
    path: path,
    itemCount: items.length,
    items: items,
    subfolders: subfolders,
  );
}

MediaItem _item({required String id, required String title}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Videos\$title.mp4',
  );
}

void main() {
  test('findFolderByPath locates nested folders with path normalization', () {
    final catalog = Catalog.fromJson({
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 0,
      'folders': [
        _folder(
          path: r'Y:\Media\Videos',
          name: 'Videos',
          subfolders: [
            _folder(path: r'Y:\Media\Videos\Action', name: 'Action'),
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
        _folder(path: r'Y:\Media\Archives', name: 'Archives').toJson(),
        _folder(path: r'Y:\Media\Videos', name: 'Videos').toJson(),
        _folder(
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
        _folder(
          path: r'Y:\Media\Videos',
          name: 'Videos',
          items: [_item(id: 'a', title: 'Alpha')],
          subfolders: [
            _folder(
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
}
