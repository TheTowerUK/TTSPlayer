import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_source_kind.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/playback_service.dart';

Catalog _testCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-07-03T00:00:00+00:00',
    'total_items': 1,
    'folders': [
      const MediaFolder(
        id: 'f1',
        name: 'Videos',
        path: r'Y:\Media\Videos',
        itemCount: 1,
        items: [
          MediaItem(
            id: 'item-1',
            title: 'Movie One',
            filePath: r'Y:\Media\Videos\one.mp4',
          ),
        ],
        subfolders: [],
      ).toJson(),
    ],
  });
}

Future<DashboardSnapshot> _buildSnapshot(PlaybackService playback) {
  final catalog = _testCatalog();
  return DashboardService().build(
    catalog: catalog,
    sourceKind: CatalogueSourceKind.liveNas,
    catalogPath: r'Y:\Media\catalog.json',
    lastRefreshedAt: null,
    playback: playback,
    historyEntries: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Continue Watching refresh', () {
    test('resumeDataVersion increments when resume state is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final playback = PlaybackService();
      expect(playback.resumeDataVersion, 0);

      await playback.persistResumeStateForTest(
        'item-1',
        const Duration(seconds: 120),
        duration: const Duration(seconds: 3600),
      );

      expect(playback.resumeDataVersion, 1);
    });

    test('resumeDataVersion increments when resume state is cleared', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });
      final playback = PlaybackService();
      expect(playback.resumeDataVersion, 0);

      await playback.clearResumeStateForTest('item-1');

      expect(playback.resumeDataVersion, 1);
    });

    test('DashboardService snapshot includes new resume data without restart',
        () async {
      SharedPreferences.setMockInitialValues({});
      final playback = PlaybackService();

      final before = await _buildSnapshot(playback);
      expect(before.continueWatching, isEmpty);

      await playback.persistResumeStateForTest(
        'item-1',
        const Duration(seconds: 120),
        duration: const Duration(seconds: 3600),
      );

      final after = await _buildSnapshot(playback);
      expect(after.continueWatching.length, 1);
      expect(after.continueWatching.first.item.id, 'item-1');
    });

    test('DashboardService snapshot removes completed/cleared resume entries',
        () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });
      final playback = PlaybackService();

      final before = await _buildSnapshot(playback);
      expect(before.continueWatching.length, 1);

      await playback.clearResumeStateForTest('item-1');

      final after = await _buildSnapshot(playback);
      expect(after.continueWatching, isEmpty);
    });
  });
}
