import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_last_error_category.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_key.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_kind.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_reference.dart';

void main() {
  group('EnrichmentFieldValue', () {
    test('round trips complete field', () {
      const field = EnrichmentFieldValue(
        value: 'A classic novel.',
        source: EnrichmentFieldSource.provider,
        providerId: 'open_library',
        updatedAt: null,
        locked: false,
      );
      final updated = field.copyWith(
        updatedAt: DateTime.utc(2026, 7, 29, 12),
        locked: true,
      );
      final json = updated.toJson();
      final recovered = EnrichmentFieldValue.fromJsonWithRecovery(
        Map<String, dynamic>.from(json),
        fieldKey: 'description',
      );
      expect(recovered, updated);
    });

    test('rejects missing value', () {
      final warnings = <String>[];
      final recovered = EnrichmentFieldValue.fromJsonWithRecovery(
        {'source': 'provider'},
        warnings: warnings,
        fieldKey: 'description',
      );
      expect(recovered, isNull);
      expect(warnings, isNotEmpty);
    });
  });

  group('MetadataEnrichmentRecord serialization', () {
    final fetchedAt = DateTime.utc(2026, 7, 29, 10);
    final expiresAt = DateTime.utc(2026, 8, 29, 10);

    MetadataEnrichmentRecord completeRecord() {
      return MetadataEnrichmentRecord(
        itemId: 'item-complete',
        matchState: EnrichmentMatchState.linkedHighConfidence,
        providerId: 'open_library',
        providerRecordId: 'OL123W',
        providerMediaType: 'book',
        matchMethod: EnrichmentMatchMethod.automatic,
        confidence: 0.95,
        fields: {
          'description': EnrichmentFieldValue(
            value: 'Synopsis text.',
            source: EnrichmentFieldSource.provider,
            providerId: 'open_library',
            updatedAt: fetchedAt,
          ),
          'title': const EnrichmentFieldValue(
            value: 'Locked display title',
            source: EnrichmentFieldSource.userOverride,
            locked: true,
          ),
        },
        fetchedAt: fetchedAt,
        expiresAt: expiresAt,
        lockedFields: const ['title'],
        lastErrorCategory: null,
      ).normalized();
    }

    test('complete record round trip', () {
      final record = completeRecord();
      final json = record.toJson();
      final warnings = <String>[];
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(
        Map<String, dynamic>.from(json),
        warnings: warnings,
      );
      expect(warnings, isEmpty);
      expect(recovered, record);
    });

    test('minimal unmatched record round trip', () {
      const record = MetadataEnrichmentRecord(
        itemId: 'item-minimal',
        matchState: EnrichmentMatchState.unmatched,
      );
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(
        record.toJson(),
      );
      expect(recovered, record.normalized());
    });

    test('each match state serializes stable string', () {
      for (final state in EnrichmentMatchState.values) {
        final record = MetadataEnrichmentRecord(
          itemId: 'item-${state.serializedValue}',
          matchState: state,
        );
        final json = record.toJson();
        expect(json['matchState'], state.serializedValue);
        final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(json);
        expect(recovered!.matchState, state);
      }
    });

    test('each match method serializes stable string', () {
      for (final method in EnrichmentMatchMethod.values) {
        final record = MetadataEnrichmentRecord(
          itemId: 'item-method',
          matchState: EnrichmentMatchState.linkedManual,
          matchMethod: method,
        );
        final json = record.toJson();
        expect(json['matchMethod'], method.serializedValue);
        final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(json);
        expect(recovered!.matchMethod, method);
      }
    });

    test('field provenance and locked override preserved', () {
      final record = completeRecord().normalized();
      final description = record.fields['description']!;
      expect(description.source, EnrichmentFieldSource.provider);
      expect(record.fields['title']!.source,
          EnrichmentFieldSource.userOverride);
      expect(record.fields['title']!.locked, isTrue);
      expect(record.lockedFields, ['title']);
    });

    test('lockedFields is authoritative over field locked flags', () {
      final record = MetadataEnrichmentRecord(
        itemId: 'item-lock',
        matchState: EnrichmentMatchState.linkedManual,
        lockedFields: const ['title'],
        fields: {
          'title': const EnrichmentFieldValue(
            value: 'Display title',
            source: EnrichmentFieldSource.userOverride,
            locked: false,
          ),
        },
      ).normalized();
      expect(record.lockedFields, ['title']);
      expect(record.fields['title']!.locked, isTrue);
    });

    test('timestamps and confidence preserved', () {
      final record = completeRecord();
      expect(record.fetchedAt, DateTime.utc(2026, 7, 29, 10));
      expect(record.expiresAt, DateTime.utc(2026, 8, 29, 10));
      expect(record.confidence, 0.95);
    });

    test('missing optional fields tolerated', () {
      final warnings = <String>[];
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(
        {
          'itemId': 'item-sparse',
          'matchState': 'unmatched',
        },
        warnings: warnings,
      );
      expect(warnings, isEmpty);
      expect(recovered!.providerId, isNull);
      expect(recovered.fields, isEmpty);
      expect(recovered.confidence, isNull);
    });

    test('unknown match state falls back to unmatched', () {
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery({
        'itemId': 'item-unknown-state',
        'matchState': 'future_state',
      });
      expect(recovered!.matchState, EnrichmentMatchState.unmatched);
    });

    test('unknown field keys in fields map are preserved', () {
      final record = MetadataEnrichmentRecord.fromJsonWithRecovery({
        'itemId': 'item-fields',
        'matchState': 'linked_manual',
        'fields': {
          'futureField': {
            'value': 'future',
            'source': 'provider',
          },
        },
      });
      expect(record!.fields.containsKey('futureField'), isTrue);
    });

    test('last error category round trip', () {
      final record = MetadataEnrichmentRecord(
        itemId: 'item-error',
        matchState: EnrichmentMatchState.unmatched,
        lastErrorCategory: EnrichmentLastErrorCategory.rateLimited,
      );
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(
        record.toJson(),
      );
      expect(
        recovered!.lastErrorCategory,
        EnrichmentLastErrorCategory.rateLimited,
      );
    });

    test('artworkReference round trip', () {
      final artworkReference = MetadataArtworkReference(
        providerId: 'open_library',
        providerRecordId: '/books/OL123M',
        artworkId: '8230111',
        kind: MetadataArtworkKind.cover,
        fetchedAt: fetchedAt,
        cacheState: MetadataArtworkCacheState.available,
        cacheKey: MetadataArtworkCacheKey.compute(
          providerId: 'open_library',
          providerRecordId: '/books/OL123M',
          artworkId: '8230111',
        ),
      ).normalized();
      final record = completeRecord().copyWith(
        artworkReference: artworkReference,
      );
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery(
        record.toJson(),
      );
      expect(recovered, record);
    });

    test('missing artworkReference remains backward compatible', () {
      final recovered = MetadataEnrichmentRecord.fromJsonWithRecovery({
        'itemId': 'item-legacy',
        'matchState': 'linked_manual',
      });
      expect(recovered!.artworkReference, isNull);
    });
  });
}
