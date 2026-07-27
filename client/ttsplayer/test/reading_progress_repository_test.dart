import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_kind.dart';

import 'support/reading_progress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingProgressRecord', () {
    test('pdf payload round-trips through JSON', () {
      final original = phase65PdfRecord(
        pageIndex: 9,
        pageCountAtSave: 200,
        progressFraction: 0.05,
      );
      final restored = ReadingProgressRecord.fromJsonWithRecovery(
        original.toJson(),
      );

      expect(restored?.toJson(), original.normalized().toJson());
    });

    test('epub payload round-trips through JSON', () {
      final original = phase65EpubRecord(
        spineIndex: 4,
        spineHref: 'part2/ch05.xhtml',
        sectionRelativeOffset: 120,
        chapterTitle: 'The Gate',
      );
      final restored = ReadingProgressRecord.fromJsonWithRecovery(
        original.toJson(),
      );

      expect(restored?.toJson(), original.normalized().toJson());
    });

    test('comic cbz payload round-trips through JSON', () {
      final original = phase65ComicRecord(
        pageIndex: 11,
        entryName: 'page012.jpg',
      );
      final restored = ReadingProgressRecord.fromJsonWithRecovery(
        original.toJson(),
      );

      expect(restored?.toJson(), original.normalized().toJson());
    });

    test('comic cbr payload round-trips through JSON', () {
      final original = phase65ComicRecord(
        mediaId: 'comic-cbr',
        title: 'Batman 01',
        archiveFormat: ReadingReaderFormat.cbr,
        entryName: '001.png',
      );
      final restored = ReadingProgressRecord.fromJsonWithRecovery(
        original.toJson(),
      );

      expect(restored?.toJson(), original.normalized().toJson());
    });

    test('normalized marks completed at 95% threshold', () {
      final normalized = phase65PdfRecord(progressFraction: 0.95).normalized();

      expect(normalized.completed, isTrue);
      expect(normalized.progressFraction, 1.0);
      expect(normalized.completedAt, isNotNull);
    });

    test('fraction below threshold stays incomplete', () {
      final normalized = phase65PdfRecord(progressFraction: 0.94).normalized();

      expect(normalized.completed, isFalse);
      expect(normalized.progressFraction, 0.94);
      expect(normalized.completedAt, isNull);
    });

    test('fromJsonWithRecovery skips malformed records defensively', () {
      final warnings = <String>[];
      final record = ReadingProgressRecord.fromJsonWithRecovery(
        {
          'mediaId': '',
          'mediaKind': 'book',
          'readerFormat': 'pdf',
          'lastReadAt': 'bad',
        },
        warnings: warnings,
      );

      expect(record, isNull);
      expect(warnings, isNotEmpty);
    });

    test('fromJsonWithRecovery rejects format/location mismatch', () {
      final warnings = <String>[];
      final record = ReadingProgressRecord.fromJsonWithRecovery(
        {
          'mediaId': 'book-pdf',
          'mediaKind': 'book',
          'readerFormat': 'pdf',
          'title': 'Manual',
          'location': {
            'format': 'epub',
            'spine_index': 0,
            'spine_href': 'a.xhtml',
            'spine_count_at_save': 3,
          },
          'progressFraction': 0.1,
          'completed': false,
          'lastReadAt': '2026-07-27T12:00:00.000Z',
        },
        warnings: warnings,
      );

      expect(record, isNull);
      expect(warnings, isNotEmpty);
    });

    test('hasMeaningfulProgress respects page and fraction gates', () {
      final tooEarly = phase65PdfRecord(pageIndex: 0, progressFraction: 0.01);
      final byPage = phase65PdfRecord(pageIndex: 1, progressFraction: 0.01);
      final byFraction = phase65PdfRecord(pageIndex: 0, progressFraction: 0.03);

      expect(ReadingProgressRecord.hasMeaningfulProgress(tooEarly), isFalse);
      expect(ReadingProgressRecord.hasMeaningfulProgress(byPage), isTrue);
      expect(ReadingProgressRecord.hasMeaningfulProgress(byFraction), isTrue);
      expect(
        ReadingProgressRecord.hasMeaningfulProgress(
          byPage.copyWith(completed: true),
        ),
        isFalse,
      );
    });
  });

  group('ReadingProgressRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('missing storage returns empty progress', () async {
      final repository = await initializedReadingProgressRepository();

      expect(repository.allRecords, isEmpty);
      expect(repository.isLoaded, isTrue);
    });

    test('valid envelope loads records', () async {
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: jsonEncode({
          'stateVersion': ReadingProgressRepository.currentStateVersion,
          'records': [phase65PdfRecord().toJson()],
        }),
      });

      final repository = ReadingProgressRepository();
      final result = await repository.load();

      expect(result.source, ReadingProgressLoadSource.envelope);
      expect(repository.allRecords, hasLength(1));
      expect(repository.getByMediaId('book-pdf'), isNotNull);
    });

    test('invalid JSON recovers to empty with warning', () async {
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: '{not json',
      });

      final repository = ReadingProgressRepository();
      final result = await repository.load();

      expect(result.source, ReadingProgressLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(result.recoveryWarnings, isNotEmpty);
    });

    test('unsupported stateVersion returns empty history with warning', () async {
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: jsonEncode({
          'stateVersion': 99,
          'records': [phase65EpubRecord().toJson()],
        }),
      });

      final repository = ReadingProgressRepository();
      final result = await repository.load();

      expect(result.source, ReadingProgressLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(
        result.recoveryWarnings,
        contains(
          'Unsupported stateVersion 99; stored reading progress was not loaded.',
        ),
      );
    });

    test('missing stateVersion returns empty history with warning', () async {
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: jsonEncode({
          'records': [phase65ComicRecord().toJson()],
        }),
      });

      final repository = ReadingProgressRepository();
      final result = await repository.load();

      expect(result.source, ReadingProgressLoadSource.defaults);
      expect(repository.allRecords, isEmpty);
      expect(
        result.recoveryWarnings,
        contains(
          'Missing stateVersion; stored reading progress was not loaded.',
        ),
      );
    });

    test('malformed entries are skipped while valid records remain', () async {
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [
            {'mediaId': '', 'lastReadAt': '2026-07-27T12:00:00.000Z'},
            phase65EpubRecord(mediaId: 'book-epub').toJson(),
          ],
        }),
      });

      final repository = ReadingProgressRepository();
      final result = await repository.load();

      expect(result.recoveryWarnings, isNotEmpty);
      expect(repository.allRecords, hasLength(1));
      expect(repository.getByMediaId('book-epub'), isNotNull);
    });

    test('duplicate mediaId keeps newest lastReadAt on load', () async {
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [
            phase65PdfRecord(
              lastReadAt: phase65Utc(2026, 7, 27, 10),
              pageIndex: 2,
            ).toJson(),
            phase65PdfRecord(
              lastReadAt: phase65Utc(2026, 7, 27, 14),
              pageIndex: 8,
            ).toJson(),
          ],
        }),
      });

      final repository = ReadingProgressRepository();
      await repository.load();

      expect(repository.allRecords, hasLength(1));
      expect(
        (repository.getByMediaId('book-pdf')!.location
                as PdfReadingLocationPayload)
            .pageIndex,
        8,
      );
    });

    test('upsert creates and updates without duplication', () async {
      final repository = await initializedReadingProgressRepository();

      await repository.upsert(phase65PdfRecord(pageIndex: 3));
      await repository.upsert(
        phase65PdfRecord(
          pageIndex: 7,
          lastReadAt: phase65Utc(2026, 7, 27, 13),
        ),
      );

      expect(repository.allRecords, hasLength(1));
      expect(
        (repository.getByMediaId('book-pdf')!.location
                as PdfReadingLocationPayload)
            .pageIndex,
        7,
      );
    });

    test('upsert preserves firstReadAt across updates', () async {
      final repository = await initializedReadingProgressRepository();
      final firstRead = phase65Utc(2026, 7, 20, 9);

      await repository.upsert(
        phase65PdfRecord(lastReadAt: firstRead, pageIndex: 2),
      );
      await repository.upsert(
        phase65PdfRecord(
          lastReadAt: phase65Utc(2026, 7, 27, 12),
          pageIndex: 5,
        ),
      );

      expect(repository.getByMediaId('book-pdf')?.firstReadAt, firstRead);
    });

    test('orders by lastReadAt descending with mediaId tie-break', () async {
      final repository = await initializedReadingProgressRepository();
      final at = phase65Utc(2026, 7, 27, 12);

      await repository.upsert(
        phase65PdfRecord(mediaId: 'book-a', lastReadAt: at, pageIndex: 2),
      );
      await repository.upsert(
        phase65EpubRecord(mediaId: 'book-b', lastReadAt: at, spineIndex: 2),
      );
      await repository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-z',
          lastReadAt: phase65Utc(2026, 7, 27, 13),
        ),
      );

      expect(
        repository.allRecords.map((record) => record.mediaId).toList(),
        ['comic-z', 'book-a', 'book-b'],
      );
    });

    test('continueReading excludes completed records', () async {
      final repository = await initializedReadingProgressRepository();

      await repository.upsert(
        phase65PdfRecord(
          mediaId: 'book-done',
          completed: true,
          progressFraction: 1.0,
          lastReadAt: phase65Utc(2026, 7, 27, 14),
        ),
      );
      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-active',
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );

      final eligible = repository.continueReading();
      expect(eligible, hasLength(1));
      expect(eligible.single.mediaId, 'book-active');
    });

    test('continueReading excludes records without meaningful progress',
        () async {
      final repository = await initializedReadingProgressRepository();

      await repository.upsert(
        phase65PdfRecord(
          mediaId: 'book-start',
          pageIndex: 0,
          progressFraction: 0.005,
        ),
      );
      await repository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-active',
          pageIndex: 3,
        ),
      );

      final eligible = repository.continueReading();
      expect(eligible, hasLength(1));
      expect(eligible.single.mediaId, 'comic-active');
    });

    test('continueReading default query cap is 20', () async {
      final repository = await initializedReadingProgressRepository();

      for (var i = 0; i < 25; i++) {
        await repository.upsert(
          phase65PdfRecord(
            mediaId: 'book-$i',
            pageIndex: 2,
            lastReadAt: phase65Utc(2026, 7, 27, 12, i),
          ),
        );
      }

      expect(repository.continueReading(), hasLength(20));
      expect(repository.storedRecordCount, 25);
    });

    test('retention cap keeps 100 newest records', () async {
      final repository = await initializedReadingProgressRepository();

      for (var i = 0; i < 105; i++) {
        await repository.upsert(
          phase65PdfRecord(
            mediaId: 'book-$i',
            pageIndex: 2,
            lastReadAt: phase65Utc(2026, 1, 1, 0, i),
          ),
        );
      }

      expect(repository.storedRecordCount, 100);
      expect(repository.getByMediaId('book-0'), isNull);
      expect(repository.getByMediaId('book-4'), isNull);
      expect(repository.getByMediaId('book-104'), isNotNull);
    });

    test('save and reload round trip', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65EpubRecord(
          spineIndex: 5,
          sectionRelativeOffset: 88,
          progressFraction: 0.42,
        ),
      );

      final reloaded = ReadingProgressRepository();
      await reloaded.load();

      final record = reloaded.getByMediaId('book-epub')!;
      expect(record.progressFraction, 0.42);
      expect(
        (record.location as EpubReadingLocationPayload).spineIndex,
        5,
      );
    });

    test('storage failure returns unsuccessful result without throwing',
        () async {
      final repository = await initializedReadingProgressRepository();
      repository.simulatePersistFailure = true;

      final result = await repository.upsert(phase65PdfRecord());

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('corrupt envelope does not overwrite storage on read', () async {
      const corrupt = '{bad json';
      SharedPreferences.setMockInitialValues({
        ReadingProgressRepository.storageKey: corrupt,
      });

      final repository = ReadingProgressRepository();
      await repository.load();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ReadingProgressRepository.storageKey), corrupt);
    });
  });

  group('ReadingProgressRepository validateAgainstCatalog', () {
    test('identical catalogue makes no persistence writes', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65PdfRecord());

      final catalog = phase65ReadingCatalog();
      final first = await repository.validateAgainstCatalog(catalog);
      final prefsAfterFirst = (await SharedPreferences.getInstance())
          .getString(ReadingProgressRepository.storageKey);

      final second = await repository.validateAgainstCatalog(catalog);
      final prefsAfterSecond = (await SharedPreferences.getInstance())
          .getString(ReadingProgressRepository.storageKey);

      expect(first.changed, isFalse);
      expect(first.persisted, isFalse);
      expect(second.changed, isFalse);
      expect(prefsAfterSecond, prefsAfterFirst);
    });

    test('removed mediaId is pruned', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65PdfRecord());
      await repository.upsert(phase65EpubRecord());

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-27T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {
          'id': 'PRUNE',
          'scanner_version': '0.5.0',
          'catalogue_version': 4,
        },
        'folders': [
          {
            'id': 'books',
            'name': 'Books',
            'path': r'Y:\Media\Books',
            'item_count': 1,
            'items': [
              {
                'id': 'book-pdf',
                'title': 'Kept Manual',
                'file_path': r'Y:\Media\Books\Owner_Manual.pdf',
                'status': 'available',
                'media_kind': 'book',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.changed, isTrue);
      expect(result.removedCount, 1);
      expect(result.retainedCount, 1);
      expect(repository.getByMediaId('book-pdf'), isNotNull);
      expect(repository.getByMediaId('book-epub'), isNull);
    });

    test('format mismatch prunes record', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65PdfRecord(mediaId: 'book-epub').copyWith(
          mediaKind: MediaKind.book,
          readerFormat: ReadingReaderFormat.pdf,
        ),
      );

      final catalog = phase65ReadingCatalog();
      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.removedCount, 1);
      expect(repository.getByMediaId('book-epub'), isNull);
    });

    test('retained record refreshes title snapshot only', () async {
      final repository = await initializedReadingProgressRepository();
      final readAt = phase65Utc(2026, 7, 20, 9);
      await repository.upsert(
        phase65PdfRecord(
          title: 'Old Title',
          pageIndex: 12,
          progressFraction: 0.11,
          lastReadAt: readAt,
        ),
      );

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-27T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {
          'id': 'REFRESH',
          'scanner_version': '0.5.0',
          'catalogue_version': 4,
        },
        'folders': [
          {
            'id': 'books',
            'name': 'Books',
            'path': r'Y:\Media\Books',
            'item_count': 1,
            'items': [
              {
                'id': 'book-pdf',
                'title': 'Fresh Title',
                'file_path': r'Y:\Media\Books\Owner_Manual.pdf',
                'status': 'available',
                'media_kind': 'book',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      await repository.validateAgainstCatalog(catalog);

      final record = repository.getByMediaId('book-pdf')!;
      expect(record.title, 'Fresh Title');
      expect(record.progressFraction, 0.11);
      expect(record.lastReadAt, readAt);
      expect(
        (record.location as PdfReadingLocationPayload).pageIndex,
        12,
      );
    });

    test('persistence failure leaves in-memory records unchanged', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(phase65PdfRecord());
      await repository.upsert(phase65EpubRecord());

      repository.simulatePersistFailure = true;
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-27T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {
          'id': 'FAIL',
          'scanner_version': '0.5.0',
          'catalogue_version': 4,
        },
        'folders': [
          {
            'id': 'books',
            'name': 'Books',
            'path': r'Y:\Media\Books',
            'item_count': 1,
            'items': [
              {
                'id': 'book-pdf',
                'title': 'Kept',
                'file_path': r'Y:\Media\Books\Owner_Manual.pdf',
                'status': 'available',
                'media_kind': 'book',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final result = await repository.validateAgainstCatalog(catalog);

      expect(result.persistenceFailed, isTrue);
      expect(repository.storedRecordCount, 2);
      expect(repository.getByMediaId('book-epub'), isNotNull);
    });
  });
}
