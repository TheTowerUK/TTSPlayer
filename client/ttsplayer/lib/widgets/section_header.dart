import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable uppercase section header used throughout the dashboard and screens.
///
/// Renders the [title] in [AppTypography.sectionLabel] (small-caps, tracked).
/// An optional [trailing] widget (e.g. a "View all" link) is right-aligned.
/// A subtle [AppColors.divider] line sits below the text row.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Optional widget placed at the trailing (right) end of the header row.
  final Widget? trailing;

  /// Outer padding — defaults to the dashboard horizontal margin with zero
  /// top padding so callers control vertical rhythm via [SizedBox] gaps.
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title.toUpperCase(), style: AppTypography.sectionLabel),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
