import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/models/catalog.dart';

import 'support/reading_progress_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContinueReadingProjection', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('empty repository yields empty projection', () async {
      final repository = await initializedReadingProgressRepository();
      final projection = ContinueReadingProjection();

      expect(
        projection.build(
          catalog: phase65ReadingCatalog(),
          repository: repository,
        ),
        isEmpty,
      );
    });

    test('mixed books and comics ordered by lastReadAt descending', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65PdfRecord(
          mediaId: 'book-pdf',
          lastReadAt: phase65Utc(2026, 7, 27, 10),
        ),
      );
      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-epub',
          lastReadAt: phase65Utc(2026, 7, 27, 14),
        ),
      );
      await repository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-cbz',
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );

      final entries = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      );

      expect(entries, hasLength(3));
      expect(entries.map((entry) => entry.item.id).toList(), [
        'book-epub',
        'comic-cbz',
        'book-pdf',
      ]);
      expect(entries.every((entry) => entry.isPlayable), isTrue);
    });

    test('limit caps projection at 20 entries', () async {
      final repository = await initializedReadingProgressRepository();
      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-27T12:00:00+00:00',
        'total_items': 25,
        'catalogue': {
          'id': 'LIMIT',
          'scanner_version': '0.5.0',
          'catalogue_version': 4,
        },
        'folders': [
          {
            'id': 'books',
            'name': 'Books',
            'path': r'Y:\Media\Books',
            'item_count': 25,
            'items': [
              for (var i = 0; i < 25; i++)
                {
                  'id': 'book-$i',
                  'title': 'Book $i',
                  'file_path': r'Y:\Media\Books\book-$i.pdf',
                  'status': 'available',
                  'media_kind': 'book',
                },
            ],
            'subfolders': [],
          },
        ],
      });

      for (var i = 0; i < 25; i++) {
        await repository.upsert(
          phase65PdfRecord(
            mediaId: 'book-$i',
            title: 'Book $i',
            lastReadAt: phase65Utc(2026, 7, 27, 12, i),
          ),
        );
      }

      final entries = ContinueReadingProjection().build(
        catalog: catalog,
        repository: repository,
      );

      expect(entries, hasLength(20));
      expect(entries.first.item.id, 'book-24');
    });

    test('completed records are excluded', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65PdfRecord(
          mediaId: 'book-pdf',
          completed: true,
          progressFraction: 1.0,
          lastReadAt: phase65Utc(2026, 7, 27, 15),
        ),
      );
      await repository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-cbz',
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );

      final entries = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      );

      expect(entries, hasLength(1));
      expect(entries.single.item.id, 'comic-cbz');
    });

    test('missing catalogue item is skipped', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65PdfRecord(
          mediaId: 'orphan-record',
          lastReadAt: phase65Utc(2026, 7, 27, 16),
        ),
      );
      await repository.upsert(
        phase65EpubRecord(
          mediaId: 'book-epub',
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );

      final entries = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      );

      expect(entries, hasLength(1));
      expect(entries.single.item.id, 'book-epub');
    });

    test('missing file status surfaces missing availability', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65PdfRecord(
          mediaId: 'book-pdf',
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-27T12:00:00+00:00',
        'total_items': 1,
        'catalogue': {
          'id': 'MISSING',
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
                'title': 'Owner Manual',
                'file_path': r'Y:\Media\Books\Owner_Manual.pdf',
                'status': 'missing',
                'media_kind': 'book',
              },
            ],
            'subfolders': [],
          },
        ],
      });

      final entry = ContinueReadingProjection().build(
        catalog: catalog,
        repository: repository,
      ).single;

      expect(entry.availability, ContinueReadingAvailability.missing);
      expect(entry.isPlayable, isFalse);
      expect(entry.unavailabilityReason, isNotNull);
    });

    test('unsupported comic format surfaces conversion guidance', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65ComicRecord(
          mediaId: 'comic-cbr',
          archiveFormat: ReadingReaderFormat.cbr,
          entryName: '001.png',
          lastReadAt: phase65Utc(2026, 7, 27, 12),
        ),
      );

      final entry = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      ).single;

      expect(entry.item.id, 'comic-cbr');
      expect(
        entry.availability,
        ContinueReadingAvailability.unsupportedComicFormat,
      );
      expect(entry.isPlayable, isFalse);
      expect(entry.unavailabilityReason, kCbrConversionGuidance);
    });

    test('location labels reflect saved payload', () async {
      final repository = await initializedReadingProgressRepository();
      await repository.upsert(
        phase65EpubRecord(
          chapterTitle: 'The Gate',
          spineIndex: 2,
          spineCountAtSave: 8,
        ),
      );

      final entry = ContinueReadingProjection().build(
        catalog: phase65ReadingCatalog(),
        repository: repository,
      ).single;

      expect(entry.locationLabel, 'The Gate');
      expect(entry.progressPercent, inInclusiveRange(0, 99));
    });
  });
}
