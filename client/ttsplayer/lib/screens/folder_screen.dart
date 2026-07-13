import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library/library_folder_view.dart';
import '../models/catalog.dart';
import '../models/library_filter.dart';
import '../models/library_sort_mode.dart';
import '../models/media_folder.dart';
import '../models/media_item.dart';
import '../navigation/folder_navigation.dart';
import '../services/catalog_service.dart';
import '../services/library/library_metadata_repository.dart';
import '../services/scanner_service.dart';
import '../services/settings/settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/favourite_toggle_button.dart';
import '../widgets/folder_breadcrumb.dart';
import '../widgets/folder_browse_controls.dart';
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
          body: _FolderBrowseBody(
            folder: folder,
            ancestors: ancestors,
            catalogSupportedExtensions: catalog.supportedExtensions,
          ),
        );
      },
    );
  }
}

/// Session-scoped sort/filter state for one [FolderScreen] route (ADR-008).
///
/// New routes initialize sort from [SettingsRepository.defaultLibrarySortMode]
/// and filter to [LibraryFilter.all]. Back navigation preserves mounted route
/// state; subfolder pushes start fresh.
class _FolderBrowseBody extends StatefulWidget {
  final MediaFolder folder;
  final List<MediaFolder> ancestors;
  final Iterable<String> catalogSupportedExtensions;

  const _FolderBrowseBody({
    required this.folder,
    required this.ancestors,
    required this.catalogSupportedExtensions,
  });

  @override
  State<_FolderBrowseBody> createState() => _FolderBrowseBodyState();
}

class _FolderBrowseBodyState extends State<_FolderBrowseBody> {
  late LibrarySortMode _sortMode;
  LibraryFilter _filter = LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _sortMode = context.read<SettingsRepository>().defaultLibrarySortMode;
  }

  LibraryFolderView _buildView() {
    return buildLibraryFolderView(
      folder: widget.folder,
      sortMode: _sortMode,
      filter: _filter,
      catalogSupportedExtensions: widget.catalogSupportedExtensions,
    );
  }

  Future<void> _setAsDefaultSort() async {
    final settings = context.read<SettingsRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await settings.saveDefaultLibrarySortMode(_sortMode);

    if (!mounted) return;

    if (result.success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Default sort order saved.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.validationErrors.isNotEmpty
                ? result.validationErrors.first
                : 'Could not save default sort order.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _buildView();
    final trulyEmpty = widget.folder.isEmpty;
    final filterEmpty = !trulyEmpty && view.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FolderBreadcrumb(
          ancestors: widget.ancestors,
          currentFolderId: widget.folder.id,
          onAncestorSelected: (target) => navigateBreadcrumbSelection(
            context,
            target: target,
            currentFolderId: widget.folder.id,
          ),
        ),
        FolderBrowseControls(
          activeSortMode: _sortMode,
          activeFilter: _filter,
          persistedDefaultSort:
              context.watch<SettingsRepository>().defaultLibrarySortMode,
          onSortModeChanged: (mode) => setState(() => _sortMode = mode),
          onFilterChanged: (filter) => setState(() => _filter = filter),
          onSetAsDefault: _setAsDefaultSort,
        ),
        Expanded(
          child: trulyEmpty
              ? const EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'This folder is empty.',
                  subtitle: 'Run a rescan if you expect content here.',
                )
              : filterEmpty
                  ? _FilterEmptyBody(
                      onShowAll: () =>
                          setState(() => _filter = LibraryFilter.all),
                    )
                  : _FolderContent(
                      folder: widget.folder,
                      view: view,
                    ),
        ),
      ],
    );
  }
}

class _FilterEmptyBody extends StatelessWidget {
  final VoidCallback onShowAll;

  const _FilterEmptyBody({required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'No items match this filter',
      subtitle: 'Try another filter to see more content.',
      actionLabel: 'Show all',
      actionKey: const Key('folder_show_all_filter'),
      onAction: onShowAll,
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
  final LibraryFolderView view;

  const _FolderContent({
    required this.folder,
    required this.view,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (view.subfolders.isNotEmpty) ...[
          const _SectionSliver(title: 'Subfolders'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sub = view.subfolders[index];
                  return TtsFolderCard(
                    folder: sub,
                    topLeftOverlay: FavouriteFolderToggle(
                      folderId: sub.id,
                      compact: true,
                    ),
                    onTap: () => openFolderScreen(context, sub),
                  );
                },
                childCount: view.subfolders.length,
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
        if (view.items.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.section),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = view.items[index];
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
                childCount: view.items.length,
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
