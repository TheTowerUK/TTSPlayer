import 'dart:async';

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
  final Completer<void> _cancelledSignal = Completer<void>();

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledSignal.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledSignal.complete();
  }
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
