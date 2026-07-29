import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';

import 'support/catalog_cache_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';

Catalog _catalogWithItemIds(List<String> itemIds) {
  return Catalog.fromJson({
    'generated_at': '2026-07-29T10:00:00+00:00',
    'total_items': itemIds.length,
    'catalogue': {
      'id': 'cat-test',
      'scanner_version': '0.5.0',
      'catalogue_version': 4,
    },
    'folders': [
      {
        'id': 'lib-main',
        'name': 'Books',
        'path': r'Y:\Media\Books',
        'item_count': itemIds.length,
        'items': [
          for (final id in itemIds)
            {
              'id': id,
              'title': id,
              'file_path': 'Y:\\Media\\Books\\$id.epub',
              'status': 'available',
              'media_kind': 'book',
            },
        ],
        'subfolders': [],
      },
    ],
  });
}

MetadataEnrichmentRecord _sampleRecord(String itemId) {
  return MetadataEnrichmentRecord(
    itemId: itemId,
    matchState: EnrichmentMatchState.linkedHighConfidence,
    providerId: 'open_library',
    providerRecordId: 'OL-$itemId',
    providerMediaType: 'book',
    matchMethod: EnrichmentMatchMethod.automatic,
    confidence: 0.92,
    fields: {
      'description': EnrichmentFieldValue(
        value: 'Description for $itemId',
        source: EnrichmentFieldSource.provider,
        providerId: 'open_library',
        updatedAt: DateTime.utc(2026, 7, 29),
      ),
    },
    fetchedAt: DateTime.utc(2026, 7, 29),
  );
}

void main() {
  group('MetadataEnrichmentRepository lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('empty initialization', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      expect(repository.storedRecordCount, 0);
      expect(repository.isLoaded, isTrue);
      expect(repository.counts.total, 0);
    });

    test('load valid v1 data', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: enrichmentEnvelopeJson([
            _sampleRecord('book-a').toJson(),
          ]),
        },
      );
      expect(repository.storedRecordCount, 1);
      expect(repository.getByItemId('book-a')?.providerRecordId, 'OL-book-a');
    });

    test('upsert replace and remove', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      expect(
        (await repository.upsert(_sampleRecord('book-a'))).success,
        isTrue,
      );
      expect(repository.storedRecordCount, 1);

      final updated = _sampleRecord('book-a').copyWith(
        matchState: EnrichmentMatchState.linkedManual,
        matchMethod: EnrichmentMatchMethod.manual,
      );
      expect((await repository.upsert(updated)).success, isTrue);
      expect(
        repository.getByItemId('book-a')!.matchState,
        EnrichmentMatchState.linkedManual,
      );

      expect((await repository.remove('book-a')).success, isTrue);
      expect(repository.storedRecordCount, 0);
    });

    test('clear all', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('book-a'));
      await repository.upsert(_sampleRecord('book-b'));
      expect((await repository.clearAll()).success, isTrue);
      expect(repository.storedRecordCount, 0);
    });

    test('deterministic persistence omits credentials and paths', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('book-a'));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(MetadataEnrichmentRepository.storageKey);
      expect(raw, isNotNull);
      expect(raw!, isNot(contains('apiKey')));
      expect(raw, isNot(contains('Authorization')));
      expect(raw, isNot(contains(r'Y:\Media')));
      expect(raw, isNot(contains('file_path')));

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['stateVersion'], 1);
      final records = decoded['records'] as List<dynamic>;
      expect(records, hasLength(1));
      expect(records.first['itemId'], 'book-a');
    });

    test('initialize is idempotent', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('book-a'));
      final first = await repository.initialize();
      final second = await repository.initialize();
      expect(first.records.length, 1);
      expect(second.records.length, 1);
    });

    test('persist failure surfaces error', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      repository.simulatePersistFailure = true;
      final result = await repository.upsert(_sampleRecord('book-a'));
      expect(result.success, isFalse);
      expect(repository.storedRecordCount, 0);
    });
  });

  group('MetadataEnrichmentRepository recovery', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('malformed JSON recovers to empty', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: '{not json',
        },
      );
      expect(repository.storedRecordCount, 0);
      expect(repository.lastRecoveryWarnings, isNotEmpty);
    });

    test('wrong root type recovers to empty', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: jsonEncode(['array']),
        },
      );
      expect(repository.storedRecordCount, 0);
    });

    test('unsupported future schema recovers to empty', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: jsonEncode({
            'stateVersion': 99,
            'records': [_sampleRecord('book-a').toJson()],
          }),
        },
      );
      expect(repository.storedRecordCount, 0);
      expect(
        repository.lastRecoveryWarnings.any((w) => w.contains('Unsupported')),
        isTrue,
      );
    });

    test('missing schema version recovers to empty', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: jsonEncode({
            'records': [_sampleRecord('book-a').toJson()],
          }),
        },
      );
      expect(repository.storedRecordCount, 0);
    });

    test('missing record collection loads empty records', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: jsonEncode({
            'stateVersion': 1,
          }),
        },
      );
      expect(repository.storedRecordCount, 0);
    });

    test('malformed individual record skipped preserving valid', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: enrichmentEnvelopeJson([
            _sampleRecord('book-good').toJson(),
            {'matchState': 'linked_manual'},
          ]),
        },
      );
      expect(repository.storedRecordCount, 1);
      expect(repository.getByItemId('book-good'), isNotNull);
      expect(repository.lastLoadSkippedRecordCount, greaterThan(0));
    });

    test('duplicate itemId keeps latest fetchedAt', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: enrichmentEnvelopeJson([
            {
              'itemId': 'dup-item',
              'matchState': 'unmatched',
              'fetchedAt': '2026-07-29T10:00:00.000Z',
              'providerRecordId': 'older',
            },
            {
              'itemId': 'dup-item',
              'matchState': 'linked_manual',
              'fetchedAt': '2026-07-30T10:00:00.000Z',
              'providerRecordId': 'newer',
            },
          ]),
        },
      );
      expect(repository.storedRecordCount, 1);
      expect(repository.getByItemId('dup-item')!.providerRecordId, 'newer');
    });

    test('duplicate itemId equal fetchedAt uses confidence tie-break', () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: enrichmentEnvelopeJson([
            {
              'itemId': 'dup-item',
              'matchState': 'unmatched',
              'fetchedAt': '2026-07-29T10:00:00.000Z',
              'confidence': 0.4,
              'providerRecordId': 'low',
            },
            {
              'itemId': 'dup-item',
              'matchState': 'linked_high_confidence',
              'fetchedAt': '2026-07-29T10:00:00.000Z',
              'confidence': 0.95,
              'providerRecordId': 'high',
            },
          ]),
        },
      );
      expect(repository.getByItemId('dup-item')!.providerRecordId, 'high');
    });

    test('duplicate itemId missing fetchedAt uses providerRecordId tie-break',
        () async {
      final repository = await initializedMetadataEnrichmentRepository(
        initialPreferences: {
          MetadataEnrichmentRepository.storageKey: enrichmentEnvelopeJson([
            {
              'itemId': 'dup-item',
              'matchState': 'unmatched',
              'providerRecordId': 'aaa',
            },
            {
              'itemId': 'dup-item',
              'matchState': 'linked_manual',
              'providerRecordId': 'zzz',
            },
          ]),
        },
      );
      expect(repository.getByItemId('dup-item')!.providerRecordId, 'zzz');
    });
  });

  group('MetadataEnrichmentRepository pruning', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('absent IDs removed retained IDs preserved', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('keep-a'));
      await repository.upsert(_sampleRecord('keep-b'));
      await repository.upsert(_sampleRecord('drop-c'));

      final result = await repository.validateAgainstCatalog(
        _catalogWithItemIds(['keep-a', 'keep-b']),
      );

      expect(result.changed, isTrue);
      expect(result.removedCount, 1);
      expect(result.retainedCount, 2);
      expect(repository.getByItemId('drop-c'), isNull);
      expect(repository.getByItemId('keep-a'), isNotNull);
    });

    test('empty catalogue clears all records', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('book-a'));

      final result = await repository.validateAgainstCatalog(
        _catalogWithItemIds([]),
      );

      expect(result.changed, isTrue);
      expect(result.removedCount, 1);
      expect(repository.storedRecordCount, 0);
    });

    test('no-op pruning does not corrupt state', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('book-a'));

      final result = await repository.validateAgainstCatalog(
        _catalogWithItemIds(['book-a']),
      );

      expect(result.changed, isFalse);
      expect(repository.storedRecordCount, 1);
    });

    test('rename/move represented as old ID removal', () async {
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(_sampleRecord('old-id-md5'));

      final renamedCatalog = _catalogWithItemIds(['new-id-md5']);
      final result = await repository.validateAgainstCatalog(renamedCatalog);

      expect(result.removedCount, 1);
      expect(repository.getByItemId('old-id-md5'), isNull);
      expect(repository.getByItemId('new-id-md5'), isNull);
    });
  });

  group('CatalogCacheCoordinator enrichment pruning', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('catalogue replacement prunes enrichment via coordinator', () async {
      final enrichmentRepository = MetadataEnrichmentRepository();
      await enrichmentRepository.initialize();
      await enrichmentRepository.upsert(_sampleRecord('stay'));
      await enrichmentRepository.upsert(_sampleRecord('go'));

      final coordinator = createTestCatalogCacheCoordinator(
        artworkService: ArtworkService(),
        searchService: SearchService(),
        musicLibraryService: MusicLibraryService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        metadataEnrichmentRepository: enrichmentRepository,
      );

      coordinator.onCatalogReplaced(_catalogWithItemIds(['stay']));
      await Future<void>.delayed(Duration.zero);

      expect(enrichmentRepository.storedRecordCount, 1);
      expect(enrichmentRepository.getByItemId('stay'), isNotNull);
      expect(enrichmentRepository.getByItemId('go'), isNull);
    });
  });

  group('MetadataEnrichmentRepository isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: jsonEncode({
          'metadataVersion': 1,
          'favourites': {
            'items': [
              {'id': 'fav-1', 'favouritedAt': '2026-07-29T10:00:00.000Z'},
            ],
            'folders': [],
          },
        }),
        MusicListeningRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [
            {
              'trackId': 'track-1',
              'title': 'Track',
              'artist': 'Artist',
              'album': 'Album',
              'lastPosition': 0,
              'duration': 100,
              'completed': false,
              'lastPlayedAt': '2026-07-29T10:00:00.000Z',
            },
          ],
        }),
        ReadingProgressRepository.storageKey: jsonEncode({
          'stateVersion': 1,
          'records': [],
        }),
        'position_video-1': 120,
      });
    });

    test('enrichment writes do not mutate unrelated repositories', () async {
      final prefs = await SharedPreferences.getInstance();
      final libraryBefore =
          prefs.getString(LibraryMetadataRepository.storageKey);
      final listeningBefore =
          prefs.getString(MusicListeningRepository.storageKey);
      final readingBefore =
          prefs.getString(ReadingProgressRepository.storageKey);
      final videoPositionBefore = prefs.getInt('position_video-1');

      final repository = MetadataEnrichmentRepository();
      await repository.initialize();
      await repository.upsert(_sampleRecord('book-a'));

      expect(prefs.getString(LibraryMetadataRepository.storageKey),
          libraryBefore);
      expect(prefs.getString(MusicListeningRepository.storageKey),
          listeningBefore);
      expect(prefs.getString(ReadingProgressRepository.storageKey),
          readingBefore);
      expect(prefs.getInt('position_video-1'), videoPositionBefore);
    });
  });
}
