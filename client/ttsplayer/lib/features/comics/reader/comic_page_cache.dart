/// Bounded LRU-ish page byte cache for the comic reader (M6.6).
///
/// Policy:
/// - Retains current page and a small window of adjacent pages when prefetched.
/// - Hard cap on entry count ([maxEntries], default 5).
/// - Hard cap on total decoded bytes ([maxBytes], default 24 MiB).
/// - Does **not** bound CBZ lazy archive metadata (central directory only).
/// - Failed loads are never stored.
/// - Cleared on [clear] / reader dispose.
class ComicPageCache {
  ComicPageCache({
    this.maxEntries = 5,
    this.maxBytes = 24 * 1024 * 1024,
  })  : assert(maxEntries > 0),
        assert(maxBytes > 0);

  final int maxEntries;
  final int maxBytes;
  final _map = <String, List<int>>{};
  final _order = <String>[];

  int get length => _map.length;
  int get estimatedBytes =>
      _map.values.fold<int>(0, (sum, bytes) => sum + bytes.length);

  List<int>? get(String entryName) => _map[entryName];

  void put(String entryName, List<int> bytes) {
    if (bytes.isEmpty) return;
    if (_map.containsKey(entryName)) {
      _order.remove(entryName);
      _order.add(entryName);
      _map[entryName] = bytes;
      _evictIfNeeded();
      return;
    }
    _map[entryName] = bytes;
    _order.add(entryName);
    _evictIfNeeded();
  }

  void remove(String entryName) {
    _map.remove(entryName);
    _order.remove(entryName);
  }

  void clear() {
    _map.clear();
    _order.clear();
  }

  void _evictIfNeeded() {
    while (_map.length > maxEntries && _order.isNotEmpty) {
      _evictOldest();
    }
    while (estimatedBytes > maxBytes && _order.isNotEmpty) {
      _evictOldest();
    }
  }

  void _evictOldest() {
    final oldest = _order.removeAt(0);
    _map.remove(oldest);
  }
}
