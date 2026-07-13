import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../models/media_folder.dart';
import '../models/media_item.dart';
import '../navigation/folder_navigation.dart';
import '../services/catalog_service.dart';
import '../services/library/library_metadata_repository.dart';
import '../services/scanner_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/favourite_toggle_button.dart';
import '../widgets/folder_breadcrumb.dart';
import '../widgets/loading_card.dart';
import '../widgets/scan_progress_dialog.dart';
import '../widgets/tts_app_bar.dart';
import '../widgets/tts_folder_card.dart';
import '../widgets/tts_media_card.dart';
import 'item_detail_screen.dart';

/// Browses a folder by catalogue identity — resolved from live [CatalogService].
class FolderScreen extends StatelessWidget {
  /// Canonical catalogue folder id (preferred).
  final String folderId;

  /// Optional path fallback for legacy callers and rescan recovery.
  final String? folderPath;

  /// Shown in the app bar while loading or when the folder disappears.
  final String folderName;

  const FolderScreen._({
    super.key,
    required this.folderId,
    this.folderPath,
    required this.folderName,
  });

  /// Preferred constructor — stable catalogue identity (ADR-009).
  factory FolderScreen.fromFolder(MediaFolder folder) {
    return FolderScreen._(
      folderId: folder.id,
      folderPath: folder.path,
      folderName: folder.name,
    );
  }

  /// Path-based compatibility constructor — id resolved from live catalogue.
  const FolderScreen({
    super.key,
    required String folderPath,
    required this.folderName,
  })  : folderId = '',
        folderPath = folderPath;

  MediaFolder? _resolveFolder(Catalog catalog) {
    if (folderId.isNotEmpty) {
      final byId = catalog.findFolderById(folderId);
      if (byId != null) return byId;
    }
    final path = folderPath;
    if (path != null && path.isNotEmpty) {
      return catalog.findFolderByPath(path);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogService>(
      builder: (context, catalogService, _) {
        if (catalogService.isLoading) {
          return Scaffold(
            appBar: TtsAppBar(title: folderName),
            body: const LoadingCard(message: 'Refreshing library…'),
          );
        }

        final catalog = catalogService.catalog;
        final folder = catalog == null ? null : _resolveFolder(catalog);

        if (folder == null) {
          return Scaffold(
            appBar: TtsAppBar(title: folderName),
            body: _FolderMissingBody(folderName: folderName),
          );
        }

        final ancestors = catalog!.ancestorChainForFolder(folder.id);

        return Scaffold(
          appBar: TtsAppBar(
            title: folder.name,
            extraActions: [_FolderActionsMenu(folder: folder)],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FolderBreadcrumb(
                ancestors: ancestors,
                currentFolderId: folder.id,
                onAncestorSelected: (target) => navigateBreadcrumbSelection(
                  context,
                  target: target,
                  currentFolderId: folder.id,
                ),
              ),
              Expanded(
                child: folder.isEmpty
                    ? const EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'This folder is empty.',
                        subtitle: 'Run a rescan if you expect content here.',
                      )
                    : _FolderContent(folder: folder),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown when a folder is no longer in the catalogue after a rescan.
class _FolderMissingBody extends StatelessWidget {
  final String folderName;

  const _FolderMissingBody({required this.folderName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined,
                size: AppIcons.hero, color: AppColors.textLow),
            const SizedBox(height: AppSpacing.base),
            Text(
              '“$folderName” is no longer in the catalogue.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'It may have been removed or renamed during the last scan.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.home_outlined, size: AppIcons.md),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderActionsMenu extends StatelessWidget {
  final MediaFolder folder;

  const _FolderActionsMenu({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryMetadataRepository>(
      builder: (context, repository, _) {
        final favourited = repository.isFolderFavourited(folder.id);
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Folder actions',
          onSelected: (value) {
            if (value == 'favourite') {
              repository.toggleFolderFavourite(folder.id);
            } else if (value == 'rescan') {
              _startLibraryScan(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'favourite',
              child: Row(
                children: [
                  Icon(
                    favourited ? Icons.star : Icons.star_border,
                    size: AppIcons.md,
                    color: favourited ? AppColors.primary : AppColors.textHigh,
                  ),
                  const SizedBox(width: AppSpacing.iconGap),
                  Expanded(
                    child: Text(
                      favourited
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      style: const TextStyle(color: AppColors.textHigh),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'rescan',
              child: Row(
                children: [
                  Icon(Icons.refresh_outlined,
                      size: AppIcons.md, color: AppColors.textHigh),
                  SizedBox(width: AppSpacing.iconGap),
                  Expanded(
                    child: Text(
                      'Rescan this folder',
                      style: TextStyle(color: AppColors.textHigh),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _startLibraryScan(BuildContext context) {
    final catalogService = context.read<CatalogService>();
    final scannerService = context.read<ScannerService>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: scannerService,
        child: const ScanProgressDialog(),
      ),
    );

    scannerService.runLibraryScan(folder.path, catalogService);
  }
}

class _FolderContent extends StatelessWidget {
  final MediaFolder folder;

  const _FolderContent({required this.folder});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (folder.subfolders.isNotEmpty) ...[
          const _SectionSliver(title: 'Subfolders'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sub = folder.subfolders[index];
                  return TtsFolderCard(
                    folder: sub,
                    topLeftOverlay: FavouriteFolderToggle(
                      folderId: sub.id,
                      compact: true,
                    ),
                    onTap: () => openFolderScreen(context, sub),
                  );
                },
                childCount: folder.subfolders.length,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: AppSpacing.gridSubfolder,
                mainAxisSpacing: AppSpacing.gridGap,
                crossAxisSpacing: AppSpacing.gridGap,
                childAspectRatio: AppSpacing.gridAspectLibrary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.section)),
        ],
        if (folder.items.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.section),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = folder.items[index];
                  return TtsMediaCard(
                    item: item,
                    parentFolder: folder,
                    topLeftOverlay: FavouriteItemToggle(
                      itemId: item.id,
                      compact: true,
                    ),
                    onTap: () => _openDetail(context, item),
                  );
                },
                childCount: folder.items.length,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: AppSpacing.gridMedia,
                mainAxisSpacing: AppSpacing.gridGap,
                crossAxisSpacing: AppSpacing.gridGap,
                childAspectRatio: AppSpacing.gridAspectMedia,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openDetail(BuildContext context, MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
    );
  }
}

class _SectionSliver extends StatelessWidget {
  final String title;

  const _SectionSliver({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: AppTypography.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}
