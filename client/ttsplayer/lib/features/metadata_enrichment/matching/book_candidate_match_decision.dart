/// Transient set-level match recommendation (M7.3.1).
///
/// Does not map directly to persisted [EnrichmentMatchState] — persistence is
/// deferred to Phase 7.3.2+.
enum BookCandidateMatchDecision {
  /// Local and candidate ISBN collections contain an equivalent valid pair.
  identifierLinked,

  /// Top candidate final score ≥ 0.85 with no ambiguity flag.
  highConfidenceCandidate,

  /// Multiple acceptable candidates within the ambiguity margin, or manual review
  /// is required because the top candidate has a critical conflict.
  ambiguous,

  /// No identifier-linked, high-confidence, or ambiguous recommendation.
  ///
  /// Does **not** mean there are no candidates suitable for manual review —
  /// see [BookCandidateMatchSet.acceptableEvaluations]. Phase 7.3.2 must not
  /// persist [EnrichmentMatchState.unmatched] solely because this value is
  /// returned; persistent unmatched requires an explicit persistence action.
  unmatched,
}

/// Transient per-candidate confidence band (M7.3.1).
enum BookCandidateMatchBand {
  identifierConfirmed,
  highConfidence,
  acceptable,
  belowMinimum,
}
