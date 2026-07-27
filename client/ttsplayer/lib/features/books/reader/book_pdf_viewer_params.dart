import 'package:pdfrx/pdfrx.dart';

/// TTSPlayer PDF viewer configuration (M6.6).
///
/// Uses public [PdfViewerParams] only — no pdfrx internal APIs.
///
/// pdfrx 2.4.7 defaults (for comparison):
/// - [limitRenderingCache]: true (PDFium limited image cache flag)
/// - [maxImageBytesCachedOnMemory]: 100 MiB
/// - [horizontalCacheExtent] / [verticalCacheExtent]: 1.0 viewport
/// - Rendered page bitmaps evicted by viewer cache when over byte budget
///
/// TTSPlayer applies a lower in-memory rendered-page budget for large documents
/// while keeping PDFium's limited rendering cache enabled.
PdfViewerParams ttsPlayerPdfViewerParams({
  void Function(PdfDocumentRef ref, bool succeeded)? onDocumentLoadFinished,
}) {
  return PdfViewerParams(
    limitRenderingCache: TtsPlayerPdfViewerPolicy.limitRenderingCache,
    maxImageBytesCachedOnMemory:
        TtsPlayerPdfViewerPolicy.maxImageBytesCachedOnMemory,
    horizontalCacheExtent: TtsPlayerPdfViewerPolicy.horizontalCacheExtent,
    verticalCacheExtent: TtsPlayerPdfViewerPolicy.verticalCacheExtent,
    onePassRenderingSizeThreshold:
        TtsPlayerPdfViewerPolicy.onePassRenderingSizeThreshold,
    onDocumentLoadFinished: onDocumentLoadFinished,
  );
}

/// Documented policy constants for diagnostics export (stable labels).
abstract final class TtsPlayerPdfViewerPolicy {
  static const limitRenderingCache = true;
  static const maxImageBytesCachedOnMemory = 48 * 1024 * 1024;
  static const horizontalCacheExtent = 1.0;
  static const verticalCacheExtent = 1.0;
  static const onePassRenderingSizeThreshold = 2000.0;
}
