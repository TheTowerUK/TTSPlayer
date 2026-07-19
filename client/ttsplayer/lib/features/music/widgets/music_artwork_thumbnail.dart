import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../services/artwork/artwork_decode_size.dart';
import '../../../services/artwork/artwork_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/artwork/artwork_image.dart';

/// Square music artwork thumbnail using the existing artwork pipeline.
class MusicArtworkThumbnail extends StatelessWidget {
  final MediaItem? item;
  final double size;

  const MusicArtworkThumbnail({
    super.key,
    required this.item,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final artworkService = context.read<ArtworkService>();
    final candidate = item == null
        ? artworkService.forMediaItem(
            MediaItem(
              id: 'music-placeholder',
              title: 'Music',
              filePath: r'Y:\Media\Music\placeholder.mp3',
              mediaKindRaw: 'audio',
            ),
          )
        : artworkService.forMediaItem(item!);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: AppRadius.chipRadius,
        child: ArtworkImage(
          candidate: candidate,
          iconSize: AppIcons.md,
          logicalDecodeSize: ArtworkSurfaceSizes.searchResultThumbnail(),
        ),
      ),
    );
  }
}
