import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Grouped block within [SettingsScreen]: heading, optional description, body.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(description!, style: AppTypography.bodyMuted),
        ],
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.base),
        child,
      ],
    );
  }
}
