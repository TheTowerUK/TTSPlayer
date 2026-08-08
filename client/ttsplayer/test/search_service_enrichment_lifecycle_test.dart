import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';

Catalog _catalogWithBook({String identity = 'cat-lifecycle-1'}) {
  final item = MediaItem(
    id: 'lifecycle-item',
    title: 'Lifecycle Book',
    filePath: r'Y:\Media\Books\lifecycle-item.epub',
    mediaKindRaw: MediaKind.book.catalogueValue,
  );
  return Catalog.fromJson({
    'generated_at': '2026-08-06T00:00:00+00:00',
    'total_items': 1,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.8.0',
      'catalogue_version': 4,
    },
    'folders': [
      MediaFolder(
        id: 'lib-main',
        name: 'Books',
        path: r'Y:\Media\Books',
        itemCount: 1,
        items: [item],
        subfolders: const [],
      ).toJson(),
    ],
  });
}

MetadataEnrichmentRecord _linkedRecord({
  String itemId = 'lifecycle-item',
  String title = 'Enriched Title Alpha',
}) {
  return MetadataEnrichmentRecord(
    itemId: itemId,
    matchState: EnrichmentMatchState.linkedManual,
    providerId: 'open_library',
    fields: {
      EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
        value: title,
        source: EnrichmentFieldSource.provider,
        providerId: 'open_library',
      ),
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('20. Enrichment mutation invalidates the index lazily', () {
    test('upsert marks the index dirty without an eager rebuild', () async {
      final repository = MetadataEnrichmentRepository();
      await repository.initialize();
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      await search.searchCatalog(
          catalog, 'lifecycle', const SearchFilters.empty());
      expect(search.indexBuildCount, 1);
      expect(search.hasIndex, isTrue);

      await repository.upsert(_linkedRecord());

      // Dirty immediately; rebuild remains deferred until next search.
      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 1);

      final results = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(search.indexBuildCount, 2);
      expect(results.single.item.id, 'lifecycle-item');
    });

    test('remove marks the index dirty without an eager rebuild', () async {
      final repository = MetadataEnrichmentRepository(
        initialRecords: [_linkedRecord()],
      );
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      final firstResults = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(firstResults.single.item.id, 'lifecycle-item');
      expect(search.indexBuildCount, 1);

      await repository.remove('lifecycle-item');

      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 1);

      final afterRemove = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(search.indexBuildCount, 2);
      expect(afterRemove, isEmpty);

      final stillFindableByTitle = await search.searchCatalog(
        catalog,
        'lifecycle book',
        const SearchFilters.empty(),
      );
      expect(stillFindableByTitle.single.item.id, 'lifecycle-item');
    });

    test('relink-style upsert replaces prior provider keywords after refresh',
        () async {
      final repository = MetadataEnrichmentRepository(
        initialRecords: [_linkedRecord(title: 'Enriched Title Alpha')],
      );
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      final before = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(before.single.item.id, 'lifecycle-item');

      await repository.upsert(_linkedRecord(title: 'Relinked Title Beta'));

      final staleQuery = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(staleQuery, isEmpty);

      final relinkedQuery = await search.searchCatalog(
        catalog,
        'relinked title beta',
        const SearchFilters.empty(),
      );
      expect(relinkedQuery.single.item.id, 'lifecycle-item');
    });

    test('unlink-style upsert clears provider keywords after refresh',
        () async {
      final repository = MetadataEnrichmentRepository(
        initialRecords: [_linkedRecord()],
      );
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      final before = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(before.single.item.id, 'lifecycle-item');

      await repository.upsert(
        const MetadataEnrichmentRecord(
          itemId: 'lifecycle-item',
          matchState: EnrichmentMatchState.unmatched,
        ),
      );

      final afterUnlink = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(afterUnlink, isEmpty);
    });
  });

  group('21. In-flight build race safety', () {
    test(
        'enrichment notification during an in-flight build does not publish stale results',
        () async {
      final repository = MetadataEnrichmentRepository();
      await repository.initialize();
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      final buildFuture = search.ensureIndex(catalog);
      await repository.upsert(_linkedRecord());
      await buildFuture;

      // The in-flight build's generation was invalidated mid-flight; it must
      // not have published a stale (pre-enrichment) index.
      expect(search.hasIndex, isFalse);

      final results = await search.searchCatalog(
        catalog,
        'enriched title alpha',
        const SearchFilters.empty(),
      );
      expect(results.single.item.id, 'lifecycle-item');
      expect(search.catalogueIdentity, catalog.catalogueIdentity);
    });
  });

  group('22. Repeated notifications coalesce', () {
    test(
        'multiple notifications before the next search still trigger one rebuild',
        () async {
      final repository = MetadataEnrichmentRepository();
      await repository.initialize();
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      await search.searchCatalog(
          catalog, 'lifecycle', const SearchFilters.empty());
      expect(search.indexBuildCount, 1);

      await repository.upsert(_linkedRecord(title: 'First Title'));
      await repository.upsert(_linkedRecord(title: 'Second Title'));
      await repository.upsert(_linkedRecord(title: 'Third Title'));

      // Still dirty and lazy — no rebuild has happened yet despite three
      // coalesced notifications.
      expect(search.indexBuildCount, 1);
      expect(search.hasIndex, isFalse);

      final results = await search.searchCatalog(
        catalog,
        'third title',
        const SearchFilters.empty(),
      );

      expect(search.indexBuildCount, 2);
      expect(results.single.item.id, 'lifecycle-item');
    });
  });

  group('23. dispose() lifecycle', () {
    test('removes the repository listener and stops further invalidation',
        () async {
      final repository = MetadataEnrichmentRepository();
      await repository.initialize();
      final search = SearchService(enrichmentRepository: repository);
      final catalog = _catalogWithBook();

      await search.searchCatalog(
          catalog, 'lifecycle', const SearchFilters.empty());
      expect(search.indexBuildCount, 1);

      search.dispose();
      await repository.upsert(_linkedRecord());

      // No listener remains, so the index must not have been invalidated.
      expect(search.hasIndex, isTrue);
      expect(search.indexBuildCount, 1);
    });

    test('is idempotent when called more than once', () async {
      final repository = MetadataEnrichmentRepository();
      await repository.initialize();
      final search = SearchService(enrichmentRepository: repository);

      expect(() => search.dispose(), returnsNormally);
      expect(() => search.dispose(), returnsNormally);
      expect(() => search.dispose(), returnsNormally);
    });
  });

  group('24. Zero-dependency constructor compatibility', () {
    test('SearchService() with no arguments behaves as before', () async {
      final search = SearchService();
      final catalog = _catalogWithBook();

      final results = await search.searchCatalog(
        catalog,
        'lifecycle book',
        const SearchFilters.empty(),
      );

      expect(results.single.item.id, 'lifecycle-item');
      expect(() => search.dispose(), returnsNormally);
    });
  });
}
