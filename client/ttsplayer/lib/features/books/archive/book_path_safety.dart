/// Path safety helpers for EPUB ZIP entries and book file labels.
library;

bool bookIsUnsafeArchiveEntry(String name) {
  if (name.isEmpty) return true;
  final normalized = name.replaceAll('\\', '/');
  if (normalized.startsWith('/')) return true;
  if (RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) return true;
  for (final part in normalized.split('/')) {
    if (part == '..') return true;
  }
  return false;
}

String bookBasename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final i = normalized.lastIndexOf('/');
  return i < 0 ? normalized : normalized.substring(i + 1);
}

String bookExtension(String path) {
  final base = bookBasename(path);
  final dot = base.lastIndexOf('.');
  if (dot < 0) return '';
  return base.substring(dot + 1).toLowerCase();
}
