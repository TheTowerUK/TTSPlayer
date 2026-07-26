import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/comic_page_ref.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_cache.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';

class _FakeSource implements ComicArchiveSource {
  _FakeSource(this.pages, {this.failOn});

  final List<ComicPageRef> pages;
  final String? failOn;
  int loadCount = 0;
  bool disposed = false;

  @override
  Future<List<ComicPageRef>> listPages() async => pages;

  @override
  Future<List<int>> loadPageBytes(String entryName) async {
    loadCount++;
    if (failOn != null && entryName == failOn) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.pageExtractFailed,
        userMessage: 'That comic page could not be opened.',
      );
    }
    return [entryName.hashCode & 0xff, loadCount];
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('navigates and respects boundaries', () async {
    final source = _FakeSource([
      for (var i = 0; i < 5; i++)
        ComicPageRef(entryName: 'p$i.png', index: i),
    ]);
    final controller = ComicReaderController(
      source: source,
      prefetchAdjacent: false,
    );
    await controller.open();
    expect(controller.pageIndex, 0);
    expect(controller.canGoPrevious, isFalse);
    expect(controller.pageIndicatorLabel, 'Page 1 of 5');

    await controller.nextPage();
    expect(controller.pageIndex, 1);
    await controller.lastPage();
    expect(controller.pageIndex, 4);
    expect(controller.canGoNext, isFalse);
    await controller.nextPage();
    expect(controller.pageIndex, 4);
    await controller.firstPage();
    expect(controller.pageIndex, 0);
    controller.dispose();
    expect(source.disposed, isTrue);
  });

  test('cache bounds and skips failed loads', () async {
    final cache = ComicPageCache(maxEntries: 2);
    cache.put('a', [1]);
    cache.put('b', [2]);
    cache.put('c', [3]);
    expect(cache.length, 2);
    expect(cache.get('a'), isNull);
    expect(cache.get('c'), [3]);

    final source = _FakeSource(
      [const ComicPageRef(entryName: 'bad.png', index: 0)],
      failOn: 'bad.png',
    );
    final controller = ComicReaderController(source: source, cache: cache);
    await controller.open();
    expect(controller.state, ComicReaderLoadState.error);
    expect(cache.get('bad.png'), isNull);
    controller.dispose();
  });
}
