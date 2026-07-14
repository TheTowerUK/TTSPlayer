/// Application DTO for an embedded subtitle track (ADR-010).
class PlaybackSubtitleTrack {
  final String id;
  final String? title;
  final String? language;

  const PlaybackSubtitleTrack({
    required this.id,
    this.title,
    this.language,
  });

  String get displayLabel {
    if (title != null && title!.isNotEmpty) {
      if (language != null && language!.isNotEmpty) {
        return '$title ($language)';
      }
      return title!;
    }
    if (language != null && language!.isNotEmpty) return language!;
    return 'Subtitle $id';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackSubtitleTrack &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
