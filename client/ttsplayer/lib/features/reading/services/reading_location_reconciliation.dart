import '../models/reading_location_payload.dart';
import '../models/reading_progress_policy.dart';

/// Outcome of reconciling a saved location against the current document.
enum ReadingLocationReconcileOutcome {
  exact,
  hrefMatched,
  entryMatched,
  indexClamped,
  fallbackToStart,
  documentChanged,
}

class ReadingLocationReconcileResult {
  const ReadingLocationReconcileResult({
    required this.outcome,
    required this.location,
    this.usedFallback = false,
  });

  final ReadingLocationReconcileOutcome outcome;
  final ReadingLocationPayload location;
  final bool usedFallback;
}

/// Reconciles persisted reading locations with current document structure (M6.5).
abstract final class ReadingLocationReconciliation {
  static ReadingLocationReconcileResult reconcilePdf({
    required PdfReadingLocationPayload saved,
    required int currentPageCount,
    required bool sameDocumentHint,
  }) {
    if (currentPageCount <= 0) {
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.fallbackToStart,
        location: PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: saved.pageCountAtSave,
        ),
        usedFallback: true,
      );
    }

    if (!sameDocumentHint ||
        saved.pageCountAtSave != currentPageCount) {
      if (saved.pageCountAtSave == currentPageCount) {
        final clamped = saved.pageIndex.clamp(0, currentPageCount - 1);
        return ReadingLocationReconcileResult(
          outcome: clamped == saved.pageIndex
              ? ReadingLocationReconcileOutcome.exact
              : ReadingLocationReconcileOutcome.indexClamped,
          location: PdfReadingLocationPayload(
            pageIndex: clamped,
            pageCountAtSave: currentPageCount,
            pageRelativeOffset: saved.pageRelativeOffset,
          ),
          usedFallback: clamped != saved.pageIndex,
        );
      }
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.documentChanged,
        location: PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: currentPageCount,
        ),
        usedFallback: true,
      );
    }

    final clamped = saved.pageIndex.clamp(0, currentPageCount - 1);
    return ReadingLocationReconcileResult(
      outcome: clamped == saved.pageIndex
          ? ReadingLocationReconcileOutcome.exact
          : ReadingLocationReconcileOutcome.indexClamped,
      location: PdfReadingLocationPayload(
        pageIndex: clamped,
        pageCountAtSave: currentPageCount,
        pageRelativeOffset: saved.pageRelativeOffset,
      ),
      usedFallback: clamped != saved.pageIndex,
    );
  }

  static ReadingLocationReconcileResult reconcileEpub({
    required EpubReadingLocationPayload saved,
    required List<String> spineHrefs,
    required int currentSpineCount,
    required bool sameDocumentHint,
  }) {
    if (currentSpineCount <= 0 || spineHrefs.isEmpty) {
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.fallbackToStart,
        location: EpubReadingLocationPayload(
          spineIndex: 0,
          spineHref: saved.spineHref,
          spineCountAtSave: saved.spineCountAtSave,
        ),
        usedFallback: true,
      );
    }

    if (!sameDocumentHint && saved.spineCountAtSave != currentSpineCount) {
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.documentChanged,
        location: EpubReadingLocationPayload(
          spineIndex: 0,
          spineHref: spineHrefs.first,
          spineCountAtSave: currentSpineCount,
        ),
        usedFallback: true,
      );
    }

    var index = spineHrefs.indexWhere(
      (href) => href == saved.spineHref || href.endsWith(saved.spineHref),
    );
    var outcome = ReadingLocationReconcileOutcome.hrefMatched;
    if (index < 0) {
      index = saved.spineIndex.clamp(0, currentSpineCount - 1);
      outcome = saved.spineIndex == index
          ? ReadingLocationReconcileOutcome.exact
          : ReadingLocationReconcileOutcome.indexClamped;
    }

    final offset = saved.sectionRelativeOffset;
    final safeOffset = offset.isFinite && !offset.isNegative ? offset : 0.0;

    return ReadingLocationReconcileResult(
      outcome: outcome,
      location: EpubReadingLocationPayload(
        spineIndex: index,
        spineHref: spineHrefs[index],
        spineCountAtSave: currentSpineCount,
        chapterTitle: saved.chapterTitle,
        sectionRelativeOffset: sameDocumentHint ? safeOffset : 0,
      ),
      usedFallback: outcome == ReadingLocationReconcileOutcome.indexClamped,
    );
  }

  static ReadingLocationReconcileResult reconcileComic({
    required ComicReadingLocationPayload saved,
    required List<String> entryNames,
    required int currentPageCount,
    required bool sameDocumentHint,
  }) {
    if (currentPageCount <= 0 || entryNames.isEmpty) {
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.fallbackToStart,
        location: ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: saved.pageCountAtSave,
          entryName: saved.entryName,
          archiveFormat: saved.archiveFormat,
        ),
        usedFallback: true,
      );
    }

    if (!sameDocumentHint &&
        saved.pageCountAtSave != currentPageCount &&
        saved.entryName != null) {
      final byEntry = entryNames.indexOf(saved.entryName!);
      if (byEntry >= 0) {
        return ReadingLocationReconcileResult(
          outcome: ReadingLocationReconcileOutcome.entryMatched,
          location: ComicReadingLocationPayload(
            pageIndex: byEntry,
            pageCountAtSave: currentPageCount,
            entryName: entryNames[byEntry],
            archiveFormat: saved.archiveFormat,
          ),
        );
      }
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.documentChanged,
        location: ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: currentPageCount,
          entryName: entryNames.first,
          archiveFormat: saved.archiveFormat,
        ),
        usedFallback: true,
      );
    }

    if (saved.entryName != null) {
      final byEntry = entryNames.indexOf(saved.entryName!);
      if (byEntry >= 0) {
        return ReadingLocationReconcileResult(
          outcome: ReadingLocationReconcileOutcome.entryMatched,
          location: ComicReadingLocationPayload(
            pageIndex: byEntry,
            pageCountAtSave: currentPageCount,
            entryName: entryNames[byEntry],
            archiveFormat: saved.archiveFormat,
          ),
        );
      }
    }

    if (saved.pageCountAtSave != currentPageCount && !sameDocumentHint) {
      return ReadingLocationReconcileResult(
        outcome: ReadingLocationReconcileOutcome.documentChanged,
        location: ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: currentPageCount,
          entryName: entryNames.first,
          archiveFormat: saved.archiveFormat,
        ),
        usedFallback: true,
      );
    }

    final clamped = saved.pageIndex.clamp(0, currentPageCount - 1);
    return ReadingLocationReconcileResult(
      outcome: clamped == saved.pageIndex
          ? ReadingLocationReconcileOutcome.exact
          : ReadingLocationReconcileOutcome.indexClamped,
      location: ComicReadingLocationPayload(
        pageIndex: clamped,
        pageCountAtSave: currentPageCount,
        entryName: entryNames[clamped],
        archiveFormat: saved.archiveFormat,
      ),
      usedFallback: clamped != saved.pageIndex,
    );
  }

  static bool isCompletedFraction(double fraction) =>
      fraction >= ReadingProgressPolicy.completionThreshold;
}
