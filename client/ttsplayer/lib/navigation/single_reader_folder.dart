import '../models/media_folder.dart';
import '../models/media_item.dart';
import 'media_item_navigation.dart';

/// Returns the single playable item in [folder] when a FolderScreen card
/// shortcut is eligible; otherwise null.
///
/// Eligibility is catalogue-only: no subfolders, exactly one direct item, and
/// that item's primary activation is the video player or the reader.
MediaItem? singlePlayableShortcutItem(MediaFolder folder) {
  if (folder.subfolders.isNotEmpty) return null;
  if (folder.items.length != 1) return null;
  final item = folder.items.single;
  switch (mediaItemActivationFor(item)) {
    case MediaItemActivation.videoPlayer:
    case MediaItemActivation.reader:
      return item;
    case MediaItemActivation.audioPlayer:
    case MediaItemActivation.details:
      return null;
  }
}

/// Returns the single playable book/comic in [folder] when a FolderScreen
/// shortcut is eligible; otherwise null.
MediaItem? singlePlayableReaderItem(MediaFolder folder) {
  final item = singlePlayableShortcutItem(folder);
  if (item == null) return null;
  if (mediaItemActivationFor(item) != MediaItemActivation.reader) {
    return null;
  }
  return item;
}

/// True when every [subfolders] entry is a single-book/comic leaf.
///
/// Used by FolderScreen to switch the shared subfolder grid to a 2:3 cover
/// layout. Mixed collections keep the landscape folder grid.
bool folderGridUsesReaderCovers(Iterable<MediaFolder> subfolders) {
  if (subfolders.isEmpty) return false;
  for (final folder in subfolders) {
    if (singlePlayableReaderItem(folder) == null) return false;
  }
  return true;
}
