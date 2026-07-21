/// Query and retention constants for music listening history (M5.4).
///
/// The 15-second history-creation threshold is enforced by
/// [MusicListeningCoordinator] in a later step — not here.
abstract final class MusicListeningPolicy {
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
