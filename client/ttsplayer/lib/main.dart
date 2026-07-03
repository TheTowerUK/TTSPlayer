import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'navigation/app_navigator.dart';
import 'services/catalog_service.dart';
import 'services/playback_service.dart';
import 'services/scan_history_service.dart';
import 'services/scanner_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    MediaKit.ensureInitialized();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogService()),
        ChangeNotifierProvider(create: (_) => PlaybackService()),
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const DashboardScreen(),
    );
  }
}
