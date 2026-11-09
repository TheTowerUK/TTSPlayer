import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'book_metadata_matching_coordinator_test.dart' show fakeCandidate;
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/widgets/artwork/resolved_media_artwork_image.dart';

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

      expect(find.byKey(const Key('book_metadata_enrichment_section')),
          findsNothing);
    });

    testWidgets('enrichment section shown for books when gate on',
        (tester) async {
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

      expect(find.byKey(const Key('book_metadata_enrichment_section')),
          findsOneWidget);
      expect(find.text('Not linked'), findsOneWidget);
    });

    testWidgets('book detail can open candidate review when gate on',
        (tester) async {
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

      expect(find.byKey(const Key('book_metadata_candidate_dialog')),
          findsOneWidget);
      expect(harness.provider.searchInvocationCount, 1);
    });

    testWidgets('video detail does not show enrichment section',
        (tester) async {
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

      expect(find.byKey(const Key('book_metadata_enrichment_section')),
          findsNothing);
    });

    testWidgets('video detail poster stays landscape cover', (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final harness = await EnrichmentTestHarness.create();

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentVideoItem(),
          repository: repository,
          coordinator: harness.coordinator,
          config: MetadataEnrichmentFeatureConfig.defaults,
        ),
      );
      await tester.pumpAndSettle();

      final poster = tester.widget<AspectRatio>(
        find.byKey(const Key('item_detail_poster')),
      );
      expect(poster.aspectRatio, closeTo(16 / 9, 0.001));
      final artwork = tester.widget<ResolvedMediaArtworkImage>(
        find.byType(ResolvedMediaArtworkImage),
      );
      expect(artwork.fit, BoxFit.cover);
    });
  });

  group('ItemDetailScreen metadata presentation', () {
    testWidgets(
        'accepted metadata fills missing book detail fields with gate off',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_record(
        fields: {
          EnrichmentBookFieldKeys.title: _providerField('Provider Title'),
          EnrichmentBookFieldKeys.subtitle:
              _providerField('A Provider Subtitle'),
          EnrichmentBookFieldKeys.authors:
              _providerField(jsonEncode(['Provider Author'])),
          EnrichmentBookFieldKeys.publishers:
              _providerField(jsonEncode(['Example Press'])),
          EnrichmentBookFieldKeys.publicationYear: _providerField('2024'),
          EnrichmentBookFieldKeys.isbn13:
              _providerField(jsonEncode(['9780306406157'])),
          EnrichmentBookFieldKeys.subjects:
              _providerField(jsonEncode(['History', 'Biography'])),
          EnrichmentBookFieldKeys.description:
              _providerField('A persisted provider description.'),
        },
      ));

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentBookItem(title: 'Local Title'),
          repository: repository,
          config: MetadataEnrichmentFeatureConfig.defaults,
          viewport: const Size(1280, 1400),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('item_detail_enriched_metadata')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('item_detail_display_title')))
            .data,
        'Local Title',
      );
      expect(find.text('Provider Title'), findsNothing);
      expect(find.text('Provider Author'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('A Provider Subtitle'), findsOneWidget);
      expect(find.text('Example Press'), findsOneWidget);
      expect(find.text('9780306406157'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Biography'), findsOneWidget);
      expect(find.text('A persisted provider description.'), findsOneWidget);
      expect(find.text('Metadata from Open Library'), findsWidgets);
      expect(
        find.byKey(const Key('book_metadata_enrichment_section')),
        findsNothing,
      );
    });

    testWidgets('overrides remain visible in ignored state and refresh live',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_record(
        matchState: EnrichmentMatchState.ignored,
        fields: {
          EnrichmentBookFieldKeys.title: _overrideField('Override Title'),
          EnrichmentBookFieldKeys.authors:
              _overrideField(jsonEncode(['Override Author'])),
          EnrichmentBookFieldKeys.subtitle: _overrideField('Override Subtitle'),
        },
      ));

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item:
              enrichmentBookItem(title: 'Local Title', author: 'Local Author'),
          repository: repository,
          viewport: const Size(1280, 1200),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('item_detail_display_title')))
            .data,
        'Override Title',
      );
      expect(find.text('Override Author'), findsOneWidget);
      expect(find.text('Override Subtitle'), findsOneWidget);
      expect(find.text('Your override'), findsOneWidget);

      await repository.remove('book-1');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('item_detail_display_title')))
            .data,
        'Local Title',
      );
      expect(find.text('Local Author'), findsOneWidget);
      expect(find.text('Override Subtitle'), findsNothing);
      expect(
        find.byKey(const Key('item_detail_enriched_metadata')),
        findsNothing,
      );
    });

    testWidgets('provider fields stay hidden outside accepted linked states',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_record(
        matchState: EnrichmentMatchState.ambiguous,
        fields: {
          EnrichmentBookFieldKeys.subtitle: _providerField('Hidden Subtitle'),
          EnrichmentBookFieldKeys.description:
              _providerField('Hidden Description'),
        },
      ));

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentBookItem(),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hidden Subtitle'), findsNothing);
      expect(find.text('Hidden Description'), findsNothing);
      expect(
        find.byKey(const Key('item_detail_enriched_metadata')),
        findsNothing,
      );
    });

    testWidgets('description expands and collapses without overflow',
        (tester) async {
      final repository = await initializedMetadataEnrichmentRepository();
      final description = List.filled(
        30,
        'A long persisted description for responsive layout testing.',
      ).join(' ');
      await repository.upsert(_record(
        fields: {
          EnrichmentBookFieldKeys.description: _providerField(description),
        },
      ));

      await tester.pumpWidget(
        itemDetailEnrichmentHarness(
          item: enrichmentBookItem(),
          repository: repository,
          viewport: const Size(360, 900),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder =
          find.byKey(const Key('item_detail_metadata_description'));
      expect(tester.widget<Text>(descriptionFinder).maxLines, 4);
      await tester.scrollUntilVisible(
        find.byKey(const Key('item_detail_metadata_description_toggle')),
        120,
      );
      await tester.tap(
        find.byKey(const Key('item_detail_metadata_description_toggle')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(descriptionFinder).maxLines, isNull);
      expect(find.text('Show less'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('item_detail_metadata_description_toggle')),
        120,
      );
      await tester.tap(
        find.byKey(const Key('item_detail_metadata_description_toggle')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(descriptionFinder).maxLines, 4);
      expect(tester.takeException(), isNull);
    });
  });
}

MetadataEnrichmentRecord _record({
  EnrichmentMatchState matchState = EnrichmentMatchState.linkedManual,
  Map<String, EnrichmentFieldValue> fields = const {},
}) {
  return MetadataEnrichmentRecord(
    itemId: 'book-1',
    matchState: matchState,
    providerId: 'open_library',
    providerRecordId: '/works/OL1W',
    fields: fields,
  );
}

EnrichmentFieldValue _providerField(String value) => EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.provider,
      providerId: 'open_library',
    );

EnrichmentFieldValue _overrideField(String value) => EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.userOverride,
    );
