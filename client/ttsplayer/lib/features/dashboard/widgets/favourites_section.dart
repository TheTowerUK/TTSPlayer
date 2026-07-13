import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../library/favourites_resolver.dart';
import '../../../models/catalog.dart';
import '../../../screens/folder_screen.dart';
import '../../../screens/item_detail_screen.dart';
import '../../../services/library/library_metadata_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/favourite_toggle_button.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_folder_card.dart';
import '../../../widgets/tts_media_card.dart';
import '../../favourites/favourites_navigation.dart';

/// Dashboard favourites section — first 10 resolved entries + View all (ADR-007).
class FavouritesSection extends StatelessWidget {
  const FavouritesSection({super.key, required this.catalog});

  final Catalog catalog;

  static const dashboardCap = 10;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryMetadataRepository>(
      builder: (context, repository, _) {
        final entries = resolveFavourites(
          catalog: catalog,
          folderRecords: repository.favouriteFolders,
          itemRecords: repository.favouriteItems,
        );

        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }

        final visible = entries.take(dashboardCap).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Favourites',
              trailing: TextButton(
                onPressed: () => openFavouritesScreen(context, catalog: catalog),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FavouritesCarousel(catalog: catalog, entries: visible),
          ],
        );
      },
    );
  }
}

class _FavouritesCarousel extends StatefulWidget {
  const _FavouritesCarousel({
    required this.catalog,
    required this.entries,
  });

  final Catalog catalog;
  final List<ResolvedFavouriteEntry> entries;

  @override
  State<_FavouritesCarousel> createState() => _FavouritesCarouselState();
}

class _FavouritesCarouselState extends State<_FavouritesCarousel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CardLayout.recentlyAddedListHeight,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: widget.entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final entry = widget.entries[index];
            return _DashboardFavouriteCard(
              catalog: widget.catalog,
              entry: entry,
            );
          },
        ),
      ),
    );
  }
}

class _DashboardFavouriteCard extends StatelessWidget {
  const _DashboardFavouriteCard({
    required this.catalog,
    required this.entry,
  });

  final Catalog catalog;
  final ResolvedFavouriteEntry entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry.kind) {
      FavouriteEntryKind.folder => SizedBox(
          width: CardLayout.featuredFolderCardWidth,
          height: CardLayout.featuredFolderCardHeight,
          child: TtsFolderCard(
            folder: entry.folder!,
            topLeftOverlay: FavouriteFolderToggle(
              folderId: entry.id,
              compact: true,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FolderScreen(
                  folderPath: entry.folder!.path,
                  folderName: entry.folder!.name,
                ),
              ),
            ),
          ),
        ),
      FavouriteEntryKind.item => Semantics(
          button: true,
          label: 'Favourite media: ${entry.item!.title}',
          child: SizedBox(
            width: CardLayout.recentlyAddedCardWidth,
            height: CardLayout.recentlyAddedCardHeight,
            child: TtsMediaCard(
              item: entry.item!,
              parentFolder: entry.parentFolder,
              topLeftOverlay: FavouriteItemToggle(
                itemId: entry.id,
                compact: true,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailScreen(item: entry.item!),
                ),
              ),
            ),
          ),
        ),
    };
  }
}
