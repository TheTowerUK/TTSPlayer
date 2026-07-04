/// Media extensions indexed by the Python scanner.
///
/// Keep in sync with [SUPPORTED_EXTENSIONS] in backend/indexer.py.
/// Used as a fallback when catalog.json predates the supported_extensions field.
abstract final class SupportedExtensions {
  static const List<String> all = [
    'avi',
    'bmp',
    'gif',
    'jpeg',
    'jpg',
    'm4v',
    'mkv',
    'mov',
    'mp4',
    'png',
    'tif',
    'tiff',
    'webp',
  ];

  /// Comma-separated list for UI, e.g. "avi, bmp, gif, …".
  static String get displayLabel => all.join(', ');
}
