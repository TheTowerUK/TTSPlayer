import '../models/library_filter.dart';
import '../models/library_sort_mode.dart';

/// User-facing labels for folder browse controls (ADR-008).
extension LibrarySortModeLabels on LibrarySortMode {
  String get displayLabel {
    switch (this) {
      case LibrarySortMode.defaultOrder:
        return 'Default';
      case LibrarySortMode.nameAsc:
        return 'Name A–Z';
      case LibrarySortMode.nameDesc:
        return 'Name Z–A';
      case LibrarySortMode.addedNewest:
        return 'Recently added';
      case LibrarySortMode.addedOldest:
        return 'Oldest added';
      case LibrarySortMode.type:
        return 'Type';
    }
  }
}

extension LibraryFilterLabels on LibraryFilter {
  String get displayLabel {
    switch (this) {
      case LibraryFilter.all:
        return 'All';
      case LibraryFilter.foldersOnly:
        return 'Folders only';
      case LibraryFilter.video:
        return 'Video';
      case LibraryFilter.images:
        return 'Images';
    }
  }
}
