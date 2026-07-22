/// Outcome of cold-start playback session restoration (M5.5 Step 4).
class MusicPlaybackSessionRestoreResult {
  const MusicPlaybackSessionRestoreResult({
    required this.persistedQueueCount,
    required this.restoredQueueCount,
    required this.unresolvedCount,
    this.restoredActiveTrackId,
    this.activeTrackFellBack = false,
    this.restoredPosition = Duration.zero,
    this.queueEmpty = false,
    this.skipped = false,
    this.autoplayAttempted = false,
    this.warnings = const [],
  });

  final int persistedQueueCount;
  final int restoredQueueCount;
  final int unresolvedCount;
  final String? restoredActiveTrackId;
  final bool activeTrackFellBack;
  final Duration restoredPosition;
  final bool queueEmpty;
  final bool skipped;
  final bool autoplayAttempted;
  final List<String> warnings;

  bool get success => warnings.isEmpty || restoredQueueCount > 0 || queueEmpty;
}
