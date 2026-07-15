/// Fixed-capacity least-recently-used map.
///
/// [get] and [putIfAbsent] promote entries to most-recently-used.
/// When at capacity, inserting a new key evicts the least-recently-used entry.
class LruCache<K, V> {
  LruCache(this.maxCapacity) : assert(maxCapacity >= 1);

  final int maxCapacity;
  final _entries = <K, V>{};
  final _order = <K>[];

  int get length => _entries.length;

  bool containsKey(K key) => _entries.containsKey(key);

  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    _touch(key);
    return _entries[key];
  }

  V putIfAbsent(K key, V Function() ifAbsent) {
    if (_entries.containsKey(key)) {
      _touch(key);
      return _entries[key] as V;
    }
    _evictIfNeeded();
    final value = ifAbsent();
    _entries[key] = value;
    _order.add(key);
    return value;
  }

  void clear() {
    _entries.clear();
    _order.clear();
  }

  void _touch(K key) {
    _order.remove(key);
    _order.add(key);
  }

  void _evictIfNeeded() {
    if (_entries.length < maxCapacity) return;
    final lru = _order.first;
    _order.removeAt(0);
    _entries.remove(lru);
  }
}
