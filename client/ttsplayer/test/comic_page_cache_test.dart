import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_cache.dart';

void main() {
  test('evicts oldest entry when count exceeded', () {
    final cache = ComicPageCache(maxEntries: 2, maxBytes: 1024 * 1024);
    cache.put('a', List.filled(10, 1));
    cache.put('b', List.filled(10, 2));
    cache.put('c', List.filled(10, 3));
    expect(cache.length, 2);
    expect(cache.get('a'), isNull);
    expect(cache.get('c'), isNotNull);
  });

  test('evicts oldest entry when byte budget exceeded', () {
    final cache = ComicPageCache(maxEntries: 10, maxBytes: 50);
    cache.put('a', List.filled(30, 1));
    cache.put('b', List.filled(30, 2));
    expect(cache.length, 1);
    expect(cache.get('a'), isNull);
    expect(cache.estimatedBytes, 30);
  });

  test('does not store empty or failed payloads', () {
    final cache = ComicPageCache();
    cache.put('empty', []);
    expect(cache.length, 0);
  });
}
