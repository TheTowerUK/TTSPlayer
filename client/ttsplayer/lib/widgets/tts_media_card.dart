import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_theme.dart';

/// Premium media item card with desktop hover and animated press effects.
///
/// Portrait layout: thumbnail occupies the top portion; title and metadata
/// sit below in a fixed-height area.  A status badge appears in the top-right
/// corner for non-available items.
class TtsMediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const TtsMediaCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<TtsMediaCard> createState() => _TtsMediaCardState();
}

class _TtsMediaCardState extends State<TtsMediaCard> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _bgColor {
    if (_pressed) return AppColors.cardPressed;
    if (_hovered) return AppColors.cardHover;
    return AppColors.card;
  }

  Color get _borderColor {
    if (_hovered || _pressed) return AppColors.primary.withAlpha(50);
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
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
            duration: AppAnimations.standard,
            curve: AppAnimations.smooth,
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: _borderColor, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail — takes up remaining space above metadata area
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.item.thumbnailPath != null
                          ? Image.network(
                              widget.item.thumbnailPath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _ThumbnailPlaceholder(),
                            )
                          : const _ThumbnailPlaceholder(),

                      // Status badge — only for non-available items
                      if (widget.item.status != MediaItemStatus.available)
                        Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: _StatusBadge(status: widget.item.status),
                        ),
                    ],
                  ),
                ),

                // Metadata area
                Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: AppTypography.cardTitle.copyWith(fontSize: AppTypography.size13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _MetaRow(item: widget.item),
                    ],
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

// ---------------------------------------------------------------------------
// Thumbnail placeholder
// ---------------------------------------------------------------------------

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.chip,
      child: const Center(
        child: Icon(Icons.play_circle_outline,
            size: AppIcons.folderLarge, color: AppColors.textDisabled),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata row — year · duration
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final MediaItemStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MediaItemStatus.missing     => ('Missing',     AppColors.statusMissing),
      MediaItemStatus.unavailable => ('Unavailable', AppColors.statusUnavailable),
      MediaItemStatus.restricted  => ('Restricted',  AppColors.statusRestricted),
      MediaItemStatus.unsupported => ('Unsupported', AppColors.statusDefault),
      MediaItemStatus.skipped     => ('Skipped',     AppColors.statusDefault),
      _                           => ('Unknown',     AppColors.statusDefault),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
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
