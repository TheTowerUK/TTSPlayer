@Tags(['phase65-reader'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/books/reader/book_navigation.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/reading/widgets/continue_reading_section.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'support/book_test_fixtures.dart';
import 'support/comic_test_fixtures.dart';
import 'support/diagnostics_test_harness.dart';

/// Opt-in Phase 6.5 reading progress Windows restart harness.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_65_READING_PROGRESS='1'
/// flutter test test/phase_65_reading_progress_windows_runtime_test.dart --tags phase65-reader
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_65_READING_PROGRESS'] != '1') {
    test('skipped — set PHASE_65_READING_PROGRESS=1', () {}, skip: true);
    return;
  }

  late Directory tmp;
  late ReadingProgressRepository repository;
  late ReadingProgressCoordinator coordinator;

  final resolver = MediaLocationResolver(
    config: MediaAccessConfig.defaults(),
    isWindowsDesktop: true,
  );

  MediaItem bookItem(String path, {String id = 'b1'}) => MediaItem(
        id: id,
        title: 'Harness Book',
        filePath: path,
        mediaKindRaw: MediaKind.book.name,
        status: MediaItemStatus.available,
      );

  MediaItem comicItem(String path, {String id = 'c1', String ext = 'cbz'}) =>
      MediaItem(
        id: id,
        title: 'Harness Comic',
        filePath: path,
        mediaKindRaw: MediaKind.comic.name,
        status: MediaItemStatus.available,
      );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('tts_p65_');
    SharedPreferences.setMockInitialValues({});
    repository = ReadingProgressRepository();
    await repository.initialize();
    coordinator = ReadingProgressCoordinator(repository: repository);
  });

  tearDown(() async {
    coordinator.dispose();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<Map<String, Object?>> _prefsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ReadingProgressRepository.storageKey);
    if (raw == null) return const {};
    return jsonDecode(raw) as Map<String, Object?>;
  }

  Future<ReadingProgressRepository> _reloadRepository() async {
    final reloaded = ReadingProgressRepository();
    await reloaded.initialize();
    return reloaded;
  }

  test('PDF progress survives repository reload and restores page', () async {
    const pageCount = 5;
    const targetPage = 2;
    final file = writePdf(tmp, 'restart.pdf', pages: pageCount);
    final item = bookItem(file.path, id: 'pdf-restart');

    coordinator.beginSession(
      item: item,
      readerFormat: ReadingReaderFormat.pdf,
      initialLocation: PdfReadingLocationPayload(
        pageIndex: targetPage,
        pageCountAtSave: pageCount,
      ),
      progressFraction: ReadingProgressRecord.fractionForPdf(
        targetPage,
        pageCount,
      ),
    );
    coordinator.markLayoutReady();
    coordinator.onLocationChanged(
      location: PdfReadingLocationPayload(
        pageIndex: targetPage,
        pageCountAtSave: pageCount,
      ),
      progressFraction: ReadingProgressRecord.fractionForPdf(
        targetPage,
        pageCount,
      ),
      force: true,
    );
    await coordinator.drainPendingWrites();

    final reloaded = await _reloadRepository();
    final record = reloaded.getByMediaId(item.id);
    expect(record, isNotNull);
    final location = record!.location as PdfReadingLocationPayload;
    expect(location.pageIndex, targetPage);
    expect(location.pageCountAtSave, pageCount);
  });

  testWidgets('Continue Reading opens restored PDF via production route',
      (tester) async {
    const pageCount = 5;
    const targetPage = 3;
    final file = writePdf(tmp, 'ui.pdf', pages: pageCount);
    final item = bookItem(file.path, id: 'pdf-ui');

    final record = ReadingProgressRecord(
      mediaId: item.id,
      mediaKind: MediaKind.book,
      readerFormat: ReadingReaderFormat.pdf,
      title: item.title,
      location: PdfReadingLocationPayload(
        pageIndex: targetPage,
        pageCountAtSave: pageCount,
      ),
      progressFraction: ReadingProgressRecord.fractionForPdf(
        targetPage,
        pageCount,
      ),
      completed: false,
      lastReadAt: DateTime.utc(2026, 7, 27),
    );
    await repository.upsert(record);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

    await tester.pumpWidget(
      Provider<MediaLocationResolver>.value(
        value: resolver,
        child: ChangeNotifierProvider<ReadingProgressRepository>.value(
          value: repository,
          child: ChangeNotifierProvider<ReadingProgressCoordinator>.value(
            value: coordinator,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: Builder(
                builder: (context) {
                  final entries = ContinueReadingProjection().build(
                    catalog: _singleItemCatalog(item),
                    repository: repository,
                  );
                  return ContinueReadingSection(entries: entries);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('continue_reading_section')), findsOneWidget);
    await tester.tap(find.byKey(Key('continue_reading_card_${item.id}')));
    await tester.pump();

    var restored = false;
    await tester.runAsync(() async {
      for (var i = 0; i < 80; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byKey(const Key('book_reader_pdf_view')).evaluate().isEmpty) {
          continue;
        }
        final viewerFinder = find.byKey(const Key('book_reader_pdf_view'));
        if (viewerFinder.evaluate().isNotEmpty) {
          restored = true;
          break;
        }
      }
    });
    expect(restored, isTrue);
    await coordinator.onReaderClosed();
  });

  test('EPUB progress round-trips through reload', () async {
    final file = writeEpub(
      tmp,
      'restart.epub',
      chapters: linkedChapters(),
    );
    final item = bookItem(file.path, id: 'epub-restart');
    coordinator.beginSession(
      item: item,
      readerFormat: ReadingReaderFormat.epub,
      initialLocation: const EpubReadingLocationPayload(
        spineIndex: 1,
        spineHref: 'chapter2.xhtml',
        spineCountAtSave: 2,
        sectionRelativeOffset: 120,
      ),
      progressFraction: 0.55,
    );
    coordinator.markLayoutReady();
    coordinator.onLocationChanged(
      location: const EpubReadingLocationPayload(
        spineIndex: 1,
        spineHref: 'chapter2.xhtml',
        spineCountAtSave: 2,
        sectionRelativeOffset: 120,
      ),
      progressFraction: 0.55,
      force: true,
    );
    await coordinator.drainPendingWrites();

    final reloaded = await _reloadRepository();
    final saved = reloaded.getByMediaId(item.id)!.location
        as EpubReadingLocationPayload;
    expect(saved.spineIndex, 1);
    expect(saved.sectionRelativeOffset, 120);
  });

  test('CBZ comic progress round-trips through reload', () async {
    final file = writeCbz(tmp, 'restart.cbz', {
      '001.jpg': tinyPng(0),
      '002.jpg': tinyPng(1),
      '003.jpg': tinyPng(2),
      '004.jpg': tinyPng(3),
    });
    final item = comicItem(file.path, id: 'cbz-restart');
    coordinator.beginSession(
      item: item,
      readerFormat: ReadingReaderFormat.cbz,
      initialLocation: ComicReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 4,
        entryName: '002.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      ),
      progressFraction: 0.75,
    );
    coordinator.markLayoutReady();
    coordinator.onLocationChanged(
      location: ComicReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 4,
        entryName: '002.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      ),
      progressFraction: 0.75,
      force: true,
    );
    await coordinator.drainPendingWrites();

    final reloaded = await _reloadRepository();
    final saved = reloaded.getByMediaId(item.id)!.location
        as ComicReadingLocationPayload;
    expect(saved.pageIndex, 2);
  });

  test('completed entries excluded from Continue Reading after reload', () async {
    final item = bookItem('${tmp.path}/done.pdf', id: 'done');
    await repository.upsert(
      ReadingProgressRecord(
        mediaId: item.id,
        mediaKind: MediaKind.book,
        readerFormat: ReadingReaderFormat.pdf,
        title: item.title,
        location: const PdfReadingLocationPayload(
          pageIndex: 9,
          pageCountAtSave: 10,
        ),
        progressFraction: 1,
        completed: true,
        lastReadAt: DateTime.utc(2026, 7, 27),
        completedAt: DateTime.utc(2026, 7, 27),
      ),
    );
    final entries = ContinueReadingProjection().build(
      catalog: _singleItemCatalog(item),
      repository: repository,
    );
    expect(entries, isEmpty);
  });

  test('corrupt single record preserves valid entries', () async {
    final good = bookItem('${tmp.path}/good.pdf', id: 'good');
    await repository.upsert(
      ReadingProgressRecord(
        mediaId: good.id,
        mediaKind: MediaKind.book,
        readerFormat: ReadingReaderFormat.pdf,
        title: good.title,
        location: const PdfReadingLocationPayload(
          pageIndex: 1,
          pageCountAtSave: 10,
        ),
        progressFraction: 0.2,
        completed: false,
        lastReadAt: DateTime.utc(2026, 7, 27),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    final envelope = jsonDecode(
      prefs.getString(ReadingProgressRepository.storageKey)!,
    ) as Map<String, dynamic>;
    final records = List<Map<String, dynamic>>.from(
      envelope['records'] as List,
    );
    records.add({'mediaId': '', 'broken': true});
    envelope['records'] = records;
    await prefs.setString(
      ReadingProgressRepository.storageKey,
      jsonEncode(envelope),
    );

    final reloaded = await _reloadRepository();
    expect(reloaded.getByMediaId(good.id), isNotNull);
    expect(reloaded.lastRecoveryWarnings, isNotEmpty);
  });

  test('music listening key remains unchanged after reading write', () async {
    const listeningKey = 'ttsplayer_music_listening_v1';
    SharedPreferences.setMockInitialValues({
      listeningKey: jsonEncode({
        'stateVersion': 1,
        'records': [],
      }),
    });
    repository = ReadingProgressRepository();
    await repository.initialize();
    coordinator = ReadingProgressCoordinator(repository: repository);

    final item = bookItem('${tmp.path}/iso.pdf', id: 'iso');
    coordinator.beginSession(
      item: item,
      readerFormat: ReadingReaderFormat.pdf,
      initialLocation: const PdfReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 5,
      ),
      progressFraction: 0.6,
    );
    coordinator.markLayoutReady();
    coordinator.onLocationChanged(
      location: const PdfReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 5,
      ),
      progressFraction: 0.6,
      force: true,
    );
    await coordinator.drainPendingWrites();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(listeningKey), isNotNull);
    expect(
      prefs.getString(ReadingProgressRepository.storageKey),
      isNotNull,
    );
  });

  test('diagnostics reflects persisted reading progress after reload', () async {
    const pageCount = 5;
    const targetPage = 2;
    final file = writePdf(tmp, 'diag.pdf', pages: pageCount);
    final item = bookItem(file.path, id: 'pdf-diag');

    coordinator.beginSession(
      item: item,
      readerFormat: ReadingReaderFormat.pdf,
      initialLocation: PdfReadingLocationPayload(
        pageIndex: targetPage,
        pageCountAtSave: pageCount,
      ),
      progressFraction: ReadingProgressRecord.fractionForPdf(
        targetPage,
        pageCount,
      ),
    );
    coordinator.markLayoutReady();
    coordinator.onLocationChanged(
      location: PdfReadingLocationPayload(
        pageIndex: targetPage,
        pageCountAtSave: pageCount,
      ),
      progressFraction: ReadingProgressRecord.fractionForPdf(
        targetPage,
        pageCount,
      ),
      force: true,
    );
    await coordinator.drainPendingWrites();

    final reloaded = await _reloadRepository();
    final catalog = _singleItemCatalog(item);

    final service = await buildDiagnosticsHarness(
      catalog: catalog,
      readingProgressRepository: reloaded,
    );
    final reading = (await service.captureSnapshot()).readingProgress;

    expect(reading?.storedRecordCount, 1);
    expect(reading?.continueReadingCount, 1);
    expect(reading?.pdfRecordCount, 1);
    expect(reading?.repositoryInitialized, isTrue);

    final export = service.formatExport(await service.captureSnapshot());
    expect(export, contains('=== Reading progress ==='));
    expect(export, contains('Total stored record count: 1'));
    expect(export, isNot(contains(file.path)));
    expect(export, isNot(contains('diag.pdf')));
  });
}

Catalog _singleItemCatalog(MediaItem item) {
  return Catalog.fromJson({
    'generated_at': '2026-07-27T00:00:00Z',
    'scanner_version': '0.5.0',
    'catalogue_version': 4,
    'root_path': '/media',
    'total_items': 1,
    'folders': [
      {
        'id': 'f1',
        'name': 'Books',
        'path': '/media/Books',
        'item_count': 1,
        'items': [item.toJson()],
        'subfolders': [],
      },
    ],
  });
}
