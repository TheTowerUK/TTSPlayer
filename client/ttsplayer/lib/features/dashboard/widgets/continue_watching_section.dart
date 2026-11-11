import 'package:flutter/material.dart';

import '../../../screens/player_screen.dart';
import '../../../services/playback_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/video_display_title.dart';
import '../../../widgets/artwork/resolved_media_artwork_image.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/horizontal_carousel_nav_buttons.dart';
import '../../../widgets/section_header.dart';

class ContinueWatchingSection extends StatefulWidget {
  final List<ContinueWatchingEntry> entries;

  const ContinueWatchingSection({super.key, required this.entries});

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
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
    final entries = widget.entries;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Continue Watching',
              trailing: entries.isEmpty
                  ? null
                  : HorizontalCarouselNavButtons(
                      controller: _scrollController,
                      sectionLabel: 'Continue Watching',
                      semanticsId: 'continue_watching',
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: EmptyState(
                  icon: Icons.play_circle_outline,
                  title: 'Nothing in progress.',
                  subtitle: 'Items you start watching will appear here.',
                ),
              )
            else
              _ContinueWatchingCarousel(
                entries: entries,
                scrollController: _scrollController,
              ),
          ],
        );
      },
    );
  }
}

class _ContinueWatchingCarousel extends StatelessWidget {
  final List<ContinueWatchingEntry> entries;
  final ScrollController scrollController;

  const _ContinueWatchingCarousel({
    required this.entries,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CardLayout.continueWatchingVideoCardHeight +
          CardLayout.continueWatchingScrollbarGutter,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: CardLayout.continueWatchingScrollbarGutter,
          ),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            return _ContinueWatchingCard(entry: entries[index]);
          },
        ),
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final ContinueWatchingEntry entry;

  const _ContinueWatchingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final progress = entry.progressFraction;

    void resume() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(item: entry.item)),
      );
    }

    return SizedBox(
      width: CardLayout.continueWatchingCardWidth,
      height: CardLayout.continueWatchingVideoCardHeight,
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.heroRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.heroRadius,
          onTap: resume,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.heroRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: CardLayout.continueWatchingArtworkWidth,
                  height: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        ResolvedMediaArtworkImage(
                      item: entry.item,
                      fit: BoxFit.contain,
                      borderRadius: AppRadius.heroRadius,
                      iconSize: AppIcons.lg,
                      logicalDecodeSize: constraints.biggest,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          VideoDisplayTitle.forItem(entry.item),
                          style: AppTypography.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FilledButton.icon(
                        onPressed: resume,
                        icon: const Icon(Icons.play_arrow, size: AppIcons.lg),
                        label: const Text('Resume'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (progress != null)
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: AppColors.progressTrack,
                          color: AppColors.primary,
                        ),
                      Text(
                        entry.resume.formattedPosition,
                        style: AppTypography.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
