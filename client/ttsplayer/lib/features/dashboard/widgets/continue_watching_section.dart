import 'package:flutter/material.dart';

import '../../../screens/player_screen.dart';
import '../../../services/playback_service.dart';
import '../../../theme/app_theme.dart';
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
  static const _cardHeight = 148.0;
  static const _scrollbarGutter = 12.0;

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
      height: _cardHeight + _scrollbarGutter,
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
    final progress = entry.progressFraction;

    return SizedBox(
      width: 260,
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(item: entry.item),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            padding: AppSpacing.cardPremium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.movie_outlined,
                        color: AppColors.textLow, size: AppIcons.lg),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        entry.item.title,
                        style: AppTypography.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: AppRadius.chipRadius,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: AppColors.chip,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Row(
                  children: [
                    Text(
                      entry.resume.formattedPosition,
                      style: AppTypography.cardSubtitle,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(item: entry.item),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: AppSpacing.buttonSm,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Resume'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
