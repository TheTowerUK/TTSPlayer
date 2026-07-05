import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_folder.dart';
import '../services/artwork/artwork_service.dart';
import '../theme/app_theme.dart';
import 'artwork/card_artwork_band.dart';
import 'card_layout.dart';

/// Reusable library card — artwork band, name, item count, and Browse action.
class LibraryCard extends StatefulWidget {
  final MediaFolder folder;
  final VoidCallback onBrowse;

  const LibraryCard({
    super.key,
    required this.folder,
    required this.onBrowse,
  });

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final artworkService = context.read<ArtworkService>();
    final candidate = artworkService.forLibrary(widget.folder);
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
        onTap: widget.onBrowse,
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
                    SizedBox(
                      height: CardLayout.artworkBandHeight(
                        width: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: CardArtworkBand(
                        candidate: candidate,
                        iconSize: AppIcons.folder,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: kCardFooterPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                widget.folder.name,
                                style: AppTypography.cardTitle.copyWith(
                                  fontSize: AppTypography.size16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              label,
                              style: AppTypography.cardSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: widget.onBrowse,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: AppSpacing.buttonSm,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Browse'),
                              ),
                            ),
                          ],
                        ),
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
}
