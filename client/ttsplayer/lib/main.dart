import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'navigation/app_navigator.dart';
import 'services/artwork/artwork_service.dart';
import 'services/catalog_service.dart';
import 'services/media_access/media_provider_config_service.dart';
import 'services/media_access/media_location_resolver.dart';
import 'services/playback_service.dart';
import 'services/scan_history_service.dart';
import 'services/scanner_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    MediaKit.ensureInitialized();
  }

  final providerConfigService = MediaProviderConfigService();
  await providerConfigService.load();

  final isWindowsDesktop = !kIsWeb && Platform.isWindows;
  final mediaLocationResolver = MediaLocationResolver(
    config: providerConfigService.mediaAccess,
    isWindowsDesktop: isWindowsDesktop,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MediaProviderConfigService>.value(
          value: providerConfigService,
        ),
        Provider<MediaLocationResolver>.value(value: mediaLocationResolver),
        Provider(create: (_) => ArtworkService()),
        ChangeNotifierProvider(create: (_) => CatalogService()),
        ChangeNotifierProvider(
          create: (_) => PlaybackService(
            mediaLocationResolver: mediaLocationResolver,
          ),
        ),
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
