import '../constants/supported_extensions.dart';
import '../models/library_filter.dart';
import '../models/library_sort_mode.dart';
import '../models/media_folder.dart';
import '../models/media_item.dart';

/// Derived visible children for the current folder browse surface (ADR-008).
///
/// Immutable snapshot — does not reference or mutate the source [MediaFolder]
/// collections on the catalogue model.
class LibraryFolderView {
  const LibraryFolderView({
    required this.subfolders,
    required this.items,
  });

  final List<MediaFolder> subfolders;
  final List<MediaItem> items;

  bool get isEmpty => subfolders.isEmpty && items.isEmpty;
}

/// Builds a filtered and sorted folder-first view from [folder]'s direct children.
///
/// Filter is applied first; sort runs independently within the subfolder and
/// item groups. Source lists on [folder] are never modified.
LibraryFolderView buildLibraryFolderView({
  required MediaFolder folder,
  required LibrarySortMode sortMode,
  required LibraryFilter filter,
  Iterable<String>? catalogSupportedExtensions,
}) {
  final filteredSubfolders = _filterSubfolders(folder.subfolders, filter);
  final filteredItems = _filterItems(
    folder.items,
    filter,
    catalogSupportedExtensions: catalogSupportedExtensions,
  );

  return LibraryFolderView(
    subfolders: _sortSubfolders(
      filteredSubfolders,
      sortMode,
      catalogSupportedExtensions: catalogSupportedExtensions,
    ),
    items: _sortItems(
      filteredItems,
      sortMode,
      catalogSupportedExtensions: catalogSupportedExtensions,
    ),
  );
}

List<MediaFolder> _filterSubfolders(
  List<MediaFolder> subfolders,
  LibraryFilter filter,
) {
  switch (filter) {
    case LibraryFilter.all:
    case LibraryFilter.foldersOnly:
    case LibraryFilter.video:
    case LibraryFilter.images:
    case LibraryFilter.books:
    case LibraryFilter.comics:
      return List<MediaFolder>.from(subfolders);
  }
}

List<MediaItem> _filterItems(
  List<MediaItem> items,
  LibraryFilter filter, {
  Iterable<String>? catalogSupportedExtensions,
}) {
  switch (filter) {
    case LibraryFilter.foldersOnly:
      return const [];
    case LibraryFilter.video:
      final videoSet = SupportedExtensions.effectiveVideoSet(
        catalogSupported: catalogSupportedExtensions,
      );
      return items
          .where((item) => videoSet.contains(item.extension))
          .toList(growable: false);
    case LibraryFilter.images:
      final imageSet = SupportedExtensions.effectiveImageSet(
        catalogSupported: catalogSupportedExtensions,
      );
      return items
          .where((item) => imageSet.contains(item.extension))
          .toList(growable: false);
    case LibraryFilter.books:
      final bookSet = SupportedExtensions.effectiveBookSet(
        catalogSupported: catalogSupportedExtensions,
      );
      return items
          .where((item) => bookSet.contains(item.extension))
          .toList(growable: false);
    case LibraryFilter.comics:
      final comicSet = SupportedExtensions.effectiveComicSet(
        catalogSupported: catalogSupportedExtensions,
      );
      return items
          .where((item) => comicSet.contains(item.extension))
          .toList(growable: false);
    case LibraryFilter.all:
      return List<MediaItem>.from(items);
  }
}

List<MediaFolder> _sortSubfolders(
  List<MediaFolder> subfolders,
  LibrarySortMode sortMode, {
  Iterable<String>? catalogSupportedExtensions,
}) {
  if (subfolders.length <= 1) {
    return List<MediaFolder>.from(subfolders);
  }

  final sorted = List<MediaFolder>.from(subfolders);
  switch (sortMode) {
    case LibrarySortMode.defaultOrder:
      return sorted;
    case LibrarySortMode.nameAsc:
      sorted.sort(_compareFolderNameAsc);
      return sorted;
    case LibrarySortMode.nameDesc:
      sorted.sort(_compareFolderNameDesc);
      return sorted;
    case LibrarySortMode.addedNewest:
    case LibrarySortMode.addedOldest:
    case LibrarySortMode.type:
      sorted.sort(_compareFolderNameAsc);
      return sorted;
  }
}

List<MediaItem> _sortItems(
  List<MediaItem> items,
  LibrarySortMode sortMode, {
  Iterable<String>? catalogSupportedExtensions,
}) {
  if (items.length <= 1) {
    return List<MediaItem>.from(items);
  }

  final sorted = List<MediaItem>.from(items);
  switch (sortMode) {
    case LibrarySortMode.defaultOrder:
      return sorted;
    case LibrarySortMode.nameAsc:
      sorted.sort(_compareItemTitleAsc);
      return sorted;
    case LibrarySortMode.nameDesc:
      sorted.sort(_compareItemTitleDesc);
      return sorted;
    case LibrarySortMode.addedNewest:
      sorted.sort(_compareItemAddedNewest);
      return sorted;
    case LibrarySortMode.addedOldest:
      sorted.sort(_compareItemAddedOldest);
      return sorted;
    case LibrarySortMode.type:
      sorted.sort(
        (a, b) => _compareItemByType(
          a,
          b,
          catalogSupportedExtensions: catalogSupportedExtensions,
        ),
      );
      return sorted;
  }
}

int _compareFolderNameAsc(MediaFolder a, MediaFolder b) =>
    _compareLabelsAsc(a.name, b.name, a.id, b.id);

int _compareFolderNameDesc(MediaFolder a, MediaFolder b) {
  final primary = _compareLabelsDesc(a.name, b.name);
  if (primary != 0) return primary;
  return _compareLabelsAsc(a.name, b.name, a.id, b.id);
}

int _compareItemTitleAsc(MediaItem a, MediaItem b) =>
    _compareLabelsAsc(a.title, b.title, a.id, b.id);

int _compareItemTitleDesc(MediaItem a, MediaItem b) {
  final primary = _compareLabelsDesc(a.title, b.title);
  if (primary != 0) return primary;
  return _compareLabelsAsc(a.title, b.title, a.id, b.id);
}

int _compareItemAddedNewest(MediaItem a, MediaItem b) {
  final aDate = a.addedAt;
  final bDate = b.addedAt;
  if (aDate == null && bDate == null) {
    return _compareItemTitleAsc(a, b);
  }
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  final byDate = bDate.compareTo(aDate);
  if (byDate != 0) return byDate;
  return _compareItemTitleAsc(a, b);
}

int _compareItemAddedOldest(MediaItem a, MediaItem b) {
  final aDate = a.addedAt;
  final bDate = b.addedAt;
  if (aDate == null && bDate == null) {
    return _compareItemTitleAsc(a, b);
  }
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  final byDate = aDate.compareTo(bDate);
  if (byDate != 0) return byDate;
  return _compareItemTitleAsc(a, b);
}

int _compareItemByType(
  MediaItem a,
  MediaItem b, {
  Iterable<String>? catalogSupportedExtensions,
}) {
  final aCategory = SupportedExtensions.categoryFor(
    a.extension,
    catalogSupported: catalogSupportedExtensions,
  );
  final bCategory = SupportedExtensions.categoryFor(
    b.extension,
    catalogSupported: catalogSupportedExtensions,
  );
  final byCategory = aCategory.index.compareTo(bCategory.index);
  if (byCategory != 0) return byCategory;
  return _compareItemTitleAsc(a, b);
}

int _compareLabelsAsc(String a, String b, String aId, String bId) {
  final byName = a.toLowerCase().compareTo(b.toLowerCase());
  if (byName != 0) return byName;
  return aId.compareTo(bId);
}

int _compareLabelsDesc(String a, String b) =>
    b.toLowerCase().compareTo(a.toLowerCase());
