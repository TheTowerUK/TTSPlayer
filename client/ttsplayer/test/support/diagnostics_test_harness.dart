import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/catalogue_provider_snapshot.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';

Catalog diagnosticsCatalog({
  required String identity,
  int itemCount = 2,
  int libraryCount = 1,
}) {
  return Catalog.fromJson({
    'generated_at': '2026-07-14T10:00:00+00:00',
    'total_items': itemCount,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
    },
    'folders': [
      for (var i = 0; i < libraryCount; i++)
        {
          'id': 'lib-$i',
          'name': 'Library $i',
          'path': r'Y:\Media\Library',
          'item_count': itemCount,
          'items': [
            for (var j = 0; j < itemCount; j++)
              {
                'id': 'item-$i-$j',
                'title': 'Item $j',
                'file_path': r'Y:\Media\Library\item.mp4',
                'status': 'available',
              },
          ],
          'subfolders': [
            {
              'id': 'sub-$i',
              'name': 'Sub',
              'path': r'Y:\Media\Library\Sub',
              'item_count': 0,
              'items': [],
              'subfolders': [],
            },
          ],
        },
    ],
  });
}

CatalogueProviderSnapshot diagnosticsProviderSnapshot({
  bool degraded = false,
  bool demoFallback = false,
  String? lastError,
}) {
  const local = MediaCatalogueProviderDefinition.localFile(
    r'Y:\Media\catalog.json',
  );
  return CatalogueProviderSnapshot(
    providers: [
      CatalogueProviderAttemptRecord(
        definition: local,
        health: degraded
            ? CatalogueProviderHealth.degraded
            : CatalogueProviderHealth.success,
        lastError: lastError,
        lastAttemptAt: DateTime.utc(2026, 7, 16, 10, 0),
        lastSuccessAt: DateTime.utc(2026, 7, 16, 10, 0),
      ),
    ],
    activeProvider: local,
    loadedCatalogueIdentity: '2026-07-14T10:00:00Z-ABC123',
    accessMode: MediaAccessMode.localPreferred,
    lastCatalogueLoadAt: DateTime.utc(2026, 7, 16, 10, 0),
    isDegradedLoad: degraded,
    isDemoFallback: demoFallback,
  );
}

class StubCatalogService extends CatalogService {
  StubCatalogService({
    Catalog? stubCatalog,
    CatalogueProviderSnapshot? stubSnapshot,
    this.loading = false,
    this.error,
    this.demo = false,
    this.degraded = false,
    this.usingFallback = false,
    this.lastRefresh,
    this.lastLoad,
    this.catalogPathValue,
  }) : _stubSnapshot = stubSnapshot ?? diagnosticsProviderSnapshot(),
       _stubCatalog = stubCatalog;

  Catalog? _stubCatalog;
  final CatalogueProviderSnapshot _stubSnapshot;
  final bool loading;
  final String? error;
  final bool demo;
  final bool degraded;
  final bool usingFallback;
  final DateTime? lastRefresh;
  final DateTime? lastLoad;
  final String? catalogPathValue;

  @override
  Catalog? get catalog => _stubCatalog;

  set stubCatalog(Catalog? value) => _stubCatalog = value;

  @override
  bool get isLoading => loading;

  @override
  String? get errorMessage => error;

  @override
  bool get isUsingFallback => usingFallback;

  @override
  bool get isDemoCatalogue => demo;

  @override
  bool get isDegradedLoad => degraded;

  @override
  CatalogueProviderSnapshot get providerSnapshot => _stubSnapshot;

  @override
  MediaCatalogueProviderDefinition? get activeCatalogueProvider =>
      _stubSnapshot.activeProvider;

  @override
  DateTime? get lastRefreshedAt => lastRefresh;

  @override
  DateTime? get lastCatalogueLoadAt => lastLoad;

  @override
  String? get catalogPath => catalogPathValue ?? _stubSnapshot.catalogPath;

  @override
  Future<void> refreshCatalogue() async {}
}

class ThrowingArtworkService extends ArtworkService {
  @override
  int get cacheEntryCount => throw StateError('artwork unavailable');
}

class ThrowingSearchService extends SearchService {
  @override
  bool get hasIndex => throw StateError('search unavailable');
}

Future<DiagnosticsService> buildDiagnosticsHarness({
  Catalog? catalog,
  CatalogueProviderSnapshot? providerSnapshot,
  ArtworkService? artworkService,
  SearchService? searchService,
  PlaybackService? playbackService,
  LibraryMetadataRepository? libraryMetadataRepository,
  MediaProviderConfigService? configService,
  DateTime? applicationStartedAt,
  Future<PackageInfo> Function()? packageInfoLoader,
  bool Function()? imageCacheAvailableProvider,
  bool withInitializedLibrary = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'TTSPlayer',
    packageName: 'ttsplayer',
    version: '0.5.0-dev',
    buildNumber: '42',
    buildSignature: 'sig',
    installerStore: null,
  );

  final metadata = libraryMetadataRepository ?? LibraryMetadataRepository();
  if (withInitializedLibrary && !metadata.isLoaded) {
    await metadata.initialize();
  }

  final config = configService ?? MediaProviderConfigService();
  if (configService == null) {
    await config.load();
  }

  return DiagnosticsService(
    catalogService: StubCatalogService(
      stubCatalog: catalog,
      stubSnapshot: providerSnapshot,
      demo: catalog == null,
    ),
    artworkService: artworkService ?? ArtworkService(fileExists: (_) => true),
    searchService: searchService ?? SearchService(),
    playbackService: playbackService ?? PlaybackService(),
    mediaProviderConfigService: config,
    libraryMetadataRepository: metadata,
    applicationStartedAt:
        applicationStartedAt ?? DateTime.utc(2026, 7, 16, 9, 0),
    packageInfoLoader: packageInfoLoader,
    platformNameProvider: () => 'windows',
    imageCacheAvailableProvider: imageCacheAvailableProvider ?? (() => false),
  );
}

MediaItem diagnosticsMediaItem({String id = 'media-1'}) {
  return MediaItem.fromJson({
    'id': id,
    'title': 'Sample Title',
    'file_path': r'Y:\Media\sample.mp4',
    'status': 'available',
  });
}

MediaFolder diagnosticsMediaFolder() {
  return MediaFolder.fromJson({
    'id': 'folder-1',
    'name': 'Videos',
    'path': r'Y:\Media\Videos',
    'item_count': 1,
    'items': [],
    'subfolders': [],
  });
}

RuntimeDiagnosticsSnapshot minimalSnapshot({
  DateTime? capturedAt,
}) {
  final at = capturedAt ?? DateTime.utc(2026, 7, 16, 12);
  return RuntimeDiagnosticsSnapshot(
    capturedAt: at,
    application: const ApplicationDiagnostics(
      status: DiagnosticSectionStatus.complete,
      appVersion: '0.5.0-dev',
      buildNumber: '42',
      platform: 'windows',
      startupElapsed: Duration(minutes: 3),
    ),
    provider: const ProviderDiagnostics(
      status: DiagnosticSectionStatus.complete,
      accessModeLabel: 'Local preferred',
    ),
    catalogue: const CatalogueDiagnostics(
      status: DiagnosticSectionStatus.complete,
      catalogueIdentity: '2026-07-14T1…',
      itemCount: 2,
    ),
    cache: const CacheDiagnostics(
      status: DiagnosticSectionStatus.complete,
      artworkCandidateCount: 1,
      artworkCandidateCapacity: 500,
    ),
    search: const SearchDiagnostics(
      status: DiagnosticSectionStatus.complete,
      hasIndex: false,
      indexBuildCount: 0,
    ),
    playback: const PlaybackDiagnostics(
      status: DiagnosticSectionStatus.complete,
      engineLabel: 'media_kit',
    ),
    library: const LibraryDiagnostics(
      status: DiagnosticSectionStatus.complete,
      favouriteItemCount: 0,
      favouriteFolderCount: 0,
    ),
  );
}
