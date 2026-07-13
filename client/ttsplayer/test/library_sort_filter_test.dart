import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/constants/supported_extensions.dart';
import 'package:ttsplayer/library/library_folder_view.dart';
import 'package:ttsplayer/models/library_filter.dart';
import 'package:ttsplayer/models/library_sort_mode.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';

MediaFolder _folder({
  required String id,
  required String name,
  String? path,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  return MediaFolder(
    id: id,
    name: name,
    path: path ?? r'Y:\Media\$name',
    itemCount: items.length,
    items: items,
    subfolders: subfolders,
  );
}

MediaItem _item({
  required String id,
  required String title,
  String? filePath,
  DateTime? addedAt,
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath ?? r'Y:\Media\$title.mp4',
    addedAt: addedAt,
  );
}

String _snapshotFolder(MediaFolder folder) => jsonEncode({
      'subfolders': folder.subfolders.map((f) => f.toJson()).toList(),
      'items': folder.items.map((i) => i.toJson()).toList(),
    });

void main() {
  group('buildLibraryFolderView', () {
    late MediaFolder sourceFolder;

    setUp(() {
      sourceFolder = _folder(
        id: 'parent',
        name: 'Parent',
        subfolders: [
          _folder(id: 'sub-b', name: 'Bravo'),
          _folder(id: 'sub-a', name: 'alpha'),
        ],
        items: [
          _item(
            id: 'item-b',
            title: 'Beta',
            filePath: r'Y:\Media\Beta.MP4',
            addedAt: DateTime.utc(2026, 7, 10),
          ),
          _item(
            id: 'item-a',
            title: 'alpha',
            filePath: r'Y:\Media\alpha.jpg',
            addedAt: DateTime.utc(2026, 7, 12),
          ),
          _item(
            id: 'item-c',
            title: 'No Date',
            filePath: r'Y:\Media\nodate.mkv',
          ),
        ],
      );
    });

    test('1 default order preserves emitted order within groups', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.all,
      );

      expect(view.subfolders.map((f) => f.id).toList(), ['sub-b', 'sub-a']);
      expect(view.items.map((i) => i.id).toList(), ['item-b', 'item-a', 'item-c']);
    });

    test('2 folder-first is enforced for every sort mode', () {
      for (final mode in LibrarySortMode.values) {
        final view = buildLibraryFolderView(
          folder: sourceFolder,
          sortMode: mode,
          filter: LibraryFilter.all,
        );
        expect(view.subfolders, isNotEmpty);
        expect(view.items, isNotEmpty);
      }
    });

    test('3 name ascending is case-insensitive and deterministic', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.nameAsc,
        filter: LibraryFilter.all,
      );

      expect(view.subfolders.map((f) => f.name).toList(), ['alpha', 'Bravo']);
      expect(view.items.map((i) => i.title).toList(), [
        'alpha',
        'Beta',
        'No Date',
      ]);
    });

    test('4 name descending is deterministic', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.nameDesc,
        filter: LibraryFilter.all,
      );

      expect(view.subfolders.map((f) => f.name).toList(), ['Bravo', 'alpha']);
      expect(view.items.first.title, 'No Date');
      expect(view.items.last.title, 'alpha');
    });

    test('5 duplicate names use stable id tie-breaking', () {
      final folder = _folder(
        id: 'parent',
        name: 'Parent',
        items: [
          _item(id: 'z-id', title: 'Same', filePath: r'Y:\a.mp4'),
          _item(id: 'a-id', title: 'same', filePath: r'Y:\b.mp4'),
        ],
      );

      final view = buildLibraryFolderView(
        folder: folder,
        sortMode: LibrarySortMode.nameAsc,
        filter: LibraryFilter.all,
      );

      expect(view.items.map((i) => i.id).toList(), ['a-id', 'z-id']);
    });

    test('6 recently added orders valid timestamps correctly', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.addedNewest,
        filter: LibraryFilter.all,
      );

      expect(view.items.map((i) => i.id).toList(), [
        'item-a',
        'item-b',
        'item-c',
      ]);
    });

    test('7 recently added handles missing timestamps last', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.addedNewest,
        filter: LibraryFilter.all,
      );

      expect(view.items.last.id, 'item-c');
    });

    test('8 oldest added orders dated items ascending', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.addedOldest,
        filter: LibraryFilter.all,
      );

      expect(view.items.take(2).map((i) => i.id).toList(), [
        'item-b',
        'item-a',
      ]);
    });

    test('9 oldest added handles missing timestamps last', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.addedOldest,
        filter: LibraryFilter.all,
      );

      expect(view.items.last.id, 'item-c');
    });

    test('10 type sorting is deterministic', () {
      final folder = _folder(
        id: 'parent',
        name: 'Parent',
        items: [
          _item(id: 'img', title: 'Poster', filePath: r'Y:\a.png'),
          _item(id: 'vid', title: 'Clip', filePath: r'Y:\b.mp4'),
          _item(id: 'oth', title: 'Archive', filePath: r'Y:\c.xyz'),
        ],
      );

      final view = buildLibraryFolderView(
        folder: folder,
        sortMode: LibrarySortMode.type,
        filter: LibraryFilter.all,
      );

      expect(view.items.map((i) => i.id).toList(), ['vid', 'img', 'oth']);
    });

    test('11 all filter shows all direct children', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.all,
      );

      expect(view.subfolders.length, 2);
      expect(view.items.length, 3);
    });

    test('12 folders-only filter hides all media items', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.foldersOnly,
      );

      expect(view.subfolders.length, 2);
      expect(view.items, isEmpty);
    });

    test('13 video filter shows video items and retains subfolders', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.video,
      );

      expect(view.subfolders.length, 2);
      expect(view.items.map((i) => i.id).toList(), ['item-b', 'item-c']);
    });

    test('14 image filter shows image items and retains subfolders', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.images,
      );

      expect(view.subfolders.length, 2);
      expect(view.items.map((i) => i.id).toList(), ['item-a']);
    });

    test('15 unknown extensions appear under other in type sort', () {
      final folder = _folder(
        id: 'parent',
        name: 'Parent',
        items: [
          _item(id: 'oth', title: 'Zed', filePath: r'Y:\z.unknown'),
          _item(id: 'vid', title: 'Clip', filePath: r'Y:\a.mp4'),
        ],
      );

      final view = buildLibraryFolderView(
        folder: folder,
        sortMode: LibrarySortMode.type,
        filter: LibraryFilter.all,
      );

      expect(view.items.map((i) => i.id).toList(), ['vid', 'oth']);
    });

    test('16 filter empty result is an empty derived view without error', () {
      final folder = _folder(
        id: 'parent',
        name: 'Parent',
        subfolders: [_folder(id: 'sub', name: 'Child')],
        items: [
          _item(id: 'img', title: 'Still', filePath: r'Y:\a.jpg'),
        ],
      );

      final view = buildLibraryFolderView(
        folder: folder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.video,
      );

      expect(view.subfolders.length, 1);
      expect(view.items, isEmpty);
      expect(view.isEmpty, isFalse);
    });

    test('17 sort and filter compose correctly', () {
      final view = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.nameAsc,
        filter: LibraryFilter.video,
      );

      expect(view.subfolders.map((f) => f.id).toList(), ['sub-a', 'sub-b']);
      expect(view.items.map((i) => i.id).toList(), ['item-b', 'item-c']);
    });

    test('18 changing sort does not alter filter state', () {
      const filter = LibraryFilter.video;

      final byDefault = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: filter,
      );
      final byName = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.nameAsc,
        filter: filter,
      );

      expect(byDefault.items.map((i) => i.id).toSet(),
          byName.items.map((i) => i.id).toSet());
      expect(byName.items.map((i) => i.id).toList(), ['item-b', 'item-c']);
    });

    test('19 changing filter does not alter sort state', () {
      const sortMode = LibrarySortMode.nameAsc;

      final all = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: sortMode,
        filter: LibraryFilter.all,
      );
      final video = buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: sortMode,
        filter: LibraryFilter.video,
      );

      expect(all.subfolders.map((f) => f.id).toList(),
          video.subfolders.map((f) => f.id).toList());
    });

    test('20 source folder lists remain structurally unchanged', () {
      final before = _snapshotFolder(sourceFolder);

      buildLibraryFolderView(
        folder: sourceFolder,
        sortMode: LibrarySortMode.nameDesc,
        filter: LibraryFilter.video,
      );

      expect(_snapshotFolder(sourceFolder), before);
    });

    test('21 nested descendants are not included in current-folder view', () {
      final folder = _folder(
        id: 'parent',
        name: 'Parent',
        subfolders: [
          _folder(
            id: 'child',
            name: 'Child',
            items: [_item(id: 'nested', title: 'Nested', filePath: r'Y:\n.mp4')],
          ),
        ],
        items: [_item(id: 'direct', title: 'Direct', filePath: r'Y:\d.mp4')],
      );

      final view = buildLibraryFolderView(
        folder: folder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.all,
      );

      expect(view.items.map((i) => i.id).toList(), ['direct']);
      expect(view.subfolders.map((f) => f.id).toList(), ['child']);
    });

    test('22 local and HTTP paths produce identical classification', () {
      final localItem = _item(
        id: 'local',
        title: 'Local',
        filePath: r'Y:\Media\clip.MP4',
      );
      final httpItem = _item(
        id: 'http',
        title: 'HTTP',
        filePath: 'https://nas.example/media/clip.mp4',
      );

      expect(
        SupportedExtensions.categoryFor(localItem.extension),
        MediaExtensionCategory.video,
      );
      expect(
        SupportedExtensions.categoryFor(httpItem.extension),
        MediaExtensionCategory.video,
      );

      final folder = _folder(
        id: 'parent',
        name: 'Parent',
        items: [localItem, httpItem],
      );

      final view = buildLibraryFolderView(
        folder: folder,
        sortMode: LibrarySortMode.defaultOrder,
        filter: LibraryFilter.video,
        catalogSupportedExtensions: SupportedExtensions.all,
      );

      expect(view.items.map((i) => i.id).toSet(), {'local', 'http'});
      expect(
        SupportedExtensions.categoryFor(localItem.extension),
        SupportedExtensions.categoryFor(httpItem.extension),
      );
    });
  });
}
