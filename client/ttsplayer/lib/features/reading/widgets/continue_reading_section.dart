import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/artwork/resolved_media_artwork_image.dart';
import '../../../widgets/card_layout.dart';
import '../../../widgets/horizontal_carousel_nav_buttons.dart';
import '../../../widgets/section_header.dart';
import '../reading_navigation.dart';
import '../services/continue_reading_projection.dart';

/// Horizontal Continue Reading carousel for the dashboard (M6.5).
class ContinueReadingSection extends StatefulWidget {
  const ContinueReadingSection({
    super.key,
    required this.entries,
  });

  final List<ContinueReadingEntry> entries;

  @override
  State<ContinueReadingSection> createState() => _ContinueReadingSectionState();
}

class _ContinueReadingSectionState extends State<ContinueReadingSection> {
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
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    return Semantics(
      header: true,
      container: true,
      label: 'Continue Reading',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            key: const Key('continue_reading_section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Continue Reading',
                trailing: HorizontalCarouselNavButtons(
                  controller: _scrollController,
                  sectionLabel: 'Continue Reading',
                  semanticsId: 'continue_reading',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ContinueReadingCarousel(
                entries: widget.entries,
                scrollController: _scrollController,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContinueReadingCarousel extends StatelessWidget {
  const _ContinueReadingCarousel({
    required this.entries,
    required this.scrollController,
  });

  final List<ContinueReadingEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CardLayout.continueWatchingListHeight,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: ListView.separated(
          key: const Key('continue_reading_carousel'),
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
            final entry = entries[index];
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
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          ResolvedMediaArtworkImage(
                        item: item,
                        fit: BoxFit.contain,
                        borderRadius: AppRadius.cardRadius,
                        iconSize: AppIcons.lg,
                        logicalDecodeSize: constraints.biggest,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        item.isBook
                            ? Icons.menu_book_outlined
                            : Icons.image_outlined,
                        size: 18,
                        color: AppColors.textMedium,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          kindLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: AppTypography.size12,
                          ),
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
                  const SizedBox(height: AppSpacing.sm),
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
