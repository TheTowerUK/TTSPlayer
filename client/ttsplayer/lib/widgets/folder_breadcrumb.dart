import 'package:flutter/material.dart';

import '../models/media_folder.dart';
import '../navigation/folder_navigation.dart';
import '../theme/app_theme.dart';

/// Catalogue-driven breadcrumb trail for [FolderScreen] (ADR-009).
///
/// [ancestors] is root-to-current inclusive from [Catalog.ancestorChainForFolder].
/// Dashboard/Home is outside this widget — use [TtsAppBar] Home button.
class FolderBreadcrumb extends StatelessWidget {
  const FolderBreadcrumb({
    super.key,
    required this.ancestors,
    required this.currentFolderId,
    required this.onAncestorSelected,
  });

  final List<MediaFolder> ancestors;
  final String currentFolderId;
  final void Function(MediaFolder folder) onAncestorSelected;

  @override
  Widget build(BuildContext context) {
    if (ancestors.isEmpty) return const SizedBox.shrink();

    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < ancestors.length; i++) ...[
                  if (i > 0) const _BreadcrumbSeparator(),
                  _BreadcrumbSegment(
                    folder: ancestors[i],
                    isCurrent: ancestors[i].id == currentFolderId,
                    onTap: ancestors[i].id == currentFolderId
                        ? null
                        : () => onAncestorSelected(ancestors[i]),
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

class _BreadcrumbSeparator extends StatelessWidget {
  const _BreadcrumbSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Icon(
        Icons.chevron_right,
        size: AppIcons.sm,
        color: AppColors.textLow,
      ),
    );
  }
}

class _BreadcrumbSegment extends StatelessWidget {
  const _BreadcrumbSegment({
    required this.folder,
    required this.isCurrent,
    required this.onTap,
  });

  final MediaFolder folder;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = folder.name;
    final textStyle = isCurrent
        ? AppTypography.cardTitle.copyWith(
            fontSize: AppTypography.size13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          )
        : AppTypography.cardSubtitle.copyWith(
            fontSize: AppTypography.size13,
            color: AppColors.textHigh,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textLow,
          );

    final child = Text(
      label,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (isCurrent || onTap == null) {
      return Semantics(
        header: true,
        label: 'Current folder: $label',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Tooltip(message: label, child: child),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Open folder: $label',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Tooltip(
          message: label,
          child: TextButton(
            key: Key('breadcrumb_segment_${folder.id}'),
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textHigh,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper used by [FolderScreen] for ancestor navigation.
Future<void> navigateBreadcrumbSelection(
  BuildContext context, {
  required MediaFolder target,
  required String currentFolderId,
}) {
  return navigateToBreadcrumbFolder(
    context,
    target: target,
    currentFolderId: currentFolderId,
  );
}
