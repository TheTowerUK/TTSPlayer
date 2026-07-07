import 'dart:async';
import 'dart:io';

/// Readable error messages for remote catalogue/media fetch failures (Phase 4.5).
class RemoteFetchErrors {
  RemoteFetchErrors._();

  /// Maps network/TLS/HTTP failures to user-facing catalogue load messages.
  static String catalogueLoadMessage(Object error, String url) {
    if (error is TimeoutException) {
      return 'Timed out loading catalogue. Check the URL and network.';
    }
    if (error is SocketException) {
      return 'Network error loading catalogue: ${error.message}';
    }
    if (error is HandshakeException) {
      return 'Secure connection failed for $url. '
          'The server certificate may be untrusted — trust the Caddy CA or use '
          'a valid certificate. (${error.message})';
    }
    if (error is CertificateException) {
      return 'Certificate error loading catalogue from $url. ${error.message}';
    }
    if (error is TlsException) {
      return 'TLS error loading catalogue: ${error.message}';
    }
    if (error is HttpException) {
      return error.message;
    }
    return 'Could not load catalogue: $error';
  }
}
