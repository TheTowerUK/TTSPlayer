import 'dart:convert';
import 'dart:typed_data';

import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_key.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_http_client.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_kind.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_reference.dart';

/// Deterministic artwork bytes and references for tests (M7.4.3).
class MetadataArtworkTestFixtures {
  const MetadataArtworkTestFixtures._();

  static final Uint8List onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  static final Uint8List invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4]);

  static final Uint8List htmlBytes =
      Uint8List.fromList('<html><body>error</body></html>'.codeUnits);

  static MetadataArtworkReference sampleReference({
    String providerId = 'open_library',
    String providerRecordId = '/books/OL123M',
    String artworkId = '8230111',
    DateTime? fetchedAt,
  }) {
    final at = fetchedAt ?? DateTime.utc(2026, 8, 3, 12);
    return MetadataArtworkReference(
      providerId: providerId,
      providerRecordId: providerRecordId,
      artworkId: artworkId,
      kind: MetadataArtworkKind.cover,
      fetchedAt: at,
      cacheState: MetadataArtworkCacheState.available,
      cacheKey: MetadataArtworkCacheKey.compute(
        providerId: providerId,
        providerRecordId: providerRecordId,
        artworkId: artworkId,
      ),
    ).normalized();
  }

  static MetadataArtworkHttpResponse pngResponse(Uint8List bytes) {
    return MetadataArtworkHttpResponse(
      statusCode: 200,
      bodyBytes: bytes,
      contentType: 'image/png',
      headers: const {'etag': 'fixture-etag-1'},
    );
  }
}
