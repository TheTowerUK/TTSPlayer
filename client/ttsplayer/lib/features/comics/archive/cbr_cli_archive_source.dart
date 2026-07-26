import '../spike/cbr_archive_adapter.dart';
import '../spike/cbr_gate0_models.dart';
import '../spike/unrar_cli_cbr_adapter.dart';
import '../spike/unrar_cli_resolver.dart';
import 'comic_archive_errors.dart';
import 'comic_archive_source.dart';
import 'comic_page_ref.dart';
import 'comic_path_safety.dart';

/// CBR (RAR) archive source backed by Gate 0 [UnrarCliCbrAdapter].
///
/// Production redistribution of UnRAR.exe remains unresolved/blocking for shipping.
/// Local/runtime validation may use [UnrarCliResolver.overrideEnvKey].
class CbrCliArchiveSource implements ComicArchiveSource {
  CbrCliArchiveSource({
    required this.archivePath,
    CbrArchiveAdapter? adapter,
    UnrarCliResolver? resolver,
  }) : _adapter = adapter ??
            UnrarCliCbrAdapter(
              resolver: resolver ??
                  UnrarCliResolver(
                    expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
                  ),
            ),
        _ownsAdapter = adapter == null;

  final String archivePath;
  final CbrArchiveAdapter _adapter;
  final bool _ownsAdapter;
  List<ComicPageRef>? _pages;

  @override
  Future<List<ComicPageRef>> listPages() async {
    if (_pages != null) return _pages!;
    try {
      final listing = await _adapter.listEntries(archivePath);
      final images = listing.imageEntries.toList()
        ..sort((a, b) => comicNaturalCompare(a.name, b.name));
      if (images.isEmpty) {
        throw ComicArchiveException(
          kind: ComicArchiveErrorKind.noReadableImages,
          userMessage: 'This comic archive has no supported image pages.',
          diagnosticDetail: 'cbr_no_pages:${comicBasename(archivePath)}',
        );
      }
      _pages = [
        for (var i = 0; i < images.length; i++)
          ComicPageRef(
            entryName: images[i].name.replaceAll('\\', '/'),
            index: i,
            sizeBytes: images[i].sizeBytes,
          ),
      ];
      return _pages!;
    } on CbrArchiveException catch (e) {
      throw _mapCbr(e);
    }
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
    try {
      final page = await _adapter.extractEntry(archivePath, normalized);
      if (page.bytes.isEmpty) {
        throw ComicArchiveException(
          kind: ComicArchiveErrorKind.pageExtractFailed,
          userMessage: 'That comic page could not be opened.',
          diagnosticDetail: 'empty_page:${comicBasename(archivePath)}',
        );
      }
      return page.bytes;
    } on CbrArchiveException catch (e) {
      throw _mapCbr(e);
    }
  }

  @override
  Future<void> dispose() async {
    _pages = null;
    if (_ownsAdapter) {
      await _adapter.dispose();
    }
  }

  ComicArchiveException _mapCbr(CbrArchiveException e) {
    switch (e.kind) {
      case CbrArchiveErrorKind.nativeLibraryMissing:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.cbrSupportUnavailable,
          userMessage: 'CBR support unavailable in this installation.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.nativeLibraryLoadFailed:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.cbrExecutableMismatch,
          userMessage: 'CBR support unavailable in this installation.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.encryptedArchive:
      case CbrArchiveErrorKind.passwordRequired:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.encryptedArchive,
          userMessage: 'This comic archive is password-protected.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.multiVolumeUnsupported:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.multiVolumeUnsupported,
          userMessage: 'Multi-volume comic archives are not supported.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.corruptArchive:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.corruptArchive,
          userMessage: 'This comic archive appears to be damaged.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.emptyArchive:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.emptyArchive,
          userMessage: 'This comic archive has no readable pages.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.noSupportedImages:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.noReadableImages,
          userMessage: 'This comic archive has no supported image pages.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.pathTraversalRejected:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.unsafeEntryPath,
          userMessage: 'This comic page path is not allowed.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.notAnArchive:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.unsupportedArchiveType,
          userMessage: 'This file is not a readable comic archive.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.entryNotFound:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.pageExtractFailed,
          userMessage: 'That comic page could not be opened.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.ioFailure:
        final detail = (e.diagnosticDetail ?? '').toLowerCase();
        if (detail.contains('timeout')) {
          return ComicArchiveException(
            kind: ComicArchiveErrorKind.timeout,
            userMessage: 'Opening this comic took too long and was cancelled.',
            diagnosticDetail: e.diagnosticDetail,
          );
        }
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.ioFailure,
          userMessage: 'This comic archive could not be opened.',
          diagnosticDetail: e.diagnosticDetail,
        );
      case CbrArchiveErrorKind.unsupported:
      case CbrArchiveErrorKind.unknown:
        return ComicArchiveException(
          kind: ComicArchiveErrorKind.unknown,
          userMessage: e.userMessage,
          diagnosticDetail: e.diagnosticDetail,
        );
    }
  }
}
