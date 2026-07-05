import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/artwork/artwork_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/artwork/artwork_image.dart';
import '../models/search_result.dart';

class SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onOpen;
  final VoidCallback? onBrowseFolder;

  const SearchResultRow({
    super.key,
    required this.result,
    required this.onOpen,
    this.onBrowseFolder,
  });

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final playable = item.status.isPlayable;
    final artworkService = context.read<ArtworkService>();
    final candidate = artworkService.forMediaItem(item);

    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          padding: AppSpacing.cardPremium,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppSpacing.searchThumbWidth,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: AppRadius.chipRadius,
                    child: ArtworkImage(
                      candidate: candidate,
                      iconSize: AppIcons.md,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.folderContext.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        result.folderContext,
                        style: AppTypography.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        _ExtensionChip(label: item.extension.toUpperCase()),
                        if (!playable) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            item.status.name,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: AppTypography.size11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Open details',
                    icon: const Icon(Icons.open_in_new_outlined),
                    color: AppColors.primary,
                    onPressed: onOpen,
                  ),
                  if (onBrowseFolder != null)
                    IconButton(
                      tooltip: 'Browse folder',
                      icon: const Icon(Icons.folder_outlined),
                      color: AppColors.textMedium,
                      onPressed: onBrowseFolder,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionChip extends StatelessWidget {
  final String label;

  const _ExtensionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.chip,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMedium,
          fontSize: AppTypography.size11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
