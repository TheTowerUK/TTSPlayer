/// Explicit title/author search input for book metadata providers (M7.2).
class BookSearchRequest {
  const BookSearchRequest({
    this.title,
    this.author,
    this.publicationYear,
    this.limit = defaultLimit,
    this.isValid = true,
    this.validationMessage,
  });

  static const int defaultLimit = 10;
  static const int maxLimit = 25;

  final String? title;
  final String? author;
  final int? publicationYear;
  final int limit;
  final bool isValid;
  final String? validationMessage;

  String? get normalizedTitle => _normalizeOptional(title);
  String? get normalizedAuthor => _normalizeOptional(author);

  /// Builds a validated search request. At least one of title or author
  /// must be present after trimming.
  factory BookSearchRequest.create({
    String? title,
    String? author,
    int? publicationYear,
    int limit = defaultLimit,
  }) {
    final normalizedTitle = _normalizeOptional(title);
    final normalizedAuthor = _normalizeOptional(author);

    if (normalizedTitle == null && normalizedAuthor == null) {
      return const BookSearchRequest(
        isValid: false,
        validationMessage: 'Title or author is required.',
      );
    }

    final boundedLimit = limit.clamp(1, maxLimit);
    int? year;
    if (publicationYear != null) {
      if (publicationYear < 0 || publicationYear > 9999) {
        return BookSearchRequest(
          title: normalizedTitle,
          author: normalizedAuthor,
          publicationYear: publicationYear,
          limit: boundedLimit,
          isValid: false,
          validationMessage: 'Publication year is out of range.',
        );
      }
      year = publicationYear;
    }

    return BookSearchRequest(
      title: normalizedTitle,
      author: normalizedAuthor,
      publicationYear: year,
      limit: boundedLimit,
      isValid: true,
    );
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final collapsed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.isEmpty ? null : collapsed;
  }

  @override
  bool operator ==(Object other) {
    return other is BookSearchRequest &&
        other.title == title &&
        other.author == author &&
        other.publicationYear == publicationYear &&
        other.limit == limit &&
        other.isValid == isValid &&
        other.validationMessage == validationMessage;
  }

  @override
  int get hashCode => Object.hash(
        title,
        author,
        publicationYear,
        limit,
        isValid,
        validationMessage,
      );
}
