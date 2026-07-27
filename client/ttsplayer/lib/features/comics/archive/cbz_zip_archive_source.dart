import 'dart:io';

import 'cbz_zip_lazy_reader.dart';
import 'comic_archive_errors.dart';
import 'comic_archive_source.dart';
import 'comic_page_ref.dart';
import 'comic_path_safety.dart';

/// In-process CBZ (ZIP) archive source with lazy per-entry reads (M6.6).
///
/// Memory model:
/// - Central directory metadata only while the source is open (entry names,
///   sizes, offsets — not decompressed page bytes).
/// - [loadPageBytes] decompresses **one** entry at a time.
/// - [ComicPageCache] bounds duplicate page-byte copies held by the controller.
class CbzZipArchiveSource implements ComicArchiveSource {
  CbzZipArchiveSource(this.archivePath) : _lazy = CbzZipLazyReader(archivePath);

  final String archivePath;
  final CbzZipLazyReader _lazy;
  List<ComicPageRef>? _pages;
  Map<String, ZipCentralEntry>? _entryByName;

  Future<void> _ensureFileValid() async {
    final file = File(archivePath);
    if (!file.existsSync()) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.archiveMissing,
        userMessage: 'This comic file could not be found.',
        diagnosticDetail: 'missing:${comicBasename(archivePath)}',
      );
    }
    if (file.lengthSync() == 0) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.emptyArchive,
        userMessage: 'This comic archive has no readable pages.',
        diagnosticDetail: 'zero_byte:${comicBasename(archivePath)}',
      );
    }
  }

  Future<Map<String, ZipCentralEntry>> _entryMap() async {
    if (_entryByName != null) return _entryByName!;
    await _ensureFileValid();
    try {
      final entries = await _lazy.centralEntries();
      _entryByName = {
        for (final entry in entries) entry.name: entry,
      };
      return _entryByName!;
    } on FormatException {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.corruptArchive,
        userMessage: 'This comic archive appears to be damaged.',
        diagnosticDetail: 'zip_open:${comicBasename(archivePath)}',
      );
    }
  }

  @override
  Future<List<ComicPageRef>> listPages() async {
    if (_pages != null) return _pages!;
    final byName = await _entryMap();
    final names = <String>[];
    for (final entry in byName.values) {
      if (comicIsUnsafeEntryName(entry.name)) continue;
      if (!comicIsImageEntryName(entry.name)) continue;
      names.add(entry.name);
    }
    names.sort(comicNaturalCompare);
    if (names.isEmpty) {
      throw ComicArchiveException(
        kind: byName.isEmpty
            ? ComicArchiveErrorKind.emptyArchive
            : ComicArchiveErrorKind.noReadableImages,
        userMessage: byName.isEmpty
            ? 'This comic archive has no readable pages.'
            : 'This comic archive has no supported image pages.',
        diagnosticDetail: 'cbz_no_pages:${comicBasename(archivePath)}',
      );
    }
    _pages = [
      for (var i = 0; i < names.length; i++)
        ComicPageRef(
          entryName: names[i],
          index: i,
          sizeBytes: byName[names[i]]!.uncompressedSize,
        ),
    ];
    return _pages!;
  }

  @override
  Future<List<int>> loadPageBytes(String entryName) async {
    final normalized = entryName.replaceAll('\\', '/');
    if (comicIsUnsafeEntryName(normalized)) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.unsafeEntryPath,
        userMessage: 'This comic page path is not allowed.',
        diagnosticDetail: 'unsafe:${comicBasename(archivePath)}',
      );
    }
    final byName = await _entryMap();
    final entry = byName[normalized];
    if (entry == null) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.pageExtractFailed,
        userMessage: 'That comic page could not be opened.',
        diagnosticDetail: 'missing_entry:${comicBasename(archivePath)}',
      );
    }
    try {
      final bytes = await _lazy.readEntryBytes(entry);
      if (bytes.isEmpty) {
        throw ComicArchiveException(
          kind: ComicArchiveErrorKind.pageExtractFailed,
          userMessage: 'That comic page could not be opened.',
          diagnosticDetail: 'empty_entry:${comicBasename(archivePath)}',
        );
      }
      return bytes;
    } on FormatException {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.corruptArchive,
        userMessage: 'This comic page could not be opened.',
        diagnosticDetail: 'bad_entry:${comicBasename(archivePath)}',
      );
    }
  }

  @override
  Future<void> dispose() async {
    _pages = null;
    _entryByName = null;
  }
}
