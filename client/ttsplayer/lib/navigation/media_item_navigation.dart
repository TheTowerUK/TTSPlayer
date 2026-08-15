import 'dart:async';

import 'package:flutter/material.dart';

import '../features/books/models/book_format.dart';
import '../features/comics/archive/comic_archive_opener.dart';
import '../features/music/music_navigation.dart';
import '../features/reading/reading_navigation.dart';
import '../models/media_item.dart';
import '../screens/item_detail_screen.dart';
import '../screens/player_screen.dart';

enum MediaItemActivation {
  videoPlayer,
  audioPlayer,
  reader,
  details,
}

/// Central policy for primary activation of a single catalogue item (M7.6.4).
MediaItemActivation mediaItemActivationFor(MediaItem item) {
  if (!item.status.isPlayable) return MediaItemActivation.details;
  if (item.isVideo) return MediaItemActivation.videoPlayer;
  if (item.isAudio) return MediaItemActivation.audioPlayer;
  if (item.isBook && bookFormatFromExtension(item.extension) != null) {
    return MediaItemActivation.reader;
  }
  if (item.isComic && isSupportedComicArchiveExtension(item.extension)) {
    return MediaItemActivation.reader;
  }
  return MediaItemActivation.details;
}

void openMediaItemDetails(BuildContext context, MediaItem item) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'media:details:${item.id}'),
      builder: (_) => ItemDetailScreen(item: item),
    ),
  );
}

/// Performs the natural primary action, falling back to details when the item
/// is unavailable, unsupported, or has no single direct action.
void activateMediaItem(BuildContext context, MediaItem item) {
  switch (mediaItemActivationFor(item)) {
    case MediaItemActivation.videoPlayer:
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          settings: RouteSettings(name: 'media:player:${item.id}'),
          builder: (_) => PlayerScreen(item: item),
        ),
      );
    case MediaItemActivation.audioPlayer:
      openMusicPlayerScreen(context, track: item);
    case MediaItemActivation.reader:
      unawaited(openReadingItem(context, item: item));
    case MediaItemActivation.details:
      openMediaItemDetails(context, item);
  }
}
