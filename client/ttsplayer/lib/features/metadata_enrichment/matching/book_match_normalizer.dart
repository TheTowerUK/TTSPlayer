/// Comparison-only normalized forms for titles and authors (M7.3.1).
class NormalizedTitleForms {
  const NormalizedTitleForms({
    required this.full,
    required this.main,
    this.subtitle,
    this.articleStrippedFull,
    this.articleStrippedMain,
    this.volumeNumber,
    this.editionMarkers = const [],
    this.formatMarkers = const [],
    this.isOmnibus = false,
    this.isStudyGuide = false,
    this.isAbridged,
  });

  final String full;
  final String main;
  final String? subtitle;
  final String? articleStrippedFull;
  final String? articleStrippedMain;
  final int? volumeNumber;
  final List<String> editionMarkers;
  final List<String> formatMarkers;
  final bool isOmnibus;
  final bool isStudyGuide;
  final bool? isAbridged;
}

/// Comparison-only normalized author forms (M7.3.1).
class NormalizedAuthorForms {
  const NormalizedAuthorForms({
    required this.displayOrder,
    required this.primary,
    required this.allExactKeys,
    required this.allSurnameKeys,
    required this.allInitialKeys,
  });

  final List<String> displayOrder;
  final String primary;
  final List<String> allExactKeys;
  final List<String> allSurnameKeys;
  final List<String> allInitialKeys;
}

/// Deterministic comparison normalization for book metadata (M7.3.1).
///
/// Display values are never mutated. Unicode NFC is approximated using
/// deterministic Latin diacritic folding — see [foldDiacritics].
class BookMatchNormalizer {
  BookMatchNormalizer._();

  static const _leadingArticles = {'the', 'a', 'an'};

  static const _formatPhrases = {
    'paperback',
    'hardback',
    'hardcover',
    'kindle edition',
    'ebook',
    'audiobook',
    'large print',
    'illustrated edition',
  };

  static const _editionPhrases = {
    'second edition',
    '2nd edition',
    'third edition',
    '3rd edition',
    'revised edition',
    'anniversary edition',
    'international edition',
    'student edition',
  };

  static const _omnibusPhrases = {
    'omnibus',
    'complete works',
    'collected works',
    'box set',
  };

  static const _studyGuidePhrases = {
    'study guide',
    'workbook',
    'cliff notes',
    'sparknotes',
  };

  static const _abridgedMarkers = {'abridged', 'unabridged'};

  static const _weakSurnames = {
    'lee',
    'king',
    'young',
    'long',
    'day',
    'may',
    'fox',
    'hill',
    'wood',
    'bell',
  };

  /// Normalizes [text] for deterministic comparison.
  static String normalizeText(String? text) {
    if (text == null) {
      return '';
    }
    var value = text.trim();
    if (value.isEmpty) {
      return '';
    }
    value = foldDiacritics(value);
    value = value.toLowerCase();
    value = _normalizeApostrophes(value);
    value = value.replaceAll('&', ' and ');
    value = _normalizePunctuation(value);
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  /// Removes apostrophes after normalization so `author's` and `authors`
  /// compare equal for token purposes.
  static String normalizeComparableTokens(String? text) {
    final normalized = normalizeText(text);
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.replaceAll("'", '').replaceAll(' ', ' ').trim();
  }

  /// Deterministic Latin diacritic folding. Full Unicode NFC is not available
  /// without an additional dependency; this covers common Western European
  /// book-metadata characters.
  static String foldDiacritics(String input) {
    const map = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ø': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ß': 'ss',
      'À': 'a',
      'Á': 'a',
      'Â': 'a',
      'Ã': 'a',
      'Ä': 'a',
      'Å': 'a',
      'Æ': 'ae',
      'Ç': 'c',
      'È': 'e',
      'É': 'e',
      'Ê': 'e',
      'Ë': 'e',
      'Ì': 'i',
      'Í': 'i',
      'Î': 'i',
      'Ï': 'i',
      'Ñ': 'n',
      'Ò': 'o',
      'Ó': 'o',
      'Ô': 'o',
      'Õ': 'o',
      'Ö': 'o',
      'Ø': 'o',
      'Œ': 'oe',
      'Ù': 'u',
      'Ú': 'u',
      'Û': 'u',
      'Ü': 'u',
      'Ý': 'y',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(map[char] ?? char);
    }
    return buffer.toString();
  }

  static NormalizedTitleForms normalizeTitle({
    required String? title,
    String? subtitle,
    Iterable<String> extraEditionMarkers = const [],
  }) {
    final rawTitle = title?.trim() ?? '';
    final explicitSubtitle = subtitle?.trim();
    var workingTitle = rawTitle;
    String? derivedSubtitle = explicitSubtitle;

    if (derivedSubtitle == null || derivedSubtitle.isEmpty) {
      final split = _splitTitleAndSubtitle(rawTitle);
      workingTitle = split.$1;
      derivedSubtitle = split.$2;
    }

    final withoutFormat = _stripFormatMarkers(workingTitle);
    final full = normalizeText(withoutFormat.$1);
    final editionFromTitle = _extractEditionMarkers(withoutFormat.$1);
    final editionMarkers = {
      ...editionFromTitle,
      ...extraEditionMarkers.map(normalizeText).where((v) => v.isNotEmpty),
    }.toList()
      ..sort();

    final mainSubtitle = _splitMainSubtitle(full, derivedSubtitle);
    final combinedFull = mainSubtitle.$2 == null || mainSubtitle.$2!.isEmpty
        ? mainSubtitle.$1
        : '${mainSubtitle.$1} ${mainSubtitle.$2!}'.trim();
    final volume = _extractVolume(combinedFull);

    return NormalizedTitleForms(
      full: combinedFull,
      main: mainSubtitle.$1,
      subtitle: mainSubtitle.$2,
      articleStrippedFull: _stripLeadingArticle(combinedFull),
      articleStrippedMain: _stripLeadingArticle(mainSubtitle.$1),
      volumeNumber: volume,
      editionMarkers: editionMarkers,
      formatMarkers: withoutFormat.$2,
      isOmnibus: _containsAnyPhrase(full, _omnibusPhrases),
      isStudyGuide: _containsAnyPhrase(full, _studyGuidePhrases),
      isAbridged: _detectAbridged(full),
    );
  }

  static NormalizedAuthorForms normalizeAuthors(Iterable<String> authors) {
    final displayOrder = <String>[];
    final exactKeys = <String>{};
    final surnameKeys = <String>{};
    final initialKeys = <String>{};

    for (final raw in authors) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      displayOrder.add(trimmed);
      final reordered = _reorderSurnameFirst(trimmed);
      final exact = normalizeComparableTokens(reordered);
      if (exact.isEmpty) {
        continue;
      }
      exactKeys.add(exact);
      final surname = _extractSurname(exact);
      if (surname != null && _isUsableSurname(surname)) {
        surnameKeys.add(surname);
      }
      initialKeys.add(_initialKey(exact));
    }

    final sortedExact = exactKeys.toList()..sort();
    final sortedSurname = surnameKeys.toList()..sort();
    final sortedInitial = initialKeys.toList()..sort();
    final primary = displayOrder.isEmpty
        ? ''
        : normalizeComparableTokens(_reorderSurnameFirst(displayOrder.first));

    return NormalizedAuthorForms(
      displayOrder: displayOrder,
      primary: primary,
      allExactKeys: sortedExact,
      allSurnameKeys: sortedSurname,
      allInitialKeys: sortedInitial,
    );
  }

  /// Token-set Jaccard similarity on normalized comparable token strings.
  static double tokenSetJaccard(String left, String right) {
    final leftTokens = _tokenSet(left);
    final rightTokens = _tokenSet(right);
    if (leftTokens.isEmpty && rightTokens.isEmpty) {
      return 1.0;
    }
    if (leftTokens.isEmpty || rightTokens.isEmpty) {
      return 0.0;
    }
    final intersection =
        leftTokens.intersection(rightTokens).length.toDouble();
    final union = leftTokens.union(rightTokens).length.toDouble();
    return intersection / union;
  }

  static String normalizeLanguage(String? language) {
    final normalized = normalizeText(language);
    if (normalized.isEmpty) {
      return '';
    }
    const aliases = {
      'english': 'eng',
      'en': 'eng',
      'eng': 'eng',
      'french': 'fre',
      'fr': 'fre',
      'fre': 'fre',
      'fra': 'fre',
      'german': 'ger',
      'de': 'ger',
      'ger': 'ger',
      'deu': 'ger',
      'spanish': 'spa',
      'es': 'spa',
      'spa': 'spa',
    };
    return aliases[normalized] ?? normalized;
  }

  static String normalizePublisher(String? publisher) {
    return normalizeComparableTokens(publisher);
  }

  static String _normalizeApostrophes(String value) {
    return value
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('`', "'");
  }

  static String _normalizePunctuation(String value) {
    var result = value;
    result = result.replaceAll(RegExp(r'[,:;]'), ' ');
    result = result.replaceAll(RegExp(r'[\u2013\u2014\-/\\]+'), ' ');
    result = result.replaceAll(RegExp(r'["“”‘’`]+'), ' ');
    result = result.replaceAll(RegExp(r'[\(\)\[\]]'), ' ');
    result = result.replaceAll(RegExp(r'[\.!?]+'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  static (String, String?) _splitTitleAndSubtitle(String title) {
    final colon = RegExp(r'\s*:\s*');
    if (colon.hasMatch(title)) {
      final parts = title.split(colon);
      if (parts.length >= 2) {
        return (parts.first.trim(), parts.sublist(1).join(':').trim());
      }
    }

    final spacedDash = RegExp(r'\s+[\u2013\u2014\-]\s+');
    if (spacedDash.hasMatch(title)) {
      final parts = title.split(spacedDash);
      if (parts.length >= 2) {
        return (parts.first.trim(), parts.sublist(1).join(' - ').trim());
      }
    }

    return (title.trim(), null);
  }

  static (String, List<String>) _stripFormatMarkers(String title) {
    var working = title;
    final markers = <String>[];
    for (final phrase in _formatPhrases) {
      final pattern = RegExp(
        r'[\(\[]\s*' + RegExp.escape(phrase) + r'\s*[\)\]]',
        caseSensitive: false,
      );
      if (pattern.hasMatch(working)) {
        markers.add(phrase);
        working = working.replaceAll(pattern, ' ');
      }
    }
    return (working.replaceAll(RegExp(r'\s+'), ' ').trim(), markers);
  }

  static List<String> _extractEditionMarkers(String title) {
    final normalized = normalizeText(title);
    final found = <String>[];
    for (final phrase in _editionPhrases) {
      if (normalized.contains(phrase)) {
        found.add(phrase);
      }
    }
    return found;
  }

  static (String, String?) _splitMainSubtitle(
    String normalizedFull,
    String? subtitle,
  ) {
    if (subtitle != null && subtitle.trim().isNotEmpty) {
      final normalizedSubtitle = normalizeText(subtitle);
      final main = normalizedFull.replaceAll(normalizedSubtitle, '').trim();
      return (
        main.isEmpty ? normalizedFull : main.replaceAll(RegExp(r'\s+'), ' '),
        normalizedSubtitle,
      );
    }
    return (normalizedFull, null);
  }

  static String? _stripLeadingArticle(String value) {
    final tokens = value.split(' ');
    if (tokens.isEmpty) {
      return null;
    }
    if (_leadingArticles.contains(tokens.first)) {
      final stripped = tokens.sublist(1).join(' ').trim();
      return stripped.isEmpty ? null : stripped;
    }
    return value;
  }

  static int? _extractVolume(String normalizedTitle) {
    final patterns = [
      RegExp(r'\bvolume\s+([0-9]+|i{1,3}|iv|v|vi{0,3}|ix|x)\b'),
      RegExp(r'\bvol\.?\s+([0-9]+|i{1,3}|iv|v|vi{0,3}|ix|x)\b'),
      RegExp(r'\bbook\s+([0-9]+|i{1,3}|iv|v|vi{0,3}|ix|x)\b'),
      RegExp(r'\bpart\s+([0-9]+|i{1,3}|iv|v|vi{0,3}|ix|x)\b'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalizedTitle);
      if (match != null) {
        return _parseVolumeToken(match.group(1)!);
      }
    }
    return null;
  }

  static int? _parseVolumeToken(String token) {
    final numeric = int.tryParse(token);
    if (numeric != null) {
      return numeric;
    }
    return _romanToInt(token);
  }

  static int? _romanToInt(String roman) {
    const map = {
      'i': 1,
      'ii': 2,
      'iii': 3,
      'iv': 4,
      'v': 5,
      'vi': 6,
      'vii': 7,
      'viii': 8,
      'ix': 9,
      'x': 10,
    };
    return map[roman.toLowerCase()];
  }

  static bool? _detectAbridged(String normalizedTitle) {
    if (normalizedTitle.contains('unabridged')) {
      return false;
    }
    if (normalizedTitle.contains('abridged')) {
      return true;
    }
    return null;
  }

  static bool _containsAnyPhrase(String haystack, Set<String> phrases) {
    for (final phrase in phrases) {
      if (haystack.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  static String _reorderSurnameFirst(String author) {
    final comma = author.indexOf(',');
    if (comma <= 0) {
      return author;
    }
    final last = author.substring(0, comma).trim();
    final first = author.substring(comma + 1).trim();
    if (first.isEmpty) {
      return author;
    }
    return '$first $last';
  }

  static String? _extractSurname(String exactKey) {
    final tokens =
        exactKey.split(' ').where((token) => token.isNotEmpty).toList();
    if (tokens.isEmpty) {
      return null;
    }
    return tokens.last;
  }

  static bool _isUsableSurname(String surname) {
    if (surname.length < 3) {
      return false;
    }
    if (_weakSurnames.contains(surname)) {
      return false;
    }
    return true;
  }

  static String _initialKey(String exactKey) {
    final tokens =
        exactKey.split(' ').where((token) => token.isNotEmpty).toList();
    if (tokens.isEmpty) {
      return '';
    }
    final initials = tokens
        .map((token) => token.replaceAll('.', '').substring(0, 1))
        .join();
    final surname = tokens.last;
    return '$initials|$surname';
  }

  static Set<String> _tokenSet(String value) {
    final comparable = normalizeComparableTokens(value);
    if (comparable.isEmpty) {
      return {};
    }
    return comparable.split(' ').where((token) => token.isNotEmpty).toSet();
  }
}

/// Returns true when two author exact keys are compatible via initials.
bool authorExactKeysCompatible(String left, String right) {
  if (left == right) {
    return true;
  }
  final leftTokens = left.split(' ');
  final rightTokens = right.split(' ');
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return false;
  }
  if (leftTokens.last != rightTokens.last) {
    return false;
  }
  final leftInitials = leftTokens
      .sublist(0, leftTokens.length - 1)
      .map((token) => token.replaceAll('.', '').substring(0, 1))
      .join();
  final rightInitials = rightTokens
      .sublist(0, rightTokens.length - 1)
      .map((token) => token.replaceAll('.', '').substring(0, 1))
      .join();
  if (leftInitials.isEmpty || rightInitials.isEmpty) {
    return false;
  }
  final minLen =
      leftInitials.length < rightInitials.length
          ? leftInitials.length
          : rightInitials.length;
  return leftInitials.substring(0, minLen) ==
      rightInitials.substring(0, minLen);
}

/// Returns true when surname keys match with initial-compatible given names.
bool authorSurnameKeysCompatible(String leftExact, String rightExact) {
  final leftTokens = leftExact.split(' ');
  final rightTokens = rightExact.split(' ');
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return false;
  }
  if (leftTokens.last != rightTokens.last) {
    return false;
  }
  return authorExactKeysCompatible(leftExact, rightExact);
}
