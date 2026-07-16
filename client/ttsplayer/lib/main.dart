import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/search/search_service.dart';
import 'navigation/app_navigator.dart';
import 'services/artwork/artwork_service.dart';
import 'services/catalog_cache_coordinator.dart';
import 'services/catalog_service.dart';
import 'services/media_access/media_provider_config_service.dart';
import 'services/media_access/media_location_resolver.dart';
import 'services/library/library_metadata_repository.dart';
import 'services/settings/settings_repository.dart';
import 'services/diagnostics/diagnostics_service.dart';
import 'services/playback_service.dart';
import 'services/scan_history_service.dart';
import 'services/scanner_service.dart';
import 'theme/app_theme.dart';
import 'widgets/artwork/artwork_image.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final applicationStartedAt = DateTime.now().toUtc();
  configureArtworkFlutterImageCache();
  if (!kIsWeb && Platform.isWindows) {
    MediaKit.ensureInitialized();
  }

  final providerConfigService = MediaProviderConfigService();
  await providerConfigService.load();

  final settingsRepository = SettingsRepository();
  await settingsRepository.initialize();

  final artworkService = ArtworkService();
  final searchService = SearchService();

  final isWindowsDesktop = !kIsWeb && Platform.isWindows;
  final mediaLocationResolver = MediaLocationResolver(
    config: providerConfigService.mediaAccess,
    isWindowsDesktop: isWindowsDesktop,
  );

  final libraryMetadataRepository = LibraryMetadataRepository();
  await libraryMetadataRepository.initialize();

  final catalogCacheCoordinator = CatalogCacheCoordinator(
    artworkService: artworkService,
    searchService: searchService,
    libraryMetadataRepository: libraryMetadataRepository,
  );

  final catalogService = CatalogService(
    settingsRepository: settingsRepository,
    onCatalogReplaced: catalogCacheCoordinator.onCatalogReplaced,
  );

  final playbackService = PlaybackService(
    mediaLocationResolver: mediaLocationResolver,
    defaultPlaybackRateProvider: () => settingsRepository.defaultPlaybackRate,
  );

  final diagnosticsService = DiagnosticsService(
    catalogService: catalogService,
    artworkService: artworkService,
    searchService: searchService,
    playbackService: playbackService,
    mediaProviderConfigService: providerConfigService,
    libraryMetadataRepository: libraryMetadataRepository,
    applicationStartedAt: applicationStartedAt,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MediaProviderConfigService>.value(
          value: providerConfigService,
        ),
        ChangeNotifierProvider<SettingsRepository>.value(
          value: settingsRepository,
        ),
        ChangeNotifierProvider<LibraryMetadataRepository>.value(
          value: libraryMetadataRepository,
        ),
        Provider<MediaLocationResolver>.value(value: mediaLocationResolver),
        Provider<ArtworkService>.value(value: artworkService),
        Provider<SearchService>.value(value: searchService),
        ChangeNotifierProvider<CatalogService>.value(
          value: catalogService,
        ),
        ChangeNotifierProvider<PlaybackService>.value(
          value: playbackService,
        ),
        Provider<DiagnosticsService>.value(value: diagnosticsService),
        ChangeNotifierProvider(create: (_) => ScannerService()),
        ChangeNotifierProvider(create: (_) => ScanHistoryService()),
      ],
      child: const TTSPlayerApp(),
    ),
  );
}

class TTSPlayerApp extends StatelessWidget {
  const TTSPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTSPlayer',
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const DashboardScreen(),
    );
  }
}
