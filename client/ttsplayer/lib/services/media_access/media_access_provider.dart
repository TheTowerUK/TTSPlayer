/// Which access provider produced a resolved media location.
enum MediaAccessProviderType {
  /// Input was already an http(s) URL.
  passThrough,

  /// Local or UNC filesystem path mapped to a file URI.
  localFile,

  /// Filesystem path mapped via HTTP serving layer rules.
  httpServing,
}

/// Outcome of a media location resolution attempt.
enum MediaLocationResolveStatus {
  /// URI is ready for the player.
  resolved,

  /// No provider could map the path.
  unresolved,

  /// Secondary provider used (reserved for future fallback flows).
  fallback,
}

extension MediaLocationResolveStatusLabels on MediaLocationResolveStatus {
  bool get isPlayable => this == MediaLocationResolveStatus.resolved;
}
