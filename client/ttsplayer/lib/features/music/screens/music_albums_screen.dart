import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_navigation.dart';
import '../widgets/music_list_tiles.dart';

class MusicAlbumsScreen extends StatelessWidget {
  const MusicAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Albums'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          final catalog = catalogService.catalog;
          if (catalog == null) {
            return const EmptyState(
              icon: Icons.album_outlined,
              title: 'No catalogue loaded.',
            );
          }

          final albums = context
              .read<MusicLibraryService>()
              .projectionFor(catalog)
              .albums;

          if (albums.isEmpty) {
            return const EmptyState(
              icon: Icons.album_outlined,
              title: 'No albums found.',
            );
          }

          return Scrollbar(
            thumbVisibility: true,
            child: ListView.separated(
              key: const Key('music_albums_list'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: albums.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final album = albums[index];
                return MusicAlbumListTile(
                  album: album,
                  onTap: () => openMusicAlbumDetailScreen(
                    context,
                    albumGroupKey: album.groupKey,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
