import 'package:flutter/material.dart';

import '../../../services/artwork/artwork_decode_size.dart';
import '../../metadata_enrichment/presentation/media_item_presentation.dart';
import '../../metadata_enrichment/presentation/metadata_presentation_service.dart';
import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/media_kind_presentation.dart';
import '../../../widgets/artwork/resolved_media_artwork_image.dart';
import '../models/search_result.dart';

/// One ranked media hit in Global Search (Phase 4.3 presentation).
class SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final MediaItemPresentation? presentation;
  final String displayContext;
  final VoidCallback onOpen;
  final VoidCallback? onBrowseFolder;
  final VoidCallback? onPlay;

  const SearchResultRow({
    super.key,
    required this.result,
    this.presentation,
    required this.displayContext,
    required this.onOpen,
    this.onBrowseFolder,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final resolvedPresentation =
        presentation ?? const MetadataPresentationService().build(item: item);
    final contextLabel =
        displayContext.isNotEmpty ? displayContext : result.folderContext;
    final metadataLine = _metadataLine(item, resolvedPresentation);
    final displayTitle = resolvedPresentation.displayTitle;

    return Semantics(
      container: true,
      label: '${MediaKindPresentation.labelFor(item)}: $displayTitle'
          '${metadataLine.isNotEmpty ? ', $metadataLine' : ''}'
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
                      child: ResolvedMediaArtworkImage(
                        item: item,
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
                        displayTitle,
                        key: Key('search_result_title_${item.id}'),
                        style: AppTypography.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (metadataLine.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          metadataLine,
                          key: Key('search_result_metadata_${item.id}'),
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
                          _KindChip(
                              label: MediaKindPresentation.labelFor(item)),
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
                        tooltip: 'Play $displayTitle',
                        icon: const Icon(Icons.play_arrow),
                        color: AppColors.primary,
                        onPressed: onPlay,
                      ),
                    IconButton(
                      key: Key('search_open_${item.id}'),
                      tooltip: 'Open details for $displayTitle',
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

  static String _metadataLine(
    MediaItem item,
    MediaItemPresentation presentation,
  ) {
    if (item.isAudio) {
      final artist = item.artist ?? item.albumArtist;
      final album = item.album;
      if (artist != null && album != null) {
        return '$artist · $album';
      }
      return artist ?? album ?? '';
    }
    if (item.isBook) {
      final parts = <String>[
        ...presentation.displayAuthors,
        if (presentation.displaySeries != null) presentation.displaySeries!,
        if (presentation.displayPublicationYear != null)
          presentation.displayPublicationYear!,
      ];
      return parts.join(' · ');
    }
    if (item.isComic) {
      final parts = <String>[
        if (item.author != null && item.author!.isNotEmpty) item.author!,
        if (item.series != null && item.series!.isNotEmpty) item.series!,
      ];
      return parts.join(' · ');
    }
    return '';
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
