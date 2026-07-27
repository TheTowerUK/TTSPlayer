/// Resource and safety limits for CBR native/CLI backends (Phase 6.3 Gate 1).
library;

/// Maximum archive entries accepted during listing.
const int cbrMaxEntryCount = 4096;

/// Maximum uncompressed bytes for a single comic page extraction.
const int cbrMaxSinglePageUncompressedBytes = 32 * 1024 * 1024;

/// Maximum sum of declared uncompressed sizes during listing (best-effort).
const int cbrMaxTotalListedUncompressedBytes = 512 * 1024 * 1024;

/// Maximum entry name length (UTF-16 code units / chars).
const int cbrMaxEntryNameLength = 1024;

/// Maximum bytes written to a temp directory during file-based extraction.
const int cbrMaxTempExtractionBytes = 64 * 1024 * 1024;

/// Maximum concurrent native archive handles per adapter instance.
const int cbrMaxConcurrentNativeHandles = 1;
