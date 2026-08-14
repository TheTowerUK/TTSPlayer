@Tags(['phase75-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/normalized_book_metadata.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_presentation_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_match_transition.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/models/search_result.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/search/widgets/search_result_row.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_presentation_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/resolved_media_artwork_image.dart';

import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';
import 'support/phase_736_metadata_fixtures.dart';
import 'support/phase_736_scripted_book_metadata_provider.dart';

/// Opt-in Windows validation for Phase 7.5 search/detail presentation.
///
/// ```powershell
/// $env:PHASE_75_RUNTIME='1'
/// flutter test test/phase_75_search_detail_windows_runtime_test.dart --tags phase75-runtime
/// Remove-Item Env:PHASE_75_RUNTIME
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_75_RUNTIME'] != '1') {
    test('skipped — set PHASE_75_RUNTIME=1 to run Phase 7.5 validation', () {},
        skip: true);
    return;
  }
  if (!Platform.isWindows) {
    test('skipped — Phase 7.5 runtime validation is Windows-only', () {},
        skip: true);
    return;
  }

  late MetadataEnrichmentRepository repository;
  late Phase736ScriptedBookMetadataProvider provider;
  late Stopwatch suiteTimer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = await initializedMetadataEnrichmentRepository();
    provider = Phase736ScriptedBookMetadataProvider();
    suiteTimer = Stopwatch()..start();
  });

  tearDown(() {
    suiteTimer.stop();
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('Phase 7.5.6 Windows runtime matrix complete: R1-R12 automated.');
  });

  testWidgets('R1 gate off and no records stays catalogue-only',
      (tester) async {
    final catalog = _catalog([Phase736Fixtures.bookA()]);
    final search = SearchService(enrichmentRepository: repository);
    final results = await _search(search, catalog, Phase736Fixtures.bookATitle);
    expect(results.single.item.id, Phase736Fixtures.bookAId);

    await tester.pumpWidget(itemDetailEnrichmentHarness(
      item: Phase736Fixtures.bookA(),
      repository: repository,
      config: MetadataEnrichmentFeatureConfig.defaults,
    ));
    await tester.pumpAndSettle();
    expect(find.text(Phase736Fixtures.bookATitle), findsWidgets);
    expect(
        find.byKey(const Key('item_detail_enriched_metadata')), findsNothing);
    expect(find.byKey(const Key('book_metadata_enrichment_section')),
        findsNothing);
    expect(provider.searchInvocationCount, 0);
    search.dispose();
  });

  test('R2 persisted linked ISBN is searchable', () async {
    await repository.upsert(_linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.title: _provider(Phase736Fixtures.bookATitle),
        EnrichmentBookFieldKeys.authors: _provider('Runtime ISBN Author'),
        EnrichmentBookFieldKeys.isbn13:
            _provider(jsonEncode(['9780306406157'])),
      },
    ));
    final search = SearchService(enrichmentRepository: repository);
    final results = await _search(
      search,
      _catalog([Phase736Fixtures.bookA()]),
      '978-0-306-40615-7',
    );
    expect(results.single.item.id, Phase736Fixtures.bookAId);
    expect(results.single.score, 70);
    expect(provider.searchInvocationCount, 0);
    search.dispose();
  });

  test('R3 exact catalogue title outranks enriched-author hit', () async {
    final authorHit = Phase736Fixtures.bookA();
    const exactTitle = MediaItem(
      id: 'm75-exact-title',
      title: 'Runtime Ranked Author',
      filePath: r'C:\Runtime\PHASE75\Books\exact.epub',
      mediaKindRaw: 'book',
    );
    await repository.upsert(_linkedRecord(
      itemId: authorHit.id,
      fields: {
        EnrichmentBookFieldKeys.authors: _provider('Runtime Ranked Author'),
      },
    ));
    final search = SearchService(enrichmentRepository: repository);
    final results = await _search(
      search,
      _catalog([authorHit, exactTitle]),
      'Runtime Ranked Author',
    );
    expect(
        results.map((result) => result.item.id), [exactTitle.id, authorHit.id]);
    expect(results.first.score, greaterThan(results.last.score));
    search.dispose();
  });

  testWidgets('R4 detail renders enriched fields and expands description',
      (tester) async {
    final description =
        List.filled(20, 'Runtime description content.').join(' ');
    await repository.upsert(_linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.subtitle: _provider('Runtime Subtitle'),
        EnrichmentBookFieldKeys.publishers:
            _provider(jsonEncode(['Runtime Press'])),
        EnrichmentBookFieldKeys.isbn13:
            _provider(jsonEncode(['9780306406157'])),
        EnrichmentBookFieldKeys.description: _provider(description),
      },
    ));
    await tester.pumpWidget(itemDetailEnrichmentHarness(
      item: Phase736Fixtures.bookA(),
      repository: repository,
      config: MetadataEnrichmentFeatureConfig.defaults,
      viewport: const Size(1280, 1400),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Runtime Subtitle'), findsOneWidget);
    expect(find.text('Runtime Press'), findsOneWidget);
    expect(find.text('9780306406157'), findsOneWidget);
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
    expect(provider.searchInvocationCount, 0);
  });

  test('R5 unlink removes provider search terms but retains override',
      () async {
    final linked = _linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.publishers: _provider('Removed Provider Term'),
        EnrichmentBookFieldKeys.title: _override('Retained Override Term'),
      },
    );
    await repository.upsert(linked);
    final search = SearchService(enrichmentRepository: repository);
    final catalog = _catalog([Phase736Fixtures.bookA()]);
    expect(
        await _search(search, catalog, 'Removed Provider Term'), hasLength(1));
    await repository.upsert(
      const BookMetadataMatchTransition().applyUnlink(linked),
    );
    expect(await _search(search, catalog, 'Removed Provider Term'), isEmpty);
    expect(
        await _search(search, catalog, 'Retained Override Term'), hasLength(1));
    search.dispose();
  });

  test('R6 ignore and resume make no provider call or provider keyword',
      () async {
    final linked = _linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.subjects: _provider('Ignored Provider Term'),
      },
    );
    const transitions = BookMetadataMatchTransition();
    final ignored = transitions.applyIgnore(linked);
    await repository.upsert(ignored);
    final search = SearchService(enrichmentRepository: repository);
    final catalog = _catalog([Phase736Fixtures.bookA()]);
    expect(await _search(search, catalog, 'Ignored Provider Term'), isEmpty);
    final resumed = transitions.applyResumeMatching(ignored);
    await repository.upsert(resumed);
    expect(resumed.matchState, EnrichmentMatchState.unmatched);
    expect(await _search(search, catalog, 'Ignored Provider Term'), isEmpty);
    expect(provider.searchInvocationCount, 0);
    search.dispose();
  });

  test('R7 relink replaces prior provider search keywords', () async {
    final linked = _linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.publishers: _provider('Old Runtime Press'),
      },
    );
    await repository.upsert(linked);
    final search = SearchService(enrichmentRepository: repository);
    final catalog = _catalog([Phase736Fixtures.bookA()]);
    expect(await _search(search, catalog, 'Old Runtime Press'), hasLength(1));
    final relinked = const BookMetadataMatchTransition().applyRelink(
      existing: linked,
      metadata: NormalizedBookMetadata(
        providerId: Phase736Fixtures.providerId,
        providerRecordId: '/books/M75-NEW',
        canonicalTitle: Phase736Fixtures.bookATitle,
        publishers: const ['New Runtime Press'],
        fetchedAt: Phase736Fixtures.fetchedAt,
      ),
      confidence: 0.95,
      fetchedAt: Phase736Fixtures.fetchedAt,
    );
    await repository.upsert(relinked);
    expect(await _search(search, catalog, 'Old Runtime Press'), isEmpty);
    expect(await _search(search, catalog, 'New Runtime Press'), hasLength(1));
    search.dispose();
  });

  test('R8 catalogue prune removes orphan search keywords', () async {
    await repository.upsert(_linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.subjects: _provider('Orphan Runtime Subject'),
      },
    ));
    final search = SearchService(enrichmentRepository: repository);
    final original = _catalog([Phase736Fixtures.bookA()]);
    expect(await _search(search, original, 'Orphan Runtime Subject'),
        hasLength(1));
    final replacement = _catalog([Phase736Fixtures.bookB()]);
    final validation = await repository.validateAgainstCatalog(replacement);
    expect(validation.removedCount, 1);
    search.onCatalogReplaced(replacement);
    expect(
        await _search(search, replacement, 'Orphan Runtime Subject'), isEmpty);
    search.dispose();
  });

  testWidgets('R9 search and detail rendering perform no provider calls',
      (tester) async {
    await repository.upsert(_linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.subtitle: _provider('Offline Runtime Subtitle'),
      },
    ));
    final search = SearchService(enrichmentRepository: repository);
    final refreshService = BookMetadataRefreshService(
      provider: provider,
      repository: repository,
    );
    final coordinator = BookMetadataMatchingCoordinator(
      provider: provider,
      repository: repository,
      refreshService: refreshService,
      clock: () => Phase736Fixtures.fetchedAt,
    );
    await _search(search, _catalog([Phase736Fixtures.bookA()]),
        'Offline Runtime Subtitle');
    await tester.pumpWidget(itemDetailEnrichmentHarness(
      item: Phase736Fixtures.bookA(),
      repository: repository,
      coordinator: coordinator,
      config: MetadataEnrichmentFeatureConfig.developmentEnabled,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Offline Runtime Subtitle'), findsOneWidget);
    expect(provider.searchInvocationCount, 0);
    search.dispose();
  });

  testWidgets('R10 search row and detail retain resolved artwork widget path',
      (tester) async {
    final item = Phase736Fixtures.bookA();
    await tester.pumpWidget(_searchRowHarness(item, repository));
    await tester.pumpAndSettle();
    expect(find.byType(ResolvedMediaArtworkImage), findsOneWidget);

    await tester.pumpWidget(itemDetailEnrichmentHarness(
      item: item,
      repository: repository,
      config: MetadataEnrichmentFeatureConfig.defaults,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ResolvedMediaArtworkImage), findsOneWidget);
  });

  testWidgets('R11 non-book search and detail remain unchanged',
      (tester) async {
    final video = Phase736Fixtures.videoItem();
    await repository.upsert(_linkedRecord(
      itemId: video.id,
      fields: {
        EnrichmentBookFieldKeys.title: _override('Must Not Leak'),
      },
    ));
    final search = SearchService(enrichmentRepository: repository);
    final results = await _search(search, _catalog([video]), video.title);
    expect(results.single.item.title, video.title);
    expect(await _search(search, _catalog([video]), 'Must Not Leak'), isEmpty);
    await tester.pumpWidget(itemDetailEnrichmentHarness(
      item: video,
      repository: repository,
      config: MetadataEnrichmentFeatureConfig.developmentEnabled,
    ));
    await tester.pumpAndSettle();
    expect(find.text(video.title), findsWidgets);
    expect(find.text('Must Not Leak'), findsNothing);
    expect(find.byKey(const Key('book_metadata_enrichment_section')),
        findsNothing);
    search.dispose();
  });

  test('R12 app restart reload keeps persisted enrichment searchable',
      () async {
    await repository.upsert(_linkedRecord(
      itemId: Phase736Fixtures.bookAId,
      fields: {
        EnrichmentBookFieldKeys.isbn13:
            _provider(jsonEncode(['9780306406157'])),
      },
    ));
    final reloaded = MetadataEnrichmentRepository();
    await reloaded.initialize();
    final search = SearchService(enrichmentRepository: reloaded);
    final results = await _search(
      search,
      _catalog([Phase736Fixtures.bookA()]),
      '9780306406157',
    );
    expect(results.single.item.id, Phase736Fixtures.bookAId);
    expect(provider.searchInvocationCount, 0);
    search.dispose();
  });
}

Catalog _catalog(List<MediaItem> items) => Catalog.fromJson({
      'generated_at': '2026-08-14T10:00:00+00:00',
      'total_items': items.length,
      'catalogue': {
        'id': Phase736Fixtures.catalogIdentity,
        'catalogue_version': 3,
      },
      'folders': [
        {
          'id': 'phase75-library',
          'name': 'Runtime Library',
          'path': r'C:\Runtime\PHASE75',
          'item_count': items.length,
          'items': items.map((item) => item.toJson()).toList(),
          'subfolders': [],
        },
      ],
    });

Future<List<SearchResult>> _search(
  SearchService service,
  Catalog catalog,
  String query,
) =>
    service.searchCatalog(catalog, query, const SearchFilters.empty());

MetadataEnrichmentRecord _linkedRecord({
  required String itemId,
  required Map<String, EnrichmentFieldValue> fields,
}) =>
    MetadataEnrichmentRecord(
      itemId: itemId,
      matchState: EnrichmentMatchState.linkedManual,
      providerId: Phase736Fixtures.providerId,
      providerRecordId: '/books/M75-RUNTIME',
      fields: fields,
      fetchedAt: Phase736Fixtures.fetchedAt,
    );

EnrichmentFieldValue _provider(String value) => EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.provider,
      providerId: Phase736Fixtures.providerId,
    );

EnrichmentFieldValue _override(String value) => EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.userOverride,
    );

Widget _searchRowHarness(
  MediaItem item,
  MetadataEnrichmentRepository repository,
) {
  final artworkService = ArtworkService(fileExists: (_) => false);
  final artworkPresentation = ArtworkPresentationService(
    artworkService: artworkService,
    enrichmentRepository: repository,
  );
  final presentation = const MetadataPresentationService().build(
    item: item,
    record: repository.getByItemId(item.id),
  );
  return MultiProvider(
    providers: [
      Provider<ArtworkService>.value(value: artworkService),
      Provider<ArtworkPresentationService?>.value(value: artworkPresentation),
      Provider<MediaLocationResolver>.value(
        value: const NonLoadingMediaLocationResolver(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SearchResultRow(
          result: SearchResult(
            item: item,
            libraryName: 'Runtime Library',
            parentFolderName: 'Books',
            parentFolderPath: r'C:\Runtime\PHASE75\Books',
            score: 100,
          ),
          presentation: presentation,
          displayContext: 'Runtime Library · Books',
          onOpen: () {},
        ),
      ),
    ),
  );
}
