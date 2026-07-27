/// Media extensions indexed by the Python scanner.
///
/// Keep in sync with [SUPPORTED_EXTENSIONS] in backend/indexer.py.
abstract final class SupportedExtensions {
  static const Set<String> video = {
    'avi',
    'm4v',
    'mkv',
    'mov',
    'mp4',
  };

  static const Set<String> audio = {
    'aac',
    'flac',
    'm4a',
    'mp3',
    'ogg',
    'opus',
    'wav',
    'wma',
  };

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

  static const Set<String> book = {
    'epub',
    'pdf',
  };

  static const Set<String> comic = {
    'cbz',
  };

  static const List<String> all = [
    'aac',
    'avi',
    'bmp',
    'cbz',
    'epub',
    'flac',
    'gif',
    'jpeg',
    'jpg',
    'm4a',
    'm4v',
    'mkv',
    'mov',
    'mp3',
    'mp4',
    'ogg',
    'opus',
    'pdf',
    'png',
    'tif',
    'tiff',
    'wav',
    'webp',
    'wma',
  ];

  static String get displayLabel => all.join(', ');

  static Set<String> effectiveVideoSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(video, catalogSupported);
  }

  static Set<String> effectiveAudioSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(audio, catalogSupported);
  }

  static Set<String> effectiveImageSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(image, catalogSupported);
  }

  static Set<String> effectiveBookSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(book, catalogSupported);
  }

  static Set<String> effectiveComicSet({Iterable<String>? catalogSupported}) {
    return _effectiveSet(comic, catalogSupported);
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

  static MediaExtensionCategory categoryFor(
    String extension, {
    Iterable<String>? catalogSupported,
  }) {
    final ext = extension.toLowerCase();
    if (effectiveVideoSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.video;
    }
    if (effectiveAudioSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.audio;
    }
    if (effectiveImageSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.image;
    }
    if (effectiveBookSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.book;
    }
    if (effectiveComicSet(catalogSupported: catalogSupported).contains(ext)) {
      return MediaExtensionCategory.comic;
    }
    return MediaExtensionCategory.other;
  }
}

enum MediaExtensionCategory {
  video,
  audio,
  image,
  book,
  comic,
  other,
}
