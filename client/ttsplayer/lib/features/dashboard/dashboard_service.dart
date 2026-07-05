import '../../../models/catalog.dart';
import '../../../models/catalogue_source_kind.dart';
import '../../../models/media_folder.dart';
import '../../../models/media_item.dart';
import '../../../models/scan_history.dart';
import '../../../services/playback_service.dart';

/// One recently indexed item with optional parent folder for artwork context.
class RecentlyAddedEntry {
  final MediaItem item;
  final MediaFolder? parentFolder;

  const RecentlyAddedEntry({
    required this.item,
    this.parentFolder,
  });
}

/// Immutable dashboard data assembled from existing services.
class DashboardSnapshot {
  final Catalog catalog;
  final CatalogueSourceKind sourceKind;
  final String? catalogPath;
  final DateTime? lastRefreshedAt;
  final List<MediaFolder> libraries;
  final List<ContinueWatchingEntry> continueWatching;
  final List<RecentlyAddedEntry> recentlyAdded;
  final List<MediaFolder> featuredFolders;
  final List<ScanHistoryEntry> recentActivity;

  const DashboardSnapshot({
    required this.catalog,
    required this.sourceKind,
    this.catalogPath,
    this.lastRefreshedAt,
    required this.libraries,
    required this.continueWatching,
    required this.recentlyAdded,
    required this.featuredFolders,
    required this.recentActivity,
  });
}

/// Assembles dashboard section data from existing services — no widget logic.
class DashboardService {
  static const maxRecentActivity = 5;
  static const maxContinueWatching = 8;
  static const maxRecentlyAdded = 12;
  static const maxFeaturedFolders = 8;

  Future<DashboardSnapshot> build({
    required Catalog catalog,
    required CatalogueSourceKind sourceKind,
    required String? catalogPath,
    required DateTime? lastRefreshedAt,
    required PlaybackService playback,
    required List<ScanHistoryEntry> historyEntries,
  }) async {
    final continueWatching = await playback.getContinueWatching(catalog);
    final activity = historyEntries.take(maxRecentActivity).toList();

    return DashboardSnapshot(
      catalog: catalog,
      sourceKind: sourceKind,
      catalogPath: catalogPath,
      lastRefreshedAt: lastRefreshedAt,
      libraries: catalog.libraryFolders,
      continueWatching: continueWatching.take(maxContinueWatching).toList(),
      recentlyAdded: _buildRecentlyAdded(catalog),
      featuredFolders:
          catalog.featuredFolders(maxCount: maxFeaturedFolders),
      recentActivity: activity,
    );
  }

  static List<RecentlyAddedEntry> _buildRecentlyAdded(Catalog catalog) {
    final withDates = catalog.allItems
        .where((item) => item.addedAt != null)
        .toList()
      ..sort((a, b) => b.addedAt!.compareTo(a.addedAt!));

    return withDates.take(maxRecentlyAdded).map((item) {
      return RecentlyAddedEntry(
        item: item,
        parentFolder: catalog.parentFolderOf(item),
      );
    }).toList();
  }
}
