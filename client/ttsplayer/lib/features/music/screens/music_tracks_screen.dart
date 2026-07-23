import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_navigation.dart';
import '../widgets/music_list_tiles.dart';

class MusicTracksScreen extends StatelessWidget {
  const MusicTracksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Tracks'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          final catalog = catalogService.catalog;
          if (catalog == null) {
            return const EmptyState(
              icon: Icons.queue_music_outlined,
              title: 'No catalogue loaded.',
            );
          }

          final tracks =
              context.read<MusicLibraryService>().projectionFor(catalog).tracks;

          if (tracks.isEmpty) {
            return const EmptyState(
              icon: Icons.queue_music_outlined,
              title: 'No tracks found.',
            );
          }

          return Scrollbar(
            thumbVisibility: true,
            child: ListView.separated(
              key: const PageStorageKey<String>('music_tracks_list'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return MusicTrackListTile(
                  track: track,
                  onTap: () => openMusicTrackDetailScreen(
                    context,
                    trackId: track.id,
                  ),
                  onPlay: track.status.isPlayable
                      ? () => openMusicPlayerScreen(context, track: track)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
