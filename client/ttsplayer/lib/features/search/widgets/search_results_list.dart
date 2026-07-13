import 'package:flutter/material.dart';

import '../../../library/folder_display_context.dart';
import '../../../models/catalog.dart';
import '../../../theme/app_theme.dart';
import '../models/search_result.dart';
import '../search_result_grouper.dart';
import 'search_result_row.dart';

/// Score-ranked search results with lightweight library grouping (Phase 4.3).
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.catalog,
    required this.results,
    required this.onOpenResult,
    required this.onBrowseFolder,
  });

  final Catalog catalog;
  final List<SearchResult> results;
  final void Function(SearchResult result) onOpenResult;
  final void Function(SearchResult result)? onBrowseFolder;

  @override
  Widget build(BuildContext context) {
    final groups = groupSearchResultsByLibrary(results);
    final showHeaders = groups.length > 1;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _itemCount(groups, showHeaders),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _buildItem(
        context,
        groups,
        index,
        showHeaders,
      ),
    );
  }

  int _itemCount(List<SearchResultGroup> groups, bool showHeaders) {
    var count = 0;
    for (final group in groups) {
      if (showHeaders) count += 1;
      count += group.results.length;
    }
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    List<SearchResultGroup> groups,
    int index,
    bool showHeaders,
  ) {
    var cursor = 0;
    for (final group in groups) {
      if (showHeaders) {
        if (index == cursor) {
          return Semantics(
            header: true,
            label: 'Library: ${group.libraryName}',
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                group.libraryName.toUpperCase(),
                style: AppTypography.sectionLabel,
              ),
            ),
          );
        }
        cursor++;
      }

      for (final result in group.results) {
        if (index == cursor) {
          final contextLabel = catalogueFolderContext(catalog, result.item.id);
          return SearchResultRow(
            result: result,
            displayContext: contextLabel,
            onOpen: () => onOpenResult(result),
            onBrowseFolder: onBrowseFolder != null &&
                    _canBrowseFolder(catalog, result)
                ? () => onBrowseFolder!(result)
                : null,
          );
        }
        cursor++;
      }
    }

    return const SizedBox.shrink();
  }

  bool _canBrowseFolder(Catalog catalog, SearchResult result) {
    if (catalog.parentFolderOfItemId(result.item.id) != null) return true;
    if (result.parentFolderPath.isEmpty) return false;
    return catalog.findFolderByPath(result.parentFolderPath) != null;
  }
}
