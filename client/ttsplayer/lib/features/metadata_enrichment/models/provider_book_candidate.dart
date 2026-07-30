import 'normalized_book_metadata.dart';

/// One search candidate from a book metadata provider (M7.2).
///
/// Provider ordering is preserved for display; it is not TTSPlayer match
/// confidence.
class ProviderBookCandidate {
  const ProviderBookCandidate({
    required this.metadata,
    this.relevanceScore,
    this.exactIdentifierMatch = false,
  });

  final NormalizedBookMetadata metadata;
  final double? relevanceScore;
  final bool exactIdentifierMatch;

  String get displayTitle => metadata.canonicalTitle;

  String? get displayAuthors =>
      metadata.authors.isEmpty ? null : metadata.authors.join(', ');

  @override
  bool operator ==(Object other) {
    return other is ProviderBookCandidate &&
        other.metadata == metadata &&
        other.relevanceScore == relevanceScore &&
        other.exactIdentifierMatch == exactIdentifierMatch;
  }

  @override
  int get hashCode =>
      Object.hash(metadata, relevanceScore, exactIdentifierMatch);
}
