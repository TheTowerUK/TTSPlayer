import 'package:flutter/material.dart';

import '../../../models/media_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/media_kind_presentation.dart';
import '../models/search_filters.dart';

class SearchFilterChips extends StatelessWidget {
  final List<String> libraryNames;
  final List<String> extensions;
  final SearchFilters filters;
  final int resultCount;
  final bool queryActive;
  final ValueChanged<SearchFilters> onFiltersChanged;

  /// Kind chips shown when the active catalogue includes these kinds.
  final List<MediaKind> availableMediaKinds;

  const SearchFilterChips({
    super.key,
    required this.libraryNames,
    required this.extensions,
    required this.filters,
    required this.resultCount,
    required this.queryActive,
    required this.onFiltersChanged,
    this.availableMediaKinds = const [],
  });

  static const _kindChipOrder = <MediaKind>[
    MediaKind.video,
    MediaKind.audio,
    MediaKind.image,
    MediaKind.book,
    MediaKind.comic,
  ];

  @override
  Widget build(BuildContext context) {
    final kindChips = _kindChipOrder
        .where(availableMediaKinds.contains)
        .toList(growable: false);

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
        if (kindChips.isNotEmpty || extensions.isNotEmpty) ...[
          Text(
            'TYPE',
            style: AppTypography.sectionLabel.copyWith(fontSize: AppTypography.size11),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final kind in kindChips)
                FilterChip(
                  key: ValueKey('search_kind_${kind.name}'),
                  avatar: Icon(MediaKindPresentation.icon(kind), size: 16),
                  label: Text(MediaKindPresentation.label(kind)),
                  selected: filters.mediaKind == kind,
                  onSelected: (selected) {
                    onFiltersChanged(
                      filters.copyWith(
                        mediaKind: selected ? kind : null,
                        clearMediaKind: !selected,
                      ),
                    );
                  },
                ),
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
