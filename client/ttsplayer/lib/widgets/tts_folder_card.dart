import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_folder.dart';
import '../models/media_item.dart';
import '../navigation/single_reader_folder.dart';
import '../services/artwork/artwork_service.dart';
import '../theme/app_theme.dart';
import 'artwork/card_artwork_band.dart';
import 'artwork/resolved_media_artwork_image.dart';
import 'card_layout.dart';

/// Premium folder card with desktop hover, artwork band, and press effects.
class TtsFolderCard extends StatefulWidget {
  final MediaFolder folder;
  final VoidCallback onTap;

  /// Optional details action (single playable video/reader leaf folders).
  final VoidCallback? onDetails;

  /// Optional overlay placed top-left on artwork (e.g. favourite toggle).
  final Widget? topLeftOverlay;

  const TtsFolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.onDetails,
    this.topLeftOverlay,
  });

  @override
  State<TtsFolderCard> createState() => _TtsFolderCardState();
}

class _TtsFolderCardState extends State<TtsFolderCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final artworkService = context.read<ArtworkService>();
    final candidate = artworkService.forFolder(widget.folder);
    final readerItem = singlePlayableReaderItem(widget.folder);
    final count = widget.folder.totalItems;
    final label = '$count item${count == 1 ? '' : 's'}';

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (readerItem != null)
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _ReaderCoverSlot(
                              item: readerItem,
                              folder: widget.folder,
                            ),
                            ..._artworkOverlays(),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: CardLayout.artworkBandHeight(
                          width: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CardArtworkBand(
                              candidate: candidate,
                              iconSize: AppIcons.folder,
                            ),
                            ..._artworkOverlays(),
                          ],
                        ),
                      ),
                    if (readerItem != null)
                      _FolderFooter(
                        name: widget.folder.name,
                        label: label,
                        expandTitle: false,
                      )
                    else
                      Expanded(
                        child: _FolderFooter(
                          name: widget.folder.name,
                          label: label,
                          expandTitle: true,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _artworkOverlays() {
    return [
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
            key: Key('folder_details_${widget.folder.id}'),
            tooltip: 'View details for ${widget.folder.name}',
            icon: const Icon(
              Icons.info_outline,
              size: AppIcons.md,
            ),
            onPressed: widget.onDetails,
            visualDensity: VisualDensity.compact,
          ),
        ),
    ];
  }
}

class _ReaderCoverSlot extends StatelessWidget {
  const _ReaderCoverSlot({
    required this.item,
    required this.folder,
  });

  final MediaItem item;
  final MediaFolder folder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final width = math.min(maxWidth, maxHeight * 2 / 3);
        final height = width * 3 / 2;
        return ColoredBox(
          color: AppColors.card,
          child: Center(
            child: SizedBox(
              key: Key('folder_reader_cover_${folder.id}'),
              width: width,
              height: height,
              child: ResolvedMediaArtworkImage(
                item: item,
                parentFolder: folder,
                fit: BoxFit.contain,
                iconSize: AppIcons.folder,
                logicalDecodeSize: Size(width, height),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FolderFooter extends StatelessWidget {
  const _FolderFooter({
    required this.name,
    required this.label,
    required this.expandTitle,
  });

  final String name;
  final String label;
  final bool expandTitle;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      name,
      style: AppTypography.cardTitle.copyWith(
        fontSize: AppTypography.size16,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: kCardFooterPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expandTitle ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (expandTitle) Flexible(child: title) else title,
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.cardSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
