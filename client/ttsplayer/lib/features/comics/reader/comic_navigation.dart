import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../services/media_access/media_location_resolver.dart';
import '../../reading/models/reading_location_payload.dart';
import '../../reading/reading_navigation.dart';
import '../../reading/services/reading_progress_coordinator.dart';
import '../../reading/services/reading_progress_repository.dart';
import '../archive/comic_archive_errors.dart';
import '../archive/comic_archive_opener.dart';
import 'comic_reader_screen.dart';

/// Opens the comic reader for [item], or shows a controlled error snackbar.
Future<void> openComicReaderScreen(
  BuildContext context, {
  required MediaItem item,
  bool startFromBeginning = false,
}) async {
  if (!item.isComic) return;
  if (!item.status.isPlayable) return;

  final ext = _extension(item.filePath);
  if (!isSupportedComicArchiveExtension(ext)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ext == 'cbr' || ext == 'rar'
              ? kCbrConversionGuidance
              : 'This comic format is not supported. Use CBZ and rescan the library.',
        ),
        action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
      ),
    );
    return;
  }

  final resolver = context.read<MediaLocationResolver>();
  final opener = ComicArchiveOpener(mediaLocationResolver: resolver);

  try {
    final source = opener.openItem(item);
    if (!context.mounted) {
      await source.dispose();
      return;
    }

    final restore = resolveReadingRestore(
      item: item,
      repository: context.read<ReadingProgressRepository>(),
      startFromBeginning: startFromBeginning,
    );

    if (startFromBeginning && context.mounted) {
      final format =
          readerFormatForComicExtension(ext) ?? ReadingReaderFormat.cbz;
      final coordinator = context.read<ReadingProgressCoordinator>();
      coordinator.beginSession(
        item: item,
        readerFormat: format,
        initialLocation: ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: 1,
          archiveFormat: format,
        ),
        progressFraction: 0,
      );
      await coordinator.onReaderRestarted();
    }

    if (!context.mounted) {
      await source.dispose();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'comic_reader'),
        builder: (_) => ComicReaderScreen(
          item: item,
          source: source,
          restorePlan: restore,
          startFromBeginning: startFromBeginning,
        ),
      ),
    );
  } on ComicArchiveException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.userMessage),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return '';
  return path.substring(dot + 1).toLowerCase();
}
