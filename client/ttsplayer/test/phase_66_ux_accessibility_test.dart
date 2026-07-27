import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/reading/widgets/continue_reading_section.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/widgets/tts_app_bar.dart';

import 'support/book_comic_catalog_fixtures.dart';
import 'support/reading_progress_test_support.dart';

/// Phase 6.6 UX and accessibility regression tests (P66-UX-*).
///
/// Simulates display scaling via [TextScaler] and [devicePixelRatio].
/// Native Windows DPI changes beyond the validation host baseline are
/// documented in `docs/roadmap/m6-phase-6.6-reader-hardening.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scaleLevels = <double>[1.0, 1.25, 1.5, 1.75, 2.0];

  late Catalog catalog;
  late SettingsRepository settings;
  late LibraryMetadataRepository metadata;
  late ReadingProgressRepository readingRepository;
  late ReadingProgressCoordinator readingCoordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    catalog = Catalog.fromJson(
      jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
    );
    settings = SettingsRepository();
    await settings.initialize();
    metadata = LibraryMetadataRepository();
    await metadata.initialize();
    readingRepository = await initializedReadingProgressRepository();
    readingCoordinator = ReadingProgressCoordinator(repository: readingRepository);
  });

  Widget scaledHarness({
    required Widget home,
    Size viewport = const Size(1280, 800),
    double scale = 1.0,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: viewport,
        devicePixelRatio: scale,
        textScaler: TextScaler.linear(scale),
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
          ChangeNotifierProvider<SettingsRepository>.value(value: settings),
          ChangeNotifierProvider<LibraryMetadataRepository>.value(
            value: metadata,
          ),
          ChangeNotifierProvider<ReadingProgressRepository>.value(
            value: readingRepository,
          ),
          ChangeNotifierProvider<ReadingProgressCoordinator>.value(
            value: readingCoordinator,
          ),
          Provider(
            create: (context) => MediaLocationResolver(
              config: context.read<MediaProviderConfigService>().mediaAccess,
              isWindowsDesktop: true,
            ),
          ),
          Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
          ChangeNotifierProvider<CatalogService>.value(
            value: _InlineCatalogService(catalog),
          ),
          ChangeNotifierProvider(
            create: (context) => PlaybackService(
              mediaLocationResolver: context.read<MediaLocationResolver>(),
            ),
          ),
          ChangeNotifierProvider(create: (_) => ScannerService()),
          ChangeNotifierProvider<ScanHistoryService>.value(
            value: _FakeScanHistoryService(),
          ),
        ],
        child: MaterialApp(home: home),
      ),
    );
  }

  MediaItem longTitleBook() => MediaItem(
        id: 'long-book',
        title: 'The Complete Annotated History of '
            '${'Very Long Chapter Names ' * 8}Volume IX',
        filePath: r'Y:\Media\Books\long_title_book.pdf',
        mediaKindRaw: MediaKind.book.name,
        status: MediaItemStatus.available,
      );

  group('P66-UX scaling matrix', () {
    for (final scale in scaleLevels) {
      testWidgets('book detail at ${(scale * 100).round()}% equivalent scale',
          (tester) async {
        await tester.pumpWidget(
          scaledHarness(
            scale: scale,
            home: ItemDetailScreen(item: longTitleBook()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TtsAppBar), findsOneWidget);
        expect(find.byKey(const Key('item_detail_open_book')), findsOneWidget);
      });
    }

    for (final scale in scaleLevels) {
      testWidgets(
          'Continue Reading at ${(scale * 100).round()}% equivalent scale',
          (tester) async {
        await readingRepository.upsert(
          phase65PdfRecord(
            mediaId: 'book-pdf',
            lastReadAt: phase65Utc(2026, 7, 27, 12),
          ),
        );
        final entries = ContinueReadingProjection().build(
          catalog: catalog,
          repository: readingRepository,
        );

        await tester.pumpWidget(
          scaledHarness(
            scale: scale,
            home: ContinueReadingSection(entries: entries),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('continue_reading_section')), findsOneWidget);
      });
    }
  });

  group('P66-UX narrow window', () {
    testWidgets('book detail at 900x420 does not overflow', (tester) async {
      await tester.pumpWidget(
        scaledHarness(
          viewport: const Size(900, 420),
          home: ItemDetailScreen(
            item: MediaItem(
              id: 'long-path-book',
              title: longTitleBook().title,
              filePath: r'Y:\Media\Books\nested\deep\'
                  '${'very_long_folder_name\\' * 6}book.pdf',
              mediaKindRaw: MediaKind.book.name,
              status: MediaItemStatus.available,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('P66-UX semantics', () {
    testWidgets('Continue Reading card exposes composite label and progress',
        (tester) async {
      await readingRepository.upsert(
        phase65PdfRecord(
          mediaId: 'book-pdf',
          pageIndex: 2,
          pageCountAtSave: 10,
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );
      final entries = ContinueReadingProjection().build(
        catalog: catalog,
        repository: readingRepository,
      );

      await tester.pumpWidget(
        scaledHarness(home: ContinueReadingSection(entries: entries)),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('continue_reading_card_book-pdf')),
      );
      expect(semantics.label, contains('Owner Manual'));
      expect(semantics.label, contains('% read'));
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
    });

    testWidgets('CBR unavailable Continue Reading card is not a button',
        (tester) async {
      await readingRepository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-cbr',
          archiveFormat: ReadingReaderFormat.cbr,
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );
      final entries = ContinueReadingProjection(
        cbrToolingAvailable: false,
      ).build(
        catalog: catalog,
        repository: readingRepository,
      );

      await tester.pumpWidget(
        scaledHarness(home: ContinueReadingSection(entries: entries)),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('continue_reading_card_comic-cbr')),
      );
      expect(semantics.hasFlag(SemanticsFlag.isButton), isFalse);
      expect(semantics.label, contains('UnRAR'));
    });

    testWidgets('Open Book button has accessible label', (tester) async {
      await tester.pumpWidget(
        scaledHarness(home: ItemDetailScreen(item: phase65BookItem())),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('item_detail_open_book')),
      );
      expect(semantics.label, 'Open Book');
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
    });
  });
}

class _InlineCatalogService extends CatalogService {
  _InlineCatalogService(this._catalog);

  final Catalog _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}
