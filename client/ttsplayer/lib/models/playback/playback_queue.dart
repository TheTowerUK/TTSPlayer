import '../media_item.dart';

/// In-memory ordered audio playback queue (M5.3 Step 2).
///
/// Duplicate [MediaItem.id] values are allowed; ordering is list order.
/// Reconciliation replaces entries with catalogue-resolved items by stable id.
class PlaybackQueue {
  final List<MediaItem> items;
  final int currentIndex;
  final int generation;

  const PlaybackQueue({
    required this.items,
    required this.currentIndex,
    required this.generation,
  });

  const PlaybackQueue.empty()
      : items = const [],
        currentIndex = 0,
        generation = 0;

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  bool get hasCurrent =>
      items.isNotEmpty && currentIndex >= 0 && currentIndex < items.length;

  MediaItem? get currentItem => hasCurrent ? items[currentIndex] : null;

  MediaItem? get nextItem =>
      hasCurrent && currentIndex + 1 < items.length
          ? items[currentIndex + 1]
          : null;

  MediaItem? get previousItem =>
      hasCurrent && currentIndex > 0 ? items[currentIndex - 1] : null;

  bool get hasNext => nextItem != null;
  bool get hasPrevious => previousItem != null;

  /// Validates and normalises audio-only items for queue insertion.
  static List<MediaItem> audioOnlyItems(Iterable<MediaItem> source) {
    return [
      for (final item in source)
        if (item.isAudio && item.status.isPlayable) item,
    ];
  }

  PlaybackQueue replaceItems(
    List<MediaItem> newItems, {
    int startIndex = 0,
  }) {
    final audioItems = audioOnlyItems(newItems);
    if (audioItems.isEmpty) {
      return PlaybackQueue.empty().copyWithGeneration(generation + 1);
    }
    final index = startIndex.clamp(0, audioItems.length - 1);
    return PlaybackQueue(
      items: List<MediaItem>.unmodifiable(audioItems),
      currentIndex: index,
      generation: generation + 1,
    );
  }

  PlaybackQueue withCurrentIndex(int index) {
    if (items.isEmpty) return this;
    final clamped = index.clamp(0, items.length - 1);
    if (clamped == currentIndex) return this;
    return PlaybackQueue(
      items: items,
      currentIndex: clamped,
      generation: generation,
    );
  }

  PlaybackQueue advanceToNext() {
    if (!hasNext) return this;
    return withCurrentIndex(currentIndex + 1);
  }

  PlaybackQueue retreatToPrevious() {
    if (!hasPrevious) return this;
    return withCurrentIndex(currentIndex - 1);
  }

  /// Retains items whose ids still exist in [resolvedById]; preserves order.
  /// [resolvedById] maps catalogue item id → current [MediaItem] snapshot.
  PlaybackQueue reconcile(Map<String, MediaItem> resolvedById) {
    if (items.isEmpty) return this;

    final currentId = currentItem?.id;
    final retained = <MediaItem>[];
    for (final item in items) {
      final resolved = resolvedById[item.id];
      if (resolved != null && resolved.isAudio && resolved.status.isPlayable) {
        retained.add(resolved);
      }
    }

    if (retained.isEmpty) {
      return PlaybackQueue.empty().copyWithGeneration(generation + 1);
    }

    var newIndex = 0;
    if (currentId != null) {
      final idx = retained.indexWhere((item) => item.id == currentId);
      if (idx >= 0) {
        newIndex = idx;
      } else {
        newIndex = currentIndex.clamp(0, retained.length - 1);
      }
    }

    return PlaybackQueue(
      items: List<MediaItem>.unmodifiable(retained),
      currentIndex: newIndex,
      generation: generation + 1,
    );
  }

  PlaybackQueue copyWithGeneration(int value) {
    return PlaybackQueue(
      items: items,
      currentIndex: currentIndex,
      generation: value,
    );
  }
}
