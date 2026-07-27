import 'cbr_cli_archive_source.dart';
import '../spike/cbr_archive_adapter.dart';
import '../spike/cbr_gate0_models.dart';
import '../../reading/services/reader_session_telemetry.dart';
import 'comic_archive_errors.dart';
import 'comic_archive_source.dart';
import 'comic_page_ref.dart';
import 'comic_path_safety.dart';
import 'cbr/cbr_backend_resolver.dart';
import 'cbr/unrar_dll/unrar_dll_adapter.dart';
import 'cbr/unrar_dll/unrar_dll_loader.dart';

/// CBR archive source backed by official UnRAR64.dll (Gate 1 Candidate A).
class CbrDllArchiveSource implements ComicArchiveSource {
  CbrDllArchiveSource({
    required this.archivePath,
    CbrArchiveAdapter? adapter,
    UnrarDllLoader? loader,
  })  : _adapter = adapter ??
            UnrarDllCbrAdapter(loader: loader ?? UnrarDllLoader()),
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
    if (_ownsAdapter && _adapter is UnrarDllCbrAdapter) {
      final dll = _adapter as UnrarDllCbrAdapter;
      ReaderSessionTelemetry.instance.updateCbrSession(
        processInvocations: 0,
        tempDirectoryCount: 0,
      );
      ReaderSessionTelemetry.instance.recordCbrDllHandles(dll.activeHandleCount);
    }
    if (_ownsAdapter) {
      await _adapter.dispose();
    }
    ReaderSessionTelemetry.instance.recordCleanupResult('cbr_dll_source_disposed');
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

/// Factory helper used by [ComicArchiveOpener].
ComicArchiveSource openCbrArchiveSource({
  required String archivePath,
  required CbrBackendResolver resolver,
}) {
  final backend = resolver.peekBackendType();
  switch (backend) {
    case CbrBackendType.unrarDll:
      return CbrDllArchiveSource(
        archivePath: archivePath,
        loader: resolver.dllLoader,
      );
    case CbrBackendType.unrarCli:
      return CbrCliArchiveSource(
        archivePath: archivePath,
        resolver: resolver.cliResolver,
      );
    case CbrBackendType.unavailable:
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.cbrSupportUnavailable,
        userMessage: 'CBR support unavailable in this installation.',
        diagnosticDetail: 'cbr_backend_unavailable',
      );
  }
}
