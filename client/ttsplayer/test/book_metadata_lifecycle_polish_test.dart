import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_match_state_presentation.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';

import 'book_metadata_matching_coordinator_test.dart' show fakeCandidate;
import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';

Future<void> _pumpLinkedManual(
  WidgetTester tester,
  EnrichmentTestHarness harness, {
  String itemId = 'book-1',
  Map<String, EnrichmentFieldValue>? fields,
  List<String> lockedFields = const [],
}) async {
  await harness.repository.upsert(
    MetadataEnrichmentRecord(
      itemId: itemId,
      matchState: EnrichmentMatchState.linkedManual,
      providerId: 'fake_books',
      providerRecordId: '/books/LINKED',
      matchMethod: EnrichmentMatchMethod.manual,
      confidence: 0.9,
      fields: {
        EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
          value: 'Provider Title',
          source: EnrichmentFieldSource.provider,
        ),
        if (fields != null) ...fields,
      },
      lockedFields: lockedFields,
    ),
  );
  await tester.pumpWidget(
    enrichmentSectionHarness(
      item: enrichmentBookItem(id: itemId),
      repository: harness.repository,
      coordinator: harness.coordinator,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Book metadata lifecycle polish — unlink', () {
    testWidgets('linked item exposes Remove metadata link', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      expect(find.text('Remove metadata link'), findsOneWidget);
    });

    testWidgets('cancel leaves link intact', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await cancelConfirmDialog(tester);
      expect(find.text('Manually linked'), findsOneWidget);
    });

    testWidgets('confirm invokes one coordinator unlink write', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final coordinator = CountingTransitionCoordinator(
        provider: provider,
        repository: repository,
        refreshService: BookMetadataRefreshService(
          provider: provider,
          repository: repository,
        ),
        clock: () => DateTime.utc(2026, 7, 31, 12),
      );
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'fake_books',
          providerRecordId: '/books/LINKED',
        ),
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_unlink_confirm'),
      );
      expect(coordinator.unlinkInvocationCount, 1);
    });

    testWidgets('success moves to unmatched and clears provider linkage fields',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(
        tester,
        harness,
        fields: {
          EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
            value: 'User Title',
            source: EnrichmentFieldSource.userOverride,
          ),
        },
        lockedFields: const [EnrichmentBookFieldKeys.title],
      );
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_unlink_confirm'),
      );
      expect(find.text('No metadata match selected'), findsOneWidget);
      expect(find.text('Metadata link removed.'), findsOneWidget);
      final record = harness.repository.getByItemId('book-1')!;
      expect(record.matchState, EnrichmentMatchState.unmatched);
      expect(record.providerRecordId, isNull);
      expect(record.fields[EnrichmentBookFieldKeys.title]?.value, 'User Title');
    });

    testWidgets('repository failure retains linked state', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      harness.repository.simulatePersistFailure = true;
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_unlink_confirm'),
      );
      expect(find.text('Manually linked'), findsOneWidget);
      expect(find.text('Metadata could not be saved.'), findsOneWidget);
      expect(harness.provider.searchInvocationCount, 0);
    });
  });

  group('Book metadata lifecycle polish — ignore and resume', () {
    testWidgets('unmatched item exposes Ignore metadata matching', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ignore metadata matching'), findsOneWidget);
    });

    testWidgets('ignore confirm invokes one write and clears search state',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final coordinator = CountingTransitionCoordinator(
        provider: provider,
        repository: repository,
        refreshService: BookMetadataRefreshService(
          provider: provider,
          repository: repository,
        ),
        clock: () => DateTime.utc(2026, 7, 31, 12),
      );
      final harness = EnrichmentTestHarness(
        repository: repository,
        provider: provider,
        coordinator: coordinator,
      );
      provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/ACCEPT',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(author: 'Candidate Author'),
          repository: repository,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await tapSearchMetadata(tester);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_ignore')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_ignore_confirm'),
      );
      expect(coordinator.ignoreInvocationCount, 1);
      expect(find.text('Metadata suggestions ignored'), findsOneWidget);
      expect(find.text('Metadata matching ignored for this book.'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsNothing);
      expect(find.byKey(const Key('book_metadata_enrichment_search')), findsNothing);
    });

    testWidgets('resume restores searchable state without provider call',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final coordinator = CountingTransitionCoordinator(
        provider: provider,
        repository: repository,
        refreshService: BookMetadataRefreshService(
          provider: provider,
          repository: repository,
        ),
        clock: () => DateTime.utc(2026, 7, 31, 12),
      );
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.ignored,
        ),
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_resume')));
      await tester.pumpAndSettle();
      expect(coordinator.resumeInvocationCount, 1);
      expect(find.text('No metadata match selected'), findsOneWidget);
      expect(find.text('Metadata matching resumed.'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_search')), findsOneWidget);
      expect(provider.searchInvocationCount, 0);
    });
  });

  group('Book metadata lifecycle polish — rematch', () {
    testWidgets('linked item exposes Find different metadata', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      expect(find.text('Find different metadata'), findsOneWidget);
    });

    testWidgets('rematch search retains link until relink confirmation',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/NEW',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manually linked'), findsOneWidget);
      expect(harness.repository.getByItemId('book-1')!.providerRecordId,
          '/books/LINKED');
    });

    testWidgets('rematch candidate cancel retains existing link', (tester) async {
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
          recordId: '/books/NEW',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(author: 'Candidate Author'),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_cancel')));
      await tester.pumpAndSettle();
      expect(harness.repository.getByItemId('book-1')!.providerRecordId,
          '/books/LINKED');
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('rematch search failure retains link', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      harness.provider.searchResult = BookMetadataSearchFailure(
        const BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.networkUnavailable,
        ),
      );
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not reach the metadata service.'), findsOneWidget);
      expect(harness.repository.getByItemId('book-1')!.providerRecordId,
          '/books/LINKED');
    });
  });

  group('Book metadata lifecycle polish — item lifecycle', () {
    testWidgets('delayed unlink on book A does not update book B', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = FakeBookMetadataProvider();
      final coordinator = DelayedUnlinkCoordinator(
        provider: provider,
        repository: repository,
        refreshService: BookMetadataRefreshService(
          provider: provider,
          repository: repository,
        ),
        clock: () => DateTime.utc(2026, 7, 31, 12),
      );
      await repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-a',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'fake_books',
          providerRecordId: '/books/A',
        ),
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(id: 'book-a'),
          repository: repository,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_unlink_confirm'),
      );
      await tester.pump();
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(id: 'book-b'),
          repository: repository,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Not linked'), findsOneWidget);
      expect(find.text('Metadata link removed.'), findsNothing);
    });

    testWidgets('open rematch review on book A closes safely for book B',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-a',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'fake_books',
          providerRecordId: '/books/LINKED',
          matchMethod: EnrichmentMatchMethod.manual,
          confidence: 0.9,
        ),
      );
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/NEW',
          title: 'Local Title',
          authors: const ['Candidate Author'],
        ),
      ]);
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(id: 'book-a', author: 'Candidate Author'),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_change_metadata')),
      );
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(id: 'book-b'),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsNothing);
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('dispose during unlink confirm does not throw', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await _pumpLinkedManual(tester, harness);
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Book metadata lifecycle polish — action matrix', () {
    test('presentation actions match policy', () {
      expect(
        MetadataMatchStatePresentation.forState(EnrichmentMatchState.unmatched)
            .permits(MetadataEnrichmentAction.ignore),
        isTrue,
      );
      expect(
        MetadataMatchStatePresentation.forState(EnrichmentMatchState.linkedManual)
            .permits(MetadataEnrichmentAction.changeMetadata),
        isTrue,
      );
      expect(
        MetadataMatchStatePresentation.forState(EnrichmentMatchState.linkedManual)
            .permits(MetadataEnrichmentAction.ignore),
        isFalse,
      );
      expect(
        MetadataMatchStatePresentation.forState(EnrichmentMatchState.ignored)
            .permits(MetadataEnrichmentAction.resumeMatching),
        isTrue,
      );
    });
  });
}
