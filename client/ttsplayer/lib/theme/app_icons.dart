/// Icon size constants for TTSPlayer.
///
/// Import via the barrel: `import '../theme/app_theme.dart';`
abstract final class AppIcons {
  // ---------------------------------------------------------------------------
  // Size scale
  // ---------------------------------------------------------------------------

  /// Inline icon in a dense row (warning indicator, etc.) — 13 px.
  static const double xs = 13;

  /// Banner close / dismiss icon — 16 px.
  static const double sm = 16;

  /// Banner status icon, menu item icon — 18 px.
  static const double md = 18;

  /// Dialog header icon — 20 px.
  static const double lg = 20;

  /// Material default icon size — 24 px.
  static const double standard = 24;

  /// Play / action button icon — 26 px.
  static const double playButton = 26;

  /// Subfolder card icon — 36 px.
  static const double folder = 36;

  /// Root folder card icon / media-card placeholder — 48 px.
  static const double folderLarge = 48;

  /// Hero icon for error / completed player state — 52 px.
  static const double hero = 52;

  /// Play / pause `IconButton.iconSize` in player controls — 44 px.
  static const double playerControl = 44;
}
