/// Supported validated image MIME types for provider artwork (M7.4.3).
class MetadataArtworkMimeTypes {
  const MetadataArtworkMimeTypes._();

  static const jpeg = 'image/jpeg';
  static const png = 'image/png';
  static const webp = 'image/webp';
  static const gif = 'image/gif';

  static const supported = {jpeg, png, webp, gif};

  static String? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.split(';').first.trim().toLowerCase();
    return supported.contains(value) ? value : null;
  }

  static String extensionForMime(String mime) {
    switch (mime) {
      case jpeg:
        return '.jpg';
      case png:
        return '.png';
      case webp:
        return '.webp';
      case gif:
        return '.gif';
      default:
        throw ArgumentError('Unsupported artwork MIME: $mime');
    }
  }
}
