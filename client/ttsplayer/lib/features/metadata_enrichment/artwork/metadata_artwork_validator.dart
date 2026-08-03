import 'dart:typed_data';
import 'dart:ui' as ui;

import 'metadata_artwork_mime_types.dart';

/// Result of validating downloaded artwork bytes (M7.4.3).
class MetadataArtworkValidationResult {
  const MetadataArtworkValidationResult({
    required this.contentType,
    required this.width,
    required this.height,
    required this.byteSize,
  });

  final String contentType;
  final int width;
  final int height;
  final int byteSize;
}

/// Validation failures for artwork downloads (M7.4.3).
enum MetadataArtworkValidationFailure {
  emptyBody,
  bodyTooLarge,
  unsupportedMime,
  htmlPayload,
  invalidImage,
  decodeFailure,
}

/// Validates provider artwork bytes before cache promotion (M7.4.3).
class MetadataArtworkValidator {
  const MetadataArtworkValidator({
    this.maxByteSize = 8 * 1024 * 1024,
    this.decodeImage = _defaultDecodeImage,
  });

  final int maxByteSize;
  final Future<(int width, int height)?> Function(Uint8List bytes) decodeImage;

  Future<MetadataArtworkValidationResult> validate({
    required Uint8List bytes,
    String? contentTypeHeader,
  }) async {
    if (bytes.isEmpty) {
      throw MetadataArtworkValidationException(
        MetadataArtworkValidationFailure.emptyBody,
      );
    }
    if (bytes.length > maxByteSize) {
      throw MetadataArtworkValidationException(
        MetadataArtworkValidationFailure.bodyTooLarge,
      );
    }
    if (_looksLikeHtml(bytes)) {
      throw MetadataArtworkValidationException(
        MetadataArtworkValidationFailure.htmlPayload,
      );
    }

    final normalizedHeader = MetadataArtworkMimeTypes.normalize(contentTypeHeader);
    final sniffedMime = _sniffMime(bytes);
    final contentType = normalizedHeader ?? sniffedMime;
    if (contentType == null) {
      throw MetadataArtworkValidationException(
        MetadataArtworkValidationFailure.unsupportedMime,
      );
    }

    final dimensions = await decodeImage(bytes);
    if (dimensions == null) {
      throw MetadataArtworkValidationException(
        MetadataArtworkValidationFailure.decodeFailure,
      );
    }
    final (width, height) = dimensions;
    if (width <= 0 || height <= 0) {
      throw MetadataArtworkValidationException(
        MetadataArtworkValidationFailure.invalidImage,
      );
    }

    return MetadataArtworkValidationResult(
      contentType: contentType,
      width: width,
      height: height,
      byteSize: bytes.length,
    );
  }

  static bool _looksLikeHtml(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final prefix = String.fromCharCodes(bytes.take(64)).trimLeft().toLowerCase();
    return prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html') ||
        prefix.startsWith('<head') ||
        prefix.startsWith('<body');
  }

  static String? _sniffMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return MetadataArtworkMimeTypes.jpeg;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return MetadataArtworkMimeTypes.png;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MetadataArtworkMimeTypes.webp;
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return MetadataArtworkMimeTypes.gif;
    }
    return null;
  }

  static Future<(int width, int height)?> _defaultDecodeImage(
    Uint8List bytes,
  ) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecFromBuffer(buffer);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();
      return (width, height);
    } catch (_) {
      return null;
    }
  }
}

class MetadataArtworkValidationException implements Exception {
  const MetadataArtworkValidationException(this.failure);

  final MetadataArtworkValidationFailure failure;
}
