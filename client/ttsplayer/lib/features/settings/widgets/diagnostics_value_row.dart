import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Label/value row for diagnostics sections.
class DiagnosticsValueRow extends StatelessWidget {
  const DiagnosticsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: AppTypography.bodyMuted,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              key: valueKey,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
