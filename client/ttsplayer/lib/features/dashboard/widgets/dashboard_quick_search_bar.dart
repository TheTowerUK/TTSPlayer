import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class DashboardQuickSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const DashboardQuickSearchBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.cardRadius,
        child: Tooltip(
          message: 'Search (Ctrl+F)',
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardRadius,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_outlined,
                    color: AppColors.textLow,
                    size: AppIcons.lg,
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Text(
                      'Search your library…',
                      style: AppTypography.bodyMuted.copyWith(
                        fontSize: AppTypography.size14,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textLow,
                    size: AppIcons.md,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
