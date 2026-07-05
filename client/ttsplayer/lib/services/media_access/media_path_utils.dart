/// Path normalisation and HTTP relative-path encoding for media access.
abstract final class MediaPathUtils {
  static bool isRemoteUrl(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static bool isUncPath(String path) => path.startsWith(r'\\');

  static bool isWindowsDrivePath(String path) {
    return path.length >= 3 &&
        path[1] == ':' &&
        (path[2] == r'\' || path[2] == '/');
  }

  /// Case-insensitive prefix match for media root stripping.
  static String normalizeForRootMatch(String path) {
    if (path.startsWith('//') && !path.startsWith(r'\\')) {
      return path.replaceAll('\\', '/').toLowerCase();
    }
    if (isUncPath(path) || isWindowsDrivePath(path)) {
      return path.replaceAll('/', r'\').toLowerCase();
    }
    return path.replaceAll('\\', '/').toLowerCase();
  }

  /// Strip the first matching [roots] prefix; returns POSIX relative path.
  static String? relativePathUnderRoots(String filePath, List<String> roots) {
    if (filePath.isEmpty) return null;

    final normalizedFile = normalizeForRootMatch(filePath);
    for (final root in roots) {
      if (root.isEmpty) continue;
      final normalizedRoot = normalizeForRootMatch(root);
      if (normalizedFile == normalizedRoot) return '';

      final separator = normalizedRoot.endsWith(r'\') || normalizedRoot.endsWith('/')
          ? ''
          : (normalizedRoot.contains(r'\') ? r'\' : '/');
      final prefix = '$normalizedRoot$separator';
      if (normalizedFile.startsWith(prefix)) {
        var remainder = filePath.substring(root.length);
        if (remainder.startsWith(r'\') || remainder.startsWith('/')) {
          remainder = remainder.substring(1);
        }
        return remainder.replaceAll(r'\', '/');
      }
    }
    return null;
  }

  /// URL-encode each path segment; preserve `/` separators.
  static String encodeRelativePathForUrl(String relativePath) {
    if (relativePath.isEmpty) return '';
    return relativePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
  }

  static String joinHttpBaseAndRelative(String baseUrl, String relativePath) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final encoded = encodeRelativePathForUrl(relativePath);
    return '$base$encoded';
  }
}
