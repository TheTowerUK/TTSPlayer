import '../../../models/catalog.dart';
import '../../../models/catalogue_source_kind.dart';
import '../../../models/media_folder.dart';
import '../../../models/scan_history.dart';
import '../../../services/playback_service.dart';

/// Immutable dashboard data assembled from existing services.
class DashboardSnapshot {
  final Catalog catalog;
  final CatalogueSourceKind sourceKind;
  final String? catalogPath;
  final DateTime? lastRefreshedAt;
  final List<MediaFolder> libraries;
  final List<ContinueWatchingEntry> continueWatching;
  final List<ScanHistoryEntry> recentActivity;

  const DashboardSnapshot({
    required this.catalog,
    required this.sourceKind,
    this.catalogPath,
    this.lastRefreshedAt,
    required this.libraries,
    required this.continueWatching,
    required this.recentActivity,
  });
}

/// Assembles dashboard section data from existing services — no widget logic.
class DashboardService {
  static const maxRecentActivity = 5;
  static const maxContinueWatching = 8;

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
      recentActivity: activity,
    );
  }
}
