import 'dart:io';

import '../../../models/media_item.dart';
import '../../../services/media_access/media_location_resolver.dart';
import '../models/book_format.dart';
import 'book_path_safety.dart';
import 'book_reader_errors.dart';

/// Resolved local book open target.
class BookOpenTarget {
  const BookOpenTarget({
    required this.localPath,
    required this.format,
    required this.documentId,
  });

  final String localPath;
  final BookFormat format;
  final String documentId;
}

/// Resolves catalogue book items to local open targets.
class BookOpener {
  BookOpener({required MediaLocationResolver mediaLocationResolver})
      : _resolver = mediaLocationResolver;

  final MediaLocationResolver _resolver;

  BookOpenTarget openItem(MediaItem item) {
    if (!item.isBook) {
      throw BookReaderException(
        kind: BookReaderErrorKind.unsupportedFormat,
        userMessage: 'This item is not a book.',
        diagnosticDetail: 'not_book',
      );
    }
    if (!item.status.isPlayable) {
      throw BookReaderException(
        kind: BookReaderErrorKind.fileMissing,
        userMessage: 'This book is not available to open.',
        diagnosticDetail: 'not_playable',
      );
    }

    final resolved = _resolver.resolve(item.filePath);
    if (!resolved.isPlayable || resolved.uri == null) {
      throw BookReaderException(
        kind: BookReaderErrorKind.fileMissing,
        userMessage: 'This book file could not be found.',
        diagnosticDetail: 'unresolved:${bookBasename(item.filePath)}',
      );
    }

    final uri = resolved.uri!;
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      throw BookReaderException(
        kind: BookReaderErrorKind.ioFailure,
        userMessage:
            'This book must be available as a local file to open in the reader.',
        diagnosticDetail: 'remote_uri:${bookBasename(item.filePath)}',
      );
    }

    var path = uri;
    if (path.startsWith('file:///')) {
      path = Uri.parse(path).toFilePath(windows: Platform.isWindows);
    } else if (path.startsWith('file://')) {
      path = Uri.parse(path).toFilePath(windows: Platform.isWindows);
    }

    if (!File(path).existsSync()) {
      throw BookReaderException(
        kind: BookReaderErrorKind.fileMissing,
        userMessage: 'This book file could not be found.',
        diagnosticDetail: 'missing:${bookBasename(item.filePath)}',
      );
    }

    final format = bookFormatFromExtension(bookExtension(path));
    if (format == null) {
      throw BookReaderException(
        kind: BookReaderErrorKind.unsupportedFormat,
        userMessage: 'This file is not a supported book format.',
        diagnosticDetail: 'bad_ext:${bookExtension(path)}',
      );
    }

    return BookOpenTarget(
      localPath: path,
      format: format,
      documentId: item.id,
    );
  }
}
