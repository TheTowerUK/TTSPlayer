import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dashboard card showing scanner metadata for the loaded catalogue.
class LibraryStatusCard extends StatelessWidget {
  /// Comma-separated lowercase extensions, e.g. "avi, m4v, mkv, mov, mp4".
  final String supportedExtensionsLabel;

  const LibraryStatusCard({
    super.key,
    required this.supportedExtensionsLabel,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.chip,
              borderRadius: AppRadius.chipRadius,
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: AppIcons.lg,
              color: AppColors.textLow,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Library Status', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Scanning for: $supportedExtensionsLabel',
                  style: AppTypography.cardSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
