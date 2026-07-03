import 'package:flutter/material.dart';

import '../../../models/scan_history.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Collapsible scan history panel — collapsed by default on dashboard load.
class RecentActivitySection extends StatefulWidget {
  final List<ScanHistoryEntry> entries;

  const RecentActivitySection({super.key, required this.entries});

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  bool _expanded = false;

  String get _summaryText {
    final count = widget.entries.length;
    if (count == 0) return 'No recent entries';
    return '$count recent ${count == 1 ? 'entry' : 'entries'}';
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: AppRadius.cardRadius,
                child: Padding(
                  padding: AppSpacing.cardPremium,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_outlined,
                        color: AppColors.textLow,
                        size: AppIcons.lg,
                      ),
                      const SizedBox(width: AppSpacing.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Activity',
                              style: AppTypography.cardTitle,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _summaryText,
                              style: AppTypography.cardSubtitle,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.textMedium,
                        size: AppIcons.lg,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: AppColors.divider),
              if (widget.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: EmptyState(
                    icon: Icons.history_outlined,
                    title: 'No scan history yet.',
                    subtitle: 'Completed scans will appear here.',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      for (final entry in widget.entries) ...[
                        _ActivityRow(entry: entry),
                        if (entry != widget.entries.last)
                          const Divider(height: 1, color: AppColors.divider),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ScanHistoryEntry entry;

  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final icon = entry.success
        ? Icons.check_circle_outline
        : Icons.error_outline;
    final iconColor =
        entry.success ? AppColors.success : AppColors.caution;

    return Padding(
      padding: AppSpacing.tileRow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: AppIcons.lg),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.success ? 'Scan completed' : 'Scan failed',
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${entry.formattedItems} items'
                  '  ·  ${entry.folders} folders'
                  '  ·  ${entry.warnings} warnings',
                  style: AppTypography.cardSubtitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.formattedDate,
                  style: AppTypography.bodyMuted.copyWith(
                    fontSize: AppTypography.size11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
