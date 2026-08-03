import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_match_state_presentation.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_provider_presentation.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_failure.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';

import 'book_metadata_matching_coordinator_test.dart' show fakeCandidate;
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookMetadataEnrichmentSection gate', () {
    testWidgets('section hidden when gate off', (tester) async {
      final harness = await EnrichmentTestHarness.create(
        config: MetadataEnrichmentFeatureConfig.defaults,
      );

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
          config: MetadataEnrichmentFeatureConfig.defaults,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsNothing);
      expect(harness.provider.lookupInvocationCount, 0);
      expect(harness.provider.searchInvocationCount, 0);
    });

    testWidgets('section shown when gate on for books', (tester) async {
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsOneWidget);
      expect(find.text('Not linked'), findsOneWidget);
      expect(harness.provider.lookupInvocationCount, 0);
      expect(harness.provider.searchInvocationCount, 0);
    });

    testWidgets('non-book item never shows section', (tester) async {
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentVideoItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsNothing);
    });
  });

  group('BookMetadataEnrichmentSection match states', () {
    Future<EnrichmentTestHarness> pumpWithRecord(
      WidgetTester tester,
      MetadataEnrichmentRecord record,
    ) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(record);
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(id: record.itemId),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('unmatched shows lookup and search actions', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );

      expect(find.text('No metadata match selected'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_lookup_isbn')),
          findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_search')),
          findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_ignore')),
          findsOneWidget);
    });

    testWidgets('linked by identifier shows attribution and unlink', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedByIdentifier,
          providerId: 'open_library',
          providerRecordId: '/books/OL123M',
          matchMethod: EnrichmentMatchMethod.identifier,
          confidence: 1.0,
          fetchedAt: DateTime.utc(2026, 7, 30),
        ),
      );

      expect(find.text('Linked by ISBN'), findsOneWidget);
      expect(find.text('Metadata from Open Library'), findsOneWidget);
      expect(find.text('Metadata fetched 2026-07-30'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_change_metadata')),
          findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_unlink')),
          findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_ignore')), findsNothing);
    });

    testWidgets('linked manually shows attribution', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'fake_books',
          providerRecordId: '/books/MANUAL',
          matchMethod: EnrichmentMatchMethod.manual,
          confidence: 0.9,
          fetchedAt: DateTime.utc(2026, 7, 30),
        ),
      );

      expect(find.text('Manually linked'), findsOneWidget);
      expect(find.text('Metadata from Fake Books'), findsOneWidget);
    });

    testWidgets('linked high confidence renders safely', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedHighConfidence,
          providerId: 'fake_books',
          providerRecordId: '/books/AUTO',
          matchMethod: EnrichmentMatchMethod.automatic,
          confidence: 0.92,
        ),
      );

      expect(find.text('Automatically linked'), findsOneWidget);
    });

    testWidgets('ambiguous shows review required state', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.ambiguous,
        ),
      );

      expect(find.text('Metadata review required'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsNothing);
    });

    testWidgets('ignored hides lookup and search', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.ignored,
        ),
      );

      expect(find.text('Metadata suggestions ignored'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_lookup_isbn')),
          findsNothing);
      expect(find.byKey(const Key('book_metadata_enrichment_search')),
          findsNothing);
      expect(find.byKey(const Key('book_metadata_enrichment_resume')),
          findsOneWidget);
    });

    testWidgets('stale shows bounded stale message', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.stale,
          providerId: 'fake_books',
          providerRecordId: '/books/STALE',
        ),
      );

      expect(find.text('Metadata link may be stale'), findsOneWidget);
    });

    testWidgets('unknown provider degrades gracefully', (tester) async {
      await pumpWithRecord(
        tester,
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.linkedManual,
          providerId: 'unknown_provider_xyz',
          providerRecordId: '/books/UNK',
        ),
      );

      expect(
        MetadataProviderPresentation.forProviderId('unknown_provider_xyz')
            .displayName,
        'External metadata provider',
      );
      expect(find.text('External metadata provider'), findsNothing);
      expect(find.text('Manually linked'), findsOneWidget);
    });
  });

  group('BookMetadataEnrichmentSection ISBN flow', () {
    testWidgets('opening dialog makes no provider call', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      expect(harness.provider.lookupInvocationCount, 0);
    });

    testWidgets('cancel makes no provider call', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await cancelIsbnDialog(tester);
      expect(harness.provider.lookupInvocationCount, 0);
    });

    testWidgets('invalid ISBN rejected without provider call', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: 'not-an-isbn');
      expect(harness.provider.lookupInvocationCount, 0);
      expect(
        find.text('Enter a valid ISBN-10 or ISBN-13.'),
        findsOneWidget,
      );
    });

    testWidgets('valid ISBN invokes provider once and refreshes state',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.lookupResult = BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(),
      );

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: '9780140449136');
      expect(harness.provider.lookupInvocationCount, 1);
      expect(find.text('Linked by ISBN'), findsOneWidget);
      expect(find.text('Metadata linked by ISBN.'), findsOneWidget);
    });

    testWidgets('no result displays bounded message', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.lookupResult = const BookMetadataLookupSuccess(null);

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: '9780140449136');
      expect(find.text('No matching book found for that ISBN.'), findsOneWidget);
      expect(find.text('No metadata match selected'), findsOneWidget);
    });

    testWidgets('linked no-result preserves existing link', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.stale,
          providerId: 'fake_books',
          providerRecordId: '/books/LINKED',
          matchMethod: EnrichmentMatchMethod.identifier,
          confidence: 1.0,
        ),
      );
      harness.provider.lookupResult = const BookMetadataLookupSuccess(null);

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: '9780140449136');
      expect(find.text('Metadata link may be stale'), findsOneWidget);
      expect(find.text('No matching book found for that ISBN.'), findsOneWidget);
    });

    testWidgets('conflict displays bounded message', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.lookupResult = BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(
          isbn13: const ['9780000000000'],
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

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: '9780140449136');
      expect(
        find.textContaining('did not confirm this ISBN'),
        findsOneWidget,
      );
    });

    testWidgets('provider failure displays bounded error', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.lookupResult = BookMetadataLookupFailure(
        BookMetadataProviderFailure(
          category: BookMetadataProviderFailureCategory.networkUnavailable,
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

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: '9780140449136');
      expect(
        find.text('Could not reach the metadata service.'),
        findsOneWidget,
      );
    });

    testWidgets('repository failure does not display success', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.lookupResult = BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(),
      );
      harness.repository.simulatePersistFailure = true;

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await submitIsbnDialog(tester, isbn: '9780140449136');
      expect(find.text('Metadata could not be saved.'), findsOneWidget);
      expect(find.text('Metadata linked by ISBN.'), findsNothing);
      expect(find.text('Not linked'), findsOneWidget);
    });

    testWidgets('repeated taps during loading do not duplicate provider calls',
        (tester) async {
      final hangingProvider = HangingSearchFakeBookMetadataProvider();
      final harness = await EnrichmentTestHarness.create(
        provider: hangingProvider,
      );

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pump();

      expect(hangingProvider.searchInvocationCount, 1);
      hangingProvider.completeSearch(const BookMetadataSearchSuccess([]));
      await tester.pumpAndSettle();
      expect(hangingProvider.searchInvocationCount, 1);
    });
  });

  group('BookMetadataEnrichmentSection search flow', () {
    testWidgets('explicit tap invokes search once', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = const BookMetadataSearchSuccess([]);

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pumpAndSettle();

      expect(harness.provider.searchInvocationCount, 1);
      expect(find.text('No metadata candidates found.'), findsOneWidget);
    });

    testWidgets('acceptable manual-review result is not shown as no candidates',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/ACCEPT',
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

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pumpAndSettle();

      expect(find.text('No metadata candidates found.'), findsNothing);
      expect(
        find.text('Metadata candidates are available for review.'),
        findsOneWidget,
      );
      expect(harness.repository.storedRecordCount, 0);
    });

    testWidgets('search evaluation remains transient for strong candidates',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/HIGH',
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

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pumpAndSettle();

      expect(find.text('No metadata candidates found.'), findsNothing);
      expect(
        find.byKey(const Key('book_metadata_enrichment_review_candidates')),
        findsOneWidget,
      );
      expect(harness.repository.storedRecordCount, 0);
    });

    testWidgets('conflict result shows review required summary', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/AUTHOR-CONFLICT',
          title: 'The Republic',
          authors: const ['Aristotle'],
        ),
      ]);

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(title: 'The Republic', author: 'Plato'),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pumpAndSettle();

      expect(find.text('Metadata review is required.'), findsOneWidget);
      expect(harness.repository.storedRecordCount, 0);
    });

    testWidgets('weak candidates offer mark as no match', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/WEAK',
          title: 'Completely Different Title',
          authors: const ['Other Author'],
        ),
      ]);

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(author: 'Local Author'),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pumpAndSettle();

      expect(
        find.text('No suitable metadata candidates found.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('book_metadata_enrichment_mark_no_match')),
          findsOneWidget);

      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_mark_no_match')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No metadata match selected'), findsOneWidget);
    });

    testWidgets('change metadata preserves current link', (tester) async {
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

      expect(find.text('Linked by ISBN'), findsOneWidget);
      expect(
        find.textContaining('Existing link retained'),
        findsOneWidget,
      );
      expect(harness.repository.getByItemId('book-1')!.matchState,
          EnrichmentMatchState.linkedByIdentifier);
    });
  });

  group('BookMetadataEnrichmentSection transitions', () {
    testWidgets('unlink cancel makes no change', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
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
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await cancelConfirmDialog(tester);

      expect(find.text('Manually linked'), findsOneWidget);
    });

    testWidgets('unlink success refreshes to unmatched', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
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
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmDialog(tester, 'Unlink');

      expect(find.text('No metadata match selected'), findsOneWidget);
    });

    testWidgets('ignore success displays ignored', (tester) async {
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

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_ignore')));
      await tester.pumpAndSettle();
      await confirmDialog(tester, 'Ignore');

      expect(find.text('Metadata suggestions ignored'), findsOneWidget);
    });

    testWidgets('resume matching displays unmatched without provider call',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.ignored,
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

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_resume')));
      await tester.pumpAndSettle();

      expect(find.text('No metadata match selected'), findsOneWidget);
      expect(harness.provider.lookupInvocationCount, 0);
      expect(harness.provider.searchInvocationCount, 0);
    });

    testWidgets('linked state does not expose ignore action', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
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
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_ignore')), findsNothing);
    });

    testWidgets('repository failure leaves prior state visible', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      await harness.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: 'book-1',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );
      harness.repository.simulatePersistFailure = true;

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_ignore')));
      await tester.pumpAndSettle();
      await confirmDialog(tester, 'Ignore');

      expect(find.text('No metadata match selected'), findsOneWidget);
      expect(find.text('Metadata could not be saved.'), findsOneWidget);
    });
  });

  group('BookMetadataEnrichmentSection candidate review', () {
    testWidgets('review candidates opens selection dialog', (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/ACCEPT',
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

      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);

      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);
      expect(find.text('Review metadata candidates'), findsOneWidget);
    });
  });

  group('BookMetadataEnrichmentSection concurrency and layout', () {
    testWidgets('actions disabled while loading', (tester) async {
      final hangingProvider = HangingSearchFakeBookMetadataProvider();
      final harness = await EnrichmentTestHarness.create(
        provider: hangingProvider,
      );

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      hangingProvider.completeSearch(const BookMetadataSearchSuccess([]));
      await tester.pumpAndSettle();
      expect(hangingProvider.searchInvocationCount, 1);
    });

    testWidgets('widget disposal during pending call produces no exception',
        (tester) async {
      final harness = await EnrichmentTestHarness.create();
      harness.provider.lookupResult = BookMetadataLookupSuccess(
        FakeBookMetadataProvider.sampleMetadata(),
      );

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await openIsbnDialog(tester);
      await tester.enterText(
        find.byKey(const Key('book_metadata_enrichment_isbn_field')),
        '9780140449136',
      );
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_isbn_submit')),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at narrow width', (tester) async {
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: harness.repository,
          coordinator: harness.coordinator,
          viewport: const Size(320, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('book_metadata_enrichment_status')),
          findsOneWidget);
    });
  });

  group('MetadataMatchStatePresentation', () {
    test('covers all enrichment match states', () {
      for (final state in EnrichmentMatchState.values) {
        final presentation = MetadataMatchStatePresentation.forState(state);
        expect(presentation.label, isNotEmpty);
        expect(presentation.explanation, isNotEmpty);
      }
      expect(MetadataMatchStatePresentation.forNoRecord().label, 'Not linked');
    });
  });
}
