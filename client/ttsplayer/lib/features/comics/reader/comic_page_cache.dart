/// Bounded LRU-ish page byte cache for the comic reader.
///
/// Policy (documented for architecture):
/// - Retains current page and a small window of adjacent pages when prefetched.
/// - Hard cap on entry count ([maxEntries], default 5) for **decoded page bytes
///   held by the controller**.
/// - Does **not** bound CBZ archive-parser memory when [CbzZipArchiveSource]
///   retains a fully decoded [Archive] separately.
/// - Failed loads are never stored.
/// - Cleared on [clear] / reader dispose; no reuse of CBR temp paths (CBR
///   adapter cleans temps per extract).
class ComicPageCache {
  ComicPageCache({this.maxEntries = 5});

  final int maxEntries;
  final _map = <String, List<int>>{};
  final _order = <String>[];

  int get length => _map.length;

  List<int>? get(String entryName) => _map[entryName];

  void put(String entryName, List<int> bytes) {
    if (bytes.isEmpty) return;
    if (_map.containsKey(entryName)) {
      _order.remove(entryName);
      _order.add(entryName);
      _map[entryName] = bytes;
      return;
    }
    while (_map.length >= maxEntries && _order.isNotEmpty) {
      final oldest = _order.removeAt(0);
      _map.remove(oldest);
    }
    _map[entryName] = bytes;
    _order.add(entryName);
  }

  void remove(String entryName) {
    _map.remove(entryName);
    _order.remove(entryName);
  }

  void clear() {
    _map.clear();
    _order.clear();
  }
}
