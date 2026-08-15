import 'package:flutter/material.dart';

import '../../../navigation/media_item_navigation.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_media_card.dart';
import '../dashboard_service.dart';

class RecentlyAddedSection extends StatelessWidget {
  final List<RecentlyAddedEntry> entries;

  const RecentlyAddedSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recently Added'),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: EmptyState(
              icon: Icons.new_releases_outlined,
              title: 'No recently added items yet.',
              subtitle:
                  'Rescan your libraries to record when new files are indexed.',
            ),
          )
        else
          _RecentlyAddedCarousel(entries: entries),
      ],
    );
  }
}

class _RecentlyAddedCarousel extends StatefulWidget {
  final List<RecentlyAddedEntry> entries;

  const _RecentlyAddedCarousel({required this.entries});

  @override
  State<_RecentlyAddedCarousel> createState() => _RecentlyAddedCarouselState();
}

class _RecentlyAddedCarouselState extends State<_RecentlyAddedCarousel> {
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
            return Semantics(
              button: true,
              label: 'Recently added: ${entry.item.title}',
              child: SizedBox(
                width: CardLayout.recentlyAddedCardWidth,
                height: CardLayout.recentlyAddedCardHeight,
                child: TtsMediaCard(
                  item: entry.item,
                  parentFolder: entry.parentFolder,
                  onTap: () => activateMediaItem(context, entry.item),
                  onDetails: () => openMediaItemDetails(context, entry.item),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
