import 'package:pdfrx/pdfrx.dart';

import '../archive/book_reader_errors.dart';

/// Maps pdfrx open failures to [BookReaderException] for pre-route probes.
BookReaderException mapPdfOpenError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('password') || message.contains('encrypt')) {
    return BookReaderException(
      kind: BookReaderErrorKind.pdfEncrypted,
      userMessage: 'This PDF is password-protected.',
    );
  }
  if (message.contains('format') || message.contains('corrupt')) {
    return BookReaderException(
      kind: BookReaderErrorKind.pdfCorrupt,
      userMessage: 'This PDF could not be opened.',
    );
  }
  return BookReaderException(
    kind: BookReaderErrorKind.pdfInvalid,
    userMessage: 'This PDF could not be opened.',
  );
}

Future<void> probePdfFile(String path) async {
  try {
    final doc = await PdfDocument.openFile(path, passwordProvider: () => null);
    await doc.dispose();
  } catch (e) {
    throw mapPdfOpenError(e);
  }
}
