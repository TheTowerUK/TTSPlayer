import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/catalogue_source_kind.dart';
import 'package:ttsplayer/services/playback_service.dart';

MediaItem _item(String id, String title, DateTime? addedAt) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\' + title + '.mp4',
    addedAt: addedAt,
  );
}

Catalog _catalogWithItems(List<MediaItem> rootItems, {List<MediaFolder>? subs}) {
  return Catalog.fromJson({
    'generated_at': '2026-07-05T00:00:00+00:00',
    'total_items': rootItems.length,
    'sources': [
      {
        'name': 'Media',
        'root_path': r'Y:\Media',
        'type': 'local',
        'accessible': true,
      },
    ],
    'folders': [
      {
        'id': 'videos',
        'name': 'Videos',
        'path': r'Y:\Media\Videos',
        'item_count': rootItems.length,
        'items': rootItems.map((i) => i.toJson()).toList(),
        'subfolders': subs?.map((f) => f.toJson()).toList() ?? [],
      },
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    test('recently added sorts newest first and caps count', () async {
      final catalog = _catalogWithItems([
        _item('old', 'Old Film', DateTime.utc(2026, 1, 1)),
        _item('mid', 'Mid Film', DateTime.utc(2026, 3, 1)),
        _item('new', 'New Film', DateTime.utc(2026, 6, 1)),
      ]);

      final snapshot = await DashboardService().build(
        catalog: catalog,
        sourceKind: CatalogueSourceKind.demo,
        catalogPath: 'bundled',
        lastRefreshedAt: null,
        playback: PlaybackService(),
        historyEntries: const [],
      );

      expect(snapshot.recentlyAdded.length, 3);
      expect(snapshot.recentlyAdded.first.item.id, 'new');
      expect(snapshot.recentlyAdded.last.item.id, 'old');
    });

    test('recently added omits items without addedAt', () async {
      final catalog = _catalogWithItems([
        _item('dated', 'Dated', DateTime.utc(2026, 5, 1)),
        _item('undated', 'Undated', null),
      ]);

      final snapshot = await DashboardService().build(
        catalog: catalog,
        sourceKind: CatalogueSourceKind.demo,
        catalogPath: 'bundled',
        lastRefreshedAt: null,
        playback: PlaybackService(),
        historyEntries: const [],
      );

      expect(snapshot.recentlyAdded.length, 1);
      expect(snapshot.recentlyAdded.single.item.id, 'dated');
    });

    test('featured folders excludes library roots and ranks by size', () {
      final action = MediaFolder(
        id: 'action',
        name: 'Action',
        path: r'Y:\Media\Videos\Action',
        itemCount: 2,
        items: [
          _item('a1', 'A1', null),
          _item('a2', 'A2', null),
        ],
        subfolders: const [],
      );
      final docs = MediaFolder(
        id: 'docs',
        name: 'Docs',
        path: r'Y:\Media\Videos\Docs',
        itemCount: 1,
        items: [_item('d1', 'D1', null)],
        subfolders: const [],
      );

      final catalog = _catalogWithItems(const [], subs: [action, docs]);
      final featured = catalog.featuredFolders(maxCount: 8);

      expect(featured.map((f) => f.name), ['Action', 'Docs']);
      expect(featured.first.name, 'Action');
    });
  });

  group('MediaItem.addedAt', () {
    test('fromJson parses ISO-8601 added_at', () {
      final item = MediaItem.fromJson({
        'id': 'x',
        'title': 'Test',
        'file_path': r'Y:\a.mp4',
        'added_at': '2026-07-05T09:30:00.000Z',
      });
      expect(item.addedAt, DateTime.utc(2026, 7, 5, 9, 30));
    });

    test('toJson includes added_at when set', () {
      final item = _item('x', 'Test', DateTime.utc(2026, 7, 5, 9, 30));
      expect(item.toJson()['added_at'], isNotNull);
    });
  });
}
