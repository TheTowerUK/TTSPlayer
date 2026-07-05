/// Interaction and loading durations for TTSPlayer.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppDurations {
  /// Card hover colour shift — 100 ms.
  static const hover = Duration(milliseconds: 100);

  /// Fade in/out — 150–200 ms.
  static const fade = Duration(milliseconds: 180);

  /// Standard transition — progress, slide (200 ms).
  static const standard = Duration(milliseconds: 200);

  /// Skeleton pulse cycle.
  static const skeleton = Duration(milliseconds: 1200);
}
