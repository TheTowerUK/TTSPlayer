import '../models/isbn_lookup_request.dart';

/// Result of comparing local and candidate ISBN identifier collections.
enum IsbnComparisonResult {
  /// At least one valid equivalent identifier pair exists.
  match,

  /// Both sides have trusted valid identifiers and none are equivalent.
  conflict,

  /// One or both sides have no valid identifier to compare.
  ///
  /// Returned when either collection is empty after validation, or when all
  /// supplied values fail checksum/length checks. Missing identifiers never
  /// produce [conflict].
  insufficient,
}

/// Provider-neutral ISBN normalization, conversion, and comparison (M7.3.1).
class IsbnEquivalence {
  IsbnEquivalence._();

  /// Parses [value] when valid; otherwise returns null.
  static String? normalizeValid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = IsbnLookupRequest.parse(value);
    return parsed.isValid ? parsed.normalizedIsbn : null;
  }

  /// Deterministically deduplicates and sorts valid ISBN values.
  static List<String> normalizeCollection(Iterable<String> values) {
    final normalized = <String>{};
    for (final value in values) {
      final valid = normalizeValid(value);
      if (valid != null) {
        normalized.add(valid);
      }
    }
    final list = normalized.toList()..sort();
    return list;
  }

  /// Converts a valid ISBN-10 to its 978-prefixed ISBN-13 equivalent.
  static String? isbn10ToIsbn13(String isbn10) {
    final normalized = normalizeValid(isbn10);
    if (normalized == null || normalized.length != 10) {
      return null;
    }
    final body = normalized.substring(0, 9);
    final prefix = '978$body';
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = int.parse(prefix[i]);
      sum += digit * (i.isEven ? 1 : 3);
    }
    final check = (10 - (sum % 10)) % 10;
    return '$prefix$check';
  }

  /// Converts a valid 978-prefixed ISBN-13 to ISBN-10.
  ///
  /// Returns null for 979 prefixes or invalid input.
  static String? isbn13ToIsbn10(String isbn13) {
    final normalized = normalizeValid(isbn13);
    if (normalized == null || normalized.length != 13) {
      return null;
    }
    if (!normalized.startsWith('978')) {
      return null;
    }
    final body = normalized.substring(3, 12);
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(body[i]) * (10 - i);
    }
    final remainder = 11 - (sum % 11);
    final check = remainder == 10 ? 'X' : remainder.toString();
    final candidate = '$body$check';
    return normalizeValid(candidate);
  }

  /// Expands a collection with deterministic cross-format equivalents.
  static Set<String> expandEquivalents(Iterable<String> values) {
    final expanded = <String>{};
    for (final value in normalizeCollection(values)) {
      expanded.add(value);
      if (value.length == 10) {
        final as13 = isbn10ToIsbn13(value);
        if (as13 != null) {
          expanded.add(as13);
        }
      } else if (value.startsWith('978')) {
        final as10 = isbn13ToIsbn10(value);
        if (as10 != null) {
          expanded.add(as10);
        }
      }
    }
    return expanded;
  }

  /// Returns true when [a] and [b] are identical or cross-format equivalents.
  static bool areEquivalent(String a, String b) {
    final left = normalizeValid(a);
    final right = normalizeValid(b);
    if (left == null || right == null) {
      return false;
    }
    if (left == right) {
      return true;
    }
    final leftExpanded = expandEquivalents([left]);
    return leftExpanded.contains(right);
  }

  /// Compares local and candidate ISBN collections.
  ///
  /// [localIsbn10] and [localIsbn13] must contain only **trusted** local
  /// identifiers — the utility treats every valid value as authoritative for
  /// conflict detection. Invalid values are ignored. [conflict] is returned
  /// only when both sides retain at least one valid identifier and no
  /// equivalent pair exists.
  static IsbnComparisonResult compareCollections({
    required Iterable<String> localIsbn10,
    required Iterable<String> localIsbn13,
    required Iterable<String> candidateIsbn10,
    required Iterable<String> candidateIsbn13,
  }) {
    final local = expandEquivalents([
      ...localIsbn10,
      ...localIsbn13,
    ]);
    final candidate = expandEquivalents([
      ...candidateIsbn10,
      ...candidateIsbn13,
    ]);

    if (local.isEmpty || candidate.isEmpty) {
      return IsbnComparisonResult.insufficient;
    }

    for (final localValue in local) {
      if (candidate.contains(localValue)) {
        return IsbnComparisonResult.match;
      }
    }

    return IsbnComparisonResult.conflict;
  }
}
