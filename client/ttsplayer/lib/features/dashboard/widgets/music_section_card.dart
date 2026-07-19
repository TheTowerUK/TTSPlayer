import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class MusicSectionCard extends StatelessWidget {
  final int artistCount;
  final int albumCount;
  final int trackCount;
  final VoidCallback onTap;

  const MusicSectionCard({
    super.key,
    required this.artistCount,
    required this.albumCount,
    required this.trackCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
              const Icon(
                Icons.library_music_outlined,
                color: AppColors.primary,
                size: AppIcons.lg,
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Browse Music', style: AppTypography.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$artistCount artists · $albumCount albums · $trackCount tracks',
                      style: AppTypography.cardSubtitle,
                    ),
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
