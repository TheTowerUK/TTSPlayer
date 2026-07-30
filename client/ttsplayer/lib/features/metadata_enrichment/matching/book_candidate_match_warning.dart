/// Bounded warning identifiers for candidate evaluation (M7.3.1).
enum BookCandidateMatchWarningKind {
  isbnConflict('identifier_conflict'),
  possibleDifferentVolume('possible_different_volume'),
  possibleDifferentEdition('possible_different_edition'),
  possibleStudyGuide('possible_study_guide'),
  possibleAbridgedEdition('possible_abridged_edition'),
  languageMismatch('language_mismatch'),
  contradictoryAuthor('contradictory_author');

  const BookCandidateMatchWarningKind(this.id);

  final String id;
}

class BookCandidateMatchWarning {
  const BookCandidateMatchWarning({required this.kind});

  final BookCandidateMatchWarningKind kind;

  String get explanationId => kind.id;
}
