import 'package:flutter/material.dart';

import '../../../models/media_folder.dart';
import '../../../navigation/folder_navigation.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/horizontal_carousel_nav_buttons.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_folder_card.dart';

class FeaturedFoldersSection extends StatefulWidget {
  final List<MediaFolder> folders;

  const FeaturedFoldersSection({super.key, required this.folders});

  @override
  State<FeaturedFoldersSection> createState() => _FeaturedFoldersSectionState();
}

class _FeaturedFoldersSectionState extends State<FeaturedFoldersSection> {
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
  void didUpdateWidget(FeaturedFoldersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels > position.maxScrollExtent) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final folders = widget.folders;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Featured Folders',
              trailing: folders.isEmpty
                  ? null
                  : HorizontalCarouselNavButtons(
                      controller: _scrollController,
                      sectionLabel: 'Featured Folders',
                      semanticsId: 'featured_folders',
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.folder_special_outlined,
                  title: 'No featured folders yet.',
                  subtitle:
                      'Browse your libraries — folders with content will appear here after a rescan.',
                ),
              )
            else
              _FeaturedFoldersCarousel(
                folders: folders,
                scrollController: _scrollController,
              ),
          ],
        );
      },
    );
  }
}

class _FeaturedFoldersCarousel extends StatelessWidget {
  const _FeaturedFoldersCarousel({
    required this.folders,
    required this.scrollController,
  });

  final List<MediaFolder> folders;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CardLayout.featuredFolderListHeight,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: CardLayout.featuredFolderScrollbarGutter,
          ),
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: folders.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final folder = folders[index];
            return Semantics(
              button: true,
              label:
                  'Featured folder: ${folder.name}, ${folder.totalItems} items',
              child: SizedBox(
                width: CardLayout.featuredFolderCardWidth,
                height: CardLayout.featuredFolderCardHeight,
                child: TtsFolderCard(
                  folder: folder,
                  onTap: () => openFolderScreen(context, folder),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
