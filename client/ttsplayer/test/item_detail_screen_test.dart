import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'book_metadata_matching_coordinator_test.dart' show fakeCandidate;
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ItemDetailScreen metadata enrichment integration', () {
    testWidgets('enrichment section hidden when gate off', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: harness.coordinator,
          config: MetadataEnrichmentFeatureConfig.defaults,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsNothing);
    });

    testWidgets('enrichment section shown for books when gate on', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentBookItem(title: 'Test Book', author: 'Author'),
          repository: repository,
          coordinator: harness.coordinator,
          config: MetadataEnrichmentFeatureConfig.developmentEnabled,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsOneWidget);
      expect(find.text('Not linked'), findsOneWidget);
    });

    testWidgets('book detail can open candidate review when gate on', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final harness = await EnrichmentTestHarness.create();
      harness.provider.searchResult = BookMetadataSearchSuccess([
        fakeCandidate(
          recordId: '/books/ACCEPT',
          title: 'Test Book',
          authors: const ['Author'],
        ),
      ]);

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentBookItem(title: 'Test Book', author: 'Author'),
          repository: repository,
          coordinator: harness.coordinator,
          config: MetadataEnrichmentFeatureConfig.developmentEnabled,
          viewport: const Size(1280, 1200),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('book_metadata_enrichment_search')),
        100,
      );
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);

      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('video detail does not show enrichment section', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentVideoItem(),
          repository: repository,
          coordinator: harness.coordinator,
          config: MetadataEnrichmentFeatureConfig.developmentEnabled,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsNothing);
    });
  });
}
