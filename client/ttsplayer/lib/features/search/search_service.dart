import 'package:flutter/foundation.dart';

import '../../models/catalog.dart';
import '../../models/media_folder.dart';
import '../../models/media_item.dart';
import 'models/search_filters.dart';
import 'models/search_index_entry.dart';
import 'models/search_result.dart';

/// Thrown when the search index cannot be built; callers may retry.
class SearchIndexBuildException implements Exception {
  SearchIndexBuildException([this.message = 'Search index build failed']);

  final String message;

  @override
  String toString() => message;
}

/// In-memory catalogue search — index built lazily per catalogue revision (ADR-016).
class SearchService {
  static const maxResults = 100;

  List<SearchIndexEntry> _index = const [];
  String? _catalogueIdentity;
  List<String> _libraryNames = const [];
  List<String> _extensions = const [];

  int _invalidationGeneration = 0;
  Future<void>? _buildFuture;
  String? _buildInFlightIdentity;
  int _indexBuildCount = 0;

  /// When true, the next index build throws [SearchIndexBuildException] (tests only).
  @visibleForTesting
  bool simulateBuildFailure = false;

  /// Lifetime count of completed index builds for this service instance.
  int get indexBuildCount => _indexBuildCount;

  /// Whether a search index is currently held for a catalogue identity.
  bool get hasIndex => _catalogueIdentity != null;

  /// Whether an index build [Future] is in flight.
  bool get isBuildInFlight => _buildFuture != null;

  List<String> get libraryNames => _libraryNames;
  List<String> get extensions => _extensions;
  int get indexedItemCount => _index.length;
  String? get catalogueIdentity => _catalogueIdentity;

  /// Library names for filter chips — from the built index when current, else [Catalog].
  List<String> libraryNamesFor(Catalog catalog) {
    if (_catalogueIdentity == catalog.catalogueIdentity && _libraryNames.isNotEmpty) {
      return _libraryNames;
    }
    return catalog.libraryFolders.map((f) => f.name).toList();
  }

  /// Extensions for filter chips — from the built index when current, else [Catalog].
  List<String> extensionsFor(Catalog catalog) {
    if (_catalogueIdentity == catalog.catalogueIdentity && _extensions.isNotEmpty) {
      return _extensions;
    }
    return _collectExtensions(catalog);
  }

  /// Synchronously populates the index (tests and direct ranking assertions).
  @visibleForTesting
  void buildIndex(Catalog catalog) {
    _indexBuildCount++;
    _populateIndex(catalog);
  }

  /// Clears the in-memory search index without rebuilding (ADR-014).
  @visibleForTesting
  void invalidateIndex() {
    _invalidationGeneration++;
    _index = const [];
    _catalogueIdentity = null;
    _libraryNames = const [];
    _extensions = const [];
  }

  /// Called from [CatalogCacheCoordinator] on successful catalogue replacement.
  /// Invalidates stale index state; rebuild is deferred until the next search.
  void onCatalogReplaced(Catalog catalog) {
    invalidateIndex();
  }

  /// Ensures an index exists for [catalog]'s [Catalog.catalogueIdentity].
  Future<void> ensureIndex(Catalog catalog) async {
    final identity = catalog.catalogueIdentity;
    if (_hasIndexFor(identity)) return;

    while (true) {
      if (_buildFuture != null) {
        await _buildFuture;
        if (_hasIndexFor(identity)) return;
      }

      if (_hasIndexFor(identity)) return;

      final gen = _invalidationGeneration;
      final future = _buildIndexAsync(catalog, identity, gen);
      _buildFuture = future;
      _buildInFlightIdentity = identity;

      try {
        await future;
      } finally {
        if (identical(_buildFuture, future)) {
          _buildFuture = null;
          _buildInFlightIdentity = null;
        }
      }

      if (_hasIndexFor(identity)) return;
      if (gen != _invalidationGeneration) return;
      return;
    }
  }

  /// Runs [query] against [catalog], building the index first when required.
  Future<List<SearchResult>> searchCatalog(
    Catalog catalog,
    String query,
    SearchFilters filters,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final tokens = _tokenize(trimmed);
    if (tokens.isEmpty) return const [];

    await ensureIndex(catalog);
    if (_catalogueIdentity != catalog.catalogueIdentity) {
      return const [];
    }

    return search(query, filters);
  }

  /// Returns ranked results for [query] with optional [filters] against the current index.
  List<SearchResult> search(String query, SearchFilters filters) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final tokens = _tokenize(trimmed);
    if (tokens.isEmpty) return const [];

    final hits = <SearchResult>[];

    for (final entry in _index) {
      if (!_passesFilters(entry, filters)) continue;
      if (!_matchesTokens(entry, tokens)) continue;

      final score = _score(entry, trimmed, tokens);
      hits.add(SearchResult.fromEntry(entry, score: score));
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase());
    });

    if (hits.length <= maxResults) return hits;
    return hits.sublist(0, maxResults);
  }

  bool _hasIndexFor(String identity) => _catalogueIdentity == identity;

  Future<void> _buildIndexAsync(
    Catalog catalog,
    String identity,
    int genAtStart,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (genAtStart != _invalidationGeneration) return;
    if (_hasIndexFor(identity)) return;

    if (simulateBuildFailure) {
      throw SearchIndexBuildException();
    }

    final libraries = catalog.libraryFolders;
    final entries = catalog.allItems
        .map((item) => _entryForItem(item, libraries))
        .toList(growable: false);
    final libraryNames = libraries.map((f) => f.name).toList();
    final extensions = _collectExtensions(catalog);

    if (genAtStart != _invalidationGeneration) return;
    if (_buildInFlightIdentity != identity) return;

    _indexBuildCount++;
    _catalogueIdentity = identity;
    _libraryNames = libraryNames;
    _extensions = extensions;
    _index = entries;
  }

  void _populateIndex(Catalog catalog) {
    final identity = catalog.catalogueIdentity;
    _catalogueIdentity = identity;
    _libraryNames = catalog.libraryFolders.map((f) => f.name).toList();
    _extensions = _collectExtensions(catalog);

    final libraries = catalog.libraryFolders;
    _index = catalog.allItems
        .map((item) => _entryForItem(item, libraries))
        .toList(growable: false);
  }

  SearchIndexEntry _entryForItem(MediaItem item, List<MediaFolder> libraries) {
    final normalizedPath = _normalize(item.filePath);
    final fileName = _fileName(item.filePath);
    final parentFolderName = _parentName(item.filePath);
    final libraryName = _resolveLibraryName(normalizedPath, libraries);

    final musicFields = item.isAudio
        ? [
            item.artist,
            item.album,
            item.albumArtist,
            item.genre,
          ].whereType<String>().join(' ')
        : '';

    final blob = _normalize(
      '${item.title} $fileName ${item.filePath} $libraryName '
      '$parentFolderName ${item.extension} $musicFields',
    );

    return SearchIndexEntry(
      item: item,
      libraryName: libraryName,
      parentFolderName: parentFolderName,
      fileName: fileName,
      searchBlob: blob,
    );
  }

  bool _passesFilters(SearchIndexEntry entry, SearchFilters filters) {
    if (filters.libraryName != null &&
        entry.libraryName != filters.libraryName) {
      return false;
    }
    if (filters.extension != null &&
        entry.item.extension != filters.extension) {
      return false;
    }
    return true;
  }

  bool _matchesTokens(SearchIndexEntry entry, List<String> tokens) {
    for (final token in tokens) {
      if (!entry.searchBlob.contains(token)) return false;
    }
    return true;
  }

  int _score(SearchIndexEntry entry, String query, List<String> tokens) {
    final q = _normalize(query);
    final title = _normalize(entry.item.title);
    final fileName = _normalize(entry.fileName);
    final path = _normalize(entry.item.filePath);
    final library = _normalize(entry.libraryName);
    final parent = _normalize(entry.parentFolderName);
    final ext = entry.item.extension;

    var score = 0;

    if (title == q) {
      score += 100;
    } else if (title.startsWith(q)) {
      score += 80;
    } else if (title.contains(q)) {
      score += 60;
    }

    if (fileName.contains(q)) score += 40;
    if (path.contains(q)) score += 30;
    if (library.contains(q) || parent.contains(q)) score += 20;

    for (final token in tokens) {
      if (token == ext) score += 10;
    }

    return score;
  }

  static List<String> _tokenize(String query) {
    return _normalize(query)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll('/', '\\');

  static String _fileName(String path) {
    final normalized = path.replaceAll('/', '\\');
    final i = normalized.lastIndexOf('\\');
    if (i < 0) return normalized;
    return normalized.substring(i + 1);
  }

  static String _parentName(String path) {
    final parent = SearchIndexEntry.parentFolderPathOf(path);
    return _fileName(parent);
  }

  static String _resolveLibraryName(
    String normalizedFilePath,
    List<MediaFolder> libraries,
  ) {
    MediaFolder? best;
    var bestLen = -1;

    for (final library in libraries) {
      final libPath = _normalize(library.path);
      final prefix = libPath.endsWith('\\') ? libPath : '$libPath\\';
      if (normalizedFilePath == libPath ||
          normalizedFilePath.startsWith(prefix)) {
        if (libPath.length > bestLen) {
          best = library;
          bestLen = libPath.length;
        }
      }
    }

    return best?.name ?? '';
  }

  static List<String> _collectExtensions(Catalog catalog) {
    final fromCatalogue = catalog.supportedExtensions;
    final fromItems = catalog.allItems.map((i) => i.extension);
    final set = {...fromCatalogue, ...fromItems}..removeWhere((e) => e.isEmpty);
    final list = set.toList()..sort();
    return list;
  }
}
