import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/artwork/card_artwork_band.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/section_header.dart';
import '../music_listening_presentation.dart';
import '../music_navigation.dart';
import 'music_artwork_thumbnail.dart';

/// Horizontal Continue Listening carousel for [MusicScreen] (M5.4).
class ContinueListeningSection extends StatelessWidget {
  const ContinueListeningSection({
    super.key,
    required this.entries,
  });

  final List<MusicListeningListEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('music_continue_listening_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Continue Listening',
          trailing: TextButton(
            key: const Key('music_continue_listening_see_all'),
            onPressed: () => openMusicRecentlyPlayedScreen(context),
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ContinueListeningCarousel(entries: entries),
      ],
    );
  }
}

class _ContinueListeningCarousel extends StatefulWidget {
  const _ContinueListeningCarousel({required this.entries});

  final List<MusicListeningListEntry> entries;

  @override
  State<_ContinueListeningCarousel> createState() =>
      _ContinueListeningCarouselState();
}

class _ContinueListeningCarouselState
    extends State<_ContinueListeningCarousel> {
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
          key: const Key('music_continue_listening_carousel'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: widget.entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            return _ContinueListeningCard(entry: widget.entries[index]);
          },
        ),
      ),
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  const _ContinueListeningCard({required this.entry});

  final MusicListeningListEntry entry;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final track = entry.mediaItem!;
    final progress = listeningProgressFraction(record);

    return Semantics(
      button: true,
      label: 'Resume ${entry.displayTitle}',
      child: SizedBox(
        key: Key('music_continue_listening_card_${record.trackId}'),
        width: AppSpacing.continueWatchingCardWidth,
        height: CardLayout.continueWatchingCardHeight,
        child: Material(
          color: AppColors.card,
          borderRadius: AppRadius.heroRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: AppRadius.heroRadius,
            onTap: () => openMusicPlayerFromListeningRecord(
              context,
              record: record,
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
                        Center(
                          child: MusicArtworkThumbnail(
                            item: track,
                            size: AppSpacing.continueWatchingCardWidth - 32,
                          ),
                        ),
                        if (progress != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress,
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
                          entry.displayTitle,
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: AppTypography.size16,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          entry.displayArtist,
                          style: AppTypography.cardSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                listeningProgressLabel(record),
                                style: AppTypography.cardSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  openMusicPlayerFromListeningRecord(
                                context,
                                record: record,
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
      ),
    );
  }
}
