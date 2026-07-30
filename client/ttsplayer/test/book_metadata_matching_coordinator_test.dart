import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/book_candidate_evaluator.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/local_book_match_input.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/normalized_book_metadata.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_book_candidate.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_candidate_selection_context.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_item.dart' show MediaItemStatus;
import 'package:ttsplayer/models/media_kind.dart';

import 'support/metadata_enrichment_test_support.dart';

ProviderBookCandidate fakeCandidate({
  required String recordId,
  String title = 'Sample Title',
  List<String> authors = const ['Sample Author'],
  List<String> isbn13 = const [],
}) {
  return ProviderBookCandidate(
    metadata: NormalizedBookMetadata(
      providerId: 'fake_books',
      providerRecordId: recordId,
      editionId: recordId,
      canonicalTitle: title,
      authors: authors,
      isbn13Values: isbn13,
      fetchedAt: DateTime.utc(2026, 7, 30),
    ),
  );
}

MediaItem bookItem({String id = 'book-1', String? author}) {
  return MediaItem(
    id: id,
    title: 'Local Title',
    author: author,
    filePath: '/media/Books/sample.epub',
    status: MediaItemStatus.available,
    mediaKindRaw: MediaKind.book.catalogueValue,
  );
}

MediaItem videoItem() {
  return MediaItem(
    id: 'video-1',
    title: 'Video',
    filePath: '/media/Movies/sample.mp4',
    status: MediaItemStatus.available,
    mediaKindRaw: MediaKind.video.catalogueValue,
  );
}

BookCandidateSelectionContext successContext(
  BookCandidateSearchEvaluationResult result,
) {
  return (result as BookCandidateSearchEvaluationSuccess).selectionContext;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookMetadataMatchingCoordinator', () {
    late MetadataEnrichmentRepository repository;
    late FakeBookMetadataProvider provider;
    late BookMetadataMatchingCoordinator coordinator;
    late BookMetadataRefreshService refreshService;
    final clock = () => DateTime.utc(2026, 7, 30, 12);

    setUp(() async {
      repository = await initializedMetadataEnrichmentRepository();
      provider = FakeBookMetadataProvider();
      refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      coordinator = BookMetadataMatchingCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: clock,
      );
    });

    group('lookupByIsbn', () {
      test('exact lookup persists linkedByIdentifier', () async {
        provider.lookupResult = BookMetadataLookupSuccess(
          FakeBookMetadataProvider.sampleMetadata(),
        );

        final result = await coordinator.lookupByIsbn(
          item: bookItem(),
          isbnInput: '9780140449136',
        );

        expect(result, isA<BookIsbnMatchSuccess>());
        final record = repository.getByItemId('book-1')!;
        expect(record.matchState, EnrichmentMatchState.linkedByIdentifier);
        expect(provider.lookupInvocationCount, 1);
      });

      test('rejects ignored items without provider call', () async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.ignored,
          ),
        );

        final result = await coordinator.lookupByIsbn(
          item: bookItem(),
          isbnInput: '9780140449136',
        );

        expect(result, isA<BookIsbnMatchRejected>());
        expect(provider.lookupInvocationCount, 0);
      });

      test('ISBN conflict does not persist', () async {
        provider.lookupResult = BookMetadataLookupSuccess(
          FakeBookMetadataProvider.sampleMetadata(
            isbn13: const ['9780000000000'],
          ),
        );

        final result = await coordinator.lookupByIsbn(
          item: bookItem(),
          isbnInput: '9780140449136',
        );

        expect(result, isA<BookIsbnMatchConflict>());
        expect(repository.storedRecordCount, 0);
      });
    });

    group('ISBN parity with refresh service', () {
      test('linked and unlinked no-result behaviour matches refresh service', () async {
        provider.lookupResult = const BookMetadataLookupSuccess(null);

        final coordinatorResult = await coordinator.lookupByIsbn(
          item: bookItem(),
          isbnInput: '9780140449136',
        );
        expect(coordinatorResult, isA<BookIsbnMatchNoResult>());
        expect(repository.getByItemId('book-1')!.matchState,
            EnrichmentMatchState.unmatched);

        repository = await initializedMetadataEnrichmentRepository();
        provider = FakeBookMetadataProvider();
        refreshService = BookMetadataRefreshService(
          provider: provider,
          repository: repository,
        );
        coordinator = BookMetadataMatchingCoordinator(
          provider: provider,
          repository: repository,
          refreshService: refreshService,
          clock: clock,
        );
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.linkedByIdentifier,
            providerId: 'fake_books',
            providerRecordId: '/books/OL123M',
            matchMethod: EnrichmentMatchMethod.identifier,
            confidence: 1.0,
          ),
        );
        provider.lookupResult = const BookMetadataLookupSuccess(null);

        final linkedResult = await coordinator.lookupByIsbn(
          item: bookItem(),
          isbnInput: '9780140449136',
        );
        expect(linkedResult, isA<BookIsbnMatchNoResult>());
        expect(repository.getByItemId('book-1')!.matchState,
            EnrichmentMatchState.linkedByIdentifier);
      });

      test('locked fields preserved through shared refresh path', () async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.unmatched,
            fields: {
              EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
                value: 'User Title',
                source: EnrichmentFieldSource.userOverride,
              ),
            },
            lockedFields: const [EnrichmentBookFieldKeys.title],
          ),
        );
        provider.lookupResult = BookMetadataLookupSuccess(
          FakeBookMetadataProvider.sampleMetadata(title: 'Provider Title'),
        );

        await coordinator.lookupByIsbn(
          item: bookItem(),
          isbnInput: '9780140449136',
        );

        expect(
          repository.getByItemId('book-1')!.fields[EnrichmentBookFieldKeys.title]?.value,
          'User Title',
        );
      });
    });

    group('searchAndEvaluate result semantics', () {
      test('empty provider list returns NoProviderCandidates only', () async {
        provider.searchResult = const BookMetadataSearchSuccess([]);

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );

        expect(result, isA<BookCandidateSearchNoProviderCandidates>());
        expect(repository.storedRecordCount, 0);
      });

      test('one acceptable candidate returns Success', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/ACCEPT',
            title: 'Local Title',
            authors: const ['Candidate Author'],
          ),
        ]);

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(author: 'Candidate Author'),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );

        expect(result, isA<BookCandidateSearchEvaluationSuccess>());
        final success = result as BookCandidateSearchEvaluationSuccess;
        expect(success.hasAcceptableCandidates, isTrue);
        expect(success.hasReviewableCandidates, isTrue);
      });

      test('high-confidence candidate remains Success and transient', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/HIGH',
            title: 'Local Title',
            authors: const ['Candidate Author'],
          ),
        ]);

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(author: 'Candidate Author'),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );

        expect(result, isA<BookCandidateSearchEvaluationSuccess>());
        expect(repository.storedRecordCount, 0);
      });

      test('ISBN-conflict candidate returns Success with reviewable conflict candidate', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/ISBN-CONFLICT',
            title: 'The Republic',
            authors: const ['Plato'],
            isbn13: const ['0061120081'],
          ),
        ]);

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(author: 'Plato'),
          searchRequest: BookSearchRequest.create(title: 'The Republic'),
          localInputOverride: LocalBookMatchInput(
            itemId: 'book-1',
            title: 'The Republic',
            authors: const ['Plato'],
            isbn13Values: const ['9780140449136'],
          ),
        );

        expect(result, isA<BookCandidateSearchEvaluationSuccess>());
        final success = result as BookCandidateSearchEvaluationSuccess;
        expect(success.hasReviewableCandidates, isTrue);
        expect(success.requiresConflictReview, isTrue);
        expect(
          success.selectionContext.isReviewableRecord('/books/ISBN-CONFLICT'),
          isTrue,
        );
      });

      test('contradictory author below threshold returns Success with reviewable candidate', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/AUTHOR-CONFLICT',
            title: 'The Republic',
            authors: const ['Aristotle'],
          ),
        ]);

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(author: 'Plato'),
          searchRequest: BookSearchRequest.create(title: 'The Republic'),
          localInputOverride: LocalBookMatchInput(
            itemId: 'book-1',
            title: 'The Republic',
            authors: const ['Plato'],
            publicationYear: 2007,
          ),
        );

        expect(result, isA<BookCandidateSearchEvaluationSuccess>());
        final success = result as BookCandidateSearchEvaluationSuccess;
        expect(success.hasAcceptableCandidates, isFalse);
        expect(success.hasReviewableCandidates, isTrue);
        expect(success.requiresConflictReview, isTrue);
      });

      test('weak unrelated candidates return Success without reviewable candidates', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/WEAK',
            title: 'Completely Different Title',
            authors: const ['Other Author'],
          ),
        ]);

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(author: 'Local Author'),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );

        expect(result, isA<BookCandidateSearchEvaluationSuccess>());
        final success = result as BookCandidateSearchEvaluationSuccess;
        expect(success.hasReviewableCandidates, isFalse);
        expect(success.matchSet.rankedEvaluations, isNotEmpty);
      });

      test('rejects ignored items without provider call', () async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.ignored,
          ),
        );

        final result = await coordinator.searchAndEvaluate(
          item: bookItem(),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );

        expect(result, isA<BookCandidateSearchEvaluationRejected>());
        expect(provider.searchInvocationCount, 0);
      });
    });

    group('selectCandidate', () {
      Future<BookCandidateSelectionContext> acceptableContext() async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/SELECT',
            title: 'Local Title',
            authors: const ['Candidate Author'],
          ),
        ]);
        final result = await coordinator.searchAndEvaluate(
          item: bookItem(author: 'Candidate Author'),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );
        return successContext(result);
      }

      test('persists linkedManual with coordinator-owned confidence', () async {
        final context = await acceptableContext();

        final result = await coordinator.selectCandidate(
          item: bookItem(),
          context: context,
          providerRecordId: '/books/SELECT',
        );

        expect(result, isA<BookCandidateSelectionSuccess>());
        final record = (result as BookCandidateSelectionSuccess).record;
        expect(record.matchState, EnrichmentMatchState.linkedManual);
        expect(record.confidence, context.evaluationForRecordId('/books/SELECT')!.finalScore);
      });

      test('requires critical override for contradictory author candidate', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/CONFLICT',
            title: 'Local Title',
            authors: const ['Different Author'],
          ),
        ]);
        final search = await coordinator.searchAndEvaluate(
          item: bookItem(),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
          localInputOverride: LocalBookMatchInput(
            itemId: 'book-1',
            title: 'Local Title',
            authors: const ['Local Author'],
          ),
        );
        final context = successContext(search);

        expect(
          await coordinator.selectCandidate(
            item: bookItem(),
            context: context,
            providerRecordId: '/books/CONFLICT',
          ),
          isA<BookCandidateSelectionConflictConfirmationRequired>(),
        );

        expect(
          await coordinator.selectCandidate(
            item: bookItem(),
            context: context,
            providerRecordId: '/books/CONFLICT',
            confirmation: BookCandidateSelectionConfirmation.overrideCriticalConflicts,
          ),
          isA<BookCandidateSelectionSuccess>(),
        );
      });

      test('rejects non-reviewable weak candidate', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/WEAK',
            title: 'Unrelated Title',
            authors: const ['Other Author'],
          ),
        ]);
        final search = await coordinator.searchAndEvaluate(
          item: bookItem(),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );
        final context = successContext(search);

        final result = await coordinator.selectCandidate(
          item: bookItem(),
          context: context,
          providerRecordId: '/books/WEAK',
        );

        expect(result, isA<BookCandidateSelectionRejected>());
      });

      test('rejects invalid context for wrong item', () async {
        final context = await acceptableContext();

        final result = await coordinator.selectCandidate(
          item: bookItem(id: 'other-item'),
          context: context,
          providerRecordId: '/books/SELECT',
        );

        expect(result, isA<BookCandidateSelectionInvalidContext>());
      });

      test('rejects invalid context for unknown record id', () async {
        final context = await acceptableContext();

        final result = await coordinator.selectCandidate(
          item: bookItem(),
          context: context,
          providerRecordId: '/books/UNKNOWN',
        );

        expect(result, isA<BookCandidateSelectionInvalidContext>());
      });

      test('rejects selection after ignore using prior context', () async {
        final context = await acceptableContext();
        await coordinator.ignore(item: bookItem());

        final result = await coordinator.selectCandidate(
          item: bookItem(),
          context: context,
          providerRecordId: '/books/SELECT',
        );

        expect(result, isA<BookCandidateSelectionRejected>());
      });
    });

    group('explicit persistence outcomes', () {
      test('recordAmbiguousOutcome requires ambiguous evaluation set', () async {
        provider.searchResult = BookMetadataSearchSuccess([
          fakeCandidate(
            recordId: '/books/WEAK',
            title: 'Unrelated Title',
          ),
        ]);
        final search = await coordinator.searchAndEvaluate(
          item: bookItem(),
          searchRequest: BookSearchRequest.create(title: 'Local Title'),
        );
        final context = successContext(search);

        final result = await coordinator.recordAmbiguousOutcome(
          item: bookItem(),
          context: context,
        );

        expect(result, isA<BookLinkTransitionRejected>());
      });

      test('recordNoMatchOutcome requires bounded reason', () async {
        final result = await coordinator.recordNoMatchOutcome(
          item: bookItem(),
          reason: BookNoMatchPersistenceReason.userSelectedNone,
        );

        expect(result, isA<BookLinkTransitionSuccess>());
        expect(repository.getByItemId('book-1')!.matchState,
            EnrichmentMatchState.unmatched);
      });

      test('recordNoMatchOutcome preserves linked record', () async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.linkedManual,
            providerId: 'fake_books',
            providerRecordId: '/books/LINKED',
            matchMethod: EnrichmentMatchMethod.manual,
            confidence: 0.9,
          ),
        );

        final result = await coordinator.recordNoMatchOutcome(
          item: bookItem(),
          reason: BookNoMatchPersistenceReason.userSelectedNone,
        );

        expect(result, isA<BookLinkTransitionPreserved>());
      });
    });

    group('repository failure', () {
      test('returns failure and leaves prior record intact', () async {
        await repository.upsert(
          MetadataEnrichmentRecord(
            itemId: 'book-1',
            matchState: EnrichmentMatchState.unmatched,
          ),
        );
        repository.simulatePersistFailure = true;

        final result = await coordinator.recordNoMatchOutcome(
          item: bookItem(),
          reason: BookNoMatchPersistenceReason.noReviewableCandidates,
        );

        expect(result, isA<BookLinkTransitionRepositoryFailure>());
        expect(repository.getByItemId('book-1')!.matchState,
            EnrichmentMatchState.unmatched);
      });
    });
  });
}
