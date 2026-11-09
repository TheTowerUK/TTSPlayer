import '../models/media_folder.dart';
import '../models/media_item.dart';
import 'media_item_navigation.dart';

/// Returns the single playable book/comic in [folder] when a FolderScreen
/// shortcut is eligible; otherwise null.
///
/// Eligibility is catalogue-only: no subfolders, exactly one direct item, and
/// that item's primary activation is the reader.
MediaItem? singlePlayableReaderItem(MediaFolder folder) {
  if (folder.subfolders.isNotEmpty) return null;
  if (folder.items.length != 1) return null;
  final item = folder.items.single;
  if (mediaItemActivationFor(item) != MediaItemActivation.reader) {
    return null;
  }
  return item;
}
