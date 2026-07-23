import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_navigation.dart';
import '../music_queue_seeding.dart';
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
      appBar: const TtsAppBar(title: 'Artist'),
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
              subtitle:
                  'This artist may have been removed by a catalogue refresh.',
              actionLabel: 'Back',
              onAction: () => Navigator.maybePop(context),
            );
          }

          final canPlayArtist =
              MusicQueueSeeding.hasPlayableTracks(artist.tracksInAlbumOrder);
          final albums = artist.albums;
          final tracks = artist.tracks;

          return Scrollbar(
            thumbVisibility: true,
            child: CustomScrollView(
              key: PageStorageKey<String>(
                'music_artist_detail_${artist.groupKey}',
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      Text(
                        artist.displayName,
                        style: AppTypography.sectionTitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${artist.albumCount} albums · ${artist.trackCount} tracks',
                        style: AppTypography.cardSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Semantics(
                        button: true,
                        enabled: canPlayArtist,
                        label: 'Play artist ${artist.displayName}',
                        excludeSemantics: true,
                        child: FilledButton.icon(
                          key: const Key('music_artist_play'),
                          onPressed: canPlayArtist
                              ? () => openMusicPlayerFromArtist(
                                    context,
                                    artist: artist,
                                  )
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play artist'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      const SectionHeader(title: 'Albums'),
                      const SizedBox(height: AppSpacing.sm),
                      if (albums.isEmpty)
                        const Text(
                          'No albums.',
                          style: AppTypography.bodyMuted,
                        ),
                    ]),
                  ),
                ),
                if (albums.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = albums[index];
                          return MusicAlbumListTile(
                            album: album,
                            onTap: () => openMusicAlbumDetailScreen(
                              context,
                              albumGroupKey: album.groupKey,
                            ),
                          );
                        },
                        childCount: albums.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.section,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: SectionHeader(title: 'Tracks'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = tracks[index];
                        return MusicTrackListTile(
                          track: track,
                          onTap: () => openMusicTrackDetailScreen(
                            context,
                            trackId: track.id,
                          ),
                          onPlay: track.status.isPlayable
                              ? () => openMusicPlayerFromArtistTrack(
                                    context,
                                    artist: artist,
                                    track: track,
                                  )
                              : null,
                          playSemanticsLabel: 'Play ${track.title} from artist',
                        );
                      },
                      childCount: tracks.length,
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
