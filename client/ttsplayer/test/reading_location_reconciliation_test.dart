import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/services/reading_location_reconciliation.dart';

void main() {
  group('ReadingLocationReconciliation PDF', () {
    test('exact match when document unchanged and index valid', () {
      const saved = PdfReadingLocationPayload(
        pageIndex: 12,
        pageCountAtSave: 100,
        pageRelativeOffset: 0.25,
      );

      final result = ReadingLocationReconciliation.reconcilePdf(
        saved: saved,
        currentPageCount: 100,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.exact);
      expect(result.usedFallback, isFalse);
      final location = result.location as PdfReadingLocationPayload;
      expect(location.pageIndex, 12);
      expect(location.pageCountAtSave, 100);
      expect(location.pageRelativeOffset, 0.25);
    });

    test('index clamped when saved page exceeds current count', () {
      const saved = PdfReadingLocationPayload(
        pageIndex: 120,
        pageCountAtSave: 100,
      );

      final result = ReadingLocationReconciliation.reconcilePdf(
        saved: saved,
        currentPageCount: 100,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.indexClamped);
      expect(result.usedFallback, isTrue);
      final location = result.location as PdfReadingLocationPayload;
      expect(location.pageIndex, 99);
      expect(location.pageCountAtSave, 100);
    });

    test('document changed when page count differs and hint is false', () {
      const saved = PdfReadingLocationPayload(
        pageIndex: 40,
        pageCountAtSave: 80,
      );

      final result = ReadingLocationReconciliation.reconcilePdf(
        saved: saved,
        currentPageCount: 120,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.documentChanged);
      expect(result.usedFallback, isTrue);
      final location = result.location as PdfReadingLocationPayload;
      expect(location.pageIndex, 0);
      expect(location.pageCountAtSave, 120);
    });

    test('same count with false hint still restores clamped index', () {
      const saved = PdfReadingLocationPayload(
        pageIndex: 40,
        pageCountAtSave: 100,
      );

      final result = ReadingLocationReconciliation.reconcilePdf(
        saved: saved,
        currentPageCount: 100,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.exact);
      final location = result.location as PdfReadingLocationPayload;
      expect(location.pageIndex, 40);
    });

    test('fallback to start when document has no pages', () {
      const saved = PdfReadingLocationPayload(
        pageIndex: 5,
        pageCountAtSave: 20,
      );

      final result = ReadingLocationReconciliation.reconcilePdf(
        saved: saved,
        currentPageCount: 0,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.fallbackToStart);
      expect(result.usedFallback, isTrue);
      expect((result.location as PdfReadingLocationPayload).pageIndex, 0);
    });
  });

  group('ReadingLocationReconciliation EPUB', () {
    const spineHrefs = [
      'cover.xhtml',
      'part1/ch01.xhtml',
      'part1/ch02.xhtml',
      'part2/ch03.xhtml',
    ];

    test('href matched when saved href suffix matches spine entry', () {
      const saved = EpubReadingLocationPayload(
        spineIndex: 9,
        spineHref: 'ch03.xhtml',
        spineCountAtSave: 10,
        sectionRelativeOffset: 120,
        chapterTitle: 'Chapter Three',
      );

      final result = ReadingLocationReconciliation.reconcileEpub(
        saved: saved,
        spineHrefs: spineHrefs,
        currentSpineCount: spineHrefs.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.hrefMatched);
      final location = result.location as EpubReadingLocationPayload;
      expect(location.spineIndex, 3);
      expect(location.spineHref, 'part2/ch03.xhtml');
      expect(location.sectionRelativeOffset, 120);
      expect(location.chapterTitle, 'Chapter Three');
    });

    test('exact index when href missing but saved index still valid', () {
      const saved = EpubReadingLocationPayload(
        spineIndex: 2,
        spineHref: 'missing.xhtml',
        spineCountAtSave: 4,
        sectionRelativeOffset: 40,
      );

      final result = ReadingLocationReconciliation.reconcileEpub(
        saved: saved,
        spineHrefs: spineHrefs,
        currentSpineCount: spineHrefs.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.exact);
      final location = result.location as EpubReadingLocationPayload;
      expect(location.spineIndex, 2);
      expect(location.spineHref, 'part1/ch02.xhtml');
    });

    test('index clamped when saved spine index exceeds current spine', () {
      const saved = EpubReadingLocationPayload(
        spineIndex: 99,
        spineHref: 'missing.xhtml',
        spineCountAtSave: 100,
      );

      final result = ReadingLocationReconciliation.reconcileEpub(
        saved: saved,
        spineHrefs: spineHrefs,
        currentSpineCount: spineHrefs.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.indexClamped);
      expect(result.usedFallback, isTrue);
      expect((result.location as EpubReadingLocationPayload).spineIndex, 3);
    });

    test('document changed when spine count differs and hint is false', () {
      const saved = EpubReadingLocationPayload(
        spineIndex: 2,
        spineHref: 'part1/ch02.xhtml',
        spineCountAtSave: 10,
        sectionRelativeOffset: 200,
      );

      final result = ReadingLocationReconciliation.reconcileEpub(
        saved: saved,
        spineHrefs: spineHrefs,
        currentSpineCount: spineHrefs.length,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.documentChanged);
      expect(result.usedFallback, isTrue);
      final location = result.location as EpubReadingLocationPayload;
      expect(location.spineIndex, 0);
      expect(location.spineHref, spineHrefs.first);
      expect(location.sectionRelativeOffset, 0);
    });

    test('fallback to start when spine is empty', () {
      const saved = EpubReadingLocationPayload(
        spineIndex: 1,
        spineHref: 'part1/ch02.xhtml',
        spineCountAtSave: 4,
      );

      final result = ReadingLocationReconciliation.reconcileEpub(
        saved: saved,
        spineHrefs: const [],
        currentSpineCount: 0,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.fallbackToStart);
      expect(result.usedFallback, isTrue);
      expect((result.location as EpubReadingLocationPayload).spineIndex, 0);
    });

    test('invalid offset is sanitized to zero', () {
      const saved = EpubReadingLocationPayload(
        spineIndex: 1,
        spineHref: 'part1/ch01.xhtml',
        spineCountAtSave: 4,
        sectionRelativeOffset: double.nan,
      );

      final result = ReadingLocationReconciliation.reconcileEpub(
        saved: saved,
        spineHrefs: spineHrefs,
        currentSpineCount: spineHrefs.length,
        sameDocumentHint: true,
      );

      expect((result.location as EpubReadingLocationPayload).sectionRelativeOffset, 0);
    });
  });

  group('ReadingLocationReconciliation comic', () {
    const entryNames = [
      '001.jpg',
      '002.jpg',
      '003.jpg',
      '004.jpg',
    ];

    test('entry matched by archive entry name', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 9,
        pageCountAtSave: 20,
        entryName: '003.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.entryMatched);
      final location = result.location as ComicReadingLocationPayload;
      expect(location.pageIndex, 2);
      expect(location.entryName, '003.jpg');
    });

    test('exact when same document and index valid', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 1,
        pageCountAtSave: 4,
        entryName: '002.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.entryMatched);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 1);
    });

    test('index clamped when saved page exceeds archive length', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 99,
        pageCountAtSave: 100,
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.indexClamped);
      expect(result.usedFallback, isTrue);
      final location = result.location as ComicReadingLocationPayload;
      expect(location.pageIndex, 3);
      expect(location.entryName, '004.jpg');
    });

    test('entry matched after reordered archive when counts differ', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 50,
        pageCountAtSave: 100,
        entryName: '004.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.entryMatched);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 3);
    });

    test('document changed when entry missing and counts differ', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 50,
        pageCountAtSave: 100,
        entryName: 'missing.jpg',
        archiveFormat: ReadingReaderFormat.cbz,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: entryNames,
        currentPageCount: entryNames.length,
        sameDocumentHint: false,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.documentChanged);
      expect(result.usedFallback, isTrue);
      final location = result.location as ComicReadingLocationPayload;
      expect(location.pageIndex, 0);
      expect(location.entryName, '001.jpg');
    });

    test('fallback to start when archive is empty', () {
      const saved = ComicReadingLocationPayload(
        pageIndex: 2,
        pageCountAtSave: 10,
        entryName: '003.jpg',
        archiveFormat: ReadingReaderFormat.cbr,
      );

      final result = ReadingLocationReconciliation.reconcileComic(
        saved: saved,
        entryNames: const [],
        currentPageCount: 0,
        sameDocumentHint: true,
      );

      expect(result.outcome, ReadingLocationReconcileOutcome.fallbackToStart);
      expect(result.usedFallback, isTrue);
      expect((result.location as ComicReadingLocationPayload).pageIndex, 0);
    });
  });

  group('ReadingLocationReconciliation completion threshold', () {
    test('isCompletedFraction uses 95% policy constant', () {
      expect(ReadingLocationReconciliation.isCompletedFraction(0.94), isFalse);
      expect(ReadingLocationReconciliation.isCompletedFraction(0.95), isTrue);
      expect(ReadingLocationReconciliation.isCompletedFraction(1.0), isTrue);
    });
  });
}
