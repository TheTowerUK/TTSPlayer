/// Session-scoped folder browse filter (ADR-008). Not persisted.
enum LibraryFilter {
  /// All direct subfolders and items.
  all('all'),

  /// Subfolders only — item grid hidden.
  foldersOnly('foldersOnly'),

  /// Video extension items; subfolders remain visible.
  video('video'),

  /// Image extension items; subfolders remain visible.
  images('images');

  const LibraryFilter(this.storageKey);

  final String storageKey;

  static LibraryFilter fromStorageKey(String? value) {
    if (value == null || value.isEmpty) {
      return LibraryFilter.all;
    }
    for (final filter in LibraryFilter.values) {
      if (filter.storageKey == value) {
        return filter;
      }
    }
    return LibraryFilter.all;
  }
}
