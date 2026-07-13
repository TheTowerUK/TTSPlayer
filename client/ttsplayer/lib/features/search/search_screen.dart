import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../navigation/folder_navigation.dart';
import '../../models/catalog.dart';
import '../../screens/item_detail_screen.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_card.dart';
import '../../widgets/tts_app_bar.dart';
import 'models/search_filters.dart';
import 'models/search_result.dart';
import 'search_service.dart';
import 'widgets/search_empty_state.dart';
import 'widgets/search_filter_chips.dart';
import 'widgets/search_results_list.dart';

class SearchScreen extends StatefulWidget {
  final bool autofocus;

  const SearchScreen({super.key, this.autofocus = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchService = SearchService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  SearchFilters _filters = const SearchFilters.empty();
  List<SearchResult> _results = const [];
  List<String> _recentQueries = [];
  Timer? _debounce;

  static const _debounceDuration = Duration(milliseconds: 150);
  static const _maxRecentQueries = 5;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _runSearch);
    setState(() {});
  }

  void _runSearch() {
    final catalog = context.read<CatalogService>().catalog;
    if (catalog == null) return;

    _searchService.buildIndex(catalog);
    final query = _controller.text;
    final results = _searchService.search(query, _filters);

    if (query.trim().length >= 2 && results.isNotEmpty) {
      _rememberQuery(query.trim());
    }

    if (!mounted) return;
    setState(() => _results = results);
  }

  void _clearQuery() {
    _controller.clear();
    _runSearch();
    _focusNode.requestFocus();
  }

  void _clearFilters() {
    setState(() => _filters = const SearchFilters.empty());
    _runSearch();
  }

  void _rememberQuery(String query) {
    _recentQueries.removeWhere((q) => q.toLowerCase() == query.toLowerCase());
    _recentQueries.insert(0, query);
    if (_recentQueries.length > _maxRecentQueries) {
      _recentQueries = _recentQueries.sublist(0, _maxRecentQueries);
    }
  }

  void _applyRecentQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _runSearch();
  }

  void _openResult(SearchResult result) {
    final catalog = context.read<CatalogService>().catalog;
    if (catalog == null) return;

    final item = catalog.findItemById(result.item.id);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is no longer in the catalogue.'),
          duration: Duration(seconds: 3),
        ),
      );
      _runSearch();
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ItemDetailScreen(item: item),
      ),
    );
  }

  void _browseFolder(SearchResult result) {
    final catalog = context.read<CatalogService>().catalog;
    if (catalog == null) return;

    final folder = catalog.parentFolderOfItemId(result.item.id) ??
        (result.parentFolderPath.isNotEmpty
            ? catalog.findFolderByPath(result.parentFolderPath)
            : null);

    if (folder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Folder is no longer available in the catalogue.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    openFolderScreen(context, folder);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _ClearSearchIntent(),
      },
      child: Actions(
        actions: {
          _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
            onInvoke: (_) {
              if (_controller.text.isNotEmpty) {
                _clearQuery();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: false,
          child: Scaffold(
            appBar: const TtsAppBar(title: 'Search'),
            body: Consumer<CatalogService>(
              builder: (context, catalogService, _) {
                if (catalogService.isLoading && catalogService.catalog == null) {
                  return const LoadingCard(message: 'Loading catalogue…');
                }

                final catalog = catalogService.catalog;
                if (catalog == null) {
                  return SearchEmptyState(
                    kind: SearchEmptyKind.catalogueUnavailable,
                    onRetry: () async {
                      await catalogService.rescan();
                      if (mounted) _runSearch();
                    },
                  );
                }

                _searchService.buildIndex(catalog);

                if (_searchService.indexedItemCount == 0) {
                  return const SearchEmptyState(
                    kind: SearchEmptyKind.catalogueEmpty,
                  );
                }

                final query = _controller.text.trim();
                final queryActive = query.isNotEmpty;
                final filtersActive = _filters.hasActiveFilters;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.base,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Semantics(
                        label: 'Search media',
                        child: TextField(
                          key: const Key('search_query_field'),
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: widget.autofocus,
                          decoration: InputDecoration(
                            hintText: 'Search media…',
                            prefixIcon: const Icon(Icons.search_outlined),
                            suffixIcon: queryActive
                                ? IconButton(
                                    key: const Key('search_clear_button'),
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearQuery,
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.card,
                            border: const OutlineInputBorder(
                              borderRadius: AppRadius.cardRadius,
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: AppRadius.cardRadius,
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: AppRadius.cardRadius,
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _runSearch(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: SearchFilterChips(
                        libraryNames: _searchService.libraryNames,
                        extensions: _searchService.extensions,
                        filters: _filters,
                        resultCount: _results.length,
                        queryActive: queryActive,
                        onFiltersChanged: (filters) {
                          setState(() => _filters = filters);
                          _runSearch();
                        },
                      ),
                    ),
                    if (!queryActive && _recentQueries.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Text(
                          'RECENT',
                          style: AppTypography.sectionLabel.copyWith(
                            fontSize: AppTypography.size11,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final term in _recentQueries)
                              ActionChip(
                                label: Text(term),
                                onPressed: () => _applyRecentQuery(term),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: _buildResults(
                        catalog: catalog,
                        queryActive: queryActive,
                        filtersActive: filtersActive,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults({
    required Catalog catalog,
    required bool queryActive,
    required bool filtersActive,
  }) {
    if (!queryActive) {
      return const SearchEmptyState(kind: SearchEmptyKind.beforeTyping);
    }

    if (_results.isEmpty) {
      return SearchEmptyState(
        kind: SearchEmptyKind.noResults,
        onClearQuery: _clearQuery,
        onClearFilters: filtersActive ? _clearFilters : null,
      );
    }

    return SearchResultsList(
      catalog: catalog,
      results: _results,
      onOpenResult: _openResult,
      onBrowseFolder: _browseFolder,
    );
  }
}
