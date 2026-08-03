import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/matching/local_book_match_input.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_book_candidate.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_candidate_selection_context.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/widgets/book_metadata_candidate_dialog.dart';
import 'package:ttsplayer/models/media_item.dart';

import 'book_metadata_matching_coordinator_test.dart' show fakeCandidate;
import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';

class InvalidContextOnSelectCoordinator extends BookMetadataMatchingCoordinator {
  InvalidContextOnSelectCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  @override
  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    return const BookCandidateSelectionInvalidContext();
  }
}

class DelayedSelectCoordinator extends BookMetadataMatchingCoordinator {
  DelayedSelectCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  var selectInvocationCount = 0;

  @override
  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    selectInvocationCount++;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return super.selectCandidate(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
    );
  }
}

class ConflictBackstopCoordinator extends BookMetadataMatchingCoordinator {
  ConflictBackstopCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  var _firstSelect = true;

  @override
  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    if (_firstSelect && confirmation == BookCandidateSelectionConfirmation.normal) {
      _firstSelect = false;
      return const BookCandidateSelectionConflictConfirmationRequired();
    }
    return super.selectCandidate(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester,
  EnrichmentTestHarness harness, {
  MediaItem? item,
  Size viewport = const Size(1280, 800),
}) async {
  await tester.pumpWidget(
    enrichmentSectionHarness(
      item: item ?? enrichmentBookItem(),
      repository: harness.repository,
      coordinator: harness.coordinator,
      viewport: viewport,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _searchWithReviewableCandidates(
  WidgetTester tester,
  EnrichmentTestHarness harness, {
  List<ProviderBookCandidate>? candidates,
  MediaItem? item,
  Size viewport = const Size(1280, 800),
}) async {
  harness.provider.searchResult = BookMetadataSearchSuccess(
    candidates ??
        [
          fakeCandidate(
            recordId: '/books/ACCEPT',
            title: 'Local Title',
            authors: const ['Candidate Author'],
          ),
        ],
  );
  await _pumpHarness(tester, harness, item: item, viewport: viewport);
  await tapSearchMetadata(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Book metadata candidate selection', () {
    testWidgets('reviewable candidates appear after explicit search', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );

      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsOneWidget);
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('opening candidate dialog makes no additional provider calls',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );

      await tapReviewCandidates(tester);
      expect(harness.provider.searchInvocationCount, 1);
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);
    });

    testWidgets('weak candidates do not open review dialog', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/WEAK',
          title: 'Completely Different Title',
          authors: const ['Other Author'],
        ),
      ]);
      await _pumpHarness(tester, harness);
      await tapSearchMetadata(tester);

      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsNothing);
      expect(find.text('No suitable metadata candidates found.'), findsOneWidget);
    });

    testWidgets('candidate order follows ranked context', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/SECOND',
          title: 'Local Title',
          authors: const ['Second Author'],
        ),
        fakeCandidate(
          recordId: '/books/FIRST',
          title: 'Local Title',
          authors: const ['First Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(author: 'First Author'),
      );
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);

      final firstTitle = find.byKey(const Key('book_metadata_candidate_title__books_FIRST'));
      final secondTitle = find.byKey(const Key('book_metadata_candidate_title__books_SECOND'));
      expect(firstTitle, findsOneWidget);
      expect(secondTitle, findsOneWidget);
      expect(tester.getTopLeft(firstTitle).dy < tester.getTopLeft(secondTitle).dy,
          isTrue);
    });

    testWidgets('no candidate selected by default', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);

      final useButton =
          tester.widget<FilledButton>(find.byKey(const Key('book_metadata_candidate_use')));
      expect(useButton.onPressed, isNull);
    });

    testWidgets('selecting candidate does not persist', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');

      expect(harness.repository.storedRecordCount, 0);
    });

    testWidgets('successful selection persists linkedManual', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);

      expect(find.text('Manually linked'), findsOneWidget);
      expect(harness.repository.getByItemId('book-1')!.matchState,
          EnrichmentMatchState.linkedManual);
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('cancel candidate dialog does not persist', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tester.tap(find.byKey(const Key('book_metadata_candidate_cancel')));
      await tester.pumpAndSettle();

      expect(harness.repository.storedRecordCount, 0);
    });

    testWidgets('cancel final confirmation does not persist', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm_cancel')));
      await tester.pumpAndSettle();

      expect(harness.repository.storedRecordCount, 0);
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);
    });

    testWidgets('contradictory author displays critical warning', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/AUTHOR-CONFLICT',
          title: 'The Republic',
          authors: const ['Aristotle'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(title: 'The Republic', author: 'Plato'),
      );
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/AUTHOR-CONFLICT');
      await tapUseSelectedCandidate(tester);

      expect(find.textContaining('Author differs'), findsWidgets);
      expect(find.byKey(const Key('book_metadata_candidate_confirm')), findsNothing);
    });

    testWidgets('critical override persists manual link', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/CONFLICT',
          title: 'Local Title',
          authors: const ['Different Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Local Author'),
      );
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/CONFLICT');
      await tapUseSelectedCandidate(tester);
      await confirmCriticalOverride(tester);

      expect(find.text('Manually linked'), findsOneWidget);
      expect(harness.repository.getByItemId('book-1')!.matchState,
          EnrichmentMatchState.linkedManual);
    });

    testWidgets('coordinator backstop can open critical confirmation', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final coordinator = ConflictBackstopCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => DateTime.utc(2026, 7, 30, 12),
      );
      final harness = EnrichmentTestHarness(
        repository: repository,
        provider: provider,
        coordinator: coordinator,
      );

      provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/BACKSTOP',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/BACKSTOP');
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);

      expect(find.byKey(const Key('book_metadata_candidate_critical_confirm')),
          findsOneWidget);
      await confirmCriticalOverride(tester);
      expect(find.text('Manually linked'), findsOneWidget);
    });

    testWidgets('linked state uses relink and preserves link until confirmation',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedByIdentifier,
          providerId: 'fake_books',
          providerRecordId: '/books/LINKED',
          matchMethod: EnrichmentMatchMethod.identifier,
          confidence: 1.0,
        ),
      );
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/NEW',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);

      expect(find.text('Linked by ISBN'), findsOneWidget);
      await tapCandidateCard(tester, '/books/NEW');
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
      await tester.pumpAndSettle();

      expect(harness.repository.getByItemId('book-1')!.providerRecordId,
          '/books/NEW');
      expect(harness.repository.getByItemId('book-1')!.matchState,
          EnrichmentMatchState.linkedManual);
    });

    testWidgets('same-record relink reports already linked', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'fake_books',
          providerRecordId: '/books/LINKED',
          matchMethod: EnrichmentMatchMethod.manual,
          confidence: 0.9,
        ),
      );
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/LINKED',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/LINKED');
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Replace link'));
      await tester.pumpAndSettle();

      expect(find.text('This metadata is already linked.'), findsOneWidget);
    });

    testWidgets('invalid context closes with recovery message', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/ACCEPT',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      final search = await harness.coordinator.searchAndEvaluate(
        item: enrichmentBookItem(author: 'Candidate Author'),
        searchRequest: BookSearchRequest.create(title: 'Local Title'),
      );
      final selectionContext =
          (search as BookCandidateSearchEvaluationSuccess).selectionContext;

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      BookMetadataCandidateDialog.show(
        context: hostContext,
        item: enrichmentBookItem(id: 'other-item'),
        selectionContext: selectionContext,
        coordinator: harness.coordinator,
        isRelink: false,
      );
      await tester.pumpAndSettle();

      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);

      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsNothing);
    });

    testWidgets('invalid context recovery message shown in section', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final coordinator = InvalidContextOnSelectCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => DateTime.utc(2026, 7, 30, 12),
      );
      final harness = EnrichmentTestHarness(
        repository: repository,
        provider: provider,
        coordinator: coordinator,
      );

      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);

      expect(
        find.text('These metadata candidates are no longer valid. Search again.'),
        findsOneWidget,
      );
      expect(harness.repository.storedRecordCount, 0);
    });

    testWidgets('repository failure shows save message and retains prior state',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      harness.repository.simulatePersistFailure = true;
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);

      expect(find.text('Metadata could not be saved.'), findsOneWidget);
      expect(harness.repository.storedRecordCount, 0);
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('relink preserves user overrides', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'fake_books',
          providerRecordId: '/books/OLD',
          matchMethod: EnrichmentMatchMethod.manual,
          confidence: 0.9,
          fields: {
            EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
              value: 'User Title',
              source: EnrichmentFieldSource.userOverride,
            ),
          },
          lockedFields: const [EnrichmentBookFieldKeys.title],
        ),
      );
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/NEW',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/NEW');
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Replace link'));
      await tester.pumpAndSettle();

      final record = harness.repository.getByItemId('book-1')!;
      expect(record.fields[EnrichmentBookFieldKeys.title]?.value, 'User Title');
    });

    testWidgets('ISBN conflict displays critical warning', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/ISBN-CONFLICT',
          title: 'The Republic',
          authors: const ['Plato'],
          isbn13: const ['0061120081'],
        ),
      ]);
      final search = await harness.coordinator.searchAndEvaluate(
        item: enrichmentBookItem(title: 'The Republic', author: 'Plato'),
        searchRequest: BookSearchRequest.create(title: 'The Republic'),
        localInputOverride: const LocalBookMatchInput(
          itemId: 'book-1',
          title: 'The Republic',
          authors: ['Plato'],
          isbn13Values: ['9780140449136'],
        ),
      );
      final selectionContext =
          (search as BookCandidateSearchEvaluationSuccess).selectionContext;

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      BookMetadataCandidateDialog.show(
        context: hostContext,
        item: enrichmentBookItem(title: 'The Republic', author: 'Plato'),
        selectionContext: selectionContext,
        coordinator: harness.coordinator,
        isRelink: false,
      );
      await tester.pumpAndSettle();
      await tapCandidateCard(tester, '/books/ISBN-CONFLICT');

      expect(find.textContaining('ISBN does not match'), findsOneWidget);
    });

    testWidgets('non-critical warnings do not require critical override', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/EDITION',
          title: 'Local Title (Paperback)',
          authors: const ['Candidate Author'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(
          title: 'Local Title (Hardcover)',
          author: 'Candidate Author',
        ),
      );
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/EDITION');
      await tapUseSelectedCandidate(tester);

      expect(find.byKey(const Key('book_metadata_candidate_confirm')), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_candidate_critical_confirm')),
          findsNothing);
    });

    testWidgets('double confirm causes one coordinator selection write', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final coordinator = DelayedSelectCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => DateTime.utc(2026, 7, 30, 12),
      );
      final harness = EnrichmentTestHarness(
        repository: repository,
        provider: provider,
        coordinator: coordinator,
      );

      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
      await tester.pumpAndSettle();

      expect(coordinator.selectInvocationCount, 1);
    });

    testWidgets('changing item closes candidate dialog and clears book A state',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/BOOK-A',
          title: 'Book A Title',
          authors: const ['Author A'],
        ),
      ]);
      await _pumpHarness(
        tester,
        harness,
        item: enrichmentBookItem(
          id: 'book-a',
          title: 'Book A Title',
          author: 'Author A',
        ),
      );
      await tapSearchMetadata(tester);
      expect(harness.provider.searchInvocationCount, 1);

      await tapReviewCandidates(tester);
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);
      expect(find.text('Book A Title'), findsOneWidget);

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(
            id: 'book-b',
            title: 'Book B Title',
            author: 'Author B',
          ),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsNothing);
      expect(find.text('Book A Title'), findsNothing);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsNothing);
      expect(harness.repository.storedRecordCount, 0);
      expect(harness.provider.searchInvocationCount, 1);

      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/BOOK-B',
          title: 'Book B Title',
          authors: const ['Author B'],
        ),
      ]);
      await tapSearchMetadata(tester);
      expect(harness.provider.searchInvocationCount, 2);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsOneWidget);
    });

    testWidgets('delayed selection result from book A does not update book B',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final coordinator = DelayedSelectCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => DateTime.utc(2026, 7, 30, 12),
      );
      final harness = EnrichmentTestHarness(
        repository: repository,
        provider: provider,
        coordinator: coordinator,
      );

      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(id: 'book-a', author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, '/books/ACCEPT');
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);
      await tester.pump();

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(id: 'book-b', author: 'Other Author'),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('Not linked'), findsOneWidget);
      expect(find.text('Manually linked'), findsNothing);
      expect(harness.repository.getByItemId('book-b'), isNull);
      expect(
        find.byKey(const Key('book_metadata_enrichment_message')),
        findsNothing,
      );
    });

    testWidgets('disposing section during open candidate dialog does not throw',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
      );
      await tapReviewCandidates(tester);
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow candidate dialog has no overflow', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _searchWithReviewableCandidates(
        tester,
        harness,
        item: enrichmentBookItem(author: 'Candidate Author'),
        viewport: const Size(360, 640),
      );
      await tapReviewCandidates(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
