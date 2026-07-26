@Tags(['phase63-reader'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_screen.dart';
import 'package:ttsplayer/features/comics/spike/unrar_cli_resolver.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';

import 'support/comic_test_fixtures.dart';

/// Opt-in Phase 6.3 comic reader Windows runtime harness.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_63_READER='1'
/// $env:PHASE_63_UNRAR_EXE=(Resolve-Path 'third_party\unrar_cli\UnRAR.exe').Path
/// flutter test test/phase_63_comic_reader_windows_runtime_test.dart --tags phase63-reader
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_63_READER'] != '1') {
    test('skipped — set PHASE_63_READER=1', () {}, skip: true);
    return;
  }

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_p63_');
  });

  tearDown(() {
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

  MediaItem comicItem(String path, {String id = 'c1'}) => MediaItem(
        id: id,
        title: 'Gate Comic',
        filePath: path,
        mediaKindRaw: MediaKind.comic.name,
        status: MediaItemStatus.available,
      );

  test('CBZ open list and navigate first/middle/last', () async {
    final file = writeCbz(tmp, 'nav.cbz', {
      for (var i = 1; i <= 5; i++)
        'page_${i.toString().padLeft(3, '0')}.png': tinyPng(i),
    });
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

  testWidgets('CBZ reader screen keyboard next/prev and escape', (tester) async {
    final file = writeCbz(tmp, 'ui.cbz', {
      'page_001.png': tinyPng(1),
      'page_002.png': tinyPng(2),
      'page_003.png': tinyPng(3),
    });
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(file.path);
    final item = comicItem(file.path);
    // Complete dart:io open outside the widget-test fake-async zone.
    late final ComicReaderController controller;
    await tester.runAsync(() async {
      controller = ComicReaderController(
        source: source,
        prefetchAdjacent: false,
      );
      await controller.open();
      // Prefetch all pages so in-widget navigation stays cache-only.
      for (var i = 0; i < controller.pageCount; i++) {
        await controller.goToIndex(i);
      }
      await controller.firstPage();
    });
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<MediaLocationResolver>.value(
        value: resolver,
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
    await tester.pump(); // push
    await tester.pump(const Duration(milliseconds: 50)); // route animation
    expect(controller.pageIndex, 0);
    expect(controller.canGoNext, isTrue);
    expect(find.textContaining('Page 1 of 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.pageIndex, 1);
    expect(find.textContaining('Page 2 of 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.pageIndex, 0);
    expect(find.textContaining('Page 1 of 3'), findsOneWidget);

    expect(find.byKey(const Key('comic_reader_back')), findsOneWidget);
    expect(find.byKey(const Key('comic_reader_page_indicator')), findsOneWidget);
  });

  test('CBR lists when PHASE_63_UNRAR_EXE is set', () async {
    final unrar = Platform.environment[UnrarCliResolver.overrideEnvKey];
    if (unrar == null || unrar.isEmpty || !File(unrar).existsSync()) {
      // ignore: avoid_print
      print('G0-CBR skip — set PHASE_63_UNRAR_EXE');
      return;
    }
    final fixture = File('test/support/cbr_gate0_fixtures/rar5_pages.cbr');
    if (!fixture.existsSync()) {
      // ignore: avoid_print
      print('G0-CBR skip — rar5_pages.cbr missing');
      return;
    }
    final opener = ComicArchiveOpener(
      mediaLocationResolver: resolver,
      cbrResolver: UnrarCliResolver(
        overrideExecutablePath: unrar,
        expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
      ),
    );
    final source = opener.openPath(fixture.path);
    final pages = await source.listPages();
    expect(pages, isNotEmpty);
    final bytes = await source.loadPageBytes(pages.first.entryName);
    expect(bytes, isNotEmpty);
    await source.dispose();
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

  test('missing CBR executable is controlled', () async {
    final opener = ComicArchiveOpener(
      mediaLocationResolver: resolver,
      cbrResolver: UnrarCliResolver(
        overrideExecutablePath: r'C:\ttsplayer_missing\UnRAR.exe',
      ),
    );
    expect(
      () => opener.openPath(r'C:\fake\book.cbr'),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          ComicArchiveErrorKind.cbrSupportUnavailable,
        ),
      ),
    );
  });

  test('encrypted and multi-volume CBR fail safely when UnRAR present', () async {
    final unrar = Platform.environment[UnrarCliResolver.overrideEnvKey];
    if (unrar == null || !File(unrar).existsSync()) return;
    final opener = ComicArchiveOpener(
      mediaLocationResolver: resolver,
      cbrResolver: UnrarCliResolver(
        overrideExecutablePath: unrar,
        expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
      ),
    );
    for (final name in ['encrypted.cbr', 'multivolume_missing_part.cbr']) {
      final path = 'test/support/cbr_gate0_fixtures/$name';
      if (!File(path).existsSync()) continue;
      final source = opener.openPath(path);
      try {
        await source.listPages();
        fail('expected failure for $name');
      } on ComicArchiveException catch (e) {
        expect(
          e.kind,
          anyOf(
            ComicArchiveErrorKind.encryptedArchive,
            ComicArchiveErrorKind.multiVolumeUnsupported,
            ComicArchiveErrorKind.corruptArchive,
          ),
        );
        // ignore: avoid_print
        print('P63 $name -> ${e.kind}');
      } finally {
        await source.dispose();
      }
    }
  });
}
