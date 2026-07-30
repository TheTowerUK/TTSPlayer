import '../models/normalized_book_metadata.dart';
import '../models/provider_book_candidate.dart';
import 'book_candidate_match_decision.dart';
import 'book_candidate_match_evaluation.dart';
import 'book_candidate_match_set.dart';
import 'book_candidate_match_signal.dart';
import 'book_candidate_match_warning.dart';
import 'book_candidate_ranker.dart';
import 'book_match_normalizer.dart';
import 'isbn_equivalence.dart';
import 'local_book_match_input.dart';

/// Deterministic weighted candidate evaluator (M7.3.1).
class BookCandidateEvaluator {
  const BookCandidateEvaluator();

  static const highConfidenceThreshold = 0.85;
  static const acceptableThreshold = 0.60;
  static const ambiguityMarginThreshold = 0.08;
  static const subtitleAgreementThreshold = 0.85;
  static const publisherAgreementThreshold = 0.85;
  static const titleStrongThreshold = 0.85;
  static const titlePartialThreshold = 0.60;
  static const filenameStemThreshold = 0.60;
  static const largeYearGapYears = 10;
  static const scoreTolerance = 1e-9;

  BookCandidateMatchEvaluation evaluateCandidate({
    required LocalBookMatchInput local,
    required ProviderBookCandidate candidate,
  }) {
    final localTitle = BookMatchNormalizer.normalizeTitle(
      title: local.title,
      subtitle: local.subtitle,
      extraEditionMarkers: local.editionMarkers,
    );
    final localAuthors = BookMatchNormalizer.normalizeAuthors(local.authors);
    final candidateTitle = BookMatchNormalizer.normalizeTitle(
      title: candidate.metadata.canonicalTitle,
      subtitle: candidate.metadata.subtitle,
    );
    final candidateAuthors =
        BookMatchNormalizer.normalizeAuthors(candidate.metadata.authors);

    final identifierStatus = IsbnEquivalence.compareCollections(
      localIsbn10: local.isbn10Values,
      localIsbn13: local.isbn13Values,
      candidateIsbn10: candidate.metadata.isbn10Values,
      candidateIsbn13: candidate.metadata.isbn13Values,
    );
    final identifierMatch = identifierStatus == IsbnComparisonResult.match;

    final signals = <BookCandidateMatchSignal>[];
    final warnings = <BookCandidateMatchWarning>[];

    var rawScore = 0.0;

    final titleTier = _evaluateTitleTier(
      local: local,
      localTitle: localTitle,
      candidateTitle: candidateTitle,
      localAuthors: localAuthors,
      candidateAuthors: candidateAuthors,
      signals: signals,
    );
    rawScore += titleTier;

    final subtitleBonus = _evaluateSubtitleBonus(
      localTitle: localTitle,
      candidateTitle: candidateTitle,
      titleTier: titleTier,
      signals: signals,
    );
    rawScore += subtitleBonus;

    final authorTier = _evaluateAuthorTier(
      localAuthors: localAuthors,
      candidateAuthors: candidateAuthors,
      signals: signals,
    );
    rawScore += authorTier;

    final yearTier = _evaluateYearTier(
      localYear: local.publicationYear,
      candidateYear: candidate.metadata.publicationYear,
      signals: signals,
    );
    rawScore += yearTier;

    rawScore += _evaluatePublisherAgreement(
      localPublisher: local.publisher,
      candidatePublishers: candidate.metadata.publishers,
      signals: signals,
    );

    rawScore += _evaluateLanguageAgreement(
      localLanguage: local.language,
      candidateLanguages: candidate.metadata.languages,
      signals: signals,
    );

    var penaltyTotal = 0.0;
    var disqualifiedForAutoLink = false;

    if (identifierStatus == IsbnComparisonResult.conflict) {
      disqualifiedForAutoLink = true;
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.isbnConflict,
          contribution: 0.0,
        ),
      );
      warnings.add(
        const BookCandidateMatchWarning(
          kind: BookCandidateMatchWarningKind.isbnConflict,
        ),
      );
    }

    penaltyTotal += _applyAuthorConflictPenalty(
      localAuthors: localAuthors,
      candidateAuthors: candidateAuthors,
      authorTier: authorTier,
      signals: signals,
      warnings: warnings,
    );

    penaltyTotal += _applyVolumePenalty(
      localTitle: localTitle,
      candidateTitle: candidateTitle,
      localVolume: local.volume,
      signals: signals,
      warnings: warnings,
    );

    penaltyTotal += _applyEditionPenalty(
      localTitle: localTitle,
      candidateTitle: candidateTitle,
      signals: signals,
      warnings: warnings,
    );

    penaltyTotal += _applyFormatVariantPenalty(
      localTitle: localTitle,
      candidateTitle: candidateTitle,
      signals: signals,
      warnings: warnings,
    );

    penaltyTotal += _applyAbridgedPenalty(
      localTitle: localTitle,
      candidateTitle: candidateTitle,
      signals: signals,
      warnings: warnings,
    );

    penaltyTotal += _applyLargeYearGapPenalty(
      localYear: local.publicationYear,
      candidateYear: candidate.metadata.publicationYear,
      identifierMatch: identifierMatch,
      signals: signals,
    );

    penaltyTotal += _applyLanguageMismatchPenalty(
      localLanguage: local.language,
      candidateLanguages: candidate.metadata.languages,
      signals: signals,
      warnings: warnings,
    );

    final penalizedScore =
        (rawScore - penaltyTotal) < 0.0 ? 0.0 : rawScore - penaltyTotal;
    final finalScore = _clampScore(penalizedScore);

    final confidenceBand = _confidenceBand(
      identifierMatch: identifierMatch,
      finalScore: finalScore,
    );

    final explanationIds = _buildExplanationIds(
      identifierStatus: identifierStatus,
      titleTier: titleTier,
      authorTier: authorTier,
      yearTier: yearTier,
      finalScore: finalScore,
      warnings: warnings,
      local: local,
    );

    return BookCandidateMatchEvaluation(
      candidate: candidate,
      rawScore: rawScore,
      penaltyTotal: penaltyTotal,
      finalScore: finalScore,
      signals: List.unmodifiable(signals),
      warnings: List.unmodifiable(warnings),
      identifierStatus: identifierStatus,
      disqualifiedForAutoLink: disqualifiedForAutoLink,
      rank: 0,
      deltaFromTop: 0.0,
      confidenceBand: confidenceBand,
      explanationIds: explanationIds,
      identifierMatch: identifierMatch,
    );
  }

  BookCandidateMatchSet evaluateSet({
    required LocalBookMatchInput local,
    required List<ProviderBookCandidate> candidates,
  }) {
    if (candidates.isEmpty) {
      return const BookCandidateMatchSet(
        rankedEvaluations: [],
        acceptableEvaluations: [],
        topCandidate: null,
        isAmbiguous: false,
        ambiguityMargin: null,
        ambiguityReasonIds: [],
        decision: BookCandidateMatchDecision.unmatched,
      );
    }

    final preliminary = <ProviderBookCandidate, BookCandidateMatchEvaluation>{};
    for (final candidate in candidates) {
      preliminary[candidate] = evaluateCandidate(local: local, candidate: candidate);
    }

    final finalScores = {
      for (final entry in preliminary.entries) entry.key: entry.value.finalScore,
    };
    final identifierMatches = {
      for (final entry in preliminary.entries)
        entry.key: entry.value.identifierMatch,
    };

    final rankedCandidates = BookCandidateRanker.rank(
      candidates: candidates,
      finalScores: finalScores,
      identifierMatches: identifierMatches,
    );

    final rankedEvaluations = <BookCandidateMatchEvaluation>[];
    BookCandidateMatchEvaluation? top;
    for (var index = 0; index < rankedCandidates.length; index++) {
      final candidate = rankedCandidates[index];
      final base = preliminary[candidate]!;
      final rank = index + 1;
      final delta = top == null ? 0.0 : top.finalScore - base.finalScore;
      if (top == null) {
        top = base;
      }
      rankedEvaluations.add(
        BookCandidateMatchEvaluation(
          candidate: base.candidate,
          rawScore: base.rawScore,
          penaltyTotal: base.penaltyTotal,
          finalScore: base.finalScore,
          signals: base.signals,
          warnings: base.warnings,
          identifierStatus: base.identifierStatus,
          disqualifiedForAutoLink: base.disqualifiedForAutoLink,
          rank: rank,
          deltaFromTop: delta,
          confidenceBand: base.confidenceBand,
          explanationIds: base.explanationIds,
          identifierMatch: base.identifierMatch,
        ),
      );
    }

    final acceptableEvaluations = rankedEvaluations
        .where(
          (evaluation) =>
              evaluation.identifierMatch ||
              evaluation.finalScore + scoreTolerance >= acceptableThreshold,
        )
        .toList();

    final ambiguity = _evaluateAmbiguity(
      rankedEvaluations: rankedEvaluations,
    );

    final decision = _decide(
      top: rankedEvaluations.isEmpty ? null : rankedEvaluations.first,
      isAmbiguous: ambiguity.isAmbiguous,
      acceptableCount: acceptableEvaluations.length,
    );

    return BookCandidateMatchSet(
      rankedEvaluations: List.unmodifiable(rankedEvaluations),
      acceptableEvaluations: List.unmodifiable(acceptableEvaluations),
      topCandidate: rankedEvaluations.isEmpty ? null : rankedEvaluations.first,
      isAmbiguous: ambiguity.isAmbiguous,
      ambiguityMargin: ambiguity.margin,
      ambiguityReasonIds: ambiguity.reasonIds,
      decision: decision,
    );
  }

  static double _clampScore(double value) {
    if (value < 0.0) {
      return 0.0;
    }
    if (value > 1.0) {
      return 1.0;
    }
    return value;
  }

  static BookCandidateMatchBand _confidenceBand({
    required bool identifierMatch,
    required double finalScore,
  }) {
    if (identifierMatch) {
      return BookCandidateMatchBand.identifierConfirmed;
    }
    if (finalScore + scoreTolerance >= highConfidenceThreshold) {
      return BookCandidateMatchBand.highConfidence;
    }
    if (finalScore + scoreTolerance >= acceptableThreshold) {
      return BookCandidateMatchBand.acceptable;
    }
    return BookCandidateMatchBand.belowMinimum;
  }

  static double _evaluateTitleTier({
    required LocalBookMatchInput local,
    required NormalizedTitleForms localTitle,
    required NormalizedTitleForms candidateTitle,
    required NormalizedAuthorForms localAuthors,
    required NormalizedAuthorForms candidateAuthors,
    required List<BookCandidateMatchSignal> signals,
  }) {
    if (localTitle.full.isNotEmpty && localTitle.full == candidateTitle.full) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.titleExact,
          contribution: 0.35,
          comparedField: 'title',
        ),
      );
      return 0.35;
    }

    if (localTitle.main.isNotEmpty &&
        localTitle.main == candidateTitle.main &&
        localTitle.subtitle != candidateTitle.subtitle) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.titleMainExact,
          contribution: 0.28,
          comparedField: 'title',
        ),
      );
      return 0.28;
    }

    final jaccardFull = BookMatchNormalizer.tokenSetJaccard(
      localTitle.full,
      candidateTitle.full,
    );
    if (jaccardFull + scoreTolerance >= titleStrongThreshold) {
      signals.add(
        BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.titleStrong,
          contribution: 0.22,
          comparedField: 'title',
        ),
      );
      return 0.22;
    }

    if (jaccardFull + scoreTolerance >= titlePartialThreshold) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.titlePartial,
          contribution: 0.12,
          comparedField: 'title',
        ),
      );
      return 0.12;
    }

    final stem = local.filenameStem?.trim();
    if (stem != null && stem.isNotEmpty) {
      final stemComparable = BookMatchNormalizer.normalizeComparableTokens(stem);
      final stemJaccard = [
        BookMatchNormalizer.tokenSetJaccard(stemComparable, candidateTitle.full),
        BookMatchNormalizer.tokenSetJaccard(stemComparable, candidateTitle.main),
      ].reduce((a, b) => a > b ? a : b);

      final authorTier = _peekAuthorTier(localAuthors, candidateAuthors);
      final authorMeetsPartial = authorTier >= 0.12;
      if (stemJaccard + scoreTolerance >= filenameStemThreshold &&
          authorMeetsPartial) {
        signals.add(
          const BookCandidateMatchSignal(
            kind: BookCandidateMatchSignalKind.titleFilename,
            contribution: 0.06,
            comparedField: 'filename_stem',
          ),
        );
        return 0.06;
      }
    }

    return 0.0;
  }

  static double _evaluateSubtitleBonus({
    required NormalizedTitleForms localTitle,
    required NormalizedTitleForms candidateTitle,
    required double titleTier,
    required List<BookCandidateMatchSignal> signals,
  }) {
    if (titleTier + scoreTolerance < 0.12) {
      return 0.0;
    }
    final localSubtitle = localTitle.subtitle;
    final candidateSubtitle = candidateTitle.subtitle;
    if (localSubtitle == null ||
        localSubtitle.isEmpty ||
        candidateSubtitle == null ||
        candidateSubtitle.isEmpty) {
      return 0.0;
    }
    final agreement = BookMatchNormalizer.tokenSetJaccard(
      localSubtitle,
      candidateSubtitle,
    );
    if (agreement + scoreTolerance >= subtitleAgreementThreshold) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.subtitleAgree,
          contribution: 0.05,
          comparedField: 'subtitle',
        ),
      );
      return 0.05;
    }
    return 0.0;
  }

  static double _evaluateAuthorTier({
    required NormalizedAuthorForms localAuthors,
    required NormalizedAuthorForms candidateAuthors,
    required List<BookCandidateMatchSignal> signals,
  }) {
    final tier = _peekAuthorTier(localAuthors, candidateAuthors);
    if (tier == 0.0) {
      return 0.0;
    }
    if (tier == 0.30) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.authorPrimaryExact,
          contribution: 0.30,
          comparedField: 'author',
        ),
      );
    } else if (tier == 0.20) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.authorAnyExact,
          contribution: 0.20,
          comparedField: 'author',
        ),
      );
    } else {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.authorSurname,
          contribution: 0.12,
          comparedField: 'author',
        ),
      );
    }
    return tier;
  }

  static double _peekAuthorTier(
    NormalizedAuthorForms localAuthors,
    NormalizedAuthorForms candidateAuthors,
  ) {
    if (localAuthors.primary.isEmpty || candidateAuthors.primary.isEmpty) {
      return 0.0;
    }

    if (authorExactKeysCompatible(
      localAuthors.primary,
      candidateAuthors.primary,
    )) {
      return 0.30;
    }

    for (final localAuthor in localAuthors.allExactKeys) {
      for (final candidateAuthor in candidateAuthors.allExactKeys) {
        if (authorExactKeysCompatible(localAuthor, candidateAuthor)) {
          return 0.20;
        }
      }
    }

    for (final localAuthor in localAuthors.allExactKeys) {
      for (final candidateAuthor in candidateAuthors.allExactKeys) {
        if (authorSurnameKeysCompatible(localAuthor, candidateAuthor)) {
          return 0.12;
        }
      }
    }

    return 0.0;
  }

  static double _evaluateYearTier({
    required int? localYear,
    required int? candidateYear,
    required List<BookCandidateMatchSignal> signals,
  }) {
    if (localYear == null || candidateYear == null) {
      return 0.0;
    }
    final diff = (localYear - candidateYear).abs();
    if (diff == 0) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.yearExact,
          contribution: 0.10,
          comparedField: 'year',
        ),
      );
      return 0.10;
    }
    if (diff == 1) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.yearNear,
          contribution: 0.07,
          comparedField: 'year',
        ),
      );
      return 0.07;
    }
    if (diff <= 3) {
      signals.add(
        const BookCandidateMatchSignal(
          kind: BookCandidateMatchSignalKind.yearLoose,
          contribution: 0.04,
          comparedField: 'year',
        ),
      );
      return 0.04;
    }
    return 0.0;
  }

  static double _evaluatePublisherAgreement({
    required String? localPublisher,
    required List<String> candidatePublishers,
    required List<BookCandidateMatchSignal> signals,
  }) {
    final local = BookMatchNormalizer.normalizePublisher(localPublisher);
    if (local.isEmpty || candidatePublishers.isEmpty) {
      return 0.0;
    }
    for (final publisher in candidatePublishers) {
      final candidate = BookMatchNormalizer.normalizePublisher(publisher);
      if (candidate.isEmpty) {
        continue;
      }
      if (local == candidate) {
        signals.add(
          const BookCandidateMatchSignal(
            kind: BookCandidateMatchSignalKind.publisherAgree,
            contribution: 0.05,
            comparedField: 'publisher',
          ),
        );
        return 0.05;
      }
      if (BookMatchNormalizer.tokenSetJaccard(local, candidate) +
              scoreTolerance >=
          publisherAgreementThreshold) {
        signals.add(
          const BookCandidateMatchSignal(
            kind: BookCandidateMatchSignalKind.publisherAgree,
            contribution: 0.05,
            comparedField: 'publisher',
          ),
        );
        return 0.05;
      }
    }
    return 0.0;
  }

  static double _evaluateLanguageAgreement({
    required String? localLanguage,
    required List<String> candidateLanguages,
    required List<BookCandidateMatchSignal> signals,
  }) {
    final local = BookMatchNormalizer.normalizeLanguage(localLanguage);
    if (local.isEmpty || candidateLanguages.isEmpty) {
      return 0.0;
    }
    for (final language in candidateLanguages) {
      final candidate = BookMatchNormalizer.normalizeLanguage(language);
      if (candidate.isNotEmpty && local == candidate) {
        signals.add(
          const BookCandidateMatchSignal(
            kind: BookCandidateMatchSignalKind.languageAgree,
            contribution: 0.03,
            comparedField: 'language',
          ),
        );
        return 0.03;
      }
    }
    return 0.0;
  }

  static double _applyAuthorConflictPenalty({
    required NormalizedAuthorForms localAuthors,
    required NormalizedAuthorForms candidateAuthors,
    required double authorTier,
    required List<BookCandidateMatchSignal> signals,
    required List<BookCandidateMatchWarning> warnings,
  }) {
    if (localAuthors.primary.isEmpty || candidateAuthors.primary.isEmpty) {
      return 0.0;
    }
    if (authorTier > 0.0) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.authorConflict,
        contribution: -0.25,
        comparedField: 'author',
      ),
    );
    warnings.add(
      const BookCandidateMatchWarning(
        kind: BookCandidateMatchWarningKind.contradictoryAuthor,
      ),
    );
    return 0.25;
  }

  static double _applyVolumePenalty({
    required NormalizedTitleForms localTitle,
    required NormalizedTitleForms candidateTitle,
    required String? localVolume,
    required List<BookCandidateMatchSignal> signals,
    required List<BookCandidateMatchWarning> warnings,
  }) {
    final localVolumeNumber =
        localTitle.volumeNumber ?? _parseVolumeMarker(localVolume);
    final candidateVolumeNumber = candidateTitle.volumeNumber;
    if (localVolumeNumber == null || candidateVolumeNumber == null) {
      return 0.0;
    }
    if (localVolumeNumber == candidateVolumeNumber) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.volumeConflict,
        contribution: -0.15,
        comparedField: 'volume',
      ),
    );
    warnings.add(
      const BookCandidateMatchWarning(
        kind: BookCandidateMatchWarningKind.possibleDifferentVolume,
      ),
    );
    return 0.15;
  }

  static int? _parseVolumeMarker(String? volume) {
    if (volume == null || volume.trim().isEmpty) {
      return null;
    }
    final normalized = BookMatchNormalizer.normalizeText(volume);
    final match = RegExp(r'^[0-9]+$').firstMatch(normalized);
    if (match != null) {
      return int.parse(normalized);
    }
    return BookMatchNormalizer.normalizeTitle(title: 'volume $normalized')
        .volumeNumber;
  }

  static double _applyEditionPenalty({
    required NormalizedTitleForms localTitle,
    required NormalizedTitleForms candidateTitle,
    required List<BookCandidateMatchSignal> signals,
    required List<BookCandidateMatchWarning> warnings,
  }) {
    if (localTitle.editionMarkers.isEmpty ||
        candidateTitle.editionMarkers.isEmpty) {
      return 0.0;
    }
    if (localTitle.editionMarkers.join('|') ==
        candidateTitle.editionMarkers.join('|')) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.editionConflict,
        contribution: -0.10,
        comparedField: 'edition',
      ),
    );
    warnings.add(
      const BookCandidateMatchWarning(
        kind: BookCandidateMatchWarningKind.possibleDifferentEdition,
      ),
    );
    return 0.10;
  }

  static double _applyFormatVariantPenalty({
    required NormalizedTitleForms localTitle,
    required NormalizedTitleForms candidateTitle,
    required List<BookCandidateMatchSignal> signals,
    required List<BookCandidateMatchWarning> warnings,
  }) {
    final localVariant =
        localTitle.isOmnibus || localTitle.isStudyGuide;
    final candidateVariant =
        candidateTitle.isOmnibus || candidateTitle.isStudyGuide;
    if (localVariant == candidateVariant) {
      return 0.0;
    }
    if (!localVariant && !candidateVariant) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.formatVariant,
        contribution: -0.20,
        comparedField: 'format',
      ),
    );
    if (localTitle.isStudyGuide || candidateTitle.isStudyGuide) {
      warnings.add(
        const BookCandidateMatchWarning(
          kind: BookCandidateMatchWarningKind.possibleStudyGuide,
        ),
      );
    }
    return 0.20;
  }

  static double _applyAbridgedPenalty({
    required NormalizedTitleForms localTitle,
    required NormalizedTitleForms candidateTitle,
    required List<BookCandidateMatchSignal> signals,
    required List<BookCandidateMatchWarning> warnings,
  }) {
    final local = localTitle.isAbridged;
    final candidate = candidateTitle.isAbridged;
    if (local == null || candidate == null || local == candidate) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.abridgedConflict,
        contribution: -0.15,
        comparedField: 'abridged',
      ),
    );
    warnings.add(
      const BookCandidateMatchWarning(
        kind: BookCandidateMatchWarningKind.possibleAbridgedEdition,
      ),
    );
    return 0.15;
  }

  static double _applyLargeYearGapPenalty({
    required int? localYear,
    required int? candidateYear,
    required bool identifierMatch,
    required List<BookCandidateMatchSignal> signals,
  }) {
    if (identifierMatch || localYear == null || candidateYear == null) {
      return 0.0;
    }
    if ((localYear - candidateYear).abs() <= largeYearGapYears) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.largeYearGap,
        contribution: -0.15,
        comparedField: 'year',
      ),
    );
    return 0.15;
  }

  static double _applyLanguageMismatchPenalty({
    required String? localLanguage,
    required List<String> candidateLanguages,
    required List<BookCandidateMatchSignal> signals,
    required List<BookCandidateMatchWarning> warnings,
  }) {
    final local = BookMatchNormalizer.normalizeLanguage(localLanguage);
    if (local.isEmpty || candidateLanguages.isEmpty) {
      return 0.0;
    }
    final normalizedCandidates = candidateLanguages
        .map(BookMatchNormalizer.normalizeLanguage)
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalizedCandidates.contains(local)) {
      return 0.0;
    }
    signals.add(
      const BookCandidateMatchSignal(
        kind: BookCandidateMatchSignalKind.languageConflict,
        contribution: -0.10,
        comparedField: 'language',
      ),
    );
    warnings.add(
      const BookCandidateMatchWarning(
        kind: BookCandidateMatchWarningKind.languageMismatch,
      ),
    );
    return 0.10;
  }

  static List<String> _buildExplanationIds({
    required IsbnComparisonResult identifierStatus,
    required double titleTier,
    required double authorTier,
    required double yearTier,
    required double finalScore,
    required List<BookCandidateMatchWarning> warnings,
    required LocalBookMatchInput local,
  }) {
    final ids = <String>[];
    if (identifierStatus == IsbnComparisonResult.match) {
      ids.add('isbn_exact');
    }
    if (identifierStatus == IsbnComparisonResult.conflict) {
      ids.add('identifier_conflict');
    }
    if (titleTier > 0 && authorTier > 0 && yearTier > 0) {
      ids.add('title_author_year_agree');
    } else if (titleTier > 0 && authorTier > 0) {
      ids.add('title_author_agree');
    } else if (titleTier > 0 && yearTier > 0) {
      ids.add('title_agrees_year_differs');
    } else if (finalScore + scoreTolerance < acceptableThreshold) {
      if (!local.hasUsableAuthor && !local.hasTrustedIsbn) {
        ids.add('insufficient_local_metadata');
      } else {
        ids.add('weak_match');
      }
    }

    for (final warning in warnings) {
      if (!ids.contains(warning.explanationId)) {
        ids.add(warning.explanationId);
      }
    }
    return ids;
  }

  static _AmbiguityResult _evaluateAmbiguity({
    required List<BookCandidateMatchEvaluation> rankedEvaluations,
  }) {
    if (rankedEvaluations.isEmpty) {
      return const _AmbiguityResult(isAmbiguous: false);
    }

    final top = rankedEvaluations.first;
    final reasons = <String>[];

    if (top.disqualifiedForAutoLink) {
      reasons.add('identifier_conflict');
    }

    final hasAuthorConflict = top.signals.any(
      (signal) => signal.kind == BookCandidateMatchSignalKind.authorConflict,
    );
    if (hasAuthorConflict) {
      reasons.add('contradictory_author');
    }

    final hasPartialOrBetterTitle = top.signals.any(
      (signal) =>
          signal.kind == BookCandidateMatchSignalKind.titleExact ||
          signal.kind == BookCandidateMatchSignalKind.titleMainExact ||
          signal.kind == BookCandidateMatchSignalKind.titleStrong ||
          signal.kind == BookCandidateMatchSignalKind.titlePartial,
    );

    if (top.finalScore + scoreTolerance < acceptableThreshold) {
      if (reasons.isNotEmpty && hasPartialOrBetterTitle) {
        return _AmbiguityResult(
          isAmbiguous: true,
          margin: rankedEvaluations.length >= 2
              ? top.finalScore - rankedEvaluations[1].finalScore
              : null,
          reasonIds: reasons,
        );
      }
      return _AmbiguityResult(
        isAmbiguous: false,
        margin: rankedEvaluations.length >= 2
            ? top.finalScore - rankedEvaluations[1].finalScore
            : null,
        reasonIds: reasons,
      );
    }

    if (rankedEvaluations.length >= 2) {
      final second = rankedEvaluations[1];
      if (second.finalScore + scoreTolerance >= acceptableThreshold) {
        final margin = top.finalScore - second.finalScore;
        if (margin + scoreTolerance < ambiguityMarginThreshold) {
          reasons.add('multiple_close_matches');
          return _AmbiguityResult(
            isAmbiguous: true,
            margin: margin,
            reasonIds: reasons,
          );
        }
      }
    }

    if (reasons.isNotEmpty) {
      return _AmbiguityResult(
        isAmbiguous: true,
        margin: rankedEvaluations.length >= 2
            ? top.finalScore - rankedEvaluations[1].finalScore
            : null,
        reasonIds: reasons,
      );
    }

    return _AmbiguityResult(
      isAmbiguous: false,
      margin: rankedEvaluations.length >= 2
          ? top.finalScore - rankedEvaluations[1].finalScore
          : null,
      reasonIds: reasons,
    );
  }

  static BookCandidateMatchDecision _decide({
    required BookCandidateMatchEvaluation? top,
    required bool isAmbiguous,
    required int acceptableCount,
  }) {
    if (top == null) {
      return BookCandidateMatchDecision.unmatched;
    }
    if (top.identifierMatch) {
      return BookCandidateMatchDecision.identifierLinked;
    }
    if (acceptableCount == 0) {
      return BookCandidateMatchDecision.unmatched;
    }
    if (isAmbiguous) {
      return BookCandidateMatchDecision.ambiguous;
    }
    if (top.finalScore + scoreTolerance >= highConfidenceThreshold) {
      return BookCandidateMatchDecision.highConfidenceCandidate;
    }
    // Acceptable candidates may remain for manual review even though no strong
    // recommendation was issued — see BookCandidateMatchSet.acceptableEvaluations.
    return BookCandidateMatchDecision.unmatched;
  }
}

class _AmbiguityResult {
  const _AmbiguityResult({
    required this.isAmbiguous,
    this.margin,
    this.reasonIds = const [],
  });

  final bool isAmbiguous;
  final double? margin;
  final List<String> reasonIds;
}
