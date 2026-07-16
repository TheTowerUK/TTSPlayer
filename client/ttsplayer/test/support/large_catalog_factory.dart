import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';

/// Generates large in-memory catalogues for lazy-browse and cache tests.
///
/// Not shipped as app assets — constructed in test or opt-in runtime harness.
Catalog buildLargeCatalog({
  int itemCount = 2000,
  int subfolderCount = 0,
  int subfolderItemCount = 0,
  String catalogueIdentity = 'large-test-catalogue',
  String libraryName = 'Large Library',
  String folderId = 'large-folder',
  String folderPath = r'Y:\Media\Large',
}) {
  assert(itemCount >= 0);
  assert(subfolderCount >= 0);

  final subfolders = <MediaFolder>[
    for (var s = 0; s < subfolderCount; s++)
      MediaFolder(
        id: 'subfolder-$s',
        name: 'Subfolder $s',
        path: '$folderPath\\Sub$s',
        itemCount: subfolderItemCount,
        items: [
          for (var i = 0; i < subfolderItemCount; i++)
            MediaItem(
              id: 'sub$s-item-$i',
              title: 'Sub $s Item $i',
              filePath: '$folderPath\\Sub$s\\item-$i.mp4',
            ),
        ],
        subfolders: const [],
      ),
  ];

  final items = <MediaItem>[
    for (var i = 0; i < itemCount; i++)
      MediaItem(
        id: 'item-$i',
        title: 'Title ${i.toString().padLeft(5, '0')}',
        filePath: '$folderPath\\item-$i.mp4',
        thumbnailPath: i.isEven ? '$folderPath\\item-$i.jpg' : null,
      ),
  ];

  final folder = MediaFolder(
    id: folderId,
    name: libraryName,
    path: folderPath,
    itemCount: items.length,
    items: items,
    subfolders: subfolders,
  );

  return Catalog.fromJson({
    'generated_at': '2026-07-16T10:00:00+00:00',
    'total_items': itemCount + (subfolderCount * subfolderItemCount),
    'catalogue': {
      'id': catalogueIdentity,
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
      'supported_extensions': ['mp4', 'mkv'],
    },
    'folders': [folder.toJson()],
  });
}

/// Returns the primary large-folder node from [buildLargeCatalog].
MediaFolder largeCatalogFolder(Catalog catalog, {String folderId = 'large-folder'}) {
  final folder = catalog.findFolderById(folderId);
  if (folder == null) {
    throw StateError('Large catalog fixture missing folder $folderId');
  }
  return folder;
}
