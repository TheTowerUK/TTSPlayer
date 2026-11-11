import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/dashboard/widgets/continue_watching_section.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/widgets/continue_reading_section.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'support/reading_progress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Catalog watchingCatalog() {
    return Catalog.fromJson({
      'generated_at': '2026-07-01T10:00:00+00:00',
      'total_items': 2,
      'folders': [
        const MediaFolder(
          id: 'f1',
          name: 'Videos',
          path: r'Y:\Media\Videos',
          itemCount: 2,
          items: [
            MediaItem(
              id: 'item-1',
              title: 'Blott on the Landscape',
              filePath: r'Y:\Media\Videos\blott-a.mp4',
            ),
            MediaItem(
              id: 'item-2',
              title: 'Blott on the Landscape',
              filePath: r'Y:\Media\Videos\blott-b.mp4',
            ),
          ],
          subfolders: [],
        ).toJson(),
      ],
    });
  }

  group('Continue Watching dismissal', () {
    test('persists by media ID and keeps saved position', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });
      final playback = PlaybackService();
      final catalog = watchingCatalog();

      expect((await playback.getContinueWatching(catalog)).single.item.id,
          'item-1');
      await playback.hideFromContinueWatching('item-1');
      expect(await playback.getContinueWatching(catalog), isEmpty);

      final resume = await playback.resumeInfoFor('item-1');
      expect(resume, isNotNull);
      expect(resume!.savedPosition.inSeconds, 120);

      final reloaded = PlaybackService();
      expect(await reloaded.getContinueWatching(catalog), isEmpty);
      expect(
        (await reloaded.resumeInfoFor('item-1'))!.savedPosition.inSeconds,
        120,
      );
    });

    test('Undo restores the Continue Watching card', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });
      final playback = PlaybackService();
      final catalog = watchingCatalog();

      await playback.hideFromContinueWatching('item-1');
      await playback.restoreToContinueWatching('item-1');
      expect((await playback.getContinueWatching(catalog)).single.item.id,
          'item-1');
    });

    test('new progress makes a dismissed item eligible again', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });
      final playback = PlaybackService();
      final catalog = watchingCatalog();

      await playback.hideFromContinueWatching('item-1');
      expect(await playback.getContinueWatching(catalog), isEmpty);

      await playback.persistResumeStateForTest(
        'item-1',
        const Duration(seconds: 180),
        duration: const Duration(seconds: 3600),
      );
      expect((await playback.getContinueWatching(catalog)).single.item.id,
          'item-1');
    });

    test('identical titles stay independent by media ID', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
        'position_item-2': 200,
        'duration_item-2': 3600,
      });
      final playback = PlaybackService();
      final catalog = watchingCatalog();

      await playback.hideFromContinueWatching('item-1');
      final remaining = await playback.getContinueWatching(catalog);
      expect(remaining, hasLength(1));
      expect(remaining.single.item.id, 'item-2');
      expect(remaining.single.item.title, 'Blott on the Landscape');
    });
  });

  group('Continue Reading dismissal', () {
    test('persists by media ID and keeps the progress record', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65EpubRecord(mediaId: 'book-epub'));
      final catalog = phase65ReadingCatalog();
      const projection = ContinueReadingProjection();

      expect(
        projection
            .build(catalog: catalog, repository: repository)
            .map((e) => e.item.id),
        contains('book-epub'),
      );

      await repository.hideFromContinueReading('book-epub');
      expect(
        projection.build(catalog: catalog, repository: repository),
        isEmpty,
      );
      expect(repository.getByMediaId('book-epub'), isNotNull);

      final reloaded = ReadingProgressRepository();
      await reloaded.initialize();
      expect(
        projection.build(catalog: catalog, repository: reloaded),
        isEmpty,
      );
      expect(reloaded.getByMediaId('book-epub'), isNotNull);
    });

    test('Undo restores Continue Reading', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65EpubRecord(mediaId: 'book-epub'));
      final catalog = phase65ReadingCatalog();

      await repository.hideFromContinueReading('book-epub');
      await repository.restoreToContinueReading('book-epub');
      expect(
        const ContinueReadingProjection()
            .build(catalog: catalog, repository: repository)
            .single
            .item
            .id,
        'book-epub',
      );
    });

    test('new reading progress reveals a dismissed item', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-epub',
          lastReadAt: DateTime.utc(2026, 7, 27, 10),
          progressFraction: 0.2,
        ),
      );
      await repository.hideFromContinueReading('book-epub');
      final catalog = phase65ReadingCatalog();
      expect(
        const ContinueReadingProjection()
            .build(catalog: catalog, repository: repository),
        isEmpty,
      );

      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-epub',
          lastReadAt: DateTime.utc(2026, 7, 27, 12),
          progressFraction: 0.35,
        ),
      );
      expect(
        const ContinueReadingProjection()
            .build(catalog: catalog, repository: repository)
            .single
            .item
            .id,
        'book-epub',
      );
    });

    test('identical titles stay independent by media ID', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-a',
          title: 'Blott on the Landscape',
        ),
      );
      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-b',
          title: 'Blott on the Landscape',
        ),
      );
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-27T12:00:00+00:00',
        'total_items': 2,
        'folders': [
          MediaFolder(
            id: 'books',
            name: 'Books',
            path: r'Y:\Media\Books',
            itemCount: 2,
            items: [
              phase65EpubItem(id: 'book-a', title: 'Blott on the Landscape'),
              phase65EpubItem(id: 'book-b', title: 'Blott on the Landscape'),
            ],
            subfolders: const [],
          ).toJson(),
        ],
      });

      await repository.hideFromContinueReading('book-a');
      final remaining = const ContinueReadingProjection()
          .build(catalog: catalog, repository: repository);
      expect(remaining, hasLength(1));
      expect(remaining.single.item.id, 'book-b');
    });
  });

  group('Continue row widgets', () {
    testWidgets('overflow remove does not open the player and offers Undo',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final playback = PlaybackService();
      const item = MediaItem(
        id: 'cw-1',
        title: 'Film One',
        filePath: r'Y:\Media\Movies\one.mp4',
      );
      await tester.pumpWidget(
        _wrap(
          playback: playback,
          child: const ContinueWatchingSection(
            entries: [
              ContinueWatchingEntry(
                item: item,
                resume: ResumeInfo(
                  savedPosition: Duration(seconds: 40),
                  totalDuration: Duration(minutes: 90),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_watching_menu_cw-1')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerScreen), findsNothing);

      await tester.tap(find.byKey(const Key('continue_watching_remove_cw-1')));
      await tester.pumpAndSettle();
      expect(find.text('Film One'), findsNothing);
      expect(find.text('Removed from Continue Watching'), findsOneWidget);
      expect(find.byType(PlayerScreen), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Film One'), findsOneWidget);
    });

    testWidgets('clamps scroll after removing a card near the end',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final playback = PlaybackService();
      await tester.pumpWidget(
        _wrap(
          playback: playback,
          child: ContinueWatchingSection(
            entries: List.generate(
              8,
              (index) => ContinueWatchingEntry(
                item: MediaItem(
                  id: 'cw-$index',
                  title: 'Film $index',
                  filePath: r'Y:\Media\Movies\film.mp4',
                ),
                resume: const ResumeInfo(
                  savedPosition: Duration(seconds: 40),
                  totalDuration: Duration(minutes: 90),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final next = find.byKey(const Key('carousel_nav_next_continue_watching'));
      while (tester
              .widget<IconButton>(
                find.descendant(of: next, matching: find.byType(IconButton)),
              )
              .onPressed !=
          null) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('continue_watching_menu_cw-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue_watching_remove_cw-7')));
      await tester.pumpAndSettle();

      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(
          position.pixels, lessThanOrEqualTo(position.maxScrollExtent + 0.5));
      expect(position.pixels, greaterThanOrEqualTo(0));
    });

    testWidgets('removing the last Continue Watching item shows empty state',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final playback = PlaybackService();
      await tester.pumpWidget(
        _wrap(
          playback: playback,
          child: const ContinueWatchingSection(
            entries: [
              ContinueWatchingEntry(
                item: MediaItem(
                  id: 'only',
                  title: 'Only Film',
                  filePath: r'Y:\Media\Movies\only.mp4',
                ),
                resume: ResumeInfo(
                  savedPosition: Duration(seconds: 40),
                  totalDuration: Duration(minutes: 90),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_watching_menu_only')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue_watching_remove_only')));
      await tester.pumpAndSettle();

      expect(find.text('Nothing in progress.'), findsOneWidget);
      expect(find.byKey(const Key('carousel_nav_next_continue_watching')),
          findsNothing);
    });

    testWidgets('Continue Reading overflow remove offers Undo', (tester) async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65EpubRecord(mediaId: 'book-epub'));
      final catalog = phase65ReadingCatalog();

      await tester.pumpWidget(
        _wrap(
          playback: PlaybackService(),
          reading: repository,
          child: Consumer<ReadingProgressRepository>(
            builder: (context, repo, _) {
              return ContinueReadingSection(
                entries: const ContinueReadingProjection().build(
                  catalog: catalog,
                  repository: repo,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continue_reading_card_book-epub')),
          findsOneWidget);

      await tester
          .tap(find.byKey(const Key('continue_reading_menu_book-epub')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('continue_reading_remove_book-epub')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continue_reading_card_book-epub')),
          findsNothing);
      expect(find.text('Removed from Continue Reading'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continue_reading_card_book-epub')),
          findsOneWidget);
    });
  });
}

Widget _wrap({
  required PlaybackService playback,
  required Widget child,
  ReadingProgressRepository? reading,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: false,
        ),
      ),
      Provider<ArtworkService>.value(
        value: ArtworkService(fileExists: (_) => false),
      ),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      if (reading != null)
        ChangeNotifierProvider<ReadingProgressRepository>.value(value: reading),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}
