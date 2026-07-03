import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A styled placeholder card for dashboard sections that are not yet functional.
///
/// Displays an [icon], [title], [subtitle], and a "Coming Soon" badge in the
/// top-right corner.  The card appearance matches the premium card design used
/// elsewhere in the app.
///
/// Used for "Storage Status" and "Continue Watching" on the home dashboard.
class PlaceholderSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PlaceholderSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: AppSpacing.cardPremium,
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.chip,
              borderRadius: AppRadius.chipRadius,
            ),
            child: Icon(icon, size: AppIcons.lg, color: AppColors.textLow),
          ),
          const SizedBox(width: AppSpacing.base),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppTypography.cardSubtitle),
              ],
            ),
          ),

          // Coming Soon badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.chip,
              borderRadius: AppRadius.chipRadius,
            ),
            child: const Text(
              'Coming Soon',
              style: TextStyle(
                color: AppColors.textLow,
                fontSize: AppTypography.size11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
