import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class MusicNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MusicNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('music_nav_$title'),
      color: AppColors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          padding: AppSpacing.cardPremium,
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: AppIcons.lg),
              const SizedBox(width: AppSpacing.base),
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
              const Icon(Icons.chevron_right, color: AppColors.textLow),
            ],
          ),
        ),
      ),
    );
  }
}
