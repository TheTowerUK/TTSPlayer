import 'package:flutter/material.dart';

import '../models/media_folder.dart';
import '../models/media_item.dart';
import '../services/artwork/artwork_decode_size.dart';
import '../theme/app_theme.dart';
import '../utils/media_kind_presentation.dart';
import '../utils/video_display_title.dart';
import 'artwork/resolved_media_artwork_image.dart';

/// Premium media item card with artwork, desktop hover, and press effects.
///
/// Portrait layout: poster occupies the top portion; title and metadata
/// sit below. A status badge appears for non-available items.
class TtsMediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onDetails;
  final MediaFolder? parentFolder;
  final bool showVideoPoster;

  /// Optional overlay placed top-left on artwork (e.g. favourite toggle).
  final Widget? topLeftOverlay;

  const TtsMediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDetails,
    this.parentFolder,
    this.showVideoPoster = false,
    this.topLeftOverlay,
  });

  @override
  State<TtsMediaCard> createState() => _TtsMediaCardState();
}

class _TtsMediaCardState extends State<TtsMediaCard> {
  bool _hovered = false;
  bool _pressed = false;

  static const double _metadataMaxHeight =
      ArtworkSurfaceSizes.mediaCardMetadataMaxHeight;

  @override
  Widget build(BuildContext context) {
    final displayTitle = VideoDisplayTitle.forItem(widget.item);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Semantics(
        button: true,
        label: '${MediaKindPresentation.labelFor(widget.item)}: $displayTitle',
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
                        if (widget.showVideoPoster)
                          Center(
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: ColoredBox(
                                color: AppColors.card,
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      _artwork(constraints, BoxFit.contain),
                                ),
                              ),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) =>
                                _artwork(constraints, BoxFit.cover),
                          ),
                        if (widget.item.status != MediaItemStatus.available)
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: _StatusBadge(status: widget.item.status),
                          ),
                        Positioned(
                          top: AppSpacing.sm,
                          left: widget.topLeftOverlay != null
                              ? AppSpacing.xl + AppSpacing.sm
                              : AppSpacing.sm,
                          child: _KindBadge(item: widget.item),
                        ),
                        if (widget.topLeftOverlay != null)
                          Positioned(
                            top: AppSpacing.xs,
                            left: AppSpacing.xs,
                            child: widget.topLeftOverlay!,
                          ),
                        if (widget.onDetails != null)
                          Positioned(
                            right: AppSpacing.xs,
                            bottom: AppSpacing.xs,
                            child: IconButton.filledTonal(
                              key: Key('media_details_${widget.item.id}'),
                              tooltip: 'View details for $displayTitle',
                              icon: const Icon(
                                Icons.info_outline,
                                size: AppIcons.md,
                              ),
                              onPressed: widget.onDetails,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: _metadataMaxHeight),
                    child: Padding(
                      padding: AppSpacing.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayTitle,
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
      ),
    );
  }

  Widget _artwork(BoxConstraints constraints, BoxFit fit) {
    return ResolvedMediaArtworkImage(
      item: widget.item,
      parentFolder: widget.parentFolder,
      fit: fit,
      logicalDecodeSize: constraints.biggest,
    );
  }
}

class _MetaRow extends StatelessWidget {
  final MediaItem item;

  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final subtitle = MediaKindPresentation.cardSubtitle(item);
    if (subtitle == null || subtitle.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      subtitle,
      style: AppTypography.cardSubtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _KindBadge extends StatelessWidget {
  final MediaItem item;

  const _KindBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: AppRadius.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MediaKindPresentation.iconFor(item),
            size: 12,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            MediaKindPresentation.labelFor(item),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTypography.size11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
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
      MediaItemStatus.unavailable => (
          'Unavailable',
          AppColors.statusUnavailable
        ),
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
