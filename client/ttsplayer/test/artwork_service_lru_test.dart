import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';

void main() {
  group('ArtworkService LRU', () {
    test('never exceeds configured capacity', () {
      final service = ArtworkService(
        fileExists: (_) => false,
        cacheCapacity: 3,
      );

      for (var i = 0; i < 10; i++) {
        service.forMediaItem(
          MediaItem(
            id: 'item-$i',
            title: 'Item $i',
            filePath: r'Y:\Media\file$i.mp4',
          ),
        );
      }

      expect(service.cacheEntryCount, lessThanOrEqualTo(3));
    });

    test('stable entity id produces cache hit without extra probes', () {
      var calls = 0;
      final service = ArtworkService(
        cacheCapacity: 4,
        fileExists: (path) {
          calls++;
          return path.endsWith('poster.jpg');
        },
      );

      const item = MediaItem(
        id: 'same-id',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      service.forMediaItem(item);
      final afterFirst = calls;
      service.forMediaItem(item);
      expect(calls, afterFirst);
      expect(service.cacheEntryCount, 1);
    });

    test('distinct entity ids remain distinct', () {
      final exists = <String, bool>{
        r'Y:\A\one.mp4': true,
        r'Y:\A\one.jpg': true,
        r'Y:\B\one.mp4': true,
        r'Y:\B\one.jpg': true,
      };

      final service = ArtworkService(
        cacheCapacity: 8,
        fileExists: (path) => exists[path] ?? false,
      );

      const itemA = MediaItem(
        id: 'a',
        title: 'One',
        filePath: r'Y:\A\one.mp4',
      );
      const itemB = MediaItem(
        id: 'b',
        title: 'One',
        filePath: r'Y:\B\one.mp4',
      );

      final resultA = service.forMediaItem(itemA);
      final resultB = service.forMediaItem(itemB);
      expect(resultA.filePath, r'Y:\A\one.jpg');
      expect(resultB.filePath, r'Y:\B\one.jpg');
      expect(service.cacheEntryCount, 2);
    });

    test('placeholder resolution is cached without filesystem re-probes', () {
      var calls = 0;
      final service = ArtworkService(
        cacheCapacity: 2,
        fileExists: (_) {
          calls++;
          return false;
        },
      );

      const item = MediaItem(
        id: 'missing-art',
        title: 'Film',
        filePath: r'Y:\Media\film.mp4',
      );

      expect(service.forMediaItem(item).source, ArtworkSource.placeholder);
      final afterFirst = calls;
      expect(service.forMediaItem(item).source, ArtworkSource.placeholder);
      expect(calls, afterFirst);
    });

    test('clearCache allows sidecar discovery after catalogue invalidation', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\film.mp4': true,
      };

      final service = ArtworkService(
        cacheCapacity: 4,
        fileExists: (path) => exists[path] ?? false,
      );

      const item = MediaItem(
        id: 'cache2',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      expect(service.forMediaItem(item).source, ArtworkSource.placeholder);
      exists[r'Y:\Media\Movies\poster.jpg'] = true;
      expect(service.forMediaItem(item).source, ArtworkSource.placeholder);

      service.clearCache();
      final resolved = service.forMediaItem(item);
      expect(resolved.source, ArtworkSource.sidecar);
      expect(resolved.filePath, r'Y:\Media\Movies\poster.jpg');
    });

    test('default capacity is 500', () {
      expect(ArtworkService.defaultCacheCapacity, 500);
    });
  });
}
