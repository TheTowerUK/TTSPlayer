/// HTTP response wrapper for metadata providers (M7.2).
class MetadataHttpResponse {
  const MetadataHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
    this.contentType,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final String? contentType;
}

/// Lightweight cancellation token for metadata HTTP requests (M7.2).
class MetadataCancellationToken {
  MetadataCancellationToken();

  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Injectable HTTP transport for metadata providers (M7.2).
abstract class MetadataHttpTransport {
  Future<MetadataHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
    MetadataCancellationToken? cancellationToken,
  });
}
