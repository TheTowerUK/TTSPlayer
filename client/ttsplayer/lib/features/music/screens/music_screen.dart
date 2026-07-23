import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_listening_presentation.dart';
import '../music_navigation.dart';
import '../models/music_listening_policy.dart';
import '../services/music_listening_repository.dart';
import '../widgets/continue_listening_section.dart';
import '../widgets/music_catalog_ui_state.dart';
import '../widgets/music_nav_tile.dart';

/// Read-only music landing — browse artists, albums, and tracks (M5.2).
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Music'),
      body: Consumer2<CatalogService, MusicListeningRepository>(
        builder: (context, catalogService, listeningRepository, _) {
          final unavailable = musicCatalogUnavailableBody(catalogService);
          if (unavailable != null) return unavailable;

          final catalog = catalogService.catalog!;
          final projection =
              context.read<MusicLibraryService>().projectionFor(catalog);

          if (projection.isEmpty) {
            return const EmptyState(
              key: Key('music_library_empty'),
              icon: Icons.library_music_outlined,
              title: 'No music in this catalogue.',
              subtitle:
                  'Scan a library that contains audio files to browse music here.',
            );
          }

          final continueEntries = listeningRepository.isLoaded
              ? resolvePlayableListeningEntries(
                  listeningRepository.continueListening(
                    limit:
                        MusicListeningPolicy.defaultContinueListeningQueryCap,
                  ),
                  projection,
                )
              : const <MusicListeningListEntry>[];

          final degraded = musicCatalogDegradedBanner(catalogService);

          return Column(
            children: [
              if (degraded != null) degraded,
              Expanded(
                child: ListView(
                  key: const Key('music_landing'),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      '${projection.artistCount} artists · '
                      '${projection.albumCount} albums · '
                      '${projection.trackCount} tracks',
                      style: AppTypography.cardSubtitle,
                    ),
                    if (continueEntries.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      ContinueListeningSection(entries: continueEntries),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    MusicNavTile(
                      key: const Key('music_recently_played_tile'),
                      icon: Icons.history,
                      title: 'Recently Played',
                      subtitle: listeningRepository.isLoaded
                          ? '${listeningRepository.storedRecordCount} tracks in history'
                          : 'Listening history',
                      onTap: () => openMusicRecentlyPlayedScreen(context),
                    ),
                    const SizedBox(height: AppSpacing.base),
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
