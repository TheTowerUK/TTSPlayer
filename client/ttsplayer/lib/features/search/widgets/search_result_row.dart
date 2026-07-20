import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/artwork/artwork_decode_size.dart';
import '../../../services/artwork/artwork_service.dart';
import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/artwork/artwork_image.dart';
import '../models/search_result.dart';

/// One ranked media hit in Global Search (Phase 4.3 presentation).
class SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final String displayContext;
  final VoidCallback onOpen;
  final VoidCallback? onBrowseFolder;
  final VoidCallback? onPlay;

  const SearchResultRow({
    super.key,
    required this.result,
    required this.displayContext,
    required this.onOpen,
    this.onBrowseFolder,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final artworkService = context.read<ArtworkService>();
    final candidate = artworkService.forMediaItem(item);
    final contextLabel =
        displayContext.isNotEmpty ? displayContext : result.folderContext;
    final musicMeta = _musicMetadataLine(item);

    return Semantics(
      container: true,
      label: '${_kindLabel(item)}: ${item.title}'
          '${musicMeta.isNotEmpty ? ', $musicMeta' : ''}'
          '${contextLabel.isNotEmpty ? ', in $contextLabel' : ''}',
      child: Material(
        key: Key('search_result_${item.id}'),
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
                        logicalDecodeSize:
                            ArtworkSurfaceSizes.searchResultThumbnail(),
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
                      if (musicMeta.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          musicMeta,
                          style: AppTypography.cardSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (contextLabel.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          contextLabel,
                          style: AppTypography.cardSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          _KindChip(label: _kindLabel(item)),
                          const SizedBox(width: AppSpacing.sm),
                          _ExtensionChip(label: item.extension.toUpperCase()),
                          if (!item.status.isPlayable) ...[
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
                    if (onPlay != null)
                      IconButton(
                        key: Key('search_play_${item.id}'),
                        tooltip: 'Play ${item.title}',
                        icon: const Icon(Icons.play_arrow),
                        color: AppColors.primary,
                        onPressed: onPlay,
                      ),
                    IconButton(
                      key: Key('search_open_${item.id}'),
                      tooltip: 'Open details for ${item.title}',
                      icon: const Icon(Icons.open_in_new_outlined),
                      color: AppColors.primary,
                      onPressed: onOpen,
                    ),
                    if (onBrowseFolder != null)
                      IconButton(
                        key: Key('search_browse_folder_${item.id}'),
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
      ),
    );
  }

  static String _kindLabel(MediaItem item) {
    return switch (item.mediaKind) {
      MediaKind.video => 'Video',
      MediaKind.audio => 'Audio',
      MediaKind.image => 'Image',
      MediaKind.unknown => 'Media',
    };
  }

  static String _musicMetadataLine(MediaItem item) {
    if (!item.isAudio) return '';
    final artist = item.artist ?? item.albumArtist;
    final album = item.album;
    if (artist != null && album != null) {
      return '$artist · $album';
    }
    return artist ?? album ?? '';
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label});

  final String label;

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
          color: AppColors.textHigh,
          fontSize: AppTypography.size11,
          fontWeight: FontWeight.w600,
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
