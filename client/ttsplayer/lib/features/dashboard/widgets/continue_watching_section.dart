import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../screens/player_screen.dart';
import '../../../services/artwork/artwork_service.dart';
import '../../../services/playback_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/artwork/artwork_image.dart';
import '../../../widgets/artwork/card_artwork_band.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';

class ContinueWatchingSection extends StatelessWidget {
  final List<ContinueWatchingEntry> entries;

  const ContinueWatchingSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Continue Watching'),
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
          _ContinueWatchingCarousel(entries: entries),
      ],
    );
  }
}

class _ContinueWatchingCarousel extends StatefulWidget {
  final List<ContinueWatchingEntry> entries;

  const _ContinueWatchingCarousel({required this.entries});

  @override
  State<_ContinueWatchingCarousel> createState() =>
      _ContinueWatchingCarouselState();
}

class _ContinueWatchingCarouselState extends State<_ContinueWatchingCarousel> {
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
      height: CardLayout.continueWatchingListHeight,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: widget.entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            return _ContinueWatchingCard(entry: widget.entries[index]);
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
    final artworkService = context.read<ArtworkService>();
    final candidate = artworkService.forMediaItem(entry.item);
    final progress = entry.progressFraction;

    return SizedBox(
      width: AppSpacing.continueWatchingCardWidth,
      height: CardLayout.continueWatchingCardHeight,
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.heroRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.heroRadius,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(item: entry.item),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.heroRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return ArtworkImage(
                            candidate: candidate,
                            logicalDecodeSize: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                          );
                        },
                      ),
                      if (progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: AppColors.progressTrack,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: kHeroCardFooterPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.item.title,
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: AppTypography.size16,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.resume.formattedPosition,
                              style: AppTypography.cardSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(item: entry.item),
                              ),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_outlined,
                              size: AppIcons.lg,
                            ),
                            label: const Text('Resume'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: AppSpacing.buttonSm,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
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
