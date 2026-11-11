import 'package:flutter/material.dart';

import '../../../navigation/media_item_navigation.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/horizontal_carousel_nav_buttons.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/tts_media_card.dart';
import '../dashboard_service.dart';

class RecentlyAddedSection extends StatefulWidget {
  final List<RecentlyAddedEntry> entries;

  const RecentlyAddedSection({super.key, required this.entries});

  @override
  State<RecentlyAddedSection> createState() => _RecentlyAddedSectionState();
}

class _RecentlyAddedSectionState extends State<RecentlyAddedSection> {
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
  void didUpdateWidget(RecentlyAddedSection oldWidget) {
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
    final entries = widget.entries;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Recently Added',
              trailing: entries.isEmpty
                  ? null
                  : HorizontalCarouselNavButtons(
                      controller: _scrollController,
                      sectionLabel: 'Recently Added',
                      semanticsId: 'recently_added',
                    ),
            ),
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
              _RecentlyAddedCarousel(
                entries: entries,
                scrollController: _scrollController,
              ),
          ],
        );
      },
    );
  }
}

class _RecentlyAddedCarousel extends StatelessWidget {
  const _RecentlyAddedCarousel({
    required this.entries,
    required this.scrollController,
  });

  final List<RecentlyAddedEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CardLayout.recentlyAddedListHeight,
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
            bottom: CardLayout.recentlyAddedScrollbarGutter,
          ),
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final entry = entries[index];
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
