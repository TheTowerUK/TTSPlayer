import 'models/search_result.dart';

/// Presentation-only library bucket for search results (Phase 4.3).
class SearchResultGroup {
  const SearchResultGroup({
    required this.libraryName,
    required this.results,
  });

  final String libraryName;
  final List<SearchResult> results;
}

/// Groups score-ranked [results] by top-level library without re-sorting hits.
///
/// Group order follows first appearance in the incoming list (highest global
/// relevance first). Order within each group is unchanged.
List<SearchResultGroup> groupSearchResultsByLibrary(List<SearchResult> results) {
  if (results.isEmpty) return const [];

  final order = <String>[];
  final buckets = <String, List<SearchResult>>{};

  for (final result in results) {
    final library = result.libraryName.isEmpty ? 'Library' : result.libraryName;
    final bucket = buckets.putIfAbsent(library, () {
      order.add(library);
      return <SearchResult>[];
    });
    bucket.add(result);
  }

  return order
      .map(
        (name) => SearchResultGroup(
          libraryName: name,
          results: List<SearchResult>.unmodifiable(buckets[name]!),
        ),
      )
      .toList();
}
