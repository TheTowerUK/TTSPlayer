import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_folder.dart';
import '../models/media_item.dart';
import '../services/artwork/artwork_service.dart';
import '../theme/app_theme.dart';
import 'artwork/artwork_image.dart';

/// Premium media item card with artwork, desktop hover, and press effects.
///
/// Portrait layout: poster occupies the top portion; title and metadata
/// sit below. A status badge appears for non-available items.
class TtsMediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final MediaFolder? parentFolder;

  const TtsMediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.parentFolder,
  });

  @override
  State<TtsMediaCard> createState() => _TtsMediaCardState();
}

class _TtsMediaCardState extends State<TtsMediaCard> {
  bool _hovered = false;
  bool _pressed = false;

  static const double _metadataMaxHeight = 72;

  @override
  Widget build(BuildContext context) {
    final artworkService = context.read<ArtworkService>();
    final candidate = artworkService.forMediaItem(
      widget.item,
      parentFolder: widget.parentFolder,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? AppAnimations.pressScale : 1.0,
          duration: AppAnimations.fast,
          curve: AppAnimations.enter,
          child: AnimatedContainer(
            duration: AppDurations.hover,
            curve: AppAnimations.smooth,
            decoration: AppCardStyles.decoration(
              hovered: _hovered,
              pressed: _pressed,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ArtworkImage(
                        candidate: candidate,
                        fit: BoxFit.cover,
                      ),
                      if (widget.item.status != MediaItemStatus.available)
                        Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: _StatusBadge(status: widget.item.status),
                        ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: _metadataMaxHeight),
                  child: Padding(
                    padding: AppSpacing.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.item.title,
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: AppTypography.size14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _MetaRow(item: widget.item),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final MediaItem item;

  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.year != null) '${item.year}',
      if (item.formattedDuration != null) item.formattedDuration!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: AppTypography.cardSubtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MediaItemStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MediaItemStatus.missing => ('Missing', AppColors.statusMissing),
      MediaItemStatus.unavailable => ('Unavailable', AppColors.statusUnavailable),
      MediaItemStatus.restricted => ('Restricted', AppColors.statusRestricted),
      MediaItemStatus.unsupported => ('Unsupported', AppColors.statusDefault),
      MediaItemStatus.skipped => ('Skipped', AppColors.statusDefault),
      _ => ('Unknown', AppColors.statusDefault),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(220),
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTypography.size11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
