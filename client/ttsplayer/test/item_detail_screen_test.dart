import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';

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
