import 'dart:async';

import '../../models/playback/playback_error_kind.dart';
import '../media_access/resolved_media_location.dart';
import 'playback_error_messages.dart';

class PlaybackErrorMapping {
  final PlaybackErrorKind kind;
  final String userMessage;
  final String? debugDetail;

  const PlaybackErrorMapping({
    required this.kind,
    required this.userMessage,
    this.debugDetail,
  });
}

/// Maps resolver and exception inputs to playback-layer taxonomy (ADR-013).
class PlaybackErrorMapper {
  PlaybackErrorMapper._();

  static PlaybackErrorMapping fromResolver(ResolvedMediaLocation location) {
    return PlaybackErrorMapping(
      kind: PlaybackErrorKind.resolverFailed,
      userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.resolverFailed),
      debugDetail: location.errorReason,
    );
  }

  static PlaybackErrorMapping fileMissing({String? debugDetail}) {
    return PlaybackErrorMapping(
      kind: PlaybackErrorKind.fileMissing,
      userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.fileMissing),
      debugDetail: debugDetail,
    );
  }

  static PlaybackErrorMapping fromException(Object error) {
    if (error is TimeoutException) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.timeout,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.timeout),
        debugDetail: error.toString(),
      );
    }

    final raw = error.toString();
    if (_containsAny(raw, ['No such file', 'FileNotFound', 'file not found'])) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.fileMissing,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.fileMissing),
        debugDetail: raw,
      );
    }
    if (_containsAny(raw, ['Certificate', 'TLS', 'SSL', 'HandshakeException'])) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.tls,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.tls),
        debugDetail: raw,
      );
    }
    if (_containsAny(raw, ['404', 'Not Found', 'HTTP 404'])) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.httpNotFound,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.httpNotFound),
        debugDetail: raw,
      );
    }
    if (_containsAny(raw, ['Permission', 'Access denied', 'Access is denied'])) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.permission,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.permission),
        debugDetail: raw,
      );
    }
    if (_containsAny(raw, [
      'NetworkError',
      'SocketException',
      'Connection refused',
      'Connection reset',
      'Failed host lookup',
    ])) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.network,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
        debugDetail: raw,
      );
    }
    if (_containsAny(raw, [
      'format',
      'codec',
      'PlatformException',
      'UnimplementedError',
      'unsupported',
    ])) {
      return PlaybackErrorMapping(
        kind: PlaybackErrorKind.unsupportedFormat,
        userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.unsupportedFormat),
        debugDetail: raw,
      );
    }

    return PlaybackErrorMapping(
      kind: PlaybackErrorKind.unknown,
      userMessage: PlaybackErrorMessages.forKind(PlaybackErrorKind.unknown),
      debugDetail: raw,
    );
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}
