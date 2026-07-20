import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_navigation.dart';
import '../widgets/music_artwork_thumbnail.dart';
import '../widgets/music_list_tiles.dart';

class MusicAlbumDetailScreen extends StatelessWidget {
  final String albumGroupKey;

  const MusicAlbumDetailScreen({
    super.key,
    required this.albumGroupKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Album'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          final catalog = catalogService.catalog;
          if (catalog == null) {
            return const EmptyState(
              icon: Icons.album_outlined,
              title: 'Album unavailable.',
            );
          }

          final album = context
              .read<MusicLibraryService>()
              .projectionFor(catalog)
              .findAlbumByGroupKey(albumGroupKey);

          if (album == null) {
            return EmptyState(
              icon: Icons.album_outlined,
              title: 'Album no longer in catalogue.',
              actionLabel: 'Back',
              onAction: () => Navigator.maybePop(context),
            );
          }

          final meta = <String>[
            album.displayArtist,
            if (album.year != null) '${album.year}',
            if (album.genre != null) album.genre!,
            if (album.discCount > 1) '${album.discCount} discs',
            '${album.trackCount} tracks',
          ].join(' · ');

          return Scrollbar(
            thumbVisibility: true,
            child: ListView(
              key: Key('music_album_detail_${album.groupKey}'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: MusicArtworkThumbnail(
                    item: album.representativeTrack,
                    size: 160,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(album.displayTitle, style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(meta, style: AppTypography.cardSubtitle),
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Tracks'),
                const SizedBox(height: AppSpacing.sm),
                ...album.tracks.map(
                  (track) => MusicTrackListTile(
                    track: track,
                    onTap: () => openMusicTrackDetailScreen(
                      context,
                      trackId: track.id,
                    ),
                    onPlay: track.status.isPlayable
                        ? () => openMusicPlayerScreen(context, track: track)
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
