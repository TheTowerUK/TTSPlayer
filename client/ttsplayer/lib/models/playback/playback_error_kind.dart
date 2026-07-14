/// Playback-layer error classification (ADR-013).
enum PlaybackErrorKind {
  resolverFailed,
  fileMissing,
  network,
  tls,
  httpNotFound,
  timeout,
  permission,
  unsupportedFormat,
  unknown,
}
