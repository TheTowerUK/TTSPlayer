import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/media_item_navigation.dart';

void main() {
  group('mediaItemActivationFor', () {
    for (final fixture in <({
      String name,
      MediaItem item,
      MediaItemActivation expected,
    })>[
      (
        name: 'available video opens video player',
        item: _item('movie.mp4', kind: 'video'),
        expected: MediaItemActivation.videoPlayer,
      ),
      (
        name: 'available audio opens audio player',
        item: _item('track.flac', kind: 'audio'),
        expected: MediaItemActivation.audioPlayer,
      ),
      (
        name: 'PDF opens reader',
        item: _item('book.pdf', kind: 'book'),
        expected: MediaItemActivation.reader,
      ),
      (
        name: 'EPUB opens reader',
        item: _item('book.epub', kind: 'book'),
        expected: MediaItemActivation.reader,
      ),
      (
        name: 'CBZ opens reader',
        item: _item('comic.cbz', kind: 'comic'),
        expected: MediaItemActivation.reader,
      ),
      (
        name: 'ZIP comic opens reader',
        item: _item('comic.zip', kind: 'comic'),
        expected: MediaItemActivation.reader,
      ),
      (
        name: 'unsupported book falls back to details',
        item: _item('book.txt', kind: 'book'),
        expected: MediaItemActivation.details,
      ),
      (
        name: 'CBR falls back to details',
        item: _item('comic.cbr', kind: 'comic'),
        expected: MediaItemActivation.details,
      ),
      (
        name: 'image falls back to details',
        item: _item('photo.jpg', kind: 'image'),
        expected: MediaItemActivation.details,
      ),
      (
        name: 'missing video falls back to details',
        item: _item(
          'movie.mp4',
          kind: 'video',
          status: MediaItemStatus.missing,
        ),
        expected: MediaItemActivation.details,
      ),
      (
        name: 'unsupported PDF falls back to details',
        item: _item(
          'book.pdf',
          kind: 'book',
          status: MediaItemStatus.unsupported,
        ),
        expected: MediaItemActivation.details,
      ),
    ]) {
      test(fixture.name, () {
        expect(mediaItemActivationFor(fixture.item), fixture.expected);
      });
    }
  });
}

MediaItem _item(
  String filename, {
  required String kind,
  MediaItemStatus status = MediaItemStatus.available,
}) {
  return MediaItem(
    id: filename,
    title: filename,
    filePath: 'Y:/Media/$filename',
    mediaKindRaw: kind,
    status: status,
  );
}
