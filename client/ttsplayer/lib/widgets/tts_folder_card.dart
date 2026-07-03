import 'package:flutter/material.dart';

import '../models/media_folder.dart';
import '../theme/app_theme.dart';

/// Premium folder card with desktop hover and animated press effects.
///
/// Used on the [HomeScreen] for library-root folders and on [FolderScreen]
/// for subfolders.  The card uses a [MouseRegion] for cursor and hover state,
/// and a [GestureDetector] for the press scale animation.
class TtsFolderCard extends StatefulWidget {
  final MediaFolder folder;
  final VoidCallback onTap;

  const TtsFolderCard({
    super.key,
    required this.folder,
    required this.onTap,
  });

  @override
  State<TtsFolderCard> createState() => _TtsFolderCardState();
}

class _TtsFolderCardState extends State<TtsFolderCard> {
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

  Color get _iconColor {
    if (_hovered || _pressed) return AppColors.primary;
    return AppColors.textLow;
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
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? AppAnimations.pressScale : 1.0,
          duration: AppAnimations.fast,
          curve: AppAnimations.enter,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppAnimations.standard,
                  curve: AppAnimations.smooth,
                  child: Icon(
                    Icons.folder_outlined,
                    size: AppIcons.folder,
                    color: _iconColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.folder.name,
                  style: AppTypography.cardTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(label, style: AppTypography.cardSubtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
