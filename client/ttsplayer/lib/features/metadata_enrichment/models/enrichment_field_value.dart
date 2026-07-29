import 'enrichment_field_source.dart';

/// One enriched presentation field with provenance (M7.1).
///
/// Does not duplicate catalogue-local values — only provider or user override
/// presentation data belongs here.
class EnrichmentFieldValue {
  const EnrichmentFieldValue({
    required this.value,
    required this.source,
    this.providerId,
    this.updatedAt,
    this.locked = false,
  });

  final String value;
  final EnrichmentFieldSource source;
  final String? providerId;
  final DateTime? updatedAt;
  final bool locked;

  EnrichmentFieldValue copyWith({
    String? value,
    EnrichmentFieldSource? source,
    String? providerId,
    DateTime? updatedAt,
    bool? locked,
    bool clearProviderId = false,
    bool clearUpdatedAt = false,
  }) {
    return EnrichmentFieldValue(
      value: value ?? this.value,
      source: source ?? this.source,
      providerId: clearProviderId ? null : (providerId ?? this.providerId),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      locked: locked ?? this.locked,
    );
  }

  EnrichmentFieldValue normalized() {
    return EnrichmentFieldValue(
      value: value.trim(),
      source: source,
      providerId: providerId?.trim().isEmpty ?? true ? null : providerId!.trim(),
      updatedAt: updatedAt?.toUtc(),
      locked: locked,
    );
  }

  static EnrichmentFieldValue? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
    required String fieldKey,
  }) {
    final rawValue = json['value'];
    if (rawValue is! String || rawValue.trim().isEmpty) {
      warnings?.add('Skipped enriched field "$fieldKey" with missing value.');
      return null;
    }

    DateTime? updatedAt;
    final rawUpdatedAt = json['updatedAt'];
    if (rawUpdatedAt is String && rawUpdatedAt.isNotEmpty) {
      updatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
      if (updatedAt == null) {
        warnings?.add('Ignored invalid updatedAt on field "$fieldKey".');
      }
    }

    final providerId = json['providerId'];
    return EnrichmentFieldValue(
      value: rawValue,
      source: EnrichmentFieldSource.fromJson(json['source']),
      providerId: providerId is String && providerId.trim().isNotEmpty
          ? providerId.trim()
          : null,
      updatedAt: updatedAt,
      locked: json['locked'] == true,
    ).normalized();
  }

  Map<String, Object?> toJson() => {
        'value': value,
        'source': source.toJson(),
        if (providerId != null) 'providerId': providerId,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (locked) 'locked': true,
      };

  @override
  bool operator ==(Object other) {
    return other is EnrichmentFieldValue &&
        other.value == value &&
        other.source == source &&
        other.providerId == providerId &&
        other.updatedAt == updatedAt &&
        other.locked == locked;
  }

  @override
  int get hashCode => Object.hash(value, source, providerId, updatedAt, locked);
}
