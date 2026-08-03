import '../matching/book_candidate_match_evaluation.dart';
import '../matching/book_candidate_match_warning.dart';
import '../services/book_candidate_review_policy.dart';

/// Bounded user-facing warning for a metadata candidate (M7.3.4).
class BookMetadataWarningPresentation {
  const BookMetadataWarningPresentation({
    required this.message,
    required this.isCritical,
  });

  final String message;
  final bool isCritical;

  static List<BookMetadataWarningPresentation> forEvaluation(
    BookCandidateMatchEvaluation evaluation,
  ) {
    final warnings = <BookMetadataWarningPresentation>[];
    final seen = <String>{};

    void add(BookMetadataWarningPresentation presentation) {
      if (seen.add(presentation.message)) {
        warnings.add(presentation);
      }
    }

    if (evaluation.disqualifiedForAutoLink) {
      add(
        const BookMetadataWarningPresentation(
          message: 'This candidate was excluded from automatic linking.',
          isCritical: true,
        ),
      );
    }

    for (final warning in evaluation.warnings) {
      final mapped = forWarning(warning);
      if (mapped != null) {
        add(mapped);
      }
    }

    return warnings;
  }

  static bool hasCriticalWarnings(BookCandidateMatchEvaluation evaluation) {
    return BookCandidateReviewPolicy.requiresCriticalConflictOverride(
      evaluation,
    );
  }

  static BookMetadataWarningPresentation? forWarning(
    BookCandidateMatchWarning warning,
  ) {
    return switch (warning.kind) {
      BookCandidateMatchWarningKind.isbnConflict =>
        const BookMetadataWarningPresentation(
          message: 'ISBN does not match the local identifier.',
          isCritical: true,
        ),
      BookCandidateMatchWarningKind.contradictoryAuthor =>
        const BookMetadataWarningPresentation(
          message: 'Author differs from the local book.',
          isCritical: true,
        ),
      BookCandidateMatchWarningKind.possibleDifferentEdition =>
        const BookMetadataWarningPresentation(
          message: 'This may be a different edition.',
          isCritical: false,
        ),
      BookCandidateMatchWarningKind.possibleDifferentVolume =>
        const BookMetadataWarningPresentation(
          message: 'Volume information may differ.',
          isCritical: false,
        ),
      BookCandidateMatchWarningKind.languageMismatch =>
        const BookMetadataWarningPresentation(
          message: 'Language may differ.',
          isCritical: false,
        ),
      BookCandidateMatchWarningKind.possibleStudyGuide =>
        const BookMetadataWarningPresentation(
          message: 'This may be a study guide rather than the main work.',
          isCritical: false,
        ),
      BookCandidateMatchWarningKind.possibleAbridgedEdition =>
        const BookMetadataWarningPresentation(
          message: 'This may be an abridged edition.',
          isCritical: false,
        ),
    };
  }
}
