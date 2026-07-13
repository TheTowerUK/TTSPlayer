/// Media extensions indexed by the Python scanner.
///
/// Keep in sync with [SUPPORTED_EXTENSIONS] in backend/indexer.py.
/// Used as a fallback when catalog.json predates the supported_extensions field.
abstract final class SupportedExtensions {
  /// Video extensions (indexer [_VIDEO_EXTENSIONS]).
  static const Set<String> video = {
    'avi',
    'm4v',
    'mkv',
    'mov',
    'mp4',
  };

  /// Image extensions (indexer [_IMAGE_EXTENSIONS]).
  static const Set<String> image = {
    'bmp',
    'gif',
    'jpeg',
    'jpg',
    'png',
    'tif',
    'tiff',
    'webp',
  };

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

  /// Effective video set for browse filter/sort — static set ∩ [catalogSupported].
  ///
  /// When [catalogSupported] is null or empty, returns the full static video set.
  static Set<String> effectiveVideoSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(video, catalogSupported);
  }

  /// Effective image set for browse filter/sort — static set ∩ [catalogSupported].
  static Set<String> effectiveImageSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(image, catalogSupported);
  }

  static Set<String> _effectiveSet(
    Set<String> staticSet,
    Iterable<String>? catalogSupported,
  ) {
    if (catalogSupported == null) return staticSet;
    final normalized = catalogSupported.map((e) => e.toLowerCase()).toSet();
    if (normalized.isEmpty) return staticSet;
    return staticSet.intersection(normalized);
  }

  /// Extension category for folder-browse type sort/filter (ADR-008).
  static MediaExtensionCategory categoryFor(
    String extension, {
    Iterable<String>? catalogSupported,
  }) {
    final ext = extension.toLowerCase();
    if (effectiveVideoSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.video;
    }
    if (effectiveImageSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.image;
    }
    return MediaExtensionCategory.other;
  }
}

/// Primary extension grouping for library browse type sort (ADR-008).
enum MediaExtensionCategory {
  video,
  image,
  other,
}
