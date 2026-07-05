import 'package:flutter/material.dart';

import '../../../models/catalog.dart';
import '../../../theme/app_theme.dart';

/// Compact at-a-glance scan and library summary for the dashboard.
class DashboardOverviewPanel extends StatelessWidget {
  final Catalog catalog;

  const DashboardOverviewPanel({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final scan = catalog.scan;
    final libraryCount = catalog.libraryFolders.length;
    final totalItems = catalog.totalItems;
    final largest = catalog.largestLibrary;

    final lastScanLabel = _formatScanTime(scan?.completed);
    final durationLabel = scan != null && scan.durationSeconds > 0
        ? _formatDuration(scan.durationSeconds)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: DecoratedBox(
        decoration: AppCardStyles.decoration(hovered: false, pressed: false),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overview', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              _OverviewRow(
                icon: Icons.movie_outlined,
                label: 'Total items',
                value: '$totalItems',
              ),
              _OverviewRow(
                icon: Icons.folder_outlined,
                label: 'Libraries',
                value: '$libraryCount',
              ),
              if (largest != null)
                _OverviewRow(
                  icon: Icons.star_outline,
                  label: 'Largest library',
                  value: '${largest.name} (${largest.itemCount})',
                ),
              if (lastScanLabel != null)
                _OverviewRow(
                  icon: Icons.schedule_outlined,
                  label: 'Last scan',
                  value: durationLabel != null
                      ? '$lastScanLabel · $durationLabel'
                      : lastScanLabel,
                ),
              if (scan != null && scan.warnings > 0)
                _OverviewRow(
                  icon: Icons.warning_amber_outlined,
                  label: 'Scan warnings',
                  value: '${scan.warnings}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _formatScanTime(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    final y = local.year;
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (minutes < 60) {
      return rem > 0 ? '${minutes}m ${rem}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    return remMin > 0 ? '${hours}h ${remMin}m' : '${hours}h';
  }
}

class _OverviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIcons.sm, color: AppColors.textMedium),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppTypography.bodyMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: AppTypography.body,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
