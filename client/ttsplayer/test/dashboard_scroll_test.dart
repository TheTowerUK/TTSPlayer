import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/dashboard_screen.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/navigation/app_navigator.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
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
  Future<void> loadOnStartup() async {}

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
  return MultiProvider(
    providers: [
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
      ChangeNotifierProvider<CatalogService>.value(
        value: _FakeCatalogService(catalog),
      ),
      ChangeNotifierProvider(create: (_) => PlaybackService()),
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

    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_dashboardHarness(_tallDashboardCatalog()));
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
    expect(find.text('STORAGE STATUS'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('STORAGE STATUS')).dy,
      lessThan(tester.view.physicalSize.height),
    );
  });
}
