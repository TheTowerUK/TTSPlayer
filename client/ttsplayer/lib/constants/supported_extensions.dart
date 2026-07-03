/// Video extensions indexed by the Python scanner.
///
/// Keep in sync with [SUPPORTED_EXTENSIONS] in backend/indexer.py.
/// Used as a fallback when catalog.json predates the supported_extensions field.
abstract final class SupportedExtensions {
  static const List<String> all = [
    'avi',
    'm4v',
    'mkv',
    'mov',
    'mp4',
  ];

  /// Comma-separated list for UI, e.g. "avi, m4v, mkv, mov, mp4".
  static String get displayLabel => all.join(', ');
}
