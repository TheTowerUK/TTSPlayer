import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_key.dart';

void main() {
  group('MetadataArtworkCacheKey', () {
    test('produces deterministic lowercase hex digest', () {
      final first = MetadataArtworkCacheKey.compute(
        providerId: 'open_library',
        providerRecordId: '/books/OL123M',
        artworkId: '8230111',
      );
      final second = MetadataArtworkCacheKey.compute(
        providerId: 'open_library',
        providerRecordId: '/books/OL123M',
        artworkId: '8230111',
      );

      expect(first, second);
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('separator prevents ambiguous concatenation', () {
      final combined = MetadataArtworkCacheKey.compute(
        providerId: 'ab',
        providerRecordId: 'c',
        artworkId: 'd',
      );
      final split = MetadataArtworkCacheKey.compute(
        providerId: 'a',
        providerRecordId: 'bc',
        artworkId: 'd',
      );

      expect(combined, isNot(split));
    });

    test('trims whitespace before hashing', () {
      final trimmed = MetadataArtworkCacheKey.compute(
        providerId: 'open_library',
        providerRecordId: '/books/OL123M',
        artworkId: '8230111',
      );
      final padded = MetadataArtworkCacheKey.compute(
        providerId: ' open_library ',
        providerRecordId: ' /books/OL123M ',
        artworkId: ' 8230111 ',
      );

      expect(trimmed, padded);
    });

    test('rejects empty identity components', () {
      expect(
        () => MetadataArtworkCacheKey.compute(
          providerId: '',
          providerRecordId: '/books/OL123M',
          artworkId: '8230111',
        ),
        throwsArgumentError,
      );
      expect(
        () => MetadataArtworkCacheKey.compute(
          providerId: 'open_library',
          providerRecordId: '   ',
          artworkId: '8230111',
        ),
        throwsArgumentError,
      );
      expect(
        () => MetadataArtworkCacheKey.compute(
          providerId: 'open_library',
          providerRecordId: '/books/OL123M',
          artworkId: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
