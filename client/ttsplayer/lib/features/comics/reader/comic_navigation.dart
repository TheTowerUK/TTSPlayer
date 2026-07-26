import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../services/media_access/media_location_resolver.dart';
import '../archive/comic_archive_errors.dart';
import '../archive/comic_archive_opener.dart';
import '../spike/unrar_cli_resolver.dart';
import 'comic_reader_screen.dart';

/// Opens the comic reader for [item], or shows a controlled error snackbar.
///
/// Books and non-comics are ignored. CBR without tooling never enters a broken
/// reader route.
Future<void> openComicReaderScreen(
  BuildContext context, {
  required MediaItem item,
}) async {
  if (!item.isComic) return;
  if (!item.status.isPlayable) return;

  final resolver = context.read<MediaLocationResolver>();
  final opener = ComicArchiveOpener(
    mediaLocationResolver: resolver,
    cbrResolver: UnrarCliResolver(
      expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
    ),
  );

  try {
    // Probe open before pushing so missing CBR tooling fails at the entry.
    final source = opener.openItem(item);
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
