import '../matching/book_candidate_match_decision.dart';
import '../matching/book_candidate_match_evaluation.dart';
import '../models/normalized_book_metadata.dart';
import '../services/book_candidate_selection_context.dart';
import 'book_metadata_warning_presentation.dart';

/// Provider-neutral candidate presentation for review UI (M7.3.4).
class BookMetadataCandidatePresentation {
  const BookMetadataCandidatePresentation({
    required this.recordId,
    required this.title,
    required this.matchSummary,
    required this.warnings,
    this.subtitle,
    this.author,
    this.publicationYear,
    this.publisher,
    this.edition,
    this.language,
    this.series,
    this.volume,
    this.isbn,
  });

  final String recordId;
  final String title;
  final String? subtitle;
  final String? author;
  final String? publicationYear;
  final String? publisher;
  final String? edition;
  final String? language;
  final String? series;
  final String? volume;
  final String? isbn;
  final String matchSummary;
  final List<BookMetadataWarningPresentation> warnings;

  bool get hasCriticalWarnings =>
      warnings.any((warning) => warning.isCritical);

  static List<String> orderedReviewableRecordIds(
    BookCandidateSelectionContext context,
  ) {
    final reviewable = context.reviewableRecordIds.toSet();
    final ordered = <String>[];
    for (final evaluation in context.matchSet.rankedEvaluations) {
      final recordId = evaluation.candidate.metadata.providerRecordId;
      if (reviewable.contains(recordId)) {
        ordered.add(recordId);
      }
    }
    return ordered;
  }

  static BookMetadataCandidatePresentation? fromContext({
    required BookCandidateSelectionContext context,
    required String providerRecordId,
  }) {
    if (!context.isReviewableRecord(providerRecordId)) {
      return null;
    }
    final evaluation = context.evaluationForRecordId(providerRecordId);
    if (evaluation == null) {
      return null;
    }
    return fromEvaluation(evaluation);
  }

  static BookMetadataCandidatePresentation fromEvaluation(
    BookCandidateMatchEvaluation evaluation,
  ) {
    final metadata = evaluation.candidate.metadata;
    return BookMetadataCandidatePresentation(
      recordId: metadata.providerRecordId,
      title: metadata.canonicalTitle,
      subtitle: _optionalText(metadata.subtitle),
      author: _formatAuthors(metadata.authors),
      publicationYear: metadata.publicationYear?.toString(),
      publisher: metadata.publishers.isEmpty ? null : metadata.publishers.first,
      edition: _optionalText(metadata.editionId),
      language: metadata.languages.isEmpty ? null : metadata.languages.first,
      series: _seriesFromSubjects(metadata),
      volume: _volumeFromSubtitle(metadata.subtitle),
      isbn: _formatIsbn(metadata),
      matchSummary: matchSummaryFor(evaluation),
      warnings: BookMetadataWarningPresentation.forEvaluation(evaluation),
    );
  }

  static String matchSummaryFor(BookCandidateMatchEvaluation evaluation) {
    if (evaluation.identifierMatch) {
      return 'ISBN match';
    }
    return switch (evaluation.confidenceBand) {
      BookCandidateMatchBand.identifierConfirmed => 'ISBN match',
      BookCandidateMatchBand.highConfidence => 'Strong match',
      BookCandidateMatchBand.acceptable => 'Possible match',
      BookCandidateMatchBand.belowMinimum => 'Review carefully',
    };
  }

  static String? _optionalText(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _formatAuthors(List<String> authors) {
    final cleaned = authors
        .map((author) => author.trim())
        .where((author) => author.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned.join(', ');
  }

  static String? _formatIsbn(NormalizedBookMetadata metadata) {
    if (metadata.isbn13Values.isNotEmpty) {
      return metadata.isbn13Values.first;
    }
    if (metadata.isbn10Values.isNotEmpty) {
      return metadata.isbn10Values.first;
    }
    return null;
  }

  static String? _seriesFromSubjects(NormalizedBookMetadata metadata) {
    for (final subject in metadata.subjects) {
      final lower = subject.toLowerCase();
      if (lower.contains('series')) {
        return subject.trim();
      }
    }
    return null;
  }

  static String? _volumeFromSubtitle(String? subtitle) {
    final value = _optionalText(subtitle);
    if (value == null) {
      return null;
    }
    final lower = value.toLowerCase();
    if (lower.contains('volume') || RegExp(r'\bv\d+\b').hasMatch(lower)) {
      return value;
    }
    return null;
  }

  static String keySuffixForRecordId(String recordId) {
    return recordId.replaceAll('/', '_');
  }
}
