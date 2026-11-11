import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/features/dashboard/dashboard_service.dart';
import 'package:ttsplayer/features/dashboard/widgets/continue_watching_section.dart';
import 'package:ttsplayer/features/dashboard/widgets/featured_folders_section.dart';
import 'package:ttsplayer/features/dashboard/widgets/recently_added_section.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/widgets/continue_reading_section.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/horizontal_carousel_nav_buttons.dart';
import 'package:ttsplayer/widgets/horizontal_carousel_scroll.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HorizontalCarouselScroll', () {
    test('steps nearly one viewport and keeps overlap', () {
      expect(HorizontalCarouselScroll.stepForViewport(400), 336);
      expect(
        HorizontalCarouselScroll.targetOffset(
          current: 0,
          viewport: 400,
          maxExtent: 2000,
          direction: 1,
        ),
        336,
      );
    });

    test('clamps to the valid scroll range', () {
      expect(
        HorizontalCarouselScroll.targetOffset(
          current: 1900,
          viewport: 400,
          maxExtent: 2000,
          direction: 1,
        ),
        2000,
      );
      expect(
        HorizontalCarouselScroll.targetOffset(
          current: 40,
          viewport: 400,
          maxExtent: 2000,
          direction: -1,
        ),
        0,
      );
    });
  });

  group('HorizontalCarouselNavButtons', () {
    testWidgets('pages right then left and disables at each end',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _navHarness(
          controller: controller,
          itemCount: 8,
          itemWidth: 180,
          width: 400,
        ),
      );
      await tester.pumpAndSettle();

      final prev = find.byKey(const Key('carousel_nav_prev_test_row'));
      final next = find.byKey(const Key('carousel_nav_next_test_row'));
      expect(prev, findsOneWidget);
      expect(next, findsOneWidget);
      expect(_iconOnPressed(tester, prev), isNull);
      expect(_iconOnPressed(tester, next), isNotNull);

      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        HorizontalCarouselScroll.stepForViewport(400),
      );
      expect(_iconOnPressed(tester, prev), isNotNull);

      while (_iconOnPressed(tester, next) != null) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(_iconOnPressed(tester, next), isNull);
      expect(_iconOnPressed(tester, prev), isNotNull);

      await tester.tap(prev);
      await tester.pumpAndSettle();
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
    });

    testWidgets('hides both buttons when the row fits', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _navHarness(
          controller: controller,
          itemCount: 2,
          itemWidth: 80,
          width: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('carousel_nav_prev_test_row')), findsNothing);
      expect(find.byKey(const Key('carousel_nav_next_test_row')), findsNothing);
    });

    testWidgets('shows buttons after the viewport shrinks', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var width = 800.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => width = 240),
                      child: const Text('narrow'),
                    ),
                    _NavHost(
                      controller: controller,
                      itemCount: 3,
                      itemWidth: 200,
                      width: width,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('carousel_nav_next_test_row')), findsNothing);

      await tester.tap(find.text('narrow'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('carousel_nav_next_test_row')),
        findsOneWidget,
      );
    });

    testWidgets('hides buttons when the item list shrinks to fit',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var count = 8;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => count = 1),
                      child: const Text('shrink'),
                    ),
                    _NavHost(
                      controller: controller,
                      itemCount: count,
                      itemWidth: 180,
                      width: 400,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('carousel_nav_next_test_row')), findsOneWidget);

      await tester.tap(find.text('shrink'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('carousel_nav_next_test_row')), findsNothing);
    });

    testWidgets('buttons are keyboard-focusable with row direction labels',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _navHarness(
          controller: controller,
          itemCount: 8,
          itemWidth: 180,
          width: 400,
        ),
      );
      await tester.pumpAndSettle();

      final next = find.byKey(const Key('carousel_nav_next_test_row'));
      final nextButton =
          find.descendant(of: next, matching: find.byType(IconButton));
      expect(tester.widget<IconButton>(nextButton).autofocus, isFalse);
      expect(tester.widget<IconButton>(nextButton).onPressed, isNotNull);
      expect(find.byTooltip('Scroll Test Row right'), findsOneWidget);
      expect(find.byTooltip('Scroll Test Row left'), findsOneWidget);

      final handle = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(next).hasFlag(SemanticsFlag.isFocusable),
          isTrue,
        );
        expect(
          tester.getSemantics(next).hasFlag(SemanticsFlag.isButton),
          isTrue,
        );
        expect(
          tester.getSemantics(next).label,
          contains('Scroll Test Row right'),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('dashboard continue rows', () {
    testWidgets('Continue Watching exposes labelled header buttons',
        (tester) async {
      await tester.pumpWidget(
        _dashboardWrap(
          ContinueWatchingSection(
            entries: List.generate(
              6,
              (index) => ContinueWatchingEntry(
                item: MediaItem(
                  id: 'cw-$index',
                  title: 'Film $index',
                  filePath: r'Y:\Media\Movies\film.mp4',
                ),
                resume: const ResumeInfo(
                  savedPosition: Duration(seconds: 30),
                  totalDuration: Duration(minutes: 90),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('carousel_nav_prev_continue_watching')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('carousel_nav_next_continue_watching')),
        findsOneWidget,
      );
      expect(find.byTooltip('Scroll Continue Watching left'), findsOneWidget);
      expect(find.byTooltip('Scroll Continue Watching right'), findsOneWidget);
    });

    testWidgets('Continue Reading exposes labelled header buttons',
        (tester) async {
      await tester.pumpWidget(
        _dashboardWrap(
          ContinueReadingSection(
            entries: List.generate(6, (index) {
              final item = MediaItem(
                id: 'cr-$index',
                title: 'Book $index',
                filePath: r'Y:\Media\Books\book.epub',
                mediaKindRaw: 'book',
              );
              return ContinueReadingEntry(
                item: item,
                record: ReadingProgressRecord(
                  mediaId: item.id,
                  mediaKind: MediaKind.book,
                  readerFormat: ReadingReaderFormat.epub,
                  title: item.title,
                  location: const EpubReadingLocationPayload(
                    spineIndex: 0,
                    spineHref: 'ch1.xhtml',
                    spineCountAtSave: 1,
                  ),
                  progressFraction: 0.2,
                  completed: false,
                  lastReadAt: DateTime.utc(2026, 11, 10),
                ),
                progressPercent: 20,
                locationLabel: 'Chapter 1',
                availability: ContinueReadingAvailability.available,
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('carousel_nav_prev_continue_reading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('carousel_nav_next_continue_reading')),
        findsOneWidget,
      );
      expect(find.byTooltip('Scroll Continue Reading left'), findsOneWidget);
      expect(find.byTooltip('Scroll Continue Reading right'), findsOneWidget);
    });

    testWidgets('Recently Added exposes labelled header buttons',
        (tester) async {
      await tester.pumpWidget(
        _dashboardWrap(
          RecentlyAddedSection(
            entries: List.generate(
              8,
              (index) => RecentlyAddedEntry(
                item: MediaItem(
                  id: 'ra-$index',
                  title: 'New $index',
                  filePath: r'Y:\Media\Movies\new.mp4',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('carousel_nav_prev_recently_added')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('carousel_nav_next_recently_added')),
        findsOneWidget,
      );
    });

    testWidgets('Featured Folders exposes labelled header buttons',
        (tester) async {
      await tester.pumpWidget(
        _dashboardWrap(
          FeaturedFoldersSection(
            folders: List.generate(
              8,
              (index) => MediaFolder(
                id: 'ff-$index',
                name: 'Folder $index',
                path: r'Y:\Media\Folder',
                itemCount: 2,
                items: const [],
                subfolders: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('carousel_nav_prev_featured_folders')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('carousel_nav_next_featured_folders')),
        findsOneWidget,
      );
    });
  });
}

Widget _dashboardWrap(Widget child) {
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
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

IconButton _icon(WidgetTester tester, Finder finder) {
  return tester.widget<IconButton>(
    find.descendant(of: finder, matching: find.byType(IconButton)),
  );
}

VoidCallback? _iconOnPressed(WidgetTester tester, Finder finder) =>
    _icon(tester, finder).onPressed;

Widget _navHarness({
  required ScrollController controller,
  required int itemCount,
  required double itemWidth,
  required double? width,
}) {
  return MaterialApp(
    home: Scaffold(
      body: _NavHost(
        controller: controller,
        itemCount: itemCount,
        itemWidth: itemWidth,
        width: width,
      ),
    ),
  );
}

class _NavHost extends StatelessWidget {
  const _NavHost({
    required this.controller,
    required this.itemCount,
    required this.itemWidth,
    required this.width,
  });

  final ScrollController controller;
  final int itemCount;
  final double itemWidth;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: HorizontalCarouselNavButtons(
            controller: controller,
            sectionLabel: 'Test Row',
            semanticsId: 'test_row',
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            itemBuilder: (_, index) => SizedBox(
              width: itemWidth,
              child: Center(child: Text('item-$index')),
            ),
          ),
        ),
      ],
    );
    if (width == null) return column;
    return SizedBox(width: width, child: column);
  }
}
