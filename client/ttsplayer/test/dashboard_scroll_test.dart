import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_coordinator.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_restorer.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/app_navigator.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  final Catalog _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}

  @override
  Future<ScannerConfigSummary?> readScannerConfig() async => null;

  @override
  String? get catalogPath => 'bundled';
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

Catalog _tallDashboardCatalog() {
  MediaFolder library(String id, String name) {
    return MediaFolder(
      id: id,
      name: name,
      path: r'Y:\Media\' + name,
      itemCount: 1,
      items: [
        MediaItem(
          id: 'item-$id',
          title: '$name Sample',
          filePath: r'Y:\Media\' + name + r'\sample.mp4',
        ),
      ],
      subfolders: const [],
    );
  }

  return Catalog.fromJson({
    'generated_at': '2026-07-03T00:00:00+00:00',
    'total_items': 4,
    'folders': [
      library('videos', 'Videos').toJson(),
      library('movies', 'Movies').toJson(),
      library('shows', 'TV Shows').toJson(),
      library('home', 'Home Videos').toJson(),
    ],
  });
}

Widget _dashboardHarness(Catalog catalog) {
  final playbackService = PlaybackService(
    mediaLocationResolver: MediaLocationResolver(
      config: MediaProviderConfig.defaults().mediaAccess,
      isWindowsDesktop: false,
    ),
  );
  final sessionRepository = MusicPlaybackSessionRepository();
  final queueController = MusicPlaybackQueueController(
    playbackService: playbackService,
  );
  final sessionCoordinator = MusicPlaybackSessionCoordinator(
    repository: sessionRepository,
    playbackService: playbackService,
    queueController: queueController,
  );
  final sessionRestorer = MusicPlaybackSessionRestorer(
    repository: sessionRepository,
    queueController: queueController,
    musicLibraryService: MusicLibraryService(),
    playbackService: playbackService,
    sessionCoordinator: sessionCoordinator,
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      ChangeNotifierProvider(
        create: (_) => LibraryMetadataRepository()..initialize(),
      ),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: false,
        ),
      ),
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
      Provider(create: (_) => SearchService()),
      ChangeNotifierProvider<ReadingProgressRepository>.value(
        value: ReadingProgressRepository(),
      ),
      ChangeNotifierProvider(
        create: (context) => ReadingProgressCoordinator(
          repository: context.read<ReadingProgressRepository>(),
        ),
      ),
      Provider(create: (_) => MusicLibraryService()),
      ChangeNotifierProvider<CatalogService>.value(
        value: _FakeCatalogService(catalog),
      ),
      ChangeNotifierProvider<PlaybackService>.value(value: playbackService),
      ChangeNotifierProvider<MusicPlaybackQueueController>.value(
        value: queueController,
      ),
      ChangeNotifierProvider<MusicPlaybackSessionRepository>.value(
        value: sessionRepository,
      ),
      ChangeNotifierProvider<MusicPlaybackSessionCoordinator>.value(
        value: sessionCoordinator,
      ),
      Provider<MusicPlaybackSessionRestorer>.value(value: sessionRestorer),
      ChangeNotifierProvider(create: (_) => ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>.value(
        value: _FakeScanHistoryService(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [routeObserver],
      home: const DashboardScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard scrolls to all sections at constrained height',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'position_item-videos': 120,
      'duration_item-videos': 3600,
    });

    final metadataRepository = LibraryMetadataRepository();
    await metadataRepository.initialize();

    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = _tallDashboardCatalog();
    final playbackService = PlaybackService(
      mediaLocationResolver: MediaLocationResolver(
        config: MediaProviderConfig.defaults().mediaAccess,
        isWindowsDesktop: false,
      ),
    );
    final sessionRepository = MusicPlaybackSessionRepository();
    final queueController = MusicPlaybackQueueController(
      playbackService: playbackService,
    );
    final sessionCoordinator = MusicPlaybackSessionCoordinator(
      repository: sessionRepository,
      playbackService: playbackService,
      queueController: queueController,
    );
    final sessionRestorer = MusicPlaybackSessionRestorer(
      repository: sessionRepository,
      queueController: queueController,
      musicLibraryService: MusicLibraryService(),
      playbackService: playbackService,
      sessionCoordinator: sessionCoordinator,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
          ChangeNotifierProvider<LibraryMetadataRepository>.value(
            value: metadataRepository,
          ),
          Provider(
            create: (context) => MediaLocationResolver(
              config: context.read<MediaProviderConfigService>().mediaAccess,
              isWindowsDesktop: false,
            ),
          ),
          Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
          Provider(create: (_) => SearchService()),
          ChangeNotifierProvider<ReadingProgressRepository>.value(
            value: ReadingProgressRepository(),
          ),
          ChangeNotifierProvider(
            create: (context) => ReadingProgressCoordinator(
              repository: context.read<ReadingProgressRepository>(),
            ),
          ),
          Provider(create: (_) => MusicLibraryService()),
          ChangeNotifierProvider<CatalogService>.value(
            value: _FakeCatalogService(catalog),
          ),
          ChangeNotifierProvider<PlaybackService>.value(value: playbackService),
          ChangeNotifierProvider<MusicPlaybackQueueController>.value(
            value: queueController,
          ),
          ChangeNotifierProvider<MusicPlaybackSessionRepository>.value(
            value: sessionRepository,
          ),
          ChangeNotifierProvider<MusicPlaybackSessionCoordinator>.value(
            value: sessionCoordinator,
          ),
          Provider<MusicPlaybackSessionRestorer>.value(value: sessionRestorer),
          ChangeNotifierProvider(create: (_) => ScannerService()),
          ChangeNotifierProvider<ScanHistoryService>.value(
            value: _FakeScanHistoryService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [routeObserver],
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('CONTINUE WATCHING'), findsOneWidget);
    expect(find.text('STORAGE STATUS'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PROVIDER STATUS'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('PROVIDER STATUS')).dy,
      lessThan(tester.view.physicalSize.height),
    );
  });
}
