import '../../../models/media_item.dart';

/// Precomputed searchable fields for one catalogue item.
class SearchIndexEntry {
  final MediaItem item;
  final String libraryName;
  final String parentFolderName;
  final String fileName;
  final String searchBlob;

  /// Normalized eligible enriched-title values, excluding any value equal to
  /// the normalized catalogue title (M7.5.3). Empty for non-books and items
  /// with no eligible enrichment title.
  final List<String> enrichedTitlesNormalized;

  /// Normalized catalogue-or-eligible-enriched author and series values,
  /// merged for the combined author/series ranking tier (M7.5.3).
  final List<String> authorSeriesTermsNormalized;

  /// Normalized eligible publisher, subject, and publication-year values,
  /// merged for the combined ranking tier (M7.5.3).
  final List<String> publisherSubjectYearTermsNormalized;

  /// Canonically normalized eligible ISBN values (M7.5.3).
  final Set<String> normalizedIsbns;

  const SearchIndexEntry({
    required this.item,
    required this.libraryName,
    required this.parentFolderName,
    required this.fileName,
    required this.searchBlob,
    this.enrichedTitlesNormalized = const [],
    this.authorSeriesTermsNormalized = const [],
    this.publisherSubjectYearTermsNormalized = const [],
    this.normalizedIsbns = const {},
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
