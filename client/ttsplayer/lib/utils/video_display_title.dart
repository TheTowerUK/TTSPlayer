import '../models/media_item.dart';

/// Presentation-only video title cleanup (filename release tags).
///
/// Does not mutate catalogue titles, paths, or IDs. Unknown or ambiguous
/// tokens are kept.
abstract final class VideoDisplayTitle {
  static const int _minReleaseYear = 1888;

  static const Set<String> _technicalTokens = {
    '240p',
    '360p',
    '480p',
    '576p',
    '720p',
    '720i',
    '1080p',
    '1080i',
    '1440p',
    '2160p',
    '4320p',
    '4k',
    '8k',
    'uhd',
    'bluray',
    'blu-ray',
    'bdrip',
    'brrip',
    'webrip',
    'web-dl',
    'webdl',
    'hdtv',
    'dvdrip',
    'hdrip',
    'remux',
    'bdremux',
    'x264',
    'x265',
    'h264',
    'h265',
    'hevc',
    'avc',
    'av1',
    'xvid',
    'aac',
    'dts',
    'ac3',
    'eac3',
    'truehd',
    'atmos',
    'flac',
    'hdr',
    'hdr10',
    'hdr10+',
    'dv',
    'dovi',
    '10bit',
    '10-bit',
  };

  /// Formats [item.title] for video cards; other kinds are unchanged.
  static String forItem(MediaItem item, {int? nowYear}) {
    if (!item.isVideo) return item.title;
    return format(item.title, nowYear: nowYear);
  }

  /// Cleans a filename-derived video title for display.
  static String format(String raw, {int? nowYear}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;

    final maxYear = (nowYear ?? DateTime.now().year) + 1;
    final tokens = trimmed
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();

    while (tokens.isNotEmpty && _isRemovableSuffix(tokens.last)) {
      tokens.removeLast();
    }

    if (tokens.isEmpty) {
      return trimmed
          .replaceAll(RegExp(r'[._]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final display = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (i > 0 && _isReleaseYear(token, maxYear: maxYear)) {
        display.add('($token)');
      } else {
        display.add(token);
      }
    }
    return display.join(' ');
  }

  static bool _isRemovableSuffix(String token) {
    if (token == '-' || token == '–' || token == '—') return true;
    final normalized = _normalizeToken(token);
    if (normalized.isEmpty) return true;
    if (_technicalTokens.contains(normalized)) return true;
    if (normalized.contains('-')) {
      final parts = normalized.split('-').where((part) => part.isNotEmpty);
      if (parts.isNotEmpty && parts.every(_technicalTokens.contains)) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeToken(String token) {
    return token
        .toLowerCase()
        .replaceAll(RegExp(r'^[\[\(\{]+'), '')
        .replaceAll(RegExp(r'[\]\)\}]+$'), '');
  }

  static bool _isReleaseYear(String token, {required int maxYear}) {
    if (!RegExp(r'^\d{4}$').hasMatch(token)) return false;
    final year = int.parse(token);
    return year >= _minReleaseYear && year <= maxYear;
  }
}
