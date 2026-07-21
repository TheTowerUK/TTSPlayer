/// Query, retention, and coordinator constants for music listening history (M5.4).
abstract final class MusicListeningPolicy {
  /// Minimum meaningful playback before a new history record is created.
  static const minListenThreshold = Duration(seconds: 15);

  /// Minimum interval between in-progress persistence writes during playback.
  static const persistInterval = Duration(seconds: 5);

  /// Maximum records persisted in [MusicListeningRepository].
  static const maxStoredRecords = 100;

  /// Default cap for [MusicListeningRepository.recentlyPlayed] queries.
  static const defaultRecentlyPlayedQueryCap = 20;

  /// Minimum saved position before a record appears in Continue Listening.
  static const minResumePosition = Duration(seconds: 30);

  /// Remaining duration below which an incomplete track is treated as complete
  /// for Continue Listening eligibility (matches video [ResumeInfo.nearEndWindow]).
  static const nearEndWindow = Duration(minutes: 2);

  /// Default cap for [MusicListeningRepository.continueListening] queries.
  static const defaultContinueListeningQueryCap = 8;
}
