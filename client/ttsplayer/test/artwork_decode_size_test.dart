import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/artwork/artwork_decode_size.dart';

void main() {
  group('ArtworkDecodeSize', () {
    test('landscape logical size sets cacheWidth only', () {
      const logical = Size(100, 50);
      final decode = ArtworkDecodeSize.fromLogicalSize(
        size: logical,
        devicePixelRatio: 1.5,
      );
      expect(decode.cacheWidth, 150);
      expect(decode.cacheHeight, isNull);
    });

    test('portrait logical size sets cacheHeight only', () {
      final decode = ArtworkDecodeSize.fromLogicalSize(
        size: const Size(50, 100),
        devicePixelRatio: 2.0,
      );
      expect(decode.cacheWidth, isNull);
      expect(decode.cacheHeight, 200);
    });

    test('decode dimensions are positive', () {
      final decode = ArtworkDecodeSize.fromLogicalSize(
        size: const Size(0.5, 0.25),
        devicePixelRatio: 1.0,
      );
      expect(decode.cacheWidth, 1);
      expect(decode.cacheHeight, isNull);
    });

    test('never sets both cacheWidth and cacheHeight', () {
      for (final size in const [
        Size(100, 50),
        Size(50, 100),
        Size(80, 80),
      ]) {
        final decode = ArtworkDecodeSize.fromLogicalSize(
          size: size,
          devicePixelRatio: 1.0,
        );
        expect(
          decode.cacheWidth == null || decode.cacheHeight == null,
          isTrue,
          reason: 'both axes set for $size',
        );
        expect(
          decode.cacheWidth != null || decode.cacheHeight != null,
          isTrue,
        );
      }
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

    test('item detail literature poster uses portrait 2:3', () {
      final size = ArtworkSurfaceSizes.itemDetailLiteraturePoster();
      expect(size.width, 280);
      expect(size.height, 420);
      expect(size.width / size.height, closeTo(2 / 3, 0.001));
    });
  });
}
