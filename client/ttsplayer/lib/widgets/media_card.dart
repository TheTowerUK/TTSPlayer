import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_theme.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const MediaCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail or placeholder
            Expanded(
              child: item.thumbnailPath != null
                  ? Image.network(
                      item.thumbnailPath!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            // Title + metadata
            Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (item.year != null)
                        Text(
                          '${item.year}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMedium),
                        ),
                      if (item.year != null && item.formattedDuration != null)
                        const Text('  ·  ', style: AppTypography.bodyFaint),
                      if (item.formattedDuration != null)
                        Text(
                          item.formattedDuration!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMedium),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.chip,
      child: const Center(
        child: Icon(Icons.play_circle_outline,
            size: AppIcons.folderLarge, color: AppColors.textDisabled),
      ),
    );
  }
}
