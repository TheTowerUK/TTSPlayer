/// Global default and in-session folder browse sort modes (ADR-008).
enum LibrarySortMode {
  /// Indexer emission order within each group.
  defaultOrder('default'),

  /// Folder [MediaFolder.name] / item [MediaItem.title] case-insensitive A→Z.
  nameAsc('nameAsc'),

  /// Folder name / item title case-insensitive Z→A.
  nameDesc('nameDesc'),

  /// Items: [MediaItem.addedAt] descending (nulls last); folders: name A→Z.
  addedNewest('addedNewest'),

  /// Items: [MediaItem.addedAt] ascending (nulls last); folders: name A→Z.
  addedOldest('addedOldest'),

  /// Items: extension category video → image → other, then title A→Z.
  type('type');

  const LibrarySortMode(this.storageKey);

  /// Persisted value in `general.libraryBrowse.defaultSortMode`.
  final String storageKey;

  static const LibrarySortMode defaultMode = LibrarySortMode.defaultOrder;

  static LibrarySortMode fromStorageKey(
    String? value, {
    List<String>? warnings,
  }) {
    if (value == null || value.isEmpty) {
      return defaultMode;
    }
    for (final mode in LibrarySortMode.values) {
      if (mode.storageKey == value) {
        return mode;
      }
    }
    warnings?.add('Unknown library sort mode "$value"; using default.');
    return defaultMode;
  }
}
