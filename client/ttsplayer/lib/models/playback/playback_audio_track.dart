/// Application DTO for an embedded audio track (ADR-010).
class PlaybackAudioTrack {
  final String id;
  final String? title;
  final String? language;

  const PlaybackAudioTrack({
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
    return 'Audio $id';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackAudioTrack &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
