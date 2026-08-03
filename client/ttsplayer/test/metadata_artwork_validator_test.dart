import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_validator.dart';

import 'support/metadata_artwork_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validator = MetadataArtworkValidator();

  group('MetadataArtworkValidator', () {
    test('accepts valid PNG bytes', () async {
      final result = await validator.validate(
        bytes: MetadataArtworkTestFixtures.onePixelPng,
        contentTypeHeader: 'image/png',
      );

      expect(result.contentType, 'image/png');
      expect(result.width, 1);
      expect(result.height, 1);
      expect(result.byteSize, MetadataArtworkTestFixtures.onePixelPng.length);
    });

    test('rejects empty body', () {
      expect(
        () => validator.validate(bytes: Uint8List(0)),
        throwsA(isA<MetadataArtworkValidationException>()),
      );
    });

    test('rejects HTML payload', () {
      expect(
        () => validator.validate(bytes: MetadataArtworkTestFixtures.htmlBytes),
        throwsA(
          predicate<MetadataArtworkValidationException>(
            (error) =>
                error.failure == MetadataArtworkValidationFailure.htmlPayload,
          ),
        ),
      );
    });

    test('rejects invalid bytes', () {
      expect(
        () => validator.validate(
          bytes: MetadataArtworkTestFixtures.invalidBytes,
        ),
        throwsA(
          predicate<MetadataArtworkValidationException>(
            (error) =>
                error.failure == MetadataArtworkValidationFailure.unsupportedMime ||
                error.failure == MetadataArtworkValidationFailure.decodeFailure,
          ),
        ),
      );
    });

    test('rejects oversized body', () {
      expect(
        () => const MetadataArtworkValidator(maxByteSize: 8).validate(
          bytes: Uint8List(16),
        ),
        throwsA(
          predicate<MetadataArtworkValidationException>(
            (error) =>
                error.failure == MetadataArtworkValidationFailure.bodyTooLarge,
          ),
        ),
      );
    });

    test('rejects wrong MIME without matching bytes', () {
      expect(
        () => validator.validate(
          bytes: MetadataArtworkTestFixtures.invalidBytes,
          contentTypeHeader: 'image/jpeg',
        ),
        throwsA(isA<MetadataArtworkValidationException>()),
      );
    });
  });
}
