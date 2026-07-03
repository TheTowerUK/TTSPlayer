import '../../../models/media_item.dart';

/// Precomputed searchable fields for one catalogue item.
class SearchIndexEntry {
  final MediaItem item;
  final String libraryName;
  final String parentFolderName;
  final String fileName;
  final String searchBlob;

  const SearchIndexEntry({
    required this.item,
    required this.libraryName,
    required this.parentFolderName,
    required this.fileName,
    required this.searchBlob,
  });

  String get parentFolderPath => parentFolderPathOf(item.filePath);

  /// Immediate parent directory path (normalized backslashes).
  static String parentFolderPathOf(String filePath) {
    final normalized = filePath.replaceAll('/', '\\');
    final i = normalized.lastIndexOf('\\');
    if (i <= 0) return normalized;
    return normalized.substring(0, i);
  }
}
