/// TTSPlayer design-system barrel.
///
/// Import this single file from every screen and widget:
///
///   import '../theme/app_theme.dart';
///
/// All token files are re-exported so callers never need to import
/// individual token files directly.
library app_theme;

export 'app_animations.dart';
export 'app_card_styles.dart';
export 'app_colors.dart';
export 'app_durations.dart';
export 'app_icons.dart';
export 'app_radius.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

/// Builds the single [ThemeData] for the application.
///
/// Used in [MaterialApp.theme].  All colour and shape values reference design
/// tokens so a single change propagates everywhere.
abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: AppColors.card,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,

        // AppBar — centred title, no elevation, consistent background
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Cards — premium radius, no elevation (we draw our own shadows via borders)
        cardTheme: const CardThemeData(
          color: AppColors.card,
          shape: AppRadius.cardShape,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),

        // Dialogs — consistent with card radius
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.card,
          shape: AppRadius.dialogShape,
        ),

        // Dividers
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // Scrollbars — visible on desktop, thin and unobtrusive
        scrollbarTheme: const ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(AppColors.textLow),
          trackColor: WidgetStatePropertyAll(AppColors.divider),
          radius: Radius.circular(4),
          thickness: WidgetStatePropertyAll(4),
          thumbVisibility: WidgetStatePropertyAll(true),
        ),

        // Filled buttons use primary colour by default
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            shape: AppRadius.buttonShape,
          ),
        ),

        // Text buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),

        // Keyboard focus ring — visible on desktop navigation
        focusColor: AppColors.primary.withAlpha(40),
        hoverColor: AppColors.cardHover,
      );
}
