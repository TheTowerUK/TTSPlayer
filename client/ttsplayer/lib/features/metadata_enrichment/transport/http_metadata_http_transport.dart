import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'metadata_http_transport.dart';

/// Production metadata HTTP transport backed by [http.Client] (M7.2).
///
/// When [client] is omitted, this transport creates and owns an internal
/// [http.Client] and closes it via [close]. When [client] is injected, the
/// caller retains ownership and must close it separately.
class HttpMetadataHttpTransport implements MetadataHttpTransport {
  HttpMetadataHttpTransport({
    http.Client? client,
    this.defaultTimeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration defaultTimeout;

  bool get ownsClient => _ownsClient;

  /// Closes the underlying [http.Client] only when this transport owns it.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<MetadataHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
    MetadataCancellationToken? cancellationToken,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      throw const MetadataTransportCancelledException();
    }

    final effectiveTimeout = timeout ?? defaultTimeout;
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(effectiveTimeout);

      if (cancellationToken?.isCancelled ?? false) {
        throw const MetadataTransportCancelledException();
      }

      return MetadataHttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
        contentType: response.headers['content-type'],
      );
    } on TimeoutException {
      throw const MetadataTransportTimeoutException();
    } on SocketException {
      throw const MetadataTransportNetworkException();
    } on HandshakeException {
      throw const MetadataTransportNetworkException();
    } on MetadataTransportCancelledException {
      rethrow;
    } catch (_) {
      throw const MetadataTransportNetworkException();
    }
  }
}

class MetadataTransportTimeoutException implements Exception {
  const MetadataTransportTimeoutException();
}

class MetadataTransportNetworkException implements Exception {
  const MetadataTransportNetworkException();
}

class MetadataTransportCancelledException implements Exception {
  const MetadataTransportCancelledException();
}
