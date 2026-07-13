import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-area empty state widget with an icon, title, and optional subtitle.
///
/// Centres content vertically and horizontally.  Used when a folder, library,
/// or section has no items to display.
///
/// Examples:
/// ```dart
/// EmptyState(
///   icon: Icons.folder_open_outlined,
///   title: 'This folder is empty.',
/// )
/// EmptyState(
///   icon: Icons.history_outlined,
///   title: 'No scan history yet.',
///   subtitle: 'Run a full scan to see results here.',
/// )
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIcons.hero, color: AppColors.textLow),
            const SizedBox(height: AppSpacing.base),
            Text(
              title,
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                key: actionKey,
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
