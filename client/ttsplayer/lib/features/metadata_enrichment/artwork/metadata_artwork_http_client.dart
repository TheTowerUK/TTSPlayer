import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../transport/http_metadata_http_transport.dart';
import '../transport/metadata_http_transport.dart';

/// Binary HTTP response for artwork downloads (M7.4.3).
class MetadataArtworkHttpResponse {
  const MetadataArtworkHttpResponse({
    required this.statusCode,
    required this.bodyBytes,
    this.headers = const {},
    this.contentType,
  });

  final int statusCode;
  final Uint8List bodyBytes;
  final Map<String, String> headers;
  final String? contentType;

  String? get validator => headers['etag'] ?? headers['last-modified'];
}

/// Injectable binary HTTP client for artwork retrieval (M7.4.3).
abstract class MetadataArtworkHttpClient {
  Future<MetadataArtworkHttpResponse> getBytes(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
    MetadataCancellationToken? cancellationToken,
  });
}

/// Production artwork HTTP client backed by [http.Client] (M7.4.3).
class HttpMetadataArtworkHttpClient implements MetadataArtworkHttpClient {
  HttpMetadataArtworkHttpClient({
    http.Client? client,
    this.defaultTimeout = const Duration(seconds: 15),
    this.allowHttpForTests = false,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration defaultTimeout;
  final bool allowHttpForTests;

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<MetadataArtworkHttpResponse> getBytes(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
    MetadataCancellationToken? cancellationToken,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      throw const MetadataTransportCancelledException();
    }
    if (!_isSecureUri(uri)) {
      throw const MetadataArtworkInsecureUriException();
    }

    final effectiveTimeout = timeout ?? defaultTimeout;
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(effectiveTimeout);

      if (cancellationToken?.isCancelled ?? false) {
        throw const MetadataTransportCancelledException();
      }

      return MetadataArtworkHttpResponse(
        statusCode: response.statusCode,
        bodyBytes: Uint8List.fromList(response.bodyBytes),
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

  bool _isSecureUri(Uri uri) {
    if (uri.scheme == 'https') return true;
    if (allowHttpForTests && uri.scheme == 'http') return true;
    return false;
  }
}

class MetadataArtworkInsecureUriException implements Exception {
  const MetadataArtworkInsecureUriException();
}
