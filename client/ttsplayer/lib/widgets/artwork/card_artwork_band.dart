import 'package:flutter/material.dart';

import '../../services/artwork/artwork_candidate.dart';
import '../../theme/app_theme.dart';
import '../card_layout.dart';
import 'artwork_image.dart';

/// 16:9 artwork band that respects fixed grid / list cell height.
class CardArtworkBand extends StatelessWidget {
  final ArtworkCandidate candidate;
  final double? iconSize;

  const CardArtworkBand({
    super.key,
    required this.candidate,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = CardLayout.artworkBandHeight(
          width: width,
          maxHeight: constraints.maxHeight,
        );

        return SizedBox(
          width: width,
          height: height,
          child: ArtworkImage(
            candidate: candidate,
            iconSize: iconSize,
            logicalDecodeSize: Size(width, height),
          ),
        );
      },
    );
  }
}

/// Footer padding for compact grid cards (library / folder).
const EdgeInsets kCardFooterPadding = EdgeInsets.fromLTRB(
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
  AppSpacing.sm,
);

/// Footer padding for Continue Watching hero cards.
const EdgeInsets kHeroCardFooterPadding = EdgeInsets.fromLTRB(
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
  AppSpacing.md,
);
