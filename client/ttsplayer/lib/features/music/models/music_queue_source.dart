/// Lightweight in-memory queue source descriptor (M5.3 Step 3).
enum MusicQueueSourceKind {
  singleTrack,
  album,
  artist,
}

class MusicQueueSource {
  final MusicQueueSourceKind kind;
  final String label;
  final String identityKey;

  const MusicQueueSource({
    required this.kind,
    required this.label,
    required this.identityKey,
  });

  const MusicQueueSource.singleTrack()
      : kind = MusicQueueSourceKind.singleTrack,
        label = '',
        identityKey = '';

  bool get hasLabel => label.isNotEmpty;
}
