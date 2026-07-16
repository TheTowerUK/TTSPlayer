@Tags(['phase45-runtime'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/library/folder_presentation_metrics.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'support/large_catalog_factory.dart';

class _RuntimeCatalogService extends CatalogService {
  _RuntimeCatalogService(this._catalog);

  final Catalog _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}
}

/// Windows runtime validation harness for M4 Phase 4.5 large-folder browsing.
///
/// Run manually:
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_45_RUNTIME='1'
/// flutter test test/phase_45_windows_runtime_test.dart --tags phase45-runtime
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_45_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_45_RUNTIME=1 to run Phase 4.5 runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  const fixtureItemCount = 1500;

  group('Phase 4.5 Windows runtime validation', () {
    late Catalog catalog;
    late ArtworkService artwork;
    late SearchService search;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FolderPresentationMetrics.reset();
      catalog = buildLargeCatalog(itemCount: fixtureItemCount);
      artwork = ArtworkService(fileExists: (_) => false);
      search = SearchService();
    });

    Future<void> pumpLargeFolder(WidgetTester tester) async {
      final folder = largeCatalogFolder(catalog);
      final settings = SettingsRepository();
      await settings.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
            ChangeNotifierProvider<SettingsRepository>.value(value: settings),
            ChangeNotifierProvider(
              create: (_) => LibraryMetadataRepository()..initialize(),
            ),
            Provider(
              create: (context) => MediaLocationResolver(
                config:
                    context.read<MediaProviderConfigService>().mediaAccess,
                isWindowsDesktop: true,
              ),
            ),
            Provider<ArtworkService>.value(value: artwork),
            Provider<SearchService>.value(value: search),
            ChangeNotifierProvider<CatalogService>.value(
              value: _RuntimeCatalogService(catalog),
            ),
            ChangeNotifierProvider(
              create: (context) => PlaybackService(
                mediaLocationResolver: context.read<MediaLocationResolver>(),
              ),
            ),
            ChangeNotifierProvider(create: (_) => ScannerService()),
            ChangeNotifierProvider(create: (_) => ScanHistoryService()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => MediaQuery(
                data: const MediaQueryData(size: Size(1280, 800)),
                child: FolderScreen.fromFolder(folder),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('C2 large folder opens without building every card', (tester) async {
      await pumpLargeFolder(tester);

      expect(tester.takeException(), isNull);
      expect(FolderPresentationMetrics.mediaCardBuildCount, lessThan(80));
      expect(FolderPresentationMetrics.mediaCardBuildCount, lessThan(fixtureItemCount));
      expect(search.indexBuildCount, 0);
    });

    testWidgets('C5 scroll through large folder without overflow or freeze',
        (tester) async {
      await pumpLargeFolder(tester);
      final cacheBefore = artwork.cacheEntryCount;

      for (var pass = 0; pass < 12; pass++) {
        await tester.drag(
          find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ),
          const Offset(0, -900),
        );
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      expect(artwork.cacheEntryCount, lessThanOrEqualTo(500));
      expect(artwork.cacheEntryCount, greaterThanOrEqualTo(cacheBefore));
      expect(FolderPresentationMetrics.mediaCardBuildCount, lessThan(fixtureItemCount));
    });

    testWidgets('C5 resize window while scrolled remains stable', (tester) async {
      await pumpLargeFolder(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(1024, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('open item and return preserves folder scroll', (tester) async {
      await pumpLargeFolder(tester);
      await tester.drag(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('media-card-item-15')),
        400,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      final offsetBefore = scrollable.position.pixels;

      await tester.tap(find.byKey(const ValueKey('media-card-item-15')));
      await tester.pumpAndSettle();
      expect(find.byType(ItemDetailScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, closeTo(offsetBefore, 4));
    });
  });
}
