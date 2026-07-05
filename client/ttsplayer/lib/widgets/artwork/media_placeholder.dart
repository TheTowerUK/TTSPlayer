import 'package:flutter/material.dart';

import '../../services/artwork/library_visual_kind.dart';
import '../../theme/app_theme.dart';

/// Styled local placeholder when no artwork file is available.
class MediaPlaceholder extends StatelessWidget {
  final LibraryVisualKind kind;
  final double? iconSize;
  final BorderRadius? borderRadius;

  const MediaPlaceholder({
    super.key,
    required this.kind,
    this.iconSize,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tint = kind.accentTint;
    final size = iconSize ?? AppIcons.folderLarge;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.chip,
            Color.alphaBlend(tint.withAlpha(28), AppColors.chip),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          kind.icon,
          size: size,
          color: Color.alphaBlend(tint.withAlpha(180), AppColors.textLow),
        ),
      ),
    );
  }
}
