import 'package:flutter/material.dart';

import '../library/library_browse_labels.dart';
import '../models/library_filter.dart';
import '../models/library_sort_mode.dart';
import '../theme/app_theme.dart';

/// Sort and filter controls for [FolderScreen] (ADR-008).
class FolderBrowseControls extends StatelessWidget {
  const FolderBrowseControls({
    super.key,
    required this.activeSortMode,
    required this.activeFilter,
    required this.persistedDefaultSort,
    required this.onSortModeChanged,
    required this.onFilterChanged,
    required this.onSetAsDefault,
  });

  final LibrarySortMode activeSortMode;
  final LibraryFilter activeFilter;
  final LibrarySortMode persistedDefaultSort;
  final ValueChanged<LibrarySortMode> onSortModeChanged;
  final ValueChanged<LibraryFilter> onFilterChanged;
  final VoidCallback onSetAsDefault;

  bool get _canSetAsDefault => activeSortMode != persistedDefaultSort;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SortControl(
                  activeSortMode: activeSortMode,
                  onSortModeChanged: onSortModeChanged,
                ),
                if (_canSetAsDefault) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    key: const Key('folder_set_default_sort'),
                    tooltip: 'Set as default sort',
                    icon: const Icon(Icons.bookmark_add_outlined, size: AppIcons.md),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    onPressed: onSetAsDefault,
                  ),
                ],
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.border,
                ),
                const SizedBox(width: AppSpacing.md),
                for (var i = 0; i < LibraryFilter.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  _FilterChip(
                    filter: LibraryFilter.values[i],
                    selected: activeFilter == LibraryFilter.values[i],
                    onSelected: () =>
                        onFilterChanged(LibraryFilter.values[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortControl extends StatelessWidget {
  const _SortControl({
    required this.activeSortMode,
    required this.onSortModeChanged,
  });

  final LibrarySortMode activeSortMode;
  final ValueChanged<LibrarySortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sort: ${activeSortMode.displayLabel}',
      child: PopupMenuButton<LibrarySortMode>(
        key: const Key('folder_sort_menu'),
        tooltip: 'Sort order',
        initialValue: activeSortMode,
        onSelected: onSortModeChanged,
        itemBuilder: (context) => [
          for (final mode in LibrarySortMode.values)
            CheckedPopupMenuItem<LibrarySortMode>(
              value: mode,
              checked: mode == activeSortMode,
              child: Text(
                mode.displayLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, size: AppIcons.md, color: AppColors.textHigh),
              const SizedBox(width: AppSpacing.xs),
              Text(
                activeSortMode.displayLabel,
                style: AppTypography.cardSubtitle.copyWith(
                  color: AppColors.textHigh,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: AppIcons.lg,
                color: AppColors.textMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onSelected,
  });

  final LibraryFilter filter;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: Key('folder_filter_${filter.storageKey}'),
      label: Text(
        filter.displayLabel,
        overflow: TextOverflow.ellipsis,
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected ? AppColors.textPrimary : AppColors.textHigh,
        fontSize: AppTypography.size12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      selectedColor: AppColors.card,
      backgroundColor: AppColors.chip,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
