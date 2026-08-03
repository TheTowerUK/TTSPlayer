/// Item-scoped generation tokens for artwork retrieval (M7.4.3).
///
/// Prevents a delayed download started before relink from committing against a
/// superseded provider record.
class MetadataArtworkDownloadGenerationGuard {
  final Map<String, int> _generations = {};

  int generationFor(String itemId) => _generations[itemId] ?? 0;

  int bump(String itemId) {
    final next = generationFor(itemId) + 1;
    _generations[itemId] = next;
    return next;
  }

  bool isCurrent(String itemId, int expectedGeneration) {
    return generationFor(itemId) == expectedGeneration;
  }
}
