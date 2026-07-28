import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/comic_page_ref.dart';
import 'package:ttsplayer/features/comics/reader/comic_fit_mode.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_screen.dart';
import 'package:ttsplayer/features/comics/reader/comic_viewport.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';

import 'support/comic_test_fixtures.dart';
import 'support/reading_progress_test_support.dart';

class _PngFakeSource implements ComicArchiveSource {
  _PngFakeSource(this.pageCount);

  final int pageCount;

  @override
  Future<List<ComicPageRef>> listPages() async => [
        for (var i = 0; i < pageCount; i++)
          ComicPageRef(entryName: 'page_$i.png', index: i),
      ];

  @override
  Future<List<int>> loadPageBytes(String entryName) async {
    return tinyPng(entryName.hashCode).toList(growable: false);
  }

  @override
  Future<void> dispose() async {}
}

Future<ComicReaderController> readyComicController({
  int pageCount = 5,
  int initialIndex = 0,
}) async {
  final source = _PngFakeSource(pageCount);
  final controller = ComicReaderController(
    source: source,
    prefetchAdjacent: false,
  );
  await controller.open(initialPageIndex: initialIndex);
  for (var i = 0; i < pageCount; i++) {
    await controller.goToIndex(i);
  }
  await controller.goToIndex(initialIndex);
  return controller;
}

Future<_ReaderHarness> pumpComicReader(
  WidgetTester tester, {
  required ComicReaderController controller,
  required ReadingProgressCoordinator coordinator,
  int pageCount = 5,
}) async {
  final item = phase65ComicItem(
    id: 'comic-ui-test',
    title: 'Interaction Comic',
    filePath: r'Y:\Media\Comics\ui.cbz',
  );

  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  late State<ComicReaderScreen> readerState;
  await tester.pumpWidget(
    ChangeNotifierProvider<ReadingProgressCoordinator>.value(
      value: coordinator,
      child: MaterialApp(
        home: ComicReaderScreen(
          item: item,
          source: _PngFakeSource(pageCount),
          debugController: controller,
        ),
      ),
    ),
  );

  // Reach state via element tree for visibleForTesting getters.
  final stateElement = tester.element(find.byType(ComicReaderScreen)) as StatefulElement;
  readerState = stateElement.state as State<ComicReaderScreen>;

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return _ReaderHarness(
    controller: controller,
    screenState: readerState,
    coordinator: coordinator,
  );
}

class _ReaderHarness {
  _ReaderHarness({
    required this.controller,
    required this.screenState,
    required this.coordinator,
  });

  final ComicReaderController controller;
  final State<ComicReaderScreen> screenState;
  final ReadingProgressCoordinator coordinator;
}

extension on State<ComicReaderScreen> {
  ComicFitMode get testFitMode =>
      (this as dynamic).fitMode as ComicFitMode;
  bool get testChromeVisible =>
      (this as dynamic).chromeVisible as bool;
}

Future<void> sendWheelDelta(
  WidgetTester tester,
  double dy,
) async {
  final state = tester.state<ComicViewportState>(find.byType(ComicViewport));
  state.debugWheelDelta(dy);
  await tester.pump();
}

Finder get comicViewport => find.byType(ComicViewport);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingProgressRepository repository;
  late ReadingProgressCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = await initializedReadingProgressRepository();
    coordinator = ReadingProgressCoordinator(repository: repository);
  });

  tearDown(() {
    coordinator.dispose();
  });

  group('Phase 6.4C fit modes', () {
    testWidgets('defaults to contain', (tester) async {
      final controller = await readyComicController();
      addTearDown(controller.dispose);
      final harness = await pumpComicReader(tester, controller: controller, coordinator: coordinator);
      expect(harness.screenState.testFitMode, ComicFitMode.contain);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('fit width and fit height update presentation and reset transform',
        (tester) async {
      final controller = await readyComicController();
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator);

      await tester.tap(find.byKey(const Key('comic_reader_fit_mode_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comic_reader_fit_fitWidth')));
      await tester.pumpAndSettle();

      var image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.fitWidth);

      final viewportState =
          tester.state<ComicViewportState>(comicViewport);
      viewportState.transformController.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();

      await tester.tap(find.byKey(const Key('comic_reader_fit_mode_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comic_reader_fit_fitHeight')));
      await tester.pumpAndSettle();

      image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.fitHeight);
      expect(
        comicViewportScaleBeyondBase(viewportState.transformController.value),
        isFalse,
      );
    });

    testWidgets('page change resets transform', (tester) async {
      final controller = await readyComicController();
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator);

      final viewportState =
          tester.state<ComicViewportState>(comicViewport);
      viewportState.transformController.value = Matrix4.diagonal3Values(1.8, 1.8, 1);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(
        comicViewportScaleBeyondBase(viewportState.transformController.value),
        isFalse,
      );
    });

    testWidgets('fit mode change does not write progress', (tester) async {
      final controller = await readyComicController();
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator);
      await coordinator.waitForIdleForTest();
      final writesBefore = coordinator.lastSuccessfulFlushAt;

      await tester.tap(find.byKey(const Key('comic_reader_fit_mode_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comic_reader_fit_fitWidth')));
      await tester.pumpAndSettle();
      await coordinator.waitForIdleForTest();

      expect(coordinator.lastSuccessfulFlushAt, writesBefore);
    });
  });

  group('Phase 6.4C keyboard navigation', () {
    testWidgets('arrow and page keys navigate once and stay bounded', (tester) async {
      final controller = await readyComicController(pageCount: 3);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 3);

      expect(find.textContaining('Page 1 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.pageIndex, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(controller.pageIndex, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(controller.pageIndex, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.pageIndex, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(controller.pageIndex, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(controller.pageIndex, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.pageIndex, 0);
    });

    testWidgets('escape reveals chrome before close would run', (tester) async {
      final controller = await readyComicController(pageCount: 2);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 2);

      final viewport = comicViewport;
      final center = tester.getCenter(viewport);
      await tester.tapAt(center);
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('Phase 6.4C mouse wheel', () {
    testWidgets('wheel at base transform moves one page', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewport = comicViewport;
      await sendWheelDelta(tester, 140);
      expect(controller.pageIndex, 1);

      await sendWheelDelta(tester, -140);
      expect(controller.pageIndex, 0);
    });

    testWidgets('wheel while zoomed does not change page', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewportState =
          tester.state<ComicViewportState>(comicViewport);
      viewportState.transformController.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();

      await sendWheelDelta(tester, 200);
      expect(controller.pageIndex, 0);
    });
  });

  group('Phase 6.4C tap zones and chrome', () {
    testWidgets('side zones and centre chrome toggle', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewport = comicViewport;
      final rect = tester.getRect(viewport);
      await tester.tapAt(Offset(rect.left + rect.width * 0.88, rect.center.dy));
      await tester.pump();
      expect(controller.pageIndex, 1);

      await tester.tapAt(Offset(rect.left + rect.width * 0.12, rect.center.dy));
      await tester.pump();
      expect(controller.pageIndex, 0);

      expect(find.byType(AppBar), findsOneWidget);
      await tester.tap(find.byKey(const Key('comic_reader_immersive_toggle')));
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);

      await tester.tapAt(rect.center);
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('toolbar buttons do not act as side zones', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      await tester.tap(find.byKey(const Key('comic_reader_next')));
      await tester.pump();
      expect(controller.pageIndex, 1);
    });

    testWidgets('drag does not trigger tap zone navigation', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewport = comicViewport;
      final rect = tester.getRect(viewport);
      final start = Offset(rect.left + rect.width * 0.88, rect.center.dy);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.up();
      await tester.pump();
      expect(controller.pageIndex, 0);
    });

    testWidgets('controls disable at bounds', (tester) async {
      final controller = await readyComicController(pageCount: 2);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 2);

      final prev = tester.widget<IconButton>(find.byKey(const Key('comic_reader_prev')));
      final next = tester.widget<IconButton>(find.byKey(const Key('comic_reader_next')));
      expect(prev.onPressed, isNull);
      expect(next.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('comic_reader_next')));
      await tester.pump();

      final prev2 = tester.widget<IconButton>(find.byKey(const Key('comic_reader_prev')));
      final next2 = tester.widget<IconButton>(find.byKey(const Key('comic_reader_next')));
      expect(prev2.onPressed, isNotNull);
      expect(next2.onPressed, isNull);
    });
  });

  group('Phase 6.4C swipe navigation', () {
    testWidgets('horizontal swipe at contain base transform changes page once',
        (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewport = comicViewport;
      await tester.drag(viewport, const Offset(-120, 0));
      await tester.pump();
      expect(controller.pageIndex, 1);

      await tester.drag(viewport, const Offset(120, 0));
      await tester.pump();
      expect(controller.pageIndex, 0);
    });

    testWidgets('short and vertical drags do not navigate', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewport = comicViewport;
      await tester.drag(viewport, const Offset(-10, 0));
      await tester.pump();
      expect(controller.pageIndex, 0);

      await tester.drag(viewport, const Offset(0, 120));
      await tester.pump();
      expect(controller.pageIndex, 0);
    });

    testWidgets('swipe while zoomed does not change page', (tester) async {
      final controller = await readyComicController(pageCount: 4);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 4);

      final viewportState =
          tester.state<ComicViewportState>(comicViewport);
      viewportState.transformController.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();

      await tester.drag(comicViewport, const Offset(-120, 0));
      await tester.pump();
      expect(controller.pageIndex, 0);
    });
  });

  group('Phase 6.4C progress with chrome hidden', () {
    testWidgets('closing with hidden chrome still flushes progress', (tester) async {
      final controller = await readyComicController(pageCount: 3);
      addTearDown(controller.dispose);
      await pumpComicReader(tester, controller: controller, coordinator: coordinator, pageCount: 3);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final viewport = comicViewport;
      await tester.tapAt(tester.getCenter(viewport));
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byKey(const Key('comic_reader_back')));
      await tester.pumpAndSettle();
      await coordinator.waitForIdleForTest();

      expect(coordinator.lastSuccessfulFlushAt, isNotNull);
      expect(repository.getByMediaId('comic-ui-test'), isNotNull);
    });
  });
}
