import 'http_metadata_http_transport.dart';
import 'metadata_http_transport.dart';

/// Deterministic metadata HTTP transport for tests (M7.2).
class FakeMetadataHttpTransport implements MetadataHttpTransport {
  FakeMetadataHttpTransport({
    Map<String, MetadataHttpResponse>? responses,
    this.defaultResponse,
    this.throwOnRequest,
    this.delay,
  }) : responses = responses ?? <String, MetadataHttpResponse>{};

  final Map<String, MetadataHttpResponse> responses;
  final MetadataHttpResponse? defaultResponse;
  final Object? throwOnRequest;
  final Duration? delay;

  final List<Uri> requestedUris = [];
  final List<Map<String, String>> requestedHeaders = [];
  int requestCount = 0;

  void registerResponse(String uriPrefix, MetadataHttpResponse response) {
    responses[uriPrefix] = response;
  }

  @override
  Future<MetadataHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
    MetadataCancellationToken? cancellationToken,
  }) async {
    requestCount++;
    requestedUris.add(uri);
    requestedHeaders.add(headers ?? const {});

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

    for (final entry in responses.entries) {
      if (uri.toString().startsWith(entry.key)) {
        return entry.value;
      }
    }

    if (defaultResponse != null) {
      return defaultResponse!;
    }

    return const MetadataHttpResponse(statusCode: 404, body: '{}');
  }
}
