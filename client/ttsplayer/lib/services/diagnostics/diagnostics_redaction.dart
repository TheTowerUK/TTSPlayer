/// Central redaction utilities for diagnostics DTOs and export (ADR-018).
library;

final RegExp _windowsDrivePath = RegExp(
  r'[A-Za-z]:\\[^\s]*',
  caseSensitive: false,
);

final RegExp _uncPath = RegExp(
  r'\\\\[^\s\\]+(?:\\[^\s]*)*',
  caseSensitive: false,
);

final RegExp _unixAbsolutePath = RegExp(
  r'/(?:volume\d+|mnt|media|home|users|var)[^\s]*',
  caseSensitive: false,
);

final RegExp _fileUri = RegExp(
  r'file://[^\s]*',
  caseSensitive: false,
);

final RegExp _httpUrl = RegExp(
  r'https?://[^\s]*',
  caseSensitive: false,
);

final RegExp _credentialInUrl = RegExp(
  r'https?://[^/\s:@]+:[^/\s@]+@',
  caseSensitive: false,
);

final RegExp _stackTraceLine = RegExp(
  r'^\s*#?\d*\s+.*\.dart:\d+',
  multiLine: true,
);

/// Truncates catalogue/search identity for display. Catalogue ids are normally
/// scanner-generated timestamps + hex (safe as-is); truncation is defence in depth.
String redactIdentity(String? identity, {int maxLength = 12}) {
  if (identity == null || identity.isEmpty) {
    return '';
  }
  if (identity.length <= maxLength) {
    return identity;
  }
  return '${identity.substring(0, maxLength)}…';
}

/// Maps a configured catalogue provider kind to a safe category label.
String providerKindLabel(String? kindName) {
  switch (kindName) {
    case 'localFile':
      return 'Local file';
    case 'http':
      return 'HTTPS';
    default:
      return 'Unavailable';
  }
}

/// Strips paths, URLs, credentials, and stack-trace fragments from free text.
String redactSensitiveText(String? text) {
  if (text == null || text.isEmpty) {
    return '';
  }
  var result = text;
  result = result.replaceAll(_credentialInUrl, '[redacted-url]');
  result = result.replaceAll(_fileUri, '[redacted-path]');
  result = result.replaceAll(_httpUrl, '[redacted-url]');
  result = result.replaceAll(_windowsDrivePath, '[redacted-path]');
  result = result.replaceAll(_uncPath, '[redacted-path]');
  result = result.replaceAll(_unixAbsolutePath, '[redacted-path]');
  result = result.replaceAll(_stackTraceLine, '[redacted-stack]');
  return result.trim();
}

/// Returns true when [text] still contains sensitive patterns after redaction.
bool containsSensitivePatterns(String text) {
  if (text.isEmpty) {
    return false;
  }
  return _windowsDrivePath.hasMatch(text) ||
      _uncPath.hasMatch(text) ||
      _unixAbsolutePath.hasMatch(text) ||
      _fileUri.hasMatch(text) ||
      _credentialInUrl.hasMatch(text) ||
      _httpUrl.hasMatch(text);
}
