import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_presentation_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/library/folder_presentation_config.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
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
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';
import 'package:ttsplayer/widgets/tts_folder_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LibraryMetadataRepository metadata;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    metadata = LibraryMetadataRepository();
    await metadata.initialize();
  });

  testWidgets('single-book folder card uses an uncropped 2:3 cover slot',
      (tester) async {
    final folder = _readerLeaf(
      id: 'blott',
      name: 'Blott on the Landscape',
      filePath:
          r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Blott\blott.epub',
    );

    await tester.pumpWidget(
      _cardHarness(
        SizedBox(
          width: 200,
          height: 384,
          child: TtsFolderCard(
            folder: folder,
            onTap: () {},
            onDetails: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final slot = tester.widget<SizedBox>(
      find.byKey(const Key('folder_reader_cover_blott')),
    );
    expect(slot.width! / slot.height!, closeTo(2 / 3, 0.001));
    expect(
      tester.widget<ArtworkImage>(find.byType(ArtworkImage)).fit,
      BoxFit.contain,
    );
    expect(find.byKey(const Key('folder_details_blott')), findsOneWidget);
  });

  testWidgets('collection folder card keeps the landscape cover band',
      (tester) async {
    await tester.pumpWidget(
      _cardHarness(
        SizedBox(
          width: 318,
          height: 246,
          child: TtsFolderCard(
            folder: _folder(
              id: 'calibre',
              name: 'Calibre',
              subfolders: [
                _readerLeaf(
                  id: 'blott',
                  name: 'Blott',
                  filePath: r'Y:\Media\blott.epub',
                ),
              ],
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('folder_reader_cover_calibre')), findsNothing);
    expect(
      tester.widget<ArtworkImage>(find.byType(ArtworkImage)).fit,
      BoxFit.cover,
    );
  });

  testWidgets('Tom Sharpe-style folder uses the reader cover grid',
      (tester) async {
    final catalog = _catalogOf(
      _folder(
        id: 'tom-sharpe',
        name: 'Tom Sharpe',
        path: r'Y:\Media\Literature\Books\Calibre\Tom Sharpe',
        subfolders: [
          _readerLeaf(
            id: 'blott',
            name: 'Blott on the Landscape',
            filePath:
                r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Blott\blott.epub',
          ),
          _readerLeaf(
            id: 'riotous',
            name: 'Riotous Assembly',
            filePath:
                r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Riotous\riotous.epub',
          ),
        ],
      ),
    );

    await _openFolder(tester, catalog: catalog, metadata: metadata);

    expect(_firstGridDelegate(tester),
        FolderPresentationConfig.readerCoverGridDelegate);
    expect(find.byKey(const Key('folder_reader_cover_blott')), findsOneWidget);
    expect(
        find.byKey(const Key('folder_reader_cover_riotous')), findsOneWidget);
    expect(
      tester.widget<ArtworkImage>(find.byType(ArtworkImage).first).fit,
      BoxFit.contain,
    );
  });

  testWidgets('mixed folder keeps landscape grid for collection cards',
      (tester) async {
    final catalog = _catalogOf(
      _folder(
        id: 'mixed',
        name: 'Mixed Author',
        path: r'Y:\Media\Literature\Books\Calibre\Mixed',
        subfolders: [
          _readerLeaf(
            id: 'blott',
            name: 'Blott on the Landscape',
            filePath: r'Y:\Media\blott.epub',
          ),
          _folder(
            id: 'series',
            name: 'A Series',
            subfolders: [
              _readerLeaf(
                id: 'vol1',
                name: 'Vol 1',
                filePath: r'Y:\Media\vol1.epub',
              ),
            ],
          ),
        ],
      ),
    );

    await _openFolder(tester, catalog: catalog, metadata: metadata);

    expect(_firstGridDelegate(tester),
        FolderPresentationConfig.subfolderGridDelegate);
    expect(find.byKey(const Key('folder_reader_cover_blott')), findsOneWidget);
    expect(find.byKey(const Key('folder_reader_cover_series')), findsNothing);
    final fits = tester
        .widgetList<ArtworkImage>(find.byType(ArtworkImage))
        .map((image) => image.fit)
        .toSet();
    expect(fits, containsAll(<BoxFit>[BoxFit.contain, BoxFit.cover]));
  });
}

SliverGridDelegate _firstGridDelegate(WidgetTester tester) {
  return tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate;
}

Future<void> _openFolder(
  WidgetTester tester, {
  required Catalog catalog,
  required LibraryMetadataRepository metadata,
}) async {
  await tester.pumpWidget(
    _folderHarness(
      catalog: catalog,
      metadata: metadata,
      home: FolderScreen.fromFolder(catalog.folders.single),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _cardHarness(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: false,
        ),
      ),
      Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

Widget _folderHarness({
  required Catalog catalog,
  required LibraryMetadataRepository metadata,
  required Widget home,
}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1280, 800)),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
        ChangeNotifierProvider(create: (_) => SettingsRepository()),
        ChangeNotifierProvider<LibraryMetadataRepository>.value(
          value: metadata,
        ),
        Provider(
          create: (context) => MediaLocationResolver(
            config: context.read<MediaProviderConfigService>().mediaAccess,
            isWindowsDesktop: true,
          ),
        ),
        Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
        ChangeNotifierProvider<CatalogService>.value(
          value: _FakeCatalogService(catalog),
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
        ChangeNotifierProvider<ReadingProgressRepository>.value(
          value: ReadingProgressRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) => ReadingProgressCoordinator(
            repository: context.read<ReadingProgressRepository>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => MetadataEnrichmentRepository()),
        Provider(create: (_) => const MetadataPresentationService()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: home,
      ),
    ),
  );
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  final Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOnStartup({MediaProviderConfig? providerConfig}) async {}

  @override
  String? get catalogPath => 'bundled';
}

class _FakeScanHistoryService extends ScanHistoryService {
  @override
  Future<void> loadAdjacentTo(String catalogPath) async {}
}

MediaFolder _readerLeaf({
  required String id,
  required String name,
  required String filePath,
}) {
  return _folder(
    id: id,
    name: name,
    items: [
      MediaItem(
        id: '$id-item',
        title: name,
        filePath: filePath,
        mediaKindRaw: filePath.endsWith('.cbz') ? 'comic' : 'book',
      ),
    ],
  );
}

MediaFolder _folder({
  required String id,
  required String name,
  String? path,
  List<MediaFolder> subfolders = const [],
  List<MediaItem> items = const [],
}) {
  return MediaFolder(
    id: id,
    name: name,
    path: path ?? r'Y:\Media\' + name,
    itemCount: items.length +
        subfolders.fold<int>(0, (sum, folder) => sum + folder.itemCount),
    items: items,
    subfolders: subfolders,
  );
}

Catalog _catalogOf(MediaFolder parent) {
  return Catalog.fromJson({
    'generated_at': '2026-11-10T00:00:00+00:00',
    'total_items': parent.totalItems,
    'folders': [parent.toJson()],
  });
}
