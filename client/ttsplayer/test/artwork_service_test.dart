import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/artwork/library_visual_kind.dart';

void main() {
  group('ArtworkService', () {
    test('uses catalog thumbnail when present', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\film.mp4': true,
        r'Y:\Media\Movies\poster.jpg': true,
      };

      final service = ArtworkService(
        fileExists: (path) => exists[path] ?? false,
      );

      const item = MediaItem(
        id: '1',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
        thumbnailPath: r'Y:\Media\Movies\poster.jpg',
      );

      final result = service.forMediaItem(item);
      expect(result.source, ArtworkSource.catalogThumbnail);
      expect(result.filePath, r'Y:\Media\Movies\poster.jpg');
      expect(result.visualKind, LibraryVisualKind.videos);
    });

    test('prefers stem sidecar over folder artwork', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\film.mp4': true,
        r'Y:\Media\Movies\film.jpg': true,
        r'Y:\Media\Movies\poster.jpg': true,
      };

      final service = ArtworkService(
        fileExists: (path) => exists[path] ?? false,
      );

      const item = MediaItem(
        id: '2',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      final result = service.forMediaItem(item);
      expect(result.source, ArtworkSource.sidecar);
      expect(result.filePath, r'Y:\Media\Movies\film.jpg');
    });

    test('falls back to named sidecar in media directory', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\film.mp4': true,
        r'Y:\Media\Movies\cover.png': true,
      };

      final service = ArtworkService(
        fileExists: (path) => exists[path] ?? false,
      );

      const item = MediaItem(
        id: '3',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      final result = service.forMediaItem(item);
      expect(result.source, ArtworkSource.sidecar);
      expect(result.filePath, r'Y:\Media\Movies\cover.png');
    });

    test('uses parent folder artwork when no media sidecar exists', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\Sub\film.mp4': true,
        r'Y:\Media\Movies\folder.jpg': true,
      };

      final service = ArtworkService(
        fileExists: (path) => exists[path] ?? false,
      );

      const item = MediaItem(
        id: '4',
        title: 'Film',
        filePath: r'Y:\Media\Movies\Sub\film.mp4',
      );

      final parent = _folder(
        id: 'movies',
        name: 'Movies',
        path: r'Y:\Media\Movies',
      );

      final result = service.forMediaItem(item, parentFolder: parent);
      expect(result.source, ArtworkSource.folderArt);
      expect(result.filePath, r'Y:\Media\Movies\folder.jpg');
    });

    test('treats folder.jpg beside media file as sidecar', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\film.mp4': true,
        r'Y:\Media\Movies\folder.jpg': true,
      };

      final service = ArtworkService(
        fileExists: (path) => exists[path] ?? false,
      );

      const item = MediaItem(
        id: '4b',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      final result = service.forMediaItem(item);
      expect(result.source, ArtworkSource.sidecar);
      expect(result.filePath, r'Y:\Media\Movies\folder.jpg');
    });

    test('returns placeholder when no artwork files exist', () {
      final service = ArtworkService(fileExists: (_) => false);

      const item = MediaItem(
        id: '5',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      final result = service.forMediaItem(item);
      expect(result.source, ArtworkSource.placeholder);
      expect(result.filePath, isNull);
      expect(result.visualKind, LibraryVisualKind.videos);
    });

    test('resolves folder artwork for libraries', () {
      final exists = <String, bool>{
        r'Y:\Media\Videos\artwork.jpg': true,
      };

      final service = ArtworkService(
        fileExists: (path) => exists[path] ?? false,
      );

      final folder = _folder(
        id: 'lib1',
        name: 'Videos',
        path: r'Y:\Media\Videos',
      );

      final result = service.forLibrary(folder);
      expect(result.source, ArtworkSource.folderArt);
      expect(result.filePath, r'Y:\Media\Videos\artwork.jpg');
      expect(result.visualKind, LibraryVisualKind.videos);
    });

    test('visualKindForFolderName is cosmetic only', () {
      final service = ArtworkService(fileExists: (_) => false);
      expect(
        service.visualKindForFolderName('My Music'),
        LibraryVisualKind.music,
      );
      expect(
        service.visualKindForFolderName('Random Stuff'),
        LibraryVisualKind.unknown,
      );
    });

    test('caches results per entity id', () {
      var calls = 0;
      final service = ArtworkService(
        fileExists: (path) {
          calls++;
          return path.endsWith('poster.jpg');
        },
      );

      const item = MediaItem(
        id: 'cache1',
        title: 'Film',
        filePath: r'Y:\Media\Movies\film.mp4',
      );

      service.forMediaItem(item);
      final callsAfterFirst = calls;
      service.forMediaItem(item);
      expect(calls, callsAfterFirst);
    });
  });
}

MediaFolder _folder({
  required String id,
  required String name,
  required String path,
}) {
  return MediaFolder(
    id: id,
    name: name,
    path: path,
    itemCount: 0,
    items: const [],
    subfolders: const [],
  );
}
