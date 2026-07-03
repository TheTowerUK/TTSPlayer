import 'package:flutter/material.dart';

import '../models/media_folder.dart';
import '../theme/app_theme.dart';

/// Reusable library card — icon, name, item count, and Browse action.
class LibraryCard extends StatefulWidget {
  final MediaFolder folder;
  final VoidCallback onBrowse;

  const LibraryCard({
    super.key,
    required this.folder,
    required this.onBrowse,
  });

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _bgColor {
    if (_pressed) return AppColors.cardPressed;
    if (_hovered) return AppColors.cardHover;
    return AppColors.card;
  }

  Color get _borderColor {
    if (_hovered || _pressed) {
      return AppColors.primary.withAlpha(50);
    }
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.folder.totalItems;
    final label = '$count item${count == 1 ? '' : 's'}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedContainer(
        duration: AppAnimations.standard,
        curve: AppAnimations.smooth,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: _borderColor, width: 1),
        ),
        padding: AppSpacing.cardPremium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.chip,
                borderRadius: AppRadius.chipRadius,
              ),
              child: Icon(
                Icons.folder_outlined,
                size: AppIcons.lg,
                color: _hovered ? AppColors.primary : AppColors.textLow,
              ),
            ),
            const Spacer(),
            Text(
              widget.folder.name,
              style: AppTypography.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTypography.cardSubtitle),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onBrowse,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: AppSpacing.buttonSm,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Browse'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
