import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/isbn_lookup_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_enrichment_mapper.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_match_transition.dart';

void main() {
  const transition = BookMetadataMatchTransition();
  const mapper = BookMetadataEnrichmentMapper();
  final fetchedAt = DateTime.utc(2026, 7, 30, 12);

  group('BookMetadataMatchTransition', () {
    test('applyIsbnLink creates linkedByIdentifier record', () {
      final metadata = FakeBookMetadataProvider.sampleMetadata();
      final request = IsbnLookupRequest.parse('9780140449136')!;

      final record = transition.applyIsbnLink(
        existing: null,
        itemId: 'book-1',
        metadata: metadata,
        request: request,
        fetchedAt: fetchedAt,
        lookupKeyConfirmed: true,
      );

      expect(record.matchState, EnrichmentMatchState.linkedByIdentifier);
      expect(record.matchMethod, EnrichmentMatchMethod.identifier);
      expect(record.confidence, 1.0);
      expect(record.providerRecordId, metadata.providerRecordId);
      expect(record.artworkReference, isNotNull);
      expect(record.artworkReference!.artworkId, '8230111');
      expect(record.artworkReference!.cacheState,
          MetadataArtworkCacheState.available);
      expect(record.artworkReference!.localRelativePath, isNull);
    });

    test('applyManualLink preserves locked fields', () {
      final existing = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.unmatched,
        fields: {
          EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
            value: 'Locked Title',
            source: EnrichmentFieldSource.userOverride,
          ),
        },
        lockedFields: const [EnrichmentBookFieldKeys.title],
      );
      final metadata = FakeBookMetadataProvider.sampleMetadata(title: 'Provider Title');

      final record = transition.applyManualLink(
        existing: existing,
        itemId: 'book-1',
        metadata: metadata,
        confidence: 0.82,
        fetchedAt: fetchedAt,
      );

      expect(record.matchState, EnrichmentMatchState.linkedManual);
      expect(record.matchMethod, EnrichmentMatchMethod.manual);
      expect(record.confidence, 0.82);
      expect(record.fields[EnrichmentBookFieldKeys.title]?.value, 'Locked Title');
      expect(record.fields[EnrichmentBookFieldKeys.authors], isNotNull);
    });

    test('applyRelink removes old unlocked provider fields', () {
      final oldMetadata = FakeBookMetadataProvider.sampleMetadata(
        providerRecordId: '/books/OLD',
        title: 'Old Title',
      );
      final linked = mapper.createLinkedRecord(
        itemId: 'book-1',
        metadata: oldMetadata,
        matchMethod: EnrichmentMatchMethod.identifier,
        confidence: 1.0,
        fetchedAt: fetchedAt,
      );
      final existing = linked.copyWith(
        matchState: EnrichmentMatchState.linkedManual,
        matchMethod: EnrichmentMatchMethod.manual,
        fields: {
          ...Map<String, EnrichmentFieldValue>.from(linked.fields),
          EnrichmentBookFieldKeys.description: EnrichmentFieldValue(
            value: 'Old description only on prior candidate',
            source: EnrichmentFieldSource.provider,
            providerId: 'fake_books',
          ),
          EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
            value: 'User Title',
            source: EnrichmentFieldSource.userOverride,
          ),
        },
        lockedFields: const [EnrichmentBookFieldKeys.authors],
      );

      final newMetadata = FakeBookMetadataProvider.sampleMetadata(
        providerRecordId: '/books/NEW',
        title: 'New Title',
        authors: ['New Author'],
      );

      final record = transition.applyRelink(
        existing: existing,
        metadata: newMetadata,
        confidence: 0.77,
        fetchedAt: fetchedAt,
      );

      expect(record.providerRecordId, '/books/NEW');
      expect(record.matchState, EnrichmentMatchState.linkedManual);
      expect(record.artworkReference?.providerRecordId, '/books/NEW');
      expect(record.artworkReference?.artworkId, '8230111');
      expect(record.fields[EnrichmentBookFieldKeys.title]?.value, 'User Title');
      expect(record.fields[EnrichmentBookFieldKeys.description], isNull);
      expect(record.fields[EnrichmentBookFieldKeys.authors]?.value, isNotNull);
    });

    test('same-record refresh retains artwork reference when cache key unchanged',
        () {
      const coverArtworkId = '8230111';
      final metadata = FakeBookMetadataProvider.sampleMetadata(
        coverArtworkId: coverArtworkId,
      );
      final linked = mapper.createLinkedRecord(
        itemId: 'book-1',
        metadata: metadata,
        matchMethod: EnrichmentMatchMethod.identifier,
        confidence: 1.0,
        fetchedAt: fetchedAt,
      );
      final originalReference = linked.artworkReference;
      expect(originalReference, isNotNull);

      final refreshedMetadata = FakeBookMetadataProvider.sampleMetadata(
        title: 'Updated Title',
        coverArtworkId: coverArtworkId,
      );
      final record = mapper.mergeProviderFields(
        existing: linked,
        metadata: refreshedMetadata,
        matchState: EnrichmentMatchState.linkedByIdentifier,
        matchMethod: EnrichmentMatchMethod.identifier,
        confidence: 1.0,
        fetchedAt: fetchedAt,
      );

      expect(record.artworkReference?.cacheKey, originalReference!.cacheKey);
      expect(record.artworkReference?.artworkId, coverArtworkId);
    });

    test('same-record refresh merge retains absent provider fields', () {
      final metadata = FakeBookMetadataProvider.sampleMetadata();
      final existing = mapper.createLinkedRecord(
        itemId: 'book-1',
        metadata: metadata,
        matchMethod: EnrichmentMatchMethod.identifier,
        confidence: 1.0,
        fetchedAt: fetchedAt,
      ).copyWith(
        fields: {
          ...existingProviderFields(
            mapper.createLinkedRecord(
              itemId: 'book-1',
              metadata: metadata,
              matchMethod: EnrichmentMatchMethod.identifier,
              confidence: 1.0,
              fetchedAt: fetchedAt,
            ),
          ),
          EnrichmentBookFieldKeys.description: EnrichmentFieldValue(
            value: 'Prior description',
            source: EnrichmentFieldSource.provider,
            providerId: 'fake_books',
          ),
        },
      );

      final refreshedMetadata = FakeBookMetadataProvider.sampleMetadata(
        title: 'Updated Title',
      );

      final record = mapper.mergeProviderFields(
        existing: existing,
        metadata: refreshedMetadata,
        matchState: EnrichmentMatchState.linkedByIdentifier,
        matchMethod: EnrichmentMatchMethod.identifier,
        confidence: 1.0,
        fetchedAt: fetchedAt,
      );

      expect(record.fields[EnrichmentBookFieldKeys.title]?.value, 'Updated Title');
      expect(record.fields[EnrichmentBookFieldKeys.description]?.value,
          'Prior description');
    });

    test('applyUnlink clears provider linkage and provider-owned fields', () {
      final existing = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.linkedManual,
        providerId: 'fake_books',
        providerRecordId: '/books/OL123M',
        matchMethod: EnrichmentMatchMethod.manual,
        confidence: 0.9,
        fields: {
          EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
            value: 'Provider Title',
            source: EnrichmentFieldSource.provider,
            providerId: 'fake_books',
          ),
          EnrichmentBookFieldKeys.subtitle: EnrichmentFieldValue(
            value: 'User Subtitle',
            source: EnrichmentFieldSource.userOverride,
          ),
        },
      );

      final record = transition.applyUnlink(existing);

      expect(record.matchState, EnrichmentMatchState.unmatched);
      expect(record.providerId, isNull);
      expect(record.providerRecordId, isNull);
      expect(record.artworkReference, isNull);
      expect(record.fields[EnrichmentBookFieldKeys.title], isNull);
      expect(record.fields[EnrichmentBookFieldKeys.subtitle]?.value, 'User Subtitle');
    });

    test('applyIgnore transitions to ignored and clears provider linkage', () {
      final existing = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.linkedByIdentifier,
        providerId: 'fake_books',
        providerRecordId: '/books/OL123M',
        fields: {
          EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
            value: 'Provider Title',
            source: EnrichmentFieldSource.provider,
            providerId: 'fake_books',
          ),
        },
      );

      final record = transition.applyIgnore(existing);

      expect(record.matchState, EnrichmentMatchState.ignored);
      expect(record.providerId, isNull);
      expect(record.artworkReference, isNull);
      expect(record.fields[EnrichmentBookFieldKeys.title], isNull);
    });

    test('applyResumeMatching transitions ignored to unmatched', () {
      final existing = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.ignored,
        fields: {
          EnrichmentBookFieldKeys.subtitle: EnrichmentFieldValue(
            value: 'User Subtitle',
            source: EnrichmentFieldSource.userOverride,
          ),
        },
      );

      final record = transition.applyResumeMatching(existing);

      expect(record.matchState, EnrichmentMatchState.unmatched);
      expect(record.fields[EnrichmentBookFieldKeys.subtitle]?.value, 'User Subtitle');
      expect(record.artworkReference, isNull);
    });

    test('isbnResponseConfirmed rejects mismatched ISBN metadata', () {
      final metadata = FakeBookMetadataProvider.sampleMetadata(
        isbn13: const ['9780000000000'],
      );
      final request = IsbnLookupRequest.parse('9780140449136')!;

      expect(
        transition.isbnResponseConfirmed(metadata, request, lookupKeyConfirmed: false),
        isFalse,
      );
    });
  });
}

Map<String, EnrichmentFieldValue> existingProviderFields(
  MetadataEnrichmentRecord record,
) {
  return Map<String, EnrichmentFieldValue>.from(record.fields);
}
