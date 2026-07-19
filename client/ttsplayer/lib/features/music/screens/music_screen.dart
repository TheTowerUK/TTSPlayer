import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../music_library_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_card.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_navigation.dart';
import '../widgets/music_nav_tile.dart';

/// Read-only music landing — browse artists, albums, and tracks (M5.2).
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Music'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          if (catalogService.isLoading && catalogService.catalog == null) {
            return const LoadingCard(message: 'Loading music…');
          }

          final catalog = catalogService.catalog;
          if (catalog == null) {
            return const EmptyState(
              icon: Icons.library_music_outlined,
              title: 'No catalogue loaded.',
              subtitle: 'Load a catalogue to browse music.',
            );
          }

          final projection = context
              .read<MusicLibraryService>()
              .projectionFor(catalog);

          if (projection.isEmpty) {
            return const EmptyState(
              icon: Icons.library_music_outlined,
              title: 'No music in this catalogue.',
              subtitle: 'Scan a library that contains audio files to browse music here.',
            );
          }

          return ListView(
            key: const Key('music_landing'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                '${projection.artistCount} artists · '
                '${projection.albumCount} albums · '
                '${projection.trackCount} tracks',
                style: AppTypography.cardSubtitle,
              ),
              const SizedBox(height: AppSpacing.section),
              MusicNavTile(
                icon: Icons.person_outline,
                title: 'Artists',
                subtitle: '${projection.artistCount} artists',
                onTap: () => openMusicArtistsScreen(context),
              ),
              const SizedBox(height: AppSpacing.base),
              MusicNavTile(
                icon: Icons.album_outlined,
                title: 'Albums',
                subtitle: '${projection.albumCount} albums',
                onTap: () => openMusicAlbumsScreen(context),
              ),
              const SizedBox(height: AppSpacing.base),
              MusicNavTile(
                icon: Icons.queue_music_outlined,
                title: 'Tracks',
                subtitle: '${projection.trackCount} tracks',
                onTap: () => openMusicTracksScreen(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
