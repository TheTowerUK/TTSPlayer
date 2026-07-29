/// How a local item was linked to an external provider record (M7.1).
enum EnrichmentMatchMethod {
  identifier('identifier'),
  automatic('automatic'),
  manual('manual');

  const EnrichmentMatchMethod(this.serializedValue);

  final String serializedValue;

  static EnrichmentMatchMethod? fromSerializedValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final method in EnrichmentMatchMethod.values) {
      if (method.serializedValue == value) return method;
    }
    return null;
  }

  static EnrichmentMatchMethod? fromJson(dynamic value) {
    if (value is EnrichmentMatchMethod) return value;
    if (value is String) return fromSerializedValue(value);
    return null;
  }

  String? toJson() => serializedValue;
}
