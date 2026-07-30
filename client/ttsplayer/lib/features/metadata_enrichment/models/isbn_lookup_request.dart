/// Local ISBN lookup input for book metadata providers (M7.2).
class IsbnLookupRequest {
  const IsbnLookupRequest({
    required this.originalInput,
    required this.normalizedIsbn,
    required this.isIsbn13,
    required this.isValid,
    this.validationMessage,
  });

  final String originalInput;
  final String normalizedIsbn;
  final bool isIsbn13;
  final bool isValid;
  final String? validationMessage;

  /// Normalizes [input] and validates length, characters, and checksum.
  ///
  /// Checksum validation is enforced in Phase 7.2 — invalid checksums fail
  /// locally without an HTTP request.
  factory IsbnLookupRequest.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const IsbnLookupRequest(
        originalInput: '',
        normalizedIsbn: '',
        isIsbn13: false,
        isValid: false,
        validationMessage: 'ISBN is required.',
      );
    }

    final normalized = trimmed
        .replaceAll(RegExp(r'[\s\-]'), '')
        .toUpperCase();

    if (!RegExp(r'^[0-9X]+$').hasMatch(normalized)) {
      return IsbnLookupRequest(
        originalInput: input,
        normalizedIsbn: normalized,
        isIsbn13: normalized.length == 13,
        isValid: false,
        validationMessage: 'ISBN contains invalid characters.',
      );
    }

    if (normalized.length == 10) {
      if (!_isValidIsbn10Checksum(normalized)) {
        return IsbnLookupRequest(
          originalInput: input,
          normalizedIsbn: normalized,
          isIsbn13: false,
          isValid: false,
          validationMessage: 'ISBN-10 checksum is invalid.',
        );
      }
      return IsbnLookupRequest(
        originalInput: input,
        normalizedIsbn: normalized,
        isIsbn13: false,
        isValid: true,
      );
    }

    if (normalized.length == 13) {
      if (!normalized.startsWith(RegExp(r'97[89]'))) {
        return IsbnLookupRequest(
          originalInput: input,
          normalizedIsbn: normalized,
          isIsbn13: true,
          isValid: false,
          validationMessage: 'ISBN-13 prefix is invalid.',
        );
      }
      if (!_isValidIsbn13Checksum(normalized)) {
        return IsbnLookupRequest(
          originalInput: input,
          normalizedIsbn: normalized,
          isIsbn13: true,
          isValid: false,
          validationMessage: 'ISBN-13 checksum is invalid.',
        );
      }
      return IsbnLookupRequest(
        originalInput: input,
        normalizedIsbn: normalized,
        isIsbn13: true,
        isValid: true,
      );
    }

    return IsbnLookupRequest(
      originalInput: input,
      normalizedIsbn: normalized,
      isIsbn13: normalized.length == 13,
      isValid: false,
      validationMessage: 'ISBN must be 10 or 13 digits.',
    );
  }

  static bool _isValidIsbn10Checksum(String isbn) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final char = isbn[i];
      final value = char == 'X' ? 10 : int.parse(char);
      sum += value * (10 - i);
    }
    return sum % 11 == 0;
  }

  static bool _isValidIsbn13Checksum(String isbn) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final digit = int.parse(isbn[i]);
      sum += digit * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0;
  }

  @override
  bool operator ==(Object other) {
    return other is IsbnLookupRequest &&
        other.originalInput == originalInput &&
        other.normalizedIsbn == normalizedIsbn &&
        other.isIsbn13 == isIsbn13 &&
        other.isValid == isValid &&
        other.validationMessage == validationMessage;
  }

  @override
  int get hashCode =>
      Object.hash(originalInput, normalizedIsbn, isIsbn13, isValid, validationMessage);
}
