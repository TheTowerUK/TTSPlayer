/// Lifecycle state of metadata enrichment for a local catalogue item (M7.1).
enum EnrichmentMatchState {
  unmatched('unmatched'),
  linkedByIdentifier('linked_by_identifier'),
  linkedHighConfidence('linked_high_confidence'),
  linkedManual('linked_manual'),
  ambiguous('ambiguous'),
  ignored('ignored'),
  stale('stale');

  const EnrichmentMatchState(this.serializedValue);

  final String serializedValue;

  static EnrichmentMatchState? fromSerializedValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final state in EnrichmentMatchState.values) {
      if (state.serializedValue == value) return state;
    }
    return null;
  }

  static EnrichmentMatchState fromJson(dynamic value) {
    if (value is EnrichmentMatchState) return value;
    if (value is String) {
      return fromSerializedValue(value) ?? EnrichmentMatchState.unmatched;
    }
    return EnrichmentMatchState.unmatched;
  }

  String toJson() => serializedValue;
}
