import 'dart:typed_data';

import '../transport/http_metadata_http_transport.dart';
import '../transport/metadata_http_transport.dart';
import 'metadata_artwork_http_client.dart';

/// Deterministic binary HTTP client for artwork tests (M7.4.3).
class FakeMetadataArtworkHttpClient implements MetadataArtworkHttpClient {
  FakeMetadataArtworkHttpClient({
    Map<String, MetadataArtworkHttpResponse>? responses,
    this.defaultResponse,
    this.throwOnRequest,
    this.delay,
    this.allowHttpForTests = true,
  }) : responses = responses ?? <String, MetadataArtworkHttpResponse>{};

  final Map<String, MetadataArtworkHttpResponse> responses;
  final MetadataArtworkHttpResponse? defaultResponse;
  final Object? throwOnRequest;
  final Duration? delay;
  final bool allowHttpForTests;

  final List<Uri> requestedUris = [];
  int requestCount = 0;

  void registerResponse(String uriPrefix, MetadataArtworkHttpResponse response) {
    responses[uriPrefix] = response;
  }

  @override
  Future<MetadataArtworkHttpResponse> getBytes(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
    MetadataCancellationToken? cancellationToken,
  }) async {
    requestCount++;
    requestedUris.add(uri);

    if (cancellationToken?.isCancelled ?? false) {
      throw const MetadataTransportCancelledException();
    }

    if (delay != null) {
      await Future<void>.delayed(delay!);
      if (cancellationToken?.isCancelled ?? false) {
        throw const MetadataTransportCancelledException();
      }
    }

    if (throwOnRequest != null) {
      throw throwOnRequest!;
    }

    if (!allowHttpForTests && uri.scheme != 'https') {
      throw const MetadataArtworkInsecureUriException();
    }

    for (final entry in responses.entries) {
      if (uri.toString().startsWith(entry.key)) {
        return entry.value;
      }
    }

    if (defaultResponse != null) {
      return defaultResponse!;
    }

    return MetadataArtworkHttpResponse(
      statusCode: 404,
      bodyBytes: Uint8List.fromList([]),
    );
  }
}
