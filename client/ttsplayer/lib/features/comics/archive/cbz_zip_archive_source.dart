import 'dart:io';

import 'package:archive/archive.dart';

import 'comic_archive_errors.dart';
import 'comic_archive_source.dart';
import 'comic_page_ref.dart';
import 'comic_path_safety.dart';

/// In-process CBZ (ZIP) archive source via `package:archive`.
///
/// Memory (interim — see books-comics.md / Phase 6.6):
/// - Reads the entire `.cbz` file into a byte buffer.
/// - [ZipDecoder.decodeBytes] decompresses **all** entries and stores each
///   entry's bytes in [ArchiveFile.content].
/// - The decoded [Archive] is retained in [_archive] for the source lifetime.
/// - [ComicPageCache] bounds only the controller's duplicate page-byte copies;
///   it does **not** cap underlying archive-parser memory.
class CbzZipArchiveSource implements ComicArchiveSource {
  CbzZipArchiveSource(this.archivePath);

  final String archivePath;
  Archive? _archive;
  List<ComicPageRef>? _pages;

  Future<Archive> _ensureDecoded() async {
    if (_archive != null) return _archive!;
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
    try {
      final bytes = await file.readAsBytes();
      final decoded = ZipDecoder().decodeBytes(bytes, verify: false);
      _archive = decoded;
      return decoded;
    } catch (_) {
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
    final archive = await _ensureDecoded();
    final names = <String>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (comicIsUnsafeEntryName(name)) continue;
      if (!comicIsImageEntryName(name)) continue;
      names.add(name);
    }
    names.sort(comicNaturalCompare);
    if (names.isEmpty) {
      throw ComicArchiveException(
        kind: archive.isEmpty
            ? ComicArchiveErrorKind.emptyArchive
            : ComicArchiveErrorKind.noReadableImages,
        userMessage: archive.isEmpty
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
          sizeBytes: archive.findFile(names[i])?.size,
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
    final archive = await _ensureDecoded();
    final file = archive.findFile(normalized) ??
        archive.findFile(normalized.replaceAll('/', '\\'));
    if (file == null || !file.isFile) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.pageExtractFailed,
        userMessage: 'That comic page could not be opened.',
        diagnosticDetail: 'missing_entry:${comicBasename(archivePath)}',
      );
    }
    return file.content;
  }

  @override
  Future<void> dispose() async {
    _archive = null;
    _pages = null;
  }
}
