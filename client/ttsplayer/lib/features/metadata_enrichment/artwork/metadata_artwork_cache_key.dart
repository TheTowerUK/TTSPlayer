import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic cache-key derivation for provider artwork (M7.4.2).
///
/// Keys are SHA-256 hex digests of UTF-8 joined identity components separated
/// by U+001E (record separator) to avoid ambiguous concatenation.
class MetadataArtworkCacheKey {
  const MetadataArtworkCacheKey._();

  static const _separator = '\u001e';

  /// Returns lowercase hex SHA-256 of [providerId], [providerRecordId], and
  /// [artworkId] after trimming and rejecting empty components.
  static String compute({
    required String providerId,
    required String providerRecordId,
    required String artworkId,
  }) {
    final normalizedProviderId = providerId.trim();
    final normalizedRecordId = providerRecordId.trim();
    final normalizedArtworkId = artworkId.trim();
    if (normalizedProviderId.isEmpty ||
        normalizedRecordId.isEmpty ||
        normalizedArtworkId.isEmpty) {
      throw ArgumentError(
        'providerId, providerRecordId, and artworkId must be non-empty.',
      );
    }

    final payload =
        '$normalizedProviderId$_separator$normalizedRecordId$_separator$normalizedArtworkId';
    return sha256.convert(utf8.encode(payload)).toString();
  }
}
