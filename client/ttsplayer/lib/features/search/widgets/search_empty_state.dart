import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

enum SearchEmptyKind {
  beforeTyping,
  noResults,
  catalogueUnavailable,
  catalogueEmpty,
}

class SearchEmptyState extends StatelessWidget {
  final SearchEmptyKind kind;
  final VoidCallback? onRetry;

  const SearchEmptyState({
    super.key,
    required this.kind,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (kind) {
      SearchEmptyKind.beforeTyping => (
          Icons.search_outlined,
          'Search your library',
          'Find media by title, filename, folder, or file type.',
        ),
      SearchEmptyKind.noResults => (
          Icons.search_off_outlined,
          'No results found',
          'Try different words, clear filters, or check spelling.',
        ),
      SearchEmptyKind.catalogueUnavailable => (
          Icons.cloud_off_outlined,
          'Catalogue unavailable',
          'Load or refresh your catalogue before searching.',
        ),
      SearchEmptyKind.catalogueEmpty => (
          Icons.folder_open_outlined,
          'No media indexed',
          'Run a scan to populate your catalogue.',
        ),
    };

    return Center(
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIcons.hero, color: AppColors.textLow),
            const SizedBox(height: AppSpacing.base),
            Text(title, style: AppTypography.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle, style: AppTypography.caption, textAlign: TextAlign.center),
            if (kind == SearchEmptyKind.catalogueUnavailable &&
                onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh catalogue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
