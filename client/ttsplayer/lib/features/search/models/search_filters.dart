/// Optional filters applied on top of the text query.
class SearchFilters {
  /// Top-level library folder name, or null for all libraries.
  final String? libraryName;

  /// Lowercase extension without dot, or null for all types.
  final String? extension;

  const SearchFilters({this.libraryName, this.extension});

  const SearchFilters.empty() : libraryName = null, extension = null;

  SearchFilters copyWith({
    String? libraryName,
    String? extension,
    bool clearLibrary = false,
    bool clearExtension = false,
  }) {
    return SearchFilters(
      libraryName: clearLibrary ? null : (libraryName ?? this.libraryName),
      extension: clearExtension ? null : (extension ?? this.extension),
    );
  }

  bool get hasActiveFilters => libraryName != null || extension != null;
}
