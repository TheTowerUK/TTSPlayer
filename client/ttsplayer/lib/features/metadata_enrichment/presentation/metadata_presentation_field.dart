/// Provenance of a resolved presentation field (M7.5.2).
///
/// Distinct from persisted [EnrichmentFieldSource]: catalogue and absent are
/// presentation layers that never appear on enrichment field values.
enum MetadataPresentationProvenance {
  /// Explicit user override on the enrichment record.
  userOverride,

  /// Catalogue / filesystem (includes scan-time embedded metadata).
  catalogue,

  /// Accepted linked provider enrichment.
  provider,

  /// No meaningful value after precedence resolution.
  absent,
}

/// One resolved scalar presentation value with typed provenance.
class MetadataPresentationField {
  const MetadataPresentationField({
    required this.value,
    required this.provenance,
    this.providerId,
  });

  static const absent = MetadataPresentationField(
    value: null,
    provenance: MetadataPresentationProvenance.absent,
  );

  final String? value;
  final MetadataPresentationProvenance provenance;
  final String? providerId;

  bool get hasValue => value != null && value!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is MetadataPresentationField &&
        other.value == value &&
        other.provenance == provenance &&
        other.providerId == providerId;
  }

  @override
  int get hashCode => Object.hash(value, provenance, providerId);
}

/// One resolved list presentation value with typed provenance.
///
/// [provenance] describes the winning layer for the displayed list.
/// Structured search lists may still include catalogue terms independently.
class MetadataPresentationListField {
  MetadataPresentationListField({
    required List<String> values,
    required this.provenance,
    this.providerId,
  }) : values = List<String>.unmodifiable(values);

  static final absent = MetadataPresentationListField(
    values: const [],
    provenance: MetadataPresentationProvenance.absent,
  );

  final List<String> values;
  final MetadataPresentationProvenance provenance;
  final String? providerId;

  bool get hasValue => values.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is MetadataPresentationListField &&
        _listEquals(other.values, values) &&
        other.provenance == provenance &&
        other.providerId == providerId;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(values),
        provenance,
        providerId,
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
