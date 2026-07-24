import '../../../models/media_kind.dart';

/// Optional filters applied on top of the text query.
class SearchFilters {
  /// Top-level library folder name, or null for all libraries.
  final String? libraryName;

  /// Lowercase extension without dot, or null for all types.
  final String? extension;

  /// Catalogue media kind filter (Book / Comic / …), or null for all kinds.
  final MediaKind? mediaKind;

  const SearchFilters({
    this.libraryName,
    this.extension,
    this.mediaKind,
  });

  const SearchFilters.empty()
      : libraryName = null,
        extension = null,
        mediaKind = null;

  SearchFilters copyWith({
    String? libraryName,
    String? extension,
    MediaKind? mediaKind,
    bool clearLibrary = false,
    bool clearExtension = false,
    bool clearMediaKind = false,
  }) {
    return SearchFilters(
      libraryName: clearLibrary ? null : (libraryName ?? this.libraryName),
      extension: clearExtension ? null : (extension ?? this.extension),
      mediaKind: clearMediaKind ? null : (mediaKind ?? this.mediaKind),
    );
  }

  bool get hasActiveFilters =>
      libraryName != null || extension != null || mediaKind != null;
}
