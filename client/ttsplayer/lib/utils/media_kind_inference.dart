import '../constants/supported_extensions.dart';
import '../models/media_kind.dart';

/// Infer [MediaKind] for legacy catalogues without `media_kind`.
MediaKind inferMediaKind({
  required String filePath,
  String? rawKind,
}) {
  final parsed = MediaKind.fromString(rawKind);
  if (parsed != MediaKind.unknown) {
    return parsed;
  }
  if (rawKind != null && rawKind.isNotEmpty) {
    return MediaKind.unknown;
  }

  final ext = filePath.split('.').last.toLowerCase();
  if (SupportedExtensions.video.contains(ext)) {
    return MediaKind.video;
  }
  if (SupportedExtensions.audio.contains(ext)) {
    return MediaKind.audio;
  }
  if (SupportedExtensions.image.contains(ext)) {
    return MediaKind.image;
  }
  if (SupportedExtensions.book.contains(ext)) {
    return MediaKind.book;
  }
  if (SupportedExtensions.comic.contains(ext)) {
    return MediaKind.comic;
  }
  return MediaKind.unknown;
}

/// Normalise a grouping key the same way as the Python scanner.
String normalizeGroupKey(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
