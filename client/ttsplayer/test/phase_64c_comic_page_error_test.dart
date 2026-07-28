import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/comic_page_ref.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_cache.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_failure.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_screen.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/models/media_item.dart';

import 'support/comic_test_fixtures.dart';
import 'support/reading_progress_test_support.dart';

class ConfigurableFakeSource implements ComicArchiveSource {
  ConfigurableFakeSource(
    this.pages, {
    Map<String, Object>? failOn,
    this.bytesFor,
    this.blockUncachedLoads = false,
    this.holdLoadFor,
  }) : failOn = failOn ?? {};

  final List<ComicPageRef> pages;
  final Map<String, Object> failOn;
  final Map<String, List<int>>? bytesFor;
  bool blockUncachedLoads;
  Completer<void>? holdLoadFor;
  int loadCount = 0;
  bool disposed = false;
  final Set<String> _loadedEntries = {};

  @override
  Future<List<ComicPageRef>> listPages() async => pages;

  @override
  Future<List<int>> loadPageBytes(String entryName) async {
    loadCount++;
    if (holdLoadFor != null) {
      await holdLoadFor!.future;
    }
    if (blockUncachedLoads && !_loadedEntries.contains(entryName)) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.archiveMissing,
        userMessage: 'This comic is no longer available.',
      );
    }
    final failure = failOn[entryName];
    if (failure is ComicArchiveException) throw failure;
    if (failure is Exception) throw failure;
    if (bytesFor != null && bytesFor!.containsKey(entryName)) {
      _loadedEntries.add(entryName);
      return bytesFor![entryName]!;
    }
    _loadedEntries.add(entryName);
    return tinyPng(entryName.hashCode).toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Future<void> waitForCondition(
  bool Function() condition, {
  String? reason,
}) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(reason ?? 'Timed out waiting for condition');
}

Future<ComicReaderController> openController(
  ConfigurableFakeSource source, {
  bool prefetch = false,
}) async {
  final controller = ComicReaderController(
    source: source,
    prefetchAdjacent: prefetch,
  );
  await controller.open();
  return controller;
}

Future<void> pumpReader(
  WidgetTester tester,
  ComicReaderController controller,
  ReadingProgressCoordinator coordinator, {
  String mediaId = 'comic-error-test',
}) async {
  final item = phase65ComicItem(
    id: mediaId,
    title: 'Error Test Comic',
    filePath: r'Y:\Media\Comics\error.cbz',
  );
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<ReadingProgressCoordinator>.value(
      value: coordinator,
      child: MaterialApp(
        home: ComicReaderScreen(
          item: item,
          source: ConfigurableFakeSource(const []),
          debugController: controller,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

ComicArchiveException pageExtractFailure() => ComicArchiveException(
      kind: ComicArchiveErrorKind.pageExtractFailed,
      userMessage: 'This page could not be displayed.',
    );

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

  group('Phase 6.4C archive-level failures', () {
    test('listPages failure leaves reader in archive error', () async {
      final source = _ListFailSource();
      final controller = ComicReaderController(source: source);
      await controller.open();
      expect(controller.state, ComicReaderLoadState.error);
      expect(controller.pages, isEmpty);
      controller.dispose();
    });

    test('legacy CBR remains unsupported at opener', () {
      expect(isSupportedComicArchiveExtension('cbr'), isFalse);
      expect(isSupportedComicArchiveExtension('cbz'), isTrue);
    });
  });

  group('Phase 6.4C current-page failures', () {
    test('corrupt first page shows page failure not archive error', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'bad.png', index: 0),
          const ComicPageRef(entryName: 'good.png', index: 1),
        ],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      expect(controller.state, ComicReaderLoadState.ready);
      expect(controller.error, isNull);
      expect(controller.currentPageFailure, isNotNull);
      expect(controller.pageIndicatorLabel, 'Page 1 of 2');
      await controller.nextPage();
      expect(controller.currentPageBytes, isNotNull);
      await controller.previousPage();
      expect(controller.currentPageFailure, isNotNull);
      controller.dispose();
    });

    test('corrupt middle page allows navigation around it', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
          const ComicPageRef(entryName: 'c.png', index: 2),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      await controller.goToIndex(1);
      expect(controller.currentPageFailure, isNotNull);
      await controller.nextPage();
      expect(controller.currentPageBytes, isNotNull);
      await controller.previousPage();
      expect(controller.currentPageFailure, isNotNull);
      controller.dispose();
    });

    test('corrupt final page does not crash', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      await controller.lastPage();
      expect(controller.state, ComicReaderLoadState.ready);
      expect(controller.currentPageFailure, isNotNull);
      controller.dispose();
    });

    test('failed page retains correct one-based page indicator', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      await controller.goToIndex(1);
      expect(controller.pageIndicatorLabel, 'Page 2 of 2');
      controller.dispose();
    });

    test('page failure does not replace reader with global archive error',
        () async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      expect(controller.state, ComicReaderLoadState.ready);
      expect(controller.pages, isNotEmpty);
      expect(controller.error, isNull);
      controller.dispose();
    });

    test('decode failure maps to failed page state', () async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        bytesFor: {
          'bad.png': [1, 2, 3, 4],
        },
      );
      final controller = await openController(source);
      expect(controller.currentPageBytes, isNotNull);
      controller.reportCurrentPageDecodeFailed();
      expect(controller.currentPageLoadStatus, ComicPageLoadStatus.failed);
      expect(controller.currentPageFailure?.category,
          ComicPageFailureCategory.decodeFailure);
      controller.dispose();
    });
  });

  group('Phase 6.4C preload failures', () {
    test('adjacent preload failure does not disturb current page', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
          const ComicPageRef(entryName: 'c.png', index: 2),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller = await openController(source, prefetch: true);
      expect(controller.pageIndex, 0);
      expect(controller.currentPageBytes, isNotNull);
      await waitForCondition(
        () => controller.failureForEntry('b.png') != null,
        reason: 'Preload failure for b.png was not recorded',
      );
      await controller.goToIndex(1);
      expect(controller.currentPageFailure, isNotNull);
      controller.dispose();
    });

    test('preload failure does not consume cache entries', () async {
      final cache = ComicPageCache(maxEntries: 2);
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller = ComicReaderController(
        source: source,
        cache: cache,
        prefetchAdjacent: true,
      );
      await controller.open();
      await waitForCondition(
        () => controller.failureForEntry('b.png') != null,
      );
      expect(cache.length, 1);
      controller.dispose();
    });

    test('navigating to preload-failed page shows failure state', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller = await openController(source, prefetch: true);
      await waitForCondition(
        () => controller.failureForEntry('b.png') != null,
      );
      await controller.nextPage();
      expect(controller.currentPageFailure, isNotNull);
      expect(controller.currentPageBytes, isNull);
      controller.dispose();
    });

    test('preload failure does not loop indefinitely', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller = await openController(source, prefetch: true);
      await waitForCondition(
        () => controller.failureForEntry('b.png') != null,
      );
      final loadsAfterPrefetch = source.loadCount;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(source.loadCount, loadsAfterPrefetch);
      controller.dispose();
    });

    test('one adjacent preload failure does not block the other', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
          const ComicPageRef(entryName: 'c.png', index: 2),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller = ComicReaderController(
        source: source,
        prefetchAdjacent: true,
      );
      await controller.open(initialPageIndex: 1);
      await waitForCondition(
        () =>
            controller.pageCache.get('a.png') != null &&
            controller.pageCache.get('c.png') != null,
        reason: 'Both neighbors of a failed middle page should preload',
      );
      expect(controller.currentPageFailure, isNotNull);
      controller.dispose();
    });
  });

  group('Phase 6.4C retry', () {
    test('retry clears failure and reloads page', () async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'flip.png', index: 0)],
        failOn: {'flip.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      expect(controller.currentPageFailure, isNotNull);
      source.failOn.clear();
      await controller.retryCurrentPage();
      expect(controller.currentPageBytes, isNotNull);
      expect(controller.currentPageFailure, isNull);
      controller.dispose();
    });

    test('repeated failed retry returns to stable placeholder', () async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      await controller.retryCurrentPage();
      expect(controller.currentPageFailure, isNotNull);
      expect(controller.pageIndex, 0);
      controller.dispose();
    });

    test('retry while loading does not start duplicate loads', () async {
      final hold = Completer<void>();
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'slow.png', index: 0)],
        holdLoadFor: hold,
      );
      final controller = ComicReaderController(
        source: source,
        prefetchAdjacent: false,
      );
      final openFuture = controller.open();
      await waitForCondition(
        () => controller.state == ComicReaderLoadState.loadingPage,
      );
      final loadsBeforeRetry = source.loadCount;
      await controller.retryCurrentPage();
      expect(source.loadCount, loadsBeforeRetry);
      hold.complete();
      await openFuture;
      controller.dispose();
    });

    test('retry does not change page index', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      await controller.goToIndex(1);
      await controller.retryCurrentPage();
      expect(controller.pageIndex, 1);
      controller.dispose();
    });
  });

  group('Phase 6.4C widget page failure UI', () {
    testWidgets('shows page failure placeholder with retry', (tester) async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'bad.png', index: 0),
          const ComicPageRef(entryName: 'good.png', index: 1),
        ],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);

      expect(find.byKey(const Key('comic_reader_page_failure_message')),
          findsOneWidget);
      expect(find.byKey(const Key('comic_reader_page_failure_indicator')),
          findsOneWidget);
      expect(find.byKey(const Key('comic_reader_page_retry')), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.byKey(const Key('comic_reader_next')));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);

      await tester.tap(find.byKey(const Key('comic_reader_prev')));
      await tester.pump();
      expect(find.byKey(const Key('comic_reader_page_failure_message')),
          findsOneWidget);
    });

    testWidgets('escape and toolbar remain available on failed page',
        (tester) async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byKey(const Key('comic_reader_next')), findsOneWidget);

      await tester.tap(find.byKey(const Key('comic_reader_immersive_toggle')));
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('close works from a failed page', (tester) async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      addTearDown(controller.dispose);
      final item = phase65ComicItem(
        id: 'comic-close-test',
        title: 'Close Test',
        filePath: r'Y:\Media\Comics\close.cbz',
      );
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<ReadingProgressCoordinator>.value(
          value: coordinator,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ComicReaderScreen(
                          item: item,
                          source: ConfigurableFakeSource(const []),
                          debugController: controller,
                        ),
                      ),
                    );
                  },
                  child: const Text('home'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('comic_reader_back')));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(ComicReaderScreen), findsNothing);
    });
  });

  group('Phase 6.4C progress on failed pages', () {
    testWidgets('navigating to failed page persists logical index',
        (tester) async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);

      await tester.tap(find.byKey(const Key('comic_reader_next')));
      await tester.pump();
      await coordinator.waitForIdleForTest();

      final record = repository.getByMediaId('comic-error-test');
      expect(record, isNotNull);
      expect((record!.location as ComicReadingLocationPayload).pageIndex, 1);
    });

    testWidgets('closing on failed page flushes progress', (tester) async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);

      await tester.tap(find.byKey(const Key('comic_reader_back')));
      await tester.pumpAndSettle();
      await coordinator.waitForIdleForTest();

      expect(repository.getByMediaId('comic-error-test'), isNotNull);
    });

    testWidgets('restoring to failed page opens placeholder at correct index',
        (tester) async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      await controller.goToIndex(1);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);

      expect(controller.pageIndex, 1);
      expect(find.byKey(const Key('comic_reader_page_failure_message')),
          findsOneWidget);
      expect(find.text('Page 2 of 2'), findsWidgets);
    });

    testWidgets('navigating past failed page updates progress normally',
        (tester) async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
          const ComicPageRef(entryName: 'c.png', index: 2),
        ],
        failOn: {'b.png': pageExtractFailure()},
      );
      final controller =
          await openController(source, prefetch: false);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);

      await tester.tap(find.byKey(const Key('comic_reader_next')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('comic_reader_next')));
      await tester.pump();
      await coordinator.waitForIdleForTest();

      final record = repository.getByMediaId('comic-error-test');
      expect((record!.location as ComicReadingLocationPayload).pageIndex, 2);
    });

    testWidgets('retry does not write reading progress', (tester) async {
      final source = ConfigurableFakeSource(
        [const ComicPageRef(entryName: 'bad.png', index: 0)],
        failOn: {'bad.png': pageExtractFailure()},
      );
      final controller = await openController(source);
      addTearDown(controller.dispose);
      await pumpReader(tester, controller, coordinator);
      await coordinator.waitForIdleForTest();

      final before = repository.getByMediaId('comic-error-test');
      await controller.retryCurrentPage();
      await coordinator.waitForIdleForTest();
      final after = repository.getByMediaId('comic-error-test');
      expect(after?.lastReadAt, before?.lastReadAt);
    });
  });

  group('Phase 6.4C source change after open', () {
    test('uncached loads fail safely after source blocked', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
      );
      final controller =
          await openController(source, prefetch: false);
      expect(controller.currentPageBytes, isNotNull);
      source.blockUncachedLoads = true;
      await controller.nextPage();
      expect(controller.currentPageFailure, isNotNull);
      expect(controller.state, ComicReaderLoadState.ready);
      controller.dispose();
    });

    test('cached pages remain readable after source blocked', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
      );
      final controller =
          await openController(source, prefetch: false);
      source.blockUncachedLoads = true;
      await controller.nextPage();
      expect(controller.currentPageFailure, isNotNull);
      await controller.previousPage();
      expect(controller.currentPageBytes, isNotNull);
      controller.dispose();
    });

    test('closing after source-change failure remains safe', () async {
      final source = ConfigurableFakeSource(
        [
          const ComicPageRef(entryName: 'a.png', index: 0),
          const ComicPageRef(entryName: 'b.png', index: 1),
        ],
      );
      final controller =
          await openController(source, prefetch: false);
      source.blockUncachedLoads = true;
      await controller.nextPage();
      expect(() => controller.dispose(), returnsNormally);
    });
  });
}

class _ListFailSource implements ComicArchiveSource {
  @override
  Future<List<ComicPageRef>> listPages() async {
    throw ComicArchiveException(
      kind: ComicArchiveErrorKind.corruptArchive,
      userMessage: 'This comic archive appears to be damaged.',
    );
  }

  @override
  Future<List<int>> loadPageBytes(String entryName) async => [];

  @override
  Future<void> dispose() async {}
}
