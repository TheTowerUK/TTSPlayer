import 'package:flutter/material.dart';

import '../../../library/folder_display_context.dart';
import '../../../models/catalog.dart';
import '../../../theme/app_theme.dart';
import '../models/search_result.dart';
import '../search_presentation_metrics.dart';
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
    this.onPlayResult,
  });

  final Catalog catalog;
  final List<SearchResult> results;
  final void Function(SearchResult result) onOpenResult;
  final void Function(SearchResult result)? onBrowseFolder;
  final void Function(SearchResult result)? onPlayResult;

  @override
  Widget build(BuildContext context) {
    final groups = groupSearchResultsByLibrary(results);
    final showHeaders = groups.length > 1;
    SearchPresentationMetrics.recordFlatten();
    final rows = _flattenGroups(groups, showHeaders);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => rows[index].build(
        context,
        catalog: catalog,
        onOpenResult: onOpenResult,
        onBrowseFolder: onBrowseFolder,
        onPlayResult: onPlayResult,
      ),
    );
  }

  List<_SearchListRow> _flattenGroups(
    List<SearchResultGroup> groups,
    bool showHeaders,
  ) {
    final rows = <_SearchListRow>[];
    for (final group in groups) {
      if (showHeaders) {
        rows.add(_SearchListHeader(group.libraryName));
      }
      for (final result in group.results) {
        rows.add(_SearchListResult(result));
      }
    }
    return rows;
  }
}

sealed class _SearchListRow {
  const _SearchListRow();

  Widget build(
    BuildContext context, {
    required Catalog catalog,
    required void Function(SearchResult result) onOpenResult,
    required void Function(SearchResult result)? onBrowseFolder,
    void Function(SearchResult result)? onPlayResult,
  });
}

final class _SearchListHeader extends _SearchListRow {
  const _SearchListHeader(this.libraryName);

  final String libraryName;

  @override
  Widget build(
    BuildContext context, {
    required Catalog catalog,
    required void Function(SearchResult result) onOpenResult,
    required void Function(SearchResult result)? onBrowseFolder,
    void Function(SearchResult result)? onPlayResult,
  }) {
    return Semantics(
      header: true,
      label: 'Library: $libraryName',
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          libraryName.toUpperCase(),
          style: AppTypography.sectionLabel,
        ),
      ),
    );
  }
}

final class _SearchListResult extends _SearchListRow {
  const _SearchListResult(this.result);

  final SearchResult result;

  @override
  Widget build(
    BuildContext context, {
    required Catalog catalog,
    required void Function(SearchResult result) onOpenResult,
    required void Function(SearchResult result)? onBrowseFolder,
    void Function(SearchResult result)? onPlayResult,
  }) {
    final contextLabel = catalogueFolderContext(catalog, result.item.id);
    final canBrowse = onBrowseFolder != null && _canBrowseFolder(catalog, result);

    return SearchResultRow(
      result: result,
      displayContext: contextLabel,
      onOpen: () => onOpenResult(result),
      onBrowseFolder: canBrowse ? () => onBrowseFolder!(result) : null,
      onPlay: _playCallback(onPlayResult),
    );
  }

  VoidCallback? _playCallback(void Function(SearchResult result)? onPlayResult) {
    if (onPlayResult == null) return null;
    final item = result.item;
    if (!item.isAudio || !item.status.isPlayable) return null;
    return () => onPlayResult(result);
  }

  bool _canBrowseFolder(Catalog catalog, SearchResult result) {
    if (catalog.parentFolderOfItemId(result.item.id) != null) return true;
    if (result.parentFolderPath.isEmpty) return false;
    return catalog.findFolderByPath(result.parentFolderPath) != null;
  }
}
