import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/artwork/artwork_decode_size.dart';

void main() {
  group('ArtworkDecodeSize', () {
    test('applies device pixel ratio with rounding', () {
      const logical = Size(100, 50);
      final decode = ArtworkDecodeSize.fromLogicalSize(
        size: logical,
        devicePixelRatio: 1.5,
      );
      expect(decode.cacheWidth, 150);
      expect(decode.cacheHeight, 75);
    });

    test('decode dimensions are positive', () {
      final decode = ArtworkDecodeSize.fromLogicalSize(
        size: const Size(0.5, 0.25),
        devicePixelRatio: 1.0,
      );
      expect(decode.cacheWidth, 1);
      expect(decode.cacheHeight, 1);
    });

    test('zero logical size omits decode hints', () {
      final decode = ArtworkDecodeSize.fromLogicalSize(
        size: Size.zero,
        devicePixelRatio: 2.0,
      );
      expect(decode.cacheWidth, isNull);
      expect(decode.cacheHeight, isNull);
    });
  });

  group('ArtworkSurfaceSizes', () {
    test('grid media card uses design token dimensions', () {
      final size = ArtworkSurfaceSizes.gridMediaCard();
      expect(size.width, 280);
      expect(size.height, greaterThan(200));
      expect(size.height, lessThan(320));
    });

    test('search thumbnail uses portrait aspect', () {
      final size = ArtworkSurfaceSizes.searchResultThumbnail();
      expect(size.width, 56);
      expect(size.height, 84);
    });

    test('item detail poster uses 16:9 of screen width', () {
      final size = ArtworkSurfaceSizes.itemDetailPoster(800);
      expect(size.width, 800);
      expect(size.height, 450);
    });
  });
}
