import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../services/media_access/media_location_resolver.dart';
import '../../reading/models/reading_location_payload.dart';
import '../../reading/reading_navigation.dart';
import '../../reading/services/reading_progress_coordinator.dart';
import '../../reading/services/reading_progress_repository.dart';
import '../archive/book_opener.dart';
import '../archive/book_reader_errors.dart';
import '../epub/epub_parser.dart';
import '../models/book_format.dart';
import 'book_pdf_probe.dart';
import 'book_reader_screen.dart';

/// Opens the book reader for [item], probing the document before navigation.
Future<void> openBookReaderScreen(
  BuildContext context, {
  required MediaItem item,
  bool startFromBeginning = false,
}) async {
  if (!item.isBook) return;
  if (!item.status.isPlayable) return;

  final resolver = context.read<MediaLocationResolver>();
  final opener = BookOpener(mediaLocationResolver: resolver);

  try {
    final target = opener.openItem(item);
    await _probeOpen(target);
    if (!context.mounted) return;

    final restore = resolveReadingRestore(
      item: item,
      repository: context.read<ReadingProgressRepository>(),
      startFromBeginning: startFromBeginning,
    );

    if (startFromBeginning && context.mounted) {
      final coordinator = context.read<ReadingProgressCoordinator>();
      coordinator.beginSession(
        item: item,
        readerFormat: target.format == BookFormat.pdf
            ? ReadingReaderFormat.pdf
            : ReadingReaderFormat.epub,
        initialLocation: target.format == BookFormat.pdf
            ? const PdfReadingLocationPayload(pageIndex: 0, pageCountAtSave: 1)
            : const EpubReadingLocationPayload(
                spineIndex: 0,
                spineHref: '',
                spineCountAtSave: 1,
              ),
        progressFraction: 0,
      );
      await coordinator.onReaderRestarted();
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'book_reader'),
        builder: (_) => BookReaderScreen(
          item: item,
          target: target,
          restorePlan: restore,
          startFromBeginning: startFromBeginning,
        ),
      ),
    );
  } on BookReaderException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.userMessage),
        action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
      ),
    );
  }
}

Future<void> _probeOpen(BookOpenTarget target) async {
  switch (target.format) {
    case BookFormat.pdf:
      await probePdfFile(target.localPath);
    case BookFormat.epub:
      await EpubParser().parseFile(target.localPath);
  }
}
