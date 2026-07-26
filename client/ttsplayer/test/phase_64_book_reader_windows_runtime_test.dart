@Tags(['phase64-reader'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/books/archive/book_opener.dart';
import 'package:ttsplayer/features/books/epub/epub_book_controller.dart';
import 'package:ttsplayer/features/books/reader/book_pdf_probe.dart';
import 'package:ttsplayer/features/books/reader/book_reader_screen.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'support/book_test_fixtures.dart';

/// Opt-in Phase 6.4 book reader Windows runtime harness.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_64_READER='1'
/// flutter test test/phase_64_book_reader_windows_runtime_test.dart --tags phase64-reader
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_64_READER'] != '1') {
    test('skipped — set PHASE_64_READER=1', () {}, skip: true);
    return;
  }

  late Directory tmp;
  late LibraryMetadataRepository metadata;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('tts_p64_');
    metadata = LibraryMetadataRepository();
    await metadata.initialize();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getTemporaryDirectory') {
          return tmp.path;
        }
        return null;
      },
    );
    await pdfrxFlutterInitialize();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  final resolver = MediaLocationResolver(
    config: MediaAccessConfig.defaults(),
    isWindowsDesktop: true,
  );

  MediaItem bookItem(String path, {String id = 'b1', String ext = 'pdf'}) =>
      MediaItem(
        id: id,
        title: 'Harness Book',
        filePath: path,
        mediaKindRaw: MediaKind.book.name,
        status: MediaItemStatus.available,
      );

  Widget _detailHarness({required MediaItem item}) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1280, 800)),
      child: Provider<MediaLocationResolver>.value(
        value: resolver,
        child: Provider(
          create: (_) => ArtworkService(fileExists: (_) => false),
          child: ChangeNotifierProvider<LibraryMetadataRepository>.value(
            value: metadata,
            child: ChangeNotifierProvider(
              create: (_) => PlaybackService(mediaLocationResolver: resolver),
              child: MaterialApp(
                theme: AppTheme.dark,
                home: ItemDetailScreen(item: item),
              ),
            ),
          ),
        ),
      ),
    );
  }

  test('PDF probe and opener resolve local file', () async {
    final file = writePdf(tmp, 'harness.pdf', pages: 4);
    final opener = BookOpener(mediaLocationResolver: resolver);
    final target = opener.openItem(bookItem(file.path));
    expect(target.format.name, 'pdf');
  });

  testWidgets(
    'PDF renders through ItemDetail Open Book route with page nav and zoom',
    (tester) async {
      const pageCount = 5;
      final file = writePdf(tmp, 'render.pdf', pages: pageCount);
      final item = bookItem(file.path, id: 'pdf-render');

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_detailHarness(item: item));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('item_detail_open_book')), findsOneWidget);

      var loaded = false;
      await tester.runAsync(() async {
        await tester.ensureVisible(find.byKey(const Key('item_detail_open_book')));
        await tester.tap(find.byKey(const Key('item_detail_open_book')));
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.byKey(const Key('book_reader_pdf_view')).evaluate().isEmpty) {
            continue;
          }
          final activeViewer = tester.widget<PdfViewer>(
            find.byKey(const Key('book_reader_pdf_view')),
          );
          if (activeViewer.controller?.isReady == true &&
              activeViewer.controller!.pageCount == pageCount) {
            loaded = true;
            break;
          }
        }
      });
      expect(loaded, isTrue, reason: 'PdfViewer did not render the first page');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BookReaderScreen), findsOneWidget);
      expect(find.byKey(const Key('book_reader_pdf_view')), findsOneWidget);
      expect(find.byType(PdfViewer), findsOneWidget);

      final viewer = tester.widget<PdfViewer>(
        find.byKey(const Key('book_reader_pdf_view')),
      );
      expect(viewer.controller?.isReady ?? false, isTrue,
          reason: 'PdfViewerController should be ready after first page render');
      expect(viewer.controller!.pageCount, pageCount);
      expect(viewer.controller!.pageNumber, 1);

      await tester.runAsync(() async {
        await viewer.controller!.goToPage(
          pageNumber: 3,
          duration: Duration.zero,
        );
      });
      await tester.pump();
      expect(viewer.controller!.pageNumber, 3);
      expect(find.textContaining('Page 3 of $pageCount'), findsOneWidget);

      await tester.runAsync(() async {
        await viewer.controller!.goToPage(
          pageNumber: pageCount,
          duration: Duration.zero,
        );
      });
      await tester.pump();
      expect(viewer.controller!.pageNumber, pageCount);
      expect(find.textContaining('Page $pageCount of $pageCount'), findsOneWidget);

      final initialZoom = viewer.controller!.currentZoom;
      await tester.runAsync(() async {
        viewer.controller!.zoomUp();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(viewer.controller!.currentZoom, greaterThan(initialZoom));

      await tester.runAsync(() async {
        final fit =
            viewer.controller!.alternativeFitScale ?? viewer.controller!.coverScale;
        viewer.controller!.setZoom(viewer.controller!.centerPosition, fit);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.byKey(const Key('book_reader_back')));
      await tester.tap(find.byKey(const Key('book_reader_back')));
      await tester.pumpAndSettle();

      expect(find.byType(BookReaderScreen), findsNothing);
      expect(find.byKey(const Key('item_detail_open_book')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('EPUB parse spine navigation', () async {
    final file = writeEpub(
      tmp,
      'harness.epub',
      chapters: linkedChapters(),
    );
    final controller = EpubBookController(
      documentId: 'h1',
      filePath: file.path,
    );
    await controller.open();
    expect(controller.chapterCount, 2);
    await controller.nextChapter();
    expect(controller.spineIndex, 1);
    controller.disposeDocument();
  });

  testWidgets('EPUB reader screen chapter navigation controls', (tester) async {
    final file = writeEpub(
      tmp,
      'ui.epub',
      chapters: [
        MapEntry('a.xhtml', '<html><body><p>A</p></body></html>'),
        MapEntry('b.xhtml', '<html><body><p>B</p></body></html>'),
      ],
    );
    final opener = BookOpener(mediaLocationResolver: resolver);
    final target = opener.openItem(bookItem(file.path, ext: 'epub'));
    final item = bookItem(file.path, ext: 'epub');

    late final EpubBookController controller;
    await tester.runAsync(() async {
      controller = EpubBookController(
        documentId: target.documentId,
        filePath: file.path,
      );
      await controller.open();
    });
    addTearDown(controller.disposeDocument);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<MediaLocationResolver>.value(
        value: resolver,
        child: MaterialApp(
          home: BookReaderScreen(
            item: item,
            target: target,
            debugEpubController: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('book_reader_location')), findsOneWidget);
    await tester.tap(find.byKey(const Key('book_reader_next')));
    await tester.pump();
    expect(find.textContaining('Chapter 2'), findsOneWidget);
  });
}
