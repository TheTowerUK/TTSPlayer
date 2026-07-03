import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getContinueWatching returns eligible in-progress items', () async {
    SharedPreferences.setMockInitialValues({
      'position_item-1': 120,
      'duration_item-1': 3600,
      'position_item-2': 10,
      'duration_item-2': 3600,
    });

    final catalog = Catalog.fromJson({
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 2,
      'folders': [
        const MediaFolder(
          id: 'f1',
          name: 'Videos',
          path: r'Y:\Media\Videos',
          itemCount: 2,
          items: [
            MediaItem(
              id: 'item-1',
              title: 'Movie One',
              filePath: r'Y:\Media\Videos\one.mp4',
            ),
            MediaItem(
              id: 'item-2',
              title: 'Movie Two',
              filePath: r'Y:\Media\Videos\two.mp4',
            ),
          ],
          subfolders: [],
        ).toJson(),
      ],
    });

    final playback = PlaybackService();
    final entries = await playback.getContinueWatching(catalog);

    expect(entries.length, 1);
    expect(entries.first.item.id, 'item-1');
    expect(entries.first.resume.savedPosition.inSeconds, 120);
  });
}
