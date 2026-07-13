import '../models/catalog.dart';
import '../models/library_metadata.dart';
import '../models/media_folder.dart';
import '../models/media_item.dart';

/// Resolved favourite entry for UI presentation (ADR-007).
///
/// Unresolved catalogue ids are omitted — never fabricated placeholders.
enum FavouriteEntryKind { folder, item }

class ResolvedFavouriteEntry {
  const ResolvedFavouriteEntry({
    required this.kind,
    required this.favouritedAt,
    required this.id,
    this.folder,
    this.item,
    this.parentFolder,
  });

  final FavouriteEntryKind kind;
  final DateTime favouritedAt;
  final String id;
  final MediaFolder? folder;
  final MediaItem? item;
  final MediaFolder? parentFolder;

  String get displayTitle =>
      kind == FavouriteEntryKind.folder ? folder!.name : item!.title;

  String get kindLabel =>
      kind == FavouriteEntryKind.folder ? 'Folder' : 'Media';
}

/// Merges folder and item favourites, resolves against [catalog], newest first.
List<ResolvedFavouriteEntry> resolveFavourites({
  required Catalog catalog,
  required List<FavouriteRecord> folderRecords,
  required List<FavouriteRecord> itemRecords,
}) {
  final entries = <ResolvedFavouriteEntry>[];

  for (final record in folderRecords) {
    final folder = catalog.findFolderById(record.id);
    if (folder == null) continue;
    entries.add(
      ResolvedFavouriteEntry(
        kind: FavouriteEntryKind.folder,
        favouritedAt: record.favouritedAt,
        id: record.id,
        folder: folder,
      ),
    );
  }

  for (final record in itemRecords) {
    final item = catalog.findItemById(record.id);
    if (item == null) continue;
    entries.add(
      ResolvedFavouriteEntry(
        kind: FavouriteEntryKind.item,
        favouritedAt: record.favouritedAt,
        id: record.id,
        item: item,
        parentFolder: catalog.parentFolderOfItemId(record.id),
      ),
    );
  }

  entries.sort(_compareEntries);
  return List.unmodifiable(entries);
}

int _compareEntries(ResolvedFavouriteEntry a, ResolvedFavouriteEntry b) {
  final byTime = b.favouritedAt.compareTo(a.favouritedAt);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}
