import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/artwork/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('insert and retrieve entry', () {
      final cache = LruCache<String, int>(3);
      cache.putIfAbsent('a', () => 1);
      expect(cache.get('a'), 1);
      expect(cache.length, 1);
    });

    test('cache hit promotes entry to most-recently-used', () {
      final cache = LruCache<String, int>(3);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('b', () => 2);
      cache.putIfAbsent('c', () => 3);
      expect(cache.get('a'), 1);
      cache.putIfAbsent('d', () => 4);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
    });

    test('never exceeds capacity', () {
      final cache = LruCache<String, int>(2);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('b', () => 2);
      cache.putIfAbsent('c', () => 3);
      expect(cache.length, 2);
    });

    test('evicts least-recently-used entry at capacity', () {
      final cache = LruCache<String, int>(2);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('b', () => 2);
      cache.putIfAbsent('c', () => 3);
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
    });

    test('accessing older entry changes next eviction candidate', () {
      final cache = LruCache<String, int>(2);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('b', () => 2);
      expect(cache.get('a'), 1);
      cache.putIfAbsent('c', () => 3);
      expect(cache.get('b'), isNull);
      expect(cache.get('a'), 1);
    });

    test('replacing existing key preserves entry count', () {
      final cache = LruCache<String, int>(2);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('a', () => 99);
      expect(cache.length, 1);
      expect(cache.get('a'), 1);
    });

    test('capacity of one behaves correctly', () {
      final cache = LruCache<String, int>(1);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('b', () => 2);
      expect(cache.length, 1);
      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
    });

    test('clear empties cache and resets ordering', () {
      final cache = LruCache<String, int>(3);
      cache.putIfAbsent('a', () => 1);
      cache.putIfAbsent('b', () => 2);
      cache.clear();
      expect(cache.length, 0);
      cache.putIfAbsent('c', () => 3);
      expect(cache.get('c'), 3);
    });
  });
}
