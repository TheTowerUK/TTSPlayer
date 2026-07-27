import 'dart:io';

import 'package:pdfrx/pdfrx.dart';
import 'package:ttsplayer/features/books/epub/epub_parser.dart';
import 'package:ttsplayer/features/books/epub/epub_resource_loader.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_lazy_reader.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_cache.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';

/// Shared long-session helpers for Phase 6.6 opt-in runtime harness.
abstract final class Phase66LongSessionHarness {
  static const comicMaxEntries = 5;
  static const comicMaxBytes = 24 * 1024 * 1024;
  static const epubMaxEntries = 32;
  static const epubMaxBytes = 16 * 1024 * 1024;

  static void assertComicCacheBounds(ComicPageCache cache) {
    if (cache.length > cache.maxEntries) {
      throw StateError(
        'Comic cache entry count ${cache.length} exceeds ${cache.maxEntries}',
      );
    }
    if (cache.estimatedBytes > cache.maxBytes) {
      throw StateError(
        'Comic cache bytes ${cache.estimatedBytes} exceed ${cache.maxBytes}',
      );
    }
  }

  static Future<void> runCbzOpenCloseCycle({
    required File archive,
    required int cycles,
    int navigationSteps = 0,
    bool randomNavigation = false,
    bool closeDuringNavigation = false,
  }) async {
    for (var cycle = 0; cycle < cycles; cycle++) {
      final source = CbzZipArchiveSource(archive.path);
      final cache = ComicPageCache(
        maxEntries: comicMaxEntries,
        maxBytes: comicMaxBytes,
      );
      final controller = ComicReaderController(source: source, cache: cache);
      await controller.open();
      assertComicCacheBounds(cache);

      var disposedEarly = false;
      if (navigationSteps > 0) {
        for (var step = 0; step < navigationSteps; step++) {
          if (closeDuringNavigation && step == navigationSteps ~/ 2) {
            controller.dispose();
            disposedEarly = true;
            break;
          }
          final target = randomNavigation
              ? (step * 37 + cycle * 11) % controller.pageCount
              : step % controller.pageCount;
          await controller.goToIndex(target);
          assertComicCacheBounds(cache);
        }
      }

      if (!disposedEarly) {
        controller.dispose();
        await source.dispose();
        if (cache.length != 0) {
          throw StateError('Comic cache not cleared after dispose');
        }
      }
    }
  }

  static Future<void> runEpubOpenCloseCycle({
    required File epub,
    required int cycles,
    bool alternateChapterLengths = false,
  }) async {
    final parser = EpubParser();
    for (var cycle = 0; cycle < cycles; cycle++) {
      final doc = await parser.parseFile(epub.path);
      final chapterCount = doc.spine.length;
      for (var i = 0; i < chapterCount; i++) {
        final index = alternateChapterLengths
            ? (i.isEven ? i : chapterCount - 1 - (i % chapterCount))
            : i;
        final html = await doc.loadChapterHtml(index);
        if (html.isEmpty) {
          throw StateError('Empty chapter html at $index');
        }
        final loader = doc.resourceLoader;
        if (loader is EpubLazyResourceLoader) {
          if (loader.cachedEntryCount > epubMaxEntries) {
            throw StateError('EPUB cache entries exceed bound');
          }
          if (loader.estimatedCachedBytes > epubMaxBytes) {
            throw StateError('EPUB cache bytes exceed bound');
          }
        }
      }
      doc.dispose();
    }
  }

  static Future<void> runPdfOpenCloseCycle({
    required File pdf,
    required int cycles,
    int renderPageIndex = 0,
    double renderWidth = 640,
  }) async {
    for (var cycle = 0; cycle < cycles; cycle++) {
      final doc = await PdfDocument.openFile(pdf.path);
      try {
        final page = doc.pages[renderPageIndex.clamp(0, doc.pages.length - 1)];
        final image = await page.render(
          fullWidth: renderWidth,
          fullHeight: renderWidth * page.height / page.width,
        );
        image?.dispose();
      } finally {
        await doc.dispose();
      }
    }
  }

  static Future<void> assertCbzLazyListingOnly(File archive) async {
    final reader = CbzZipLazyReader(archive.path);
    final central = await reader.centralEntries();
    if (central.isEmpty) {
      throw StateError('Expected non-empty central directory listing');
    }
  }

  static Future<void> allowCleanupPause() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
