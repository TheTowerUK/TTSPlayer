/// Result of a playback control action (rate / track selection).
enum PlaybackActionStatus {
  success,
  unsupported,
  invalidArgument,
  backendFailed,
}

class PlaybackActionResult {
  final PlaybackActionStatus status;
  final String? debugDetail;

  const PlaybackActionResult._(this.status, [this.debugDetail]);

  const PlaybackActionResult.success() : this._(PlaybackActionStatus.success);

  const PlaybackActionResult.unsupported([String? detail])
      : this._(PlaybackActionStatus.unsupported, detail);

  const PlaybackActionResult.invalidArgument([String? detail])
      : this._(PlaybackActionStatus.invalidArgument, detail);

  const PlaybackActionResult.backendFailed([String? detail])
      : this._(PlaybackActionStatus.backendFailed, detail);

  bool get isSuccess => status == PlaybackActionStatus.success;
}
