import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/section_header.dart';
import '../reading_navigation.dart';
import '../services/continue_reading_projection.dart';

/// Horizontal Continue Reading carousel for the dashboard (M6.5).
class ContinueReadingSection extends StatelessWidget {
  const ContinueReadingSection({
    super.key,
    required this.entries,
  });

  final List<ContinueReadingEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Semantics(
      header: true,
      container: true,
      label: 'Continue Reading',
      child: Column(
        key: const Key('continue_reading_section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Continue Reading'),
          const SizedBox(height: AppSpacing.md),
          _ContinueReadingCarousel(entries: entries),
        ],
      ),
    );
  }
}

class _ContinueReadingCarousel extends StatefulWidget {
  const _ContinueReadingCarousel({required this.entries});

  final List<ContinueReadingEntry> entries;

  @override
  State<_ContinueReadingCarousel> createState() =>
      _ContinueReadingCarouselState();
}

class _ContinueReadingCarouselState extends State<_ContinueReadingCarousel> {
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
          key: const Key('continue_reading_carousel'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: widget.entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final entry = widget.entries[index];
            return _ContinueReadingCard(entry: entry);
          },
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.entry});

  final ContinueReadingEntry entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final label = entry.isPlayable
        ? entry.locationLabel
        : (entry.unavailabilityReason ?? 'Unavailable');
    final kindLabel = item.isBook ? 'Book' : 'Comic';

    return Semantics(
      button: entry.isPlayable,
      label:
          '${item.title}. $kindLabel. ${entry.progressPercent}% read. $label',
      child: SizedBox(
        width: AppSpacing.continueWatchingCardWidth,
        child: Material(
          color: AppColors.surface,
          shape: AppRadius.cardShape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('continue_reading_card_${item.id}'),
            onTap: entry.isPlayable
                ? () {
                    // ignore: discarded_futures
                    openReadingItem(context, item: item);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.isBook ? Icons.menu_book_outlined : Icons.image_outlined,
                        size: 18,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        kindLabel,
                        style: const TextStyle(
                          color: AppColors.textMedium,
                          fontSize: AppTypography.size12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: AppTypography.size14,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: '${entry.progressPercent} percent read',
                    value: '${entry.progressPercent}%',
                    child: LinearProgressIndicator(
                      value: entry.progressPercent / 100,
                      backgroundColor: Colors.white12,
                      color: AppColors.primary,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.isPlayable
                          ? AppColors.textLow
                          : AppColors.textMedium,
                      fontSize: AppTypography.size12,
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
