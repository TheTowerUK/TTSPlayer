import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../models/search_filters.dart';

class SearchFilterChips extends StatelessWidget {
  final List<String> libraryNames;
  final List<String> extensions;
  final SearchFilters filters;
  final int resultCount;
  final bool queryActive;
  final ValueChanged<SearchFilters> onFiltersChanged;

  const SearchFilterChips({
    super.key,
    required this.libraryNames,
    required this.extensions,
    required this.filters,
    required this.resultCount,
    required this.queryActive,
    required this.onFiltersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (queryActive)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '$resultCount result${resultCount == 1 ? '' : 's'}',
              style: AppTypography.cardSubtitle,
            ),
          ),
        if (libraryNames.isNotEmpty) ...[
          Text(
            'LIBRARY',
            style: AppTypography.sectionLabel.copyWith(fontSize: AppTypography.size11),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final name in libraryNames)
                FilterChip(
                  label: Text(name),
                  selected: filters.libraryName == name,
                  onSelected: (selected) {
                    onFiltersChanged(
                      filters.copyWith(
                        libraryName: selected ? name : null,
                        clearLibrary: !selected,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (extensions.isNotEmpty) ...[
          Text(
            'TYPE',
            style: AppTypography.sectionLabel.copyWith(fontSize: AppTypography.size11),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final ext in extensions)
                FilterChip(
                  label: Text(ext.toUpperCase()),
                  selected: filters.extension == ext,
                  onSelected: (selected) {
                    onFiltersChanged(
                      filters.copyWith(
                        extension: selected ? ext : null,
                        clearExtension: !selected,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
