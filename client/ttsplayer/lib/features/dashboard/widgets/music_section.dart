import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/section_header.dart';
import '../../music/music_library_service.dart';
import '../../music/music_navigation.dart';
import 'music_section_card.dart';

/// Dashboard entry to read-only music browsing (M5.2).
class MusicSection extends StatelessWidget {
  const MusicSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogService>(
      builder: (context, catalogService, _) {
        final catalog = catalogService.catalog;
        if (catalog == null) return const SizedBox.shrink();

        final projection = context
            .read<MusicLibraryService>()
            .projectionFor(catalog);
        if (projection.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Music'),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: MusicSectionCard(
                key: const Key('dashboard_music_entry'),
                artistCount: projection.artistCount,
                albumCount: projection.albumCount,
                trackCount: projection.trackCount,
                onTap: () => openMusicScreen(context),
              ),
            ),
          ],
        );
      },
    );
  }
}
