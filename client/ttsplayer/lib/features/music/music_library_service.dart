import '../../models/catalog.dart';
import 'models/music_library_projection.dart';

/// Memoised derived music views keyed by catalogue identity (M5.2).
class MusicLibraryService {
  MusicLibraryProjection? _cached;
  String? _cachedIdentity;

  MusicLibraryProjection projectionFor(Catalog catalog) {
    final identity = catalog.catalogueIdentity;
    if (_cached != null && _cachedIdentity == identity) {
      return _cached!;
    }
    final built = MusicLibraryProjection.build(catalog);
    _cached = built;
    _cachedIdentity = identity;
    return built;
  }

  /// Clears memoised projection — called when catalogue is replaced.
  void invalidate() {
    _cached = null;
    _cachedIdentity = null;
  }

  /// Whether a memoised projection exists for [identity].
  bool hasCachedProjectionFor(String identity) {
    return _cached != null && _cachedIdentity == identity;
  }
}
