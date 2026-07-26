import 'dart:io';

import '../../../models/media_item.dart';
import '../../../services/media_access/media_location_resolver.dart';
import '../spike/unrar_cli_resolver.dart';
import 'cbz_zip_archive_source.dart';
import 'cbr_cli_archive_source.dart';
import 'comic_archive_errors.dart';
import 'comic_archive_source.dart';
import 'comic_path_safety.dart';

/// Resolves a catalogue comic [MediaItem] to a [ComicArchiveSource].
class ComicArchiveOpener {
  ComicArchiveOpener({
    required MediaLocationResolver mediaLocationResolver,
    UnrarCliResolver? cbrResolver,
  })  : _resolver = mediaLocationResolver,
        _cbrResolver = cbrResolver;

  final MediaLocationResolver _resolver;
  final UnrarCliResolver? _cbrResolver;

  /// Returns a local filesystem path suitable for archive APIs.
  String resolveLocalArchivePath(MediaItem item) {
    if (!item.isComic) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.unsupportedArchiveType,
        userMessage: 'This item is not a comic archive.',
        diagnosticDetail: 'not_comic',
      );
    }
    final resolved = _resolver.resolve(item.filePath);
    if (!resolved.isPlayable || resolved.uri == null) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.archiveMissing,
        userMessage: 'This comic file could not be found.',
        diagnosticDetail: 'unresolved:${comicBasename(item.filePath)}',
      );
    }
    final uri = resolved.uri!;
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.ioFailure,
        userMessage:
            'This comic must be available as a local file to open in the reader.',
        diagnosticDetail: 'remote_uri:${comicBasename(item.filePath)}',
      );
    }
    var path = uri;
    if (path.startsWith('file:///')) {
      path = Uri.parse(path).toFilePath(windows: Platform.isWindows);
    } else if (path.startsWith('file://')) {
      path = Uri.parse(path).toFilePath(windows: Platform.isWindows);
    }
    if (!File(path).existsSync()) {
      throw ComicArchiveException(
        kind: ComicArchiveErrorKind.archiveMissing,
        userMessage: 'This comic file could not be found.',
        diagnosticDetail: 'missing:${comicBasename(item.filePath)}',
      );
    }
    return path;
  }

  ComicArchiveSource openPath(String archivePath) {
    final ext = archivePath.contains('.')
        ? archivePath.split('.').last.toLowerCase()
        : '';
    if (ext == 'cbz' || ext == 'zip') {
      return CbzZipArchiveSource(archivePath);
    }
    if (ext == 'cbr' || ext == 'rar') {
      // Probe CBR tooling before constructing a broken reader session.
      final resolver = _cbrResolver ??
          UnrarCliResolver(
            expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
          );
      if (resolver.resolvePath() == null) {
        throw ComicArchiveException(
          kind: ComicArchiveErrorKind.cbrSupportUnavailable,
          userMessage: 'CBR support unavailable in this installation.',
          diagnosticDetail: 'unrar_cli_missing',
        );
      }
      return CbrCliArchiveSource(
        archivePath: archivePath,
        resolver: resolver,
      );
    }
    throw ComicArchiveException(
      kind: ComicArchiveErrorKind.unsupportedArchiveType,
      userMessage: 'This file is not a readable comic archive.',
      diagnosticDetail: 'bad_ext:$ext',
    );
  }

  ComicArchiveSource openItem(MediaItem item) {
    final path = resolveLocalArchivePath(item);
    return openPath(path);
  }
}
