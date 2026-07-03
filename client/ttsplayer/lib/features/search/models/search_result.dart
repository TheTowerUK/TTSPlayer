import '../../../models/media_item.dart';
import 'search_index_entry.dart';

/// A ranked search hit with display context.
class SearchResult {
  final MediaItem item;
  final String libraryName;
  final String parentFolderName;
  final String parentFolderPath;
  final int score;

  const SearchResult({
    required this.item,
    required this.libraryName,
    required this.parentFolderName,
    required this.parentFolderPath,
    required this.score,
  });

  factory SearchResult.fromEntry(SearchIndexEntry entry, {required int score}) {
    return SearchResult(
      item: entry.item,
      libraryName: entry.libraryName,
      parentFolderName: entry.parentFolderName,
      parentFolderPath: entry.parentFolderPath,
      score: score,
    );
  }

  /// Folder context for list subtitle, e.g. "Videos · Action".
  String get folderContext {
    if (libraryName.isEmpty && parentFolderName.isEmpty) return '';
    if (libraryName.isEmpty) return parentFolderName;
    if (parentFolderName.isEmpty || parentFolderName == libraryName) {
      return libraryName;
    }
    return '$libraryName · $parentFolderName';
  }
}
