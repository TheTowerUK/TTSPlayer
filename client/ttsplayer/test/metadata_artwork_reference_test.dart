import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_key.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_kind.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_reference.dart';

void main() {
  final fetchedAt = DateTime.utc(2026, 8, 3, 12);
  final validatedAt = DateTime.utc(2026, 8, 3, 13);

  MetadataArtworkReference sampleReference() {
    return MetadataArtworkReference(
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
  }

  group('MetadataArtworkReference', () {
    test('round trips complete reference', () {
      final reference = sampleReference().copyWith(
        contentType: 'image/jpeg',
        width: 400,
        height: 600,
        validatedAt: validatedAt,
        localRelativePath: 'ab/cd123.jpg',
        validator: 'etag-1',
      );
      final json = reference.toJson();
      final warnings = <String>[];
      final recovered = MetadataArtworkReference.fromJsonWithRecovery(
        Map<String, dynamic>.from(json),
        warnings: warnings,
      );

      expect(warnings, isEmpty);
      expect(recovered, reference);
    });

    test('copyWith clear flags remove optional fields', () {
      final reference = sampleReference().copyWith(
        contentType: 'image/jpeg',
        width: 400,
        height: 600,
        validatedAt: validatedAt,
        localRelativePath: 'ab/cd123.jpg',
        validator: 'etag-1',
      );

      final cleared = reference.copyWith(
        clearContentType: true,
        clearWidth: true,
        clearHeight: true,
        clearValidatedAt: true,
        clearLocalRelativePath: true,
        clearValidator: true,
      );

      expect(cleared.contentType, isNull);
      expect(cleared.width, isNull);
      expect(cleared.height, isNull);
      expect(cleared.validatedAt, isNull);
      expect(cleared.localRelativePath, isNull);
      expect(cleared.validator, isNull);
    });

    test('enum values serialize stable strings', () {
      for (final kind in MetadataArtworkKind.values) {
        expect(MetadataArtworkKind.fromJson(kind.toJson()), kind);
      }
      for (final state in MetadataArtworkCacheState.values) {
        expect(MetadataArtworkCacheState.fromJson(state.toJson()), state);
      }
    });

    test('rejects mismatched cacheKey on normalize', () {
      expect(
        () => MetadataArtworkReference(
          providerId: 'open_library',
          providerRecordId: '/books/OL123M',
          artworkId: '8230111',
          kind: MetadataArtworkKind.cover,
          fetchedAt: fetchedAt,
          cacheState: MetadataArtworkCacheState.available,
          cacheKey: 'deadbeef',
        ).normalized(),
        throwsArgumentError,
      );
    });

    test('fromJsonWithRecovery rejects missing identity', () {
      final warnings = <String>[];
      final recovered = MetadataArtworkReference.fromJsonWithRecovery(
        {
          'providerId': 'open_library',
          'artworkId': '8230111',
          'kind': 'cover',
          'fetchedAt': fetchedAt.toIso8601String(),
          'cacheState': 'available',
          'cacheKey': 'abc',
        },
        warnings: warnings,
      );

      expect(recovered, isNull);
      expect(warnings, isNotEmpty);
    });
  });
}
