import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_navigation.dart';
import '../widgets/music_list_tiles.dart';

class MusicArtistDetailScreen extends StatelessWidget {
  final String artistGroupKey;

  const MusicArtistDetailScreen({
    super.key,
    required this.artistGroupKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TtsAppBar(title: 'Artist'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          final catalog = catalogService.catalog;
          if (catalog == null) {
            return const EmptyState(
              icon: Icons.person_outline,
              title: 'Artist unavailable.',
              subtitle: 'The catalogue is no longer loaded.',
            );
          }

          final artist = context
              .read<MusicLibraryService>()
              .projectionFor(catalog)
              .findArtistByGroupKey(artistGroupKey);

          if (artist == null) {
            return EmptyState(
              icon: Icons.person_outline,
              title: 'Artist no longer in catalogue.',
              subtitle: 'This artist may have been removed by a catalogue refresh.',
              actionLabel: 'Back',
              onAction: () => Navigator.maybePop(context),
            );
          }

          return Scrollbar(
            thumbVisibility: true,
            child: ListView(
              key: Key('music_artist_detail_${artist.groupKey}'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(artist.displayName, style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${artist.albumCount} albums · ${artist.trackCount} tracks',
                  style: AppTypography.cardSubtitle,
                ),
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Albums'),
                const SizedBox(height: AppSpacing.sm),
                if (artist.albums.isEmpty)
                  const Text('No albums.', style: AppTypography.bodyMuted)
                else
                  ...artist.albums.map(
                    (album) => MusicAlbumListTile(
                      album: album,
                      onTap: () => openMusicAlbumDetailScreen(
                        context,
                        albumGroupKey: album.groupKey,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Tracks'),
                const SizedBox(height: AppSpacing.sm),
                ...artist.tracks.map(
                  (track) => MusicTrackListTile(
                    track: track,
                    onTap: () => openMusicTrackDetailScreen(
                      context,
                      trackId: track.id,
                    ),
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
