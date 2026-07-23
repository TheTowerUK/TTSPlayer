import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_navigation.dart';
import '../widgets/music_catalog_ui_state.dart';
import '../widgets/music_list_tiles.dart';

class MusicArtistsScreen extends StatelessWidget {
  const MusicArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Artists'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          final unavailable = musicCatalogUnavailableBody(catalogService);
          if (unavailable != null) return unavailable;

          final catalog = catalogService.catalog!;
          final artists = context
              .read<MusicLibraryService>()
              .projectionFor(catalog)
              .artists;

          if (artists.isEmpty) {
            return const EmptyState(
              key: Key('music_artists_empty'),
              icon: Icons.person_outline,
              title: 'No artists found.',
              subtitle: 'This catalogue has no audio grouped by artist.',
            );
          }

          final degraded = musicCatalogDegradedBanner(catalogService);

          return Column(
            children: [
              if (degraded != null) degraded,
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    key: const PageStorageKey<String>('music_artists_list'),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: artists.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      return MusicArtistListTile(
                        artist: artist,
                        onTap: () => openMusicArtistDetailScreen(
                          context,
                          artistGroupKey: artist.groupKey,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
