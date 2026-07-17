import 'package:flutter/material.dart';

import '../../../services/diagnostics/diagnostic_section_status.dart';
import '../../../theme/app_theme.dart';
import '../diagnostics_formatters.dart';

/// Compact section-level status for diagnostics sections.
class DiagnosticsStatusBanner extends StatelessWidget {
  const DiagnosticsStatusBanner({
    super.key,
    required this.status,
  });

  final DiagnosticSectionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == DiagnosticSectionStatus.complete) {
      return const SizedBox.shrink();
    }

    final (icon, message, color) = switch (status) {
      DiagnosticSectionStatus.partial => (
          Icons.info_outline,
          'Some values in this section are unavailable.',
          AppColors.textMedium,
        ),
      DiagnosticSectionStatus.unavailable => (
          Icons.error_outline,
          'This section could not be read.',
          AppColors.warning,
        ),
      DiagnosticSectionStatus.complete => (
          Icons.check_circle_outline,
          '',
          AppColors.textMedium,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${DiagnosticsFormatters.sectionStatusLabel(status)} — $message',
              style: AppTypography.bodyMuted.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
