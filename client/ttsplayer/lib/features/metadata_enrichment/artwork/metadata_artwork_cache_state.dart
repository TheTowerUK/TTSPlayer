/// Local cache lifecycle for provider artwork references (M7.4.2).
enum MetadataArtworkCacheState {
  /// Identity known; no validated local file yet.
  available('available'),

  /// Validated file present on disk (7.4.3+).
  downloaded('downloaded'),

  /// Cached file may be outdated relative to provider revision.
  stale('stale'),

  /// Last explicit download or validation failed.
  failed('failed'),

  /// Provider artwork unavailable for this reference.
  unavailable('unavailable');

  const MetadataArtworkCacheState(this.serializedValue);

  final String serializedValue;

  static MetadataArtworkCacheState? fromSerializedValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final state in MetadataArtworkCacheState.values) {
      if (state.serializedValue == value) return state;
    }
    return null;
  }

  static MetadataArtworkCacheState fromJson(dynamic value) {
    if (value is MetadataArtworkCacheState) return value;
    if (value is String) {
      return fromSerializedValue(value) ?? MetadataArtworkCacheState.available;
    }
    return MetadataArtworkCacheState.available;
  }

  String toJson() => serializedValue;
}
