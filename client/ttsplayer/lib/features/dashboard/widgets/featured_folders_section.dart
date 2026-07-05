import 'package:flutter/material.dart';

import '../../../models/media_folder.dart';
import '../../../screens/folder_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_folder_card.dart';

class FeaturedFoldersSection extends StatelessWidget {
  final List<MediaFolder> folders;

  const FeaturedFoldersSection({super.key, required this.folders});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Featured Folders'),
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
          _FeaturedFoldersCarousel(folders: folders),
      ],
    );
  }
}

class _FeaturedFoldersCarousel extends StatefulWidget {
  final List<MediaFolder> folders;

  const _FeaturedFoldersCarousel({required this.folders});

  @override
  State<_FeaturedFoldersCarousel> createState() =>
      _FeaturedFoldersCarouselState();
}

class _FeaturedFoldersCarouselState extends State<_FeaturedFoldersCarousel> {
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
      height: CardLayout.featuredFolderListHeight,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: widget.folders.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final folder = widget.folders[index];
            return Semantics(
              button: true,
              label: 'Featured folder: ${folder.name}, ${folder.totalItems} items',
              child: SizedBox(
                width: CardLayout.featuredFolderCardWidth,
                height: CardLayout.featuredFolderCardHeight,
                child: TtsFolderCard(
                  folder: folder,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderScreen(
                        folderPath: folder.path,
                        folderName: folder.name,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
