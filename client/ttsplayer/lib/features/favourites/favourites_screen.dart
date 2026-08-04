import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../library/favourites_resolver.dart';
import '../../models/catalog.dart';
import '../../navigation/folder_navigation.dart';
import '../../screens/item_detail_screen.dart';
import '../../services/artwork/artwork_decode_size.dart';
import '../../services/library/library_metadata_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artwork/resolved_media_artwork_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/favourite_toggle_button.dart';
import '../../widgets/tts_app_bar.dart';

/// Full favourites list reached from dashboard **View all** (ADR-007).
class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key, required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TtsAppBar(title: 'Favourites'),
      body: Consumer<LibraryMetadataRepository>(
        builder: (context, repository, _) {
          final entries = resolveFavourites(
            catalog: catalog,
            folderRecords: repository.favouriteFolders,
            itemRecords: repository.favouriteItems,
          );

          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.star_border,
                  title: 'No favourites yet',
                  subtitle:
                      'Add folders or media to favourites to find them quickly here.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.section,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _FavouriteListTile(
                entry: entry,
                onOpen: () => _openEntry(context, entry),
              );
            },
          );
        },
      ),
    );
  }

  void _openEntry(BuildContext context, ResolvedFavouriteEntry entry) {
    switch (entry.kind) {
      case FavouriteEntryKind.folder:
        openFolderScreen(context, entry.folder!);
      case FavouriteEntryKind.item:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(item: entry.item!),
          ),
        );
    }
  }
}

class _FavouriteListTile extends StatelessWidget {
  const _FavouriteListTile({
    required this.entry,
    required this.onOpen,
  });

  final ResolvedFavouriteEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = entry.displayTitle;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 48,
                child: entry.kind == FavouriteEntryKind.folder
                    ? Icon(
                        Icons.folder_outlined,
                        size: AppIcons.folderLarge,
                        color: AppColors.textLow,
                      )
                    : ResolvedMediaArtworkImage(
                        item: entry.item!,
                        parentFolder: entry.parentFolder,
                        fit: BoxFit.cover,
                        logicalDecodeSize:
                            ArtworkSurfaceSizes.favouritesRowThumbnail(),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.kindLabel,
                      style: AppTypography.cardSubtitle,
                    ),
                  ],
                ),
              ),
              if (entry.kind == FavouriteEntryKind.folder)
                FavouriteFolderToggle(folderId: entry.id)
              else
                FavouriteItemToggle(itemId: entry.id),
            ],
          ),
        ),
      ),
    );
  }
}
