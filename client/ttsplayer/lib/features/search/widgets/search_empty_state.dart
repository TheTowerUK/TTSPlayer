import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

enum SearchEmptyKind {
  beforeTyping,
  noResults,
  catalogueUnavailable,
  catalogueEmpty,
}

class SearchEmptyState extends StatelessWidget {
  final SearchEmptyKind kind;
  final VoidCallback? onRetry;
  final VoidCallback? onClearQuery;
  final VoidCallback? onClearFilters;

  const SearchEmptyState({
    super.key,
    required this.kind,
    this.onRetry,
    this.onClearQuery,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case SearchEmptyKind.beforeTyping:
        return const EmptyState(
          icon: Icons.search_outlined,
          title: 'Search your library',
          subtitle: 'Enter a search term to find media by title, filename, or folder.',
        );
      case SearchEmptyKind.noResults:
        return Center(
          child: SingleChildScrollView(
            padding: AppSpacing.errorView,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_outlined,
                  size: AppIcons.hero,
                  color: AppColors.textLow,
                ),
                const SizedBox(height: AppSpacing.base),
                const Text(
                  'No results found',
                  style: AppTypography.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Try a different search term or adjust the filters.',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
                if (onClearQuery != null || onClearFilters != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (onClearFilters != null)
                        OutlinedButton(
                          key: const Key('search_clear_filters'),
                          onPressed: onClearFilters,
                          child: const Text('Clear filters'),
                        ),
                      if (onClearQuery != null)
                        FilledButton(
                          key: const Key('search_clear_query'),
                          onPressed: onClearQuery,
                          child: const Text('Clear search'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      case SearchEmptyKind.catalogueUnavailable:
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Catalogue unavailable',
          subtitle:
              'Check Provider Status on the dashboard or refresh your catalogue in Settings before searching.',
          actionLabel: onRetry != null ? 'Refresh catalogue' : null,
          onAction: onRetry,
        );
      case SearchEmptyKind.catalogueEmpty:
        return const EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No media indexed',
          subtitle: 'Run a scan to populate your catalogue.',
        );
    }
  }
}
