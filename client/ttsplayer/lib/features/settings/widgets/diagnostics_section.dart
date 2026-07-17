import 'package:flutter/material.dart';

import '../../../services/diagnostics/diagnostic_section_status.dart';
import '../../../theme/app_theme.dart';
import 'diagnostics_status_banner.dart';

/// Grouped diagnostics block with heading and optional status banner.
class DiagnosticsSection extends StatelessWidget {
  const DiagnosticsSection({
    super.key,
    required this.title,
    required this.status,
    required this.children,
    this.sectionKey,
  });

  final String title;
  final DiagnosticSectionStatus status;
  final List<Widget> children;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          DiagnosticsStatusBanner(status: status),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.base),
          ...children,
        ],
      ),
    );
  }
}
