import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_queue.dart';

MediaItem _audio(String id, {String title = 'Track'}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: r'Y:\Media\Music\$id.mp3',
    mediaKindRaw: 'audio',
  );
}

MediaItem _video(String id) {
  return MediaItem(
    id: id,
    title: 'Video $id',
    filePath: r'Y:\Media\Videos\$id.mp4',
    mediaKindRaw: 'video',
  );
}

void main() {
  group('PlaybackQueue', () {
    test('empty queue has no current item', () {
      const queue = PlaybackQueue.empty();
      expect(queue.isEmpty, isTrue);
      expect(queue.currentItem, isNull);
      expect(queue.hasNext, isFalse);
      expect(queue.hasPrevious, isFalse);
    });

    test('one-item queue current index is zero', () {
      final track = _audio('a1');
      final queue = const PlaybackQueue.empty().replaceItems([track]);
      expect(queue.length, 1);
      expect(queue.currentItem?.id, 'a1');
      expect(queue.hasNext, isFalse);
      expect(queue.hasPrevious, isFalse);
    });

    test('multi-item queue exposes neighbours', () {
      final items = [_audio('a1'), _audio('a2'), _audio('a3')];
      final queue = const PlaybackQueue.empty().replaceItems(items, startIndex: 1);
      expect(queue.currentItem?.id, 'a2');
      expect(queue.previousItem?.id, 'a1');
      expect(queue.nextItem?.id, 'a3');
      expect(queue.hasNext, isTrue);
      expect(queue.hasPrevious, isTrue);
    });

    test('replace increments generation', () {
      final q1 = const PlaybackQueue.empty().replaceItems([_audio('a1')]);
      final q2 = q1.replaceItems([_audio('a2')]);
      expect(q2.generation, greaterThan(q1.generation));
    });

    test('audioOnlyItems filters video and non-playable', () {
      final missing = MediaItem.fromJson({
        'id': 'm1',
        'title': 'Missing',
        'file_path': r'Y:\m.mp3',
        'status': 'missing',
        'media_kind': 'audio',
      });
      final filtered = PlaybackQueue.audioOnlyItems([
        _audio('a1'),
        _video('v1'),
        missing,
      ]);
      expect(filtered.length, 1);
      expect(filtered.first.id, 'a1');
    });

    test('duplicate ids are preserved in order', () {
      final items = [_audio('dup'), _audio('dup', title: 'Dup 2')];
      final queue = const PlaybackQueue.empty().replaceItems(items);
      expect(queue.length, 2);
      expect(queue.items[0].title, 'Track');
      expect(queue.items[1].title, 'Dup 2');
    });

    test('advance and retreat preserve ordering', () {
      final items = [_audio('a1'), _audio('a2'), _audio('a3')];
      var queue = const PlaybackQueue.empty().replaceItems(items);
      queue = queue.advanceToNext();
      expect(queue.currentItem?.id, 'a2');
      queue = queue.retreatToPrevious();
      expect(queue.currentItem?.id, 'a1');
    });

    test('advance at end is no-op', () {
      final items = [_audio('a1'), _audio('a2')];
      var queue = const PlaybackQueue.empty().replaceItems(items, startIndex: 1);
      final advanced = queue.advanceToNext();
      expect(advanced, queue);
    });

    test('reconcile retains order and refreshes metadata', () {
      final items = [_audio('a1', title: 'Old 1'), _audio('a2'), _audio('a3')];
      final queue = const PlaybackQueue.empty().replaceItems(items, startIndex: 1);
      final resolved = {
        'a1': _audio('a1', title: 'Fresh 1'),
        'a3': _audio('a3', title: 'Fresh 3'),
      };
      final reconciled = queue.reconcile(resolved);
      expect(reconciled.length, 2);
      expect(reconciled.items.map((i) => i.id), ['a1', 'a3']);
      expect(reconciled.currentItem?.id, 'a3');
      expect(reconciled.items.first.title, 'Fresh 1');
    });

    test('reconcile empty result clears queue', () {
      final queue = const PlaybackQueue.empty().replaceItems([_audio('gone')]);
      final reconciled = queue.reconcile({});
      expect(reconciled.isEmpty, isTrue);
    });
  });
}
