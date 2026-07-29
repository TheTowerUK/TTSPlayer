/// Bounded repository/provider error category (M7.1 — no raw exception text).
enum EnrichmentLastErrorCategory {
  decodeFailure('decode_failure'),
  unsupportedSchema('unsupported_schema'),
  persistenceFailure('persistence_failure'),
  malformedRecord('malformed_record'),
  authenticationFailure('authentication_failure'),
  rateLimited('rate_limited'),
  networkFailure('network_failure'),
  providerUnavailable('provider_unavailable'),
  notFound('not_found'),
  parseFailure('parse_failure'),
  cancelled('cancelled');

  const EnrichmentLastErrorCategory(this.serializedValue);

  final String serializedValue;

  static EnrichmentLastErrorCategory? fromSerializedValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final category in EnrichmentLastErrorCategory.values) {
      if (category.serializedValue == value) return category;
    }
    return null;
  }

  static EnrichmentLastErrorCategory? fromJson(dynamic value) {
    if (value is EnrichmentLastErrorCategory) return value;
    if (value is String) return fromSerializedValue(value);
    return null;
  }

  String? toJson() => serializedValue;
}
