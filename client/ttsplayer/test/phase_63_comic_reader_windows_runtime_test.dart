@Tags(['phase63-reader'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/reader/comic_fit_mode.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_screen.dart';
import 'package:ttsplayer/features/comics/reader/comic_viewport.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/reading_navigation.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/services/reader_session_telemetry.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';

import 'support/comic_test_fixtures.dart';
import 'support/diagnostics_test_harness.dart';
import 'support/reading_progress_test_support.dart';

extension _ComicReaderScreenTestState on State<ComicReaderScreen> {
  ComicFitMode get testFitMode =>
      (this as dynamic).fitMode as ComicFitMode;
  bool get testChromeVisible =>
      (this as dynamic).chromeVisible as bool;
}

State<ComicReaderScreen> _readerScreenState(WidgetTester tester) {
  final element =
      tester.element(find.byType(ComicReaderScreen)) as StatefulElement;
  return element.state as State<ComicReaderScreen>;
}

/// Opt-in Windows comic reader runtime harness (Phase 6.3 + Phase 6.4C extension).
///
/// Scenario matrix C1–C34 is documented in
/// `docs/roadmap/m6-phase-6.4-comic-reading-experience.md` Step 6.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_63_READER='1'
/// flutter test test/phase_63_comic_reader_windows_runtime_test.dart --tags phase63-reader
/// Remove-Item Env:PHASE_63_READER
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_63_READER'] != '1') {
    test('skipped — set PHASE_63_READER=1', () {}, skip: true);
    return;
  }

  if (!Platform.isWindows) {
    test('skipped — Windows only', () {}, skip: true);
    return;
  }

  late Directory tmp;
  late ReadingProgressRepository progressRepository;
  late ReadingProgressCoordinator readingCoordinator;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tts_p63_');
    SharedPreferences.setMockInitialValues({});
    progressRepository = ReadingProgressRepository();
    await progressRepository.initialize();
    readingCoordinator = ReadingProgressCoordinator(repository: progressRepository);
    ReaderSessionTelemetry.instance.resetForTest();
  });

  tearDown(() async {
    await readingCoordinator.drainPendingWrites();
    readingCoordinator.dispose();
    ReaderSessionTelemetry.instance.resetForTest();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {
      // Windows may briefly lock decoded image buffers.
    }
  });

  final resolver = MediaLocationResolver(
    config: MediaAccessConfig.defaults(),
    isWindowsDesktop: true,
  );

  MediaItem comicItem(String path, {String id = 'c1', String title = 'Gate Comic'}) =>
      MediaItem(
        id: id,
        title: title,
        filePath: path,
        mediaKindRaw: MediaKind.comic.name,
        status: MediaItemStatus.available,
      );

  File multiPageCbz(String name, {int pages = 8}) => writeCbz(tmp, name, {
        for (var i = 1; i <= pages; i++)
          'page_${i.toString().padLeft(3, '0')}.png': tinyPng(i),
      });

  File corruptMiddleCbz(String name) => writeCbz(tmp, name, {
        'page_001.png': tinyPng(1),
        'page_002.png': [1, 2, 3, 4],
        'page_003.png': tinyPng(1),
      });

  String pageIndicatorText(WidgetTester tester) {
    final finder = find.byKey(const Key('comic_reader_page_indicator'));
    if (finder.evaluate().isEmpty) return '';
    return tester.widget<Text>(finder).data ?? '';
  }

  bool readerShowsPageIndicator(WidgetTester tester) {
    final text = pageIndicatorText(tester);
    return text.startsWith('Page ') && text.contains(' of ');
  }

  Future<void> waitForReaderUi(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 15),
    String? expectedPageLabel,
  }) async {
    var ready = false;
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find
                .byKey(const Key('comic_reader_page_failure_message'))
                .evaluate()
                .isNotEmpty ||
            find
                .byKey(const Key('comic_reader_error_message'))
                .evaluate()
                .isNotEmpty) {
          ready = true;
          return;
        }
        if (readerShowsPageIndicator(tester)) {
          if (expectedPageLabel == null ||
              pageIndicatorText(tester) == expectedPageLabel) {
            ready = true;
            return;
          }
        }
      }
    });
    if (!ready) {
      fail(
        'Timed out waiting for comic reader UI'
        '${expectedPageLabel == null ? '' : ' ($expectedPageLabel)'}',
      );
    }
    await tester.pump();
  }

  Future<void> sendReaderKey(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    String? expectPageLabel,
  }) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
    if (expectPageLabel != null) {
      await waitForReaderUi(tester, expectedPageLabel: expectPageLabel);
    }
  }

  State<ComicReaderScreen> readerScreenState(WidgetTester tester) =>
      _readerScreenState(tester);

  Future<void> waitForComicTelemetry(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (ReaderSessionTelemetry.instance.comicReaderSnapshot() != null) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
  }

  Future<void> selectFitMode(WidgetTester tester, Key optionKey) async {
    await tester.tap(find.byKey(const Key('comic_reader_fit_mode_menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final option = find.byKey(optionKey).last;
    await tester.ensureVisible(option);
    await tester.tap(option, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> closeReader(WidgetTester tester) async {
    if (find.byKey(const Key('comic_reader_back')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('comic_reader_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await readingCoordinator.waitForIdleForTest();
  }

  Future<void> waitForPageFailureUi(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (find
            .byKey(const Key('comic_reader_page_failure_message'))
            .evaluate()
            .isNotEmpty) {
          return;
        }
      }
      fail('Timed out waiting for page failure UI');
    });
    await tester.pump();
  }

  Future<void> unmountReader(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ReadingProgressCoordinator>.value(
        value: readingCoordinator,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpProductionReader(
    WidgetTester tester, {
    required MediaItem item,
    required dynamic source,
    ReadingProgressRestorePlan? restorePlan,
    bool startFromBeginning = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<ReadingProgressCoordinator>.value(
        value: readingCoordinator,
        child: MaterialApp(
          home: ComicReaderScreen(
            item: item,
            source: source,
            restorePlan: restorePlan,
            startFromBeginning: startFromBeginning,
          ),
        ),
      ),
    );
    await waitForReaderUi(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        if (readingCoordinator.sessionActive) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  // --- Phase 6.3 baseline (retained) ---

  test('CBZ open list and navigate first/middle/last', () async {
    final file = multiPageCbz('nav.cbz', pages: 5);
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(file.path);
    final controller = ComicReaderController(
      source: source,
      prefetchAdjacent: false,
    );
    await controller.open();
    expect(controller.pageCount, 5);
    expect(controller.currentPageBytes, isNotEmpty);
    await controller.goToIndex(2);
    expect(controller.pageIndex, 2);
    await controller.lastPage();
    expect(controller.pageIndex, 4);
    controller.dispose();
  });

  test('corrupt CBZ fails with controlled archive error', () async {
    final bad = File('${tmp.path}${Platform.pathSeparator}corrupt.cbz')
      ..writeAsBytesSync(List<int>.filled(64, 0x7F));
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(bad.path);
    final controller = ComicReaderController(
      source: source,
      prefetchAdjacent: false,
    );
    await controller.open();
    expect(controller.state, ComicReaderLoadState.error);
    expect(
      controller.error?.kind,
      anyOf(
        ComicArchiveErrorKind.corruptArchive,
        ComicArchiveErrorKind.emptyArchive,
        ComicArchiveErrorKind.noReadableImages,
      ),
    );
    controller.dispose();
  });

  group('Phase 6.4C opening and baseline (C1–C5)', () {
    testWidgets('production path opens CBZ with contain chrome and telemetry',
        (tester) async {
      final file = multiPageCbz('baseline.cbz');
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final source = opener.openPath(file.path);
      final item = comicItem(file.path, id: 'baseline-comic');

      await pumpProductionReader(tester, item: item, source: source);

      expect(pageIndicatorText(tester), 'Page 1 of 8');
      expect(find.byType(AppBar), findsOneWidget);
      expect(readerScreenState(tester).testFitMode, ComicFitMode.contain);
      expect(readerScreenState(tester).testChromeVisible, isTrue);

      await waitForComicTelemetry(tester);
      final snap = ReaderSessionTelemetry.instance.comicReaderSnapshot();
      expect(snap, isNotNull);
      expect(snap!.archiveType, 'cbz');
      expect(snap.pageIndex, 0);
      expect(snap.pageCount, 8);
      expect(snap.itemIdentity, item.id);
    });
  });

  group('Phase 6.4C keyboard navigation (C6–C10)', () {
    testWidgets('arrow home end bounded navigation on production reader',
        (tester) async {
      final file = multiPageCbz('keyboard.cbz', pages: 6);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final source = opener.openPath(file.path);
      final item = comicItem(file.path, id: 'keyboard-comic');

      await pumpProductionReader(tester, item: item, source: source);
      expect(pageIndicatorText(tester), 'Page 1 of 6');

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.arrowRight,
        expectPageLabel: 'Page 2 of 6',
      );

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.arrowLeft,
        expectPageLabel: 'Page 1 of 6',
      );

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.end,
        expectPageLabel: 'Page 6 of 6',
      );

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.home,
        expectPageLabel: 'Page 1 of 6',
      );

      await sendReaderKey(tester, LogicalKeyboardKey.arrowLeft);
      expect(pageIndicatorText(tester), 'Page 1 of 6');
    });

    // C11 wheel: Widget automated in phase_64c_comic_reader_interaction_test.dart
    // (debugWheelDelta). Native pointer-signal dispatch under flutter test is
    // classified Runtime observational — not asserted here.
  });

  group('Phase 6.4C fit and chrome (C12–C15)', () {
    testWidgets('fit modes and immersive chrome via production toolbar',
        (tester) async {
      final file = multiPageCbz('fit.cbz', pages: 3);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final source = opener.openPath(file.path);
      final item = comicItem(file.path, id: 'fit-comic');

      await pumpProductionReader(tester, item: item, source: source);

      await selectFitMode(
        tester,
        const Key('comic_reader_fit_fitWidth'),
      );
      expect(readerScreenState(tester).testFitMode, ComicFitMode.fitWidth);
      // C13 Fit Height: widget-automated in phase_64c_comic_reader_interaction_test.dart
      // (popup menu item exceeds 800px test surface under flutter test).

      await tester.tap(find.byKey(const Key('comic_reader_immersive_toggle')));
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('Phase 6.4C progress and restore (C16–C21)', () {
    testWidgets('close flush and restore reopens at saved page', (tester) async {
      final file = multiPageCbz('restore.cbz', pages: 8);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = comicItem(file.path, id: 'restore-comic');

      final source1 = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source1);
      expect(readingCoordinator.sessionActive, isTrue);

      for (var i = 0; i < 3; i++) {
        await sendReaderKey(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(pageIndicatorText(tester), 'Page 4 of 8');

      await closeReader(tester);

      final record = progressRepository.getByMediaId(item.id);
      expect(record, isNotNull);
      expect((record!.location as ComicReadingLocationPayload).pageIndex, 3);

      final restore = resolveReadingRestore(
        item: item,
        repository: progressRepository,
      );
      expect(restore, isNotNull);

      final source2 = opener.openPath(file.path);
      await pumpProductionReader(
        tester,
        item: item,
        source: source2,
        restorePlan: restore,
      );
      await waitForReaderUi(tester, expectedPageLabel: 'Page 4 of 8');
      expect(pageIndicatorText(tester), 'Page 4 of 8');
    });

    testWidgets('final page completion excludes Continue Reading', (tester) async {
      final file = multiPageCbz('complete.cbz', pages: 4);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = phase65ComicItem(filePath: file.path);

      final source = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source);

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.end,
        expectPageLabel: 'Page 4 of 4',
      );
      await readingCoordinator.waitForIdleForTest();

      await closeReader(tester);

      final record = progressRepository.getByMediaId(item.id)!;
      expect(record.completed, isTrue);

      final entries = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: progressRepository,
      );
      expect(entries.where((e) => e.item.id == item.id), isEmpty);
    });

    testWidgets('Read Again reopens page one after completion', (tester) async {
      final file = multiPageCbz('read-again.cbz', pages: 4);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = comicItem(file.path, id: 'read-again-comic');

      final source1 = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source1);

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.end,
        expectPageLabel: 'Page 4 of 4',
      );
      await readingCoordinator.waitForIdleForTest();

      await closeReader(tester);
      expect(progressRepository.getByMediaId(item.id)!.completed, isTrue);

      await unmountReader(tester);

      readingCoordinator.beginSession(
        item: item,
        readerFormat: ReadingReaderFormat.cbz,
        initialLocation: const ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 1,
          archiveFormat: ReadingReaderFormat.cbz,
        ),
        progressFraction: 0,
      );
      await readingCoordinator.onReaderRestarted();

      final source2 = opener.openPath(file.path);
      await pumpProductionReader(
        tester,
        item: item,
        source: source2,
        startFromBeginning: true,
      );
      await waitForReaderUi(tester, expectedPageLabel: 'Page 1 of 4');
      expect(pageIndicatorText(tester), 'Page 1 of 4');
      expect(progressRepository.getByMediaId(item.id)!.completed, isFalse);
    });

    testWidgets('close before debounce persists latest page', (tester) async {
      final file = multiPageCbz('debounce.cbz', pages: 6);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = comicItem(file.path, id: 'debounce-comic');

      final source = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source);

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.arrowRight,
        expectPageLabel: 'Page 2 of 6',
      );
      await sendReaderKey(
        tester,
        LogicalKeyboardKey.arrowRight,
        expectPageLabel: 'Page 3 of 6',
      );

      await closeReader(tester);

      final record = progressRepository.getByMediaId(item.id)!;
      expect((record.location as ComicReadingLocationPayload).pageIndex, 2);
    });
  });

  group('Phase 6.4C single-page completion (C22–C24)', () {
    testWidgets('single page in progress on open completes on close', (tester) async {
      final file = writeCbz(tmp, 'single.cbz', {
        'only.png': tinyPng(1),
      });
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = comicItem(file.path, id: 'single-comic', title: 'Single');

      final source = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source);
      expect(pageIndicatorText(tester), 'Page 1 of 1');

      var record = progressRepository.getByMediaId(item.id);
      expect(record?.completed ?? false, isFalse);

      await closeReader(tester);

      record = progressRepository.getByMediaId(item.id);
      expect(record, isNotNull);
      expect(record!.completed, isTrue);
    });
  });

  group('Phase 6.4C per-page resilience (C25–C31)', () {
    testWidgets('corrupt middle page placeholder navigation retry close',
        (tester) async {
      final file = corruptMiddleCbz('partial.cbz');
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = comicItem(file.path, id: 'partial-comic');

      final source = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source);
      expect(pageIndicatorText(tester), 'Page 1 of 3');

      await sendReaderKey(
        tester,
        LogicalKeyboardKey.arrowRight,
        expectPageLabel: 'Page 2 of 3',
      );
      await waitForPageFailureUi(tester);
      expect(pageIndicatorText(tester), 'Page 2 of 3');
      // C29 navigation to the valid page after a corrupt page is covered in
      // phase_64c_comic_page_error_test.dart (ConfigurableFakeSource).

      expect(find.byKey(const Key('comic_reader_page_retry')), findsOneWidget);
      final snapFail = ReaderSessionTelemetry.instance.comicReaderSnapshot();
      expect(snapFail?.currentPageFailureCategory, isNotNull);

      await closeReader(tester);

      final record = progressRepository.getByMediaId(item.id);
      expect(record, isNotNull);
      expect((record!.location as ComicReadingLocationPayload).pageIndex, 1);
    });
  });

  group('Phase 6.4C diagnostics (C32–C34)', () {
    testWidgets('active diagnostics redacted and cleared on close',
        (tester) async {
      final file = multiPageCbz('diag.cbz', pages: 5);
      final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
      final item = comicItem(file.path, id: 'diag-comic');

      final source = opener.openPath(file.path);
      await pumpProductionReader(tester, item: item, source: source);

      final snap = ReaderSessionTelemetry.instance.comicReaderSnapshot()!;
      expect(snap.archiveType, 'cbz');
      expect(snap.pageCount, 5);
      expect(snap.fitMode, 'Contain');
      expect(snap.itemIdentity, item.id);
      expect(snap.itemIdentity!.contains(r'\'), isFalse);

      await tester.runAsync(() async {
        final harness = await buildDiagnosticsHarness(
          readingProgressRepository: progressRepository,
          readingProgressCoordinator: readingCoordinator,
        );
        final snapshot = await harness.captureSnapshot();
        final export = harness.formatExport(snapshot);
        expect(snapshot.comicReader?.active, isTrue);
        expect(export, contains('=== Comic reader ==='));
        expect(export, contains('Archive type: cbz'));
        expect(exportContainsSensitiveData(export), isFalse);
        expect(export.contains(tmp.path.replaceAll(r'\', r'\\')), isFalse);
      });

      await closeReader(tester);
      await unmountReader(tester);
      expect(ReaderSessionTelemetry.instance.comicReaderSnapshot(), isNull);
    });
  });

  // Retained Phase 6.3 widget keyboard test (debug controller prefetch path).
  testWidgets('CBZ reader screen keyboard next/prev (prefetched debug path)',
      (tester) async {
    final file = writeCbz(tmp, 'ui.cbz', {
      'page_001.png': tinyPng(1),
      'page_002.png': tinyPng(2),
      'page_003.png': tinyPng(3),
    });
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(file.path);
    final item = comicItem(file.path);
    late final ComicReaderController controller;
    await tester.runAsync(() async {
      controller = ComicReaderController(
        source: source,
        prefetchAdjacent: false,
      );
      await controller.open();
      for (var i = 0; i < controller.pageCount; i++) {
        await controller.goToIndex(i);
      }
      await controller.firstPage();
    });
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<ReadingProgressCoordinator>.value(
        value: readingCoordinator,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  key: const Key('open_reader'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ComicReaderScreen(
                          item: item,
                          source: source,
                          debugController: controller,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_reader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.pageIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.pageIndex, 0);
  });
}
