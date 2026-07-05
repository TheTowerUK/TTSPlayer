import 'library_visual_kind.dart';
import 'artwork_kind.dart';

/// Result of artwork resolution for a library, folder, or media item.
class ArtworkCandidate {
  final ArtworkKind kind;
  final ArtworkSource source;
  final String? filePath;
  final LibraryVisualKind visualKind;

  const ArtworkCandidate({
    required this.kind,
    required this.source,
    required this.filePath,
    required this.visualKind,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  /// Stable cache key for this candidate's entity.
  String cacheKeyFor(String entityId) => '$entityId:${filePath ?? 'placeholder'}';
}
