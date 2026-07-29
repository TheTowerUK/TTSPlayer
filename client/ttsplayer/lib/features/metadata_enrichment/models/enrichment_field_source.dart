/// Provenance source for an enriched presentation field (M7.1).
enum EnrichmentFieldSource {
  provider('provider'),
  userOverride('user_override');

  const EnrichmentFieldSource(this.serializedValue);

  final String serializedValue;

  static EnrichmentFieldSource? fromSerializedValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final source in EnrichmentFieldSource.values) {
      if (source.serializedValue == value) return source;
    }
    return null;
  }

  static EnrichmentFieldSource fromJson(dynamic value) {
    if (value is EnrichmentFieldSource) return value;
    if (value is String) {
      return fromSerializedValue(value) ?? EnrichmentFieldSource.provider;
    }
    return EnrichmentFieldSource.provider;
  }

  String toJson() => serializedValue;
}
