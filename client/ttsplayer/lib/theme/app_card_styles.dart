import 'package:flutter/material.dart';

import 'app_animations.dart';
import 'app_colors.dart';
import 'app_durations.dart';
import 'app_radius.dart';

/// Shared card decoration and hover-state helpers.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppCardStyles {
  static Color backgroundColor({required bool hovered, required bool pressed}) {
    if (pressed) return AppColors.cardPressed;
    if (hovered) return AppColors.cardHover;
    return AppColors.card;
  }

  static Color borderColor({required bool hovered, required bool pressed}) {
    if (hovered || pressed) return AppColors.primary.withAlpha(50);
    return AppColors.border;
  }

  static BoxDecoration decoration({
    required bool hovered,
    required bool pressed,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: backgroundColor(hovered: hovered, pressed: pressed),
      borderRadius: borderRadius ?? AppRadius.cardRadius,
      border: Border.all(
        color: borderColor(hovered: hovered, pressed: pressed),
        width: 1,
      ),
    );
  }

  static Duration get hoverDuration => AppDurations.hover;

  static Duration get pressDuration => AppAnimations.fast;
}
