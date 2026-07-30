import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../matching/book_candidate_evaluator.dart';
import '../matching/local_book_match_input.dart';
import '../models/book_search_request.dart';
import '../models/enrichment_match_state.dart';
import '../models/isbn_lookup_request.dart';
import '../models/metadata_enrichment_record.dart';
import '../providers/book_metadata_provider.dart';
import '../providers/book_metadata_provider_failure.dart';
import '../providers/book_metadata_provider_result.dart';
import 'book_candidate_review_policy.dart';
import 'book_candidate_selection_context.dart';
import 'book_metadata_match_transition.dart';
import 'book_metadata_matching_result.dart';
import 'book_metadata_refresh_service.dart';
import 'metadata_enrichment_repository.dart';

typedef BookMetadataClock = DateTime Function();

/// Application-facing orchestration for book metadata matching (M7.3.2).
///
/// Future UI and main application wiring must call this coordinator.
/// [BookMetadataRefreshService] is a lower-level ISBN implementation service.
///
/// Every provider call requires an explicit coordinator method invocation.
class BookMetadataMatchingCoordinator {
  BookMetadataMatchingCoordinator({
    required BookMetadataProvider provider,
    required MetadataEnrichmentRepository repository,
    BookCandidateEvaluator? evaluator,
    BookMetadataMatchTransition? transition,
    BookMetadataRefreshService? refreshService,
    BookMetadataClock? clock,
  })  : _provider = provider,
        _repository = repository,
        _evaluator = evaluator ?? const BookCandidateEvaluator(),
        _transition = transition ?? const BookMetadataMatchTransition(),
        _refreshService = refreshService ??
            BookMetadataRefreshService(
              provider: provider,
              repository: repository,
              transition: transition ?? const BookMetadataMatchTransition(),
            ),
        _clock = clock ?? _defaultClock;

  final BookMetadataProvider _provider;
  final MetadataEnrichmentRepository _repository;
  final BookCandidateEvaluator _evaluator;
  final BookMetadataMatchTransition _transition;
  final BookMetadataRefreshService _refreshService;
  final BookMetadataClock _clock;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  Future<BookIsbnMatchResult> lookupByIsbn({
    required MediaItem item,
    required String isbnInput,
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    final rejection = _validateOperationalRequest(item);
    if (rejection != null) {
      return BookIsbnMatchRejected(rejection);
    }

    final request = IsbnLookupRequest.parse(isbnInput);
    if (!request.isValid) {
      return BookIsbnMatchRejected(
        request.validationMessage ?? 'ISBN is invalid.',
      );
    }

    final result = await _refreshService.refreshByIsbn(
      item: item,
      isbnInput: isbnInput,
      options: options,
    );
    return _mapIsbnRefreshResult(result);
  }

  Future<BookCandidateSearchEvaluationResult> searchAndEvaluate({
    required MediaItem item,
    required BookSearchRequest searchRequest,
    LocalBookMatchInput? localInputOverride,
    Iterable<String> trustedIsbn10 = const [],
    Iterable<String> trustedIsbn13 = const [],
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    final rejection = _validateOperationalRequest(item);
    if (rejection != null) {
      return BookCandidateSearchEvaluationRejected(rejection);
    }
    if (!searchRequest.isValid) {
      return BookCandidateSearchEvaluationRejected(
        searchRequest.validationMessage ?? 'Search request is invalid.',
      );
    }

    final searchResult = await _provider.search(searchRequest, options: options);
    switch (searchResult) {
      case BookMetadataSearchSuccess(:final candidates):
        if (candidates.isEmpty) {
          return const BookCandidateSearchNoProviderCandidates();
        }
        final local = localInputOverride ??
            _localInputFromItem(
              item,
              trustedIsbn10: trustedIsbn10,
              trustedIsbn13: trustedIsbn13,
            );
        final matchSet = _evaluator.evaluateSet(
          local: local,
          candidates: candidates,
        );
        final context = BookCandidateSelectionContext.fromEvaluation(
          itemId: item.id,
          providerId: _provider.providerId,
          searchFingerprint: BookSearchFingerprint.fromLocalInput(local),
          matchSet: matchSet,
          generatedAt: _clock(),
        );
        return BookCandidateSearchEvaluationSuccess(
          matchSet: matchSet,
          selectionContext: context,
        );
      case BookMetadataSearchFailure(:final failure):
        return BookCandidateSearchEvaluationProviderFailure(
          category: failure.category,
          retryAfter: failure.retryAfter,
        );
    }
  }

  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    return _selectCandidateInternal(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
      relink: false,
    );
  }

  Future<BookCandidateSelectionResult> relinkCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    final rejection = _validateOperationalRequest(item);
    if (rejection != null) {
      return BookCandidateSelectionRejected(rejection);
    }

    final existing = _repository.getByItemId(item.id);
    if (!BookMetadataMatchTransition.isProviderLinked(existing)) {
      return const BookCandidateSelectionRejected(
        'Relink requires an existing provider linkage.',
      );
    }
    return _selectCandidateInternal(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
      relink: true,
    );
  }

  Future<BookLinkTransitionResult> recordAmbiguousOutcome({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    bool replaceExistingLink = false,
  }) async {
    final rejection = _validateOperationalRequest(item);
    if (rejection != null) {
      return BookLinkTransitionRejected(rejection);
    }
    final contextRejection = _validateSelectionContext(item, context);
    if (contextRejection != null) {
      return BookLinkTransitionInvalidState(contextRejection);
    }
    if (!BookCandidateReviewPolicy.canRecordAmbiguousOutcome(context.matchSet)) {
      return const BookLinkTransitionRejected(
        'Ambiguous outcome requires an ambiguous or conflict-review evaluation set.',
      );
    }

    final existing = _repository.getByItemId(item.id);
    if (BookMetadataMatchTransition.isProviderLinked(existing) &&
        !replaceExistingLink) {
      return BookLinkTransitionPreserved(
        record: existing!,
        reason: 'Existing provider linkage retained.',
      );
    }

    final top = context.matchSet.topCandidate;
    if (top == null) {
      return const BookLinkTransitionRejected(
        'Ambiguous outcome requires at least one evaluated candidate.',
      );
    }

    final next = _transition.applyAmbiguous(
      existing: existing,
      itemId: item.id,
      providerId: context.providerId,
      topScore: top.finalScore,
      fetchedAt: _clock(),
    );
    return _persistTransition(next);
  }

  Future<BookLinkTransitionResult> recordNoMatchOutcome({
    required MediaItem item,
    required BookNoMatchPersistenceReason reason,
  }) async {
    final rejection = _validateOperationalRequest(item);
    if (rejection != null) {
      return BookLinkTransitionRejected(rejection);
    }

    final existing = _repository.getByItemId(item.id);
    if (BookMetadataMatchTransition.isProviderLinked(existing)) {
      return BookLinkTransitionPreserved(
        record: existing!,
        reason: 'Linked records require explicit unlink before recording unmatched.',
      );
    }

    switch (reason) {
      case BookNoMatchPersistenceReason.userSelectedNone:
      case BookNoMatchPersistenceReason.noReviewableCandidates:
        break;
    }

    final next = _transition.applyNoMatch(
      existing: existing,
      itemId: item.id,
      updatedAt: _clock(),
    );
    return _persistTransition(next);
  }

  Future<BookLinkTransitionResult> unlink({required MediaItem item}) async {
    final rejection = _validateBookItem(item);
    if (rejection != null) {
      return BookLinkTransitionRejected(rejection);
    }

    final existing = _repository.getByItemId(item.id);
    if (existing == null) {
      return const BookLinkTransitionInvalidState('No enrichment record to unlink.');
    }

    final next = _transition.applyUnlink(existing);
    return _persistTransition(next);
  }

  Future<BookLinkTransitionResult> ignore({required MediaItem item}) async {
    final rejection = _validateBookItem(item);
    if (rejection != null) {
      return BookLinkTransitionRejected(rejection);
    }

    final existing = _repository.getByItemId(item.id);
    final next = _transition.applyIgnoreForItem(
      existing: existing,
      itemId: item.id,
    );
    return _persistTransition(next);
  }

  Future<BookLinkTransitionResult> resumeMatching({required MediaItem item}) async {
    final rejection = _validateBookItem(item);
    if (rejection != null) {
      return BookLinkTransitionRejected(rejection);
    }

    final existing = _repository.getByItemId(item.id);
    if (existing == null) {
      return const BookLinkTransitionInvalidState('No enrichment record to resume.');
    }
    if (existing.matchState != EnrichmentMatchState.ignored) {
      return BookLinkTransitionInvalidState(
        'Resume matching is only valid from ignored state.',
      );
    }

    final next = _transition.applyResumeMatching(existing);
    return _persistTransition(next);
  }

  Future<BookCandidateSelectionResult> _selectCandidateInternal({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    required BookCandidateSelectionConfirmation confirmation,
    required bool relink,
  }) async {
    final rejection = _validateOperationalRequest(item);
    if (rejection != null) {
      return BookCandidateSelectionRejected(rejection);
    }
    final contextRejection = _validateSelectionContext(item, context);
    if (contextRejection != null) {
      return BookCandidateSelectionInvalidContext(contextRejection);
    }

    final evaluation = context.evaluationForRecordId(providerRecordId);
    if (evaluation == null) {
      return const BookCandidateSelectionInvalidContext(
        'Selection context does not contain the requested provider record.',
      );
    }
    if (!context.isReviewableRecord(providerRecordId)) {
      return const BookCandidateSelectionRejected(
        'Candidate is not reviewable for manual selection.',
      );
    }

    if (BookCandidateReviewPolicy.requiresCriticalConflictOverride(evaluation) &&
        confirmation != BookCandidateSelectionConfirmation.overrideCriticalConflicts) {
      return const BookCandidateSelectionConflictConfirmationRequired();
    }

    final fetchedAt = evaluation.candidate.metadata.fetchedAt;
    final existing = _repository.getByItemId(item.id);
    final MetadataEnrichmentRecord next;
    if (relink && existing != null) {
      next = _transition.applyRelink(
        existing: existing,
        metadata: evaluation.candidate.metadata,
        confidence: evaluation.finalScore,
        fetchedAt: fetchedAt,
      );
    } else {
      next = _transition.applyManualLink(
        existing: existing,
        itemId: item.id,
        metadata: evaluation.candidate.metadata,
        confidence: evaluation.finalScore,
        fetchedAt: fetchedAt,
      );
    }

    final save = await _repository.upsert(next);
    if (!save.success) {
      return BookCandidateSelectionRepositoryFailure(
        save.errorMessage ?? 'Could not save metadata enrichment.',
      );
    }
    return BookCandidateSelectionSuccess(next);
  }

  BookIsbnMatchResult _mapIsbnRefreshResult(BookMetadataRefreshResult result) {
    switch (result) {
      case BookMetadataRefreshSuccess(:final record):
        return BookIsbnMatchSuccess(record);
      case BookMetadataRefreshEmpty(:final record):
        return BookIsbnMatchNoResult(record: record);
      case BookMetadataRefreshConflict(:final existingRecord):
        return BookIsbnMatchConflict(existingRecord: existingRecord);
      case BookMetadataRefreshFailure(:final category, :final retryAfter):
        return BookIsbnMatchProviderFailure(
          category: category,
          retryAfter: retryAfter,
        );
      case BookMetadataRefreshRejected(:final reason):
        return BookIsbnMatchRejected(reason);
    }
  }

  Future<BookLinkTransitionResult> _persistTransition(
    MetadataEnrichmentRecord record,
  ) async {
    final save = await _repository.upsert(record);
    if (!save.success) {
      return BookLinkTransitionRepositoryFailure(
        save.errorMessage ?? 'Could not save metadata enrichment.',
      );
    }
    return BookLinkTransitionSuccess(record);
  }

  String? _validateBookItem(MediaItem item) {
    if (item.mediaKind != MediaKind.book) {
      return 'Metadata matching is supported for books only.';
    }
    return null;
  }

  String? _rejectIfIgnored(MediaItem item) {
    final existing = _repository.getByItemId(item.id);
    if (existing?.matchState == EnrichmentMatchState.ignored) {
      return 'Item is ignored. Resume matching before performing this operation.';
    }
    return null;
  }

  String? _validateOperationalRequest(MediaItem item) {
    final bookRejection = _validateBookItem(item);
    if (bookRejection != null) {
      return bookRejection;
    }
    return _rejectIfIgnored(item);
  }

  String? _validateSelectionContext(
    MediaItem item,
    BookCandidateSelectionContext context,
  ) {
    if (!context.matchesItem(item.id)) {
      return 'Selection context does not match the requested item.';
    }
    if (!context.matchesProvider(_provider.providerId)) {
      return 'Selection context does not match the active provider.';
    }
    return null;
  }

  LocalBookMatchInput _localInputFromItem(
    MediaItem item, {
    Iterable<String> trustedIsbn10 = const [],
    Iterable<String> trustedIsbn13 = const [],
  }) {
    final path = item.filePath;
    String? stem;
    if (path.isNotEmpty) {
      final normalized = path.replaceAll('\\', '/');
      final slash = normalized.lastIndexOf('/');
      final name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
      final dot = name.lastIndexOf('.');
      stem = dot > 0 ? name.substring(0, dot) : name;
    }

    return LocalBookMatchInput(
      itemId: item.id,
      title: item.title,
      authors: item.author == null || item.author!.trim().isEmpty
          ? const []
          : [item.author!.trim()],
      publicationYear: item.year,
      isbn10Values: trustedIsbn10.map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
      isbn13Values: trustedIsbn13.map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
      filenameStem: stem,
    );
  }
}
