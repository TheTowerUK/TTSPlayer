import 'enrichment_field_value.dart';
import 'enrichment_last_error_category.dart';
import 'enrichment_match_method.dart';
import 'enrichment_match_state.dart';
import '../artwork/metadata_artwork_reference.dart';

/// Persisted metadata enrichment overlay for one local catalogue item (M7.1).
///
/// [itemId] is the sole identity key (md5 of catalogue file path). Provider
/// identifiers are secondary linkage metadata only.
///
/// **Field locks:** [lockedFields] is authoritative. [EnrichmentFieldValue.locked]
/// is derived on [normalized] and must not disagree after normalization.
class MetadataEnrichmentRecord {
  const MetadataEnrichmentRecord({
    required this.itemId,
    required this.matchState,
    this.providerId,
    this.providerRecordId,
    this.providerMediaType,
    this.matchMethod,
    this.confidence,
    this.fields = const {},
    this.fetchedAt,
    this.expiresAt,
    this.lockedFields = const [],
    this.lastErrorCategory,
    this.artworkReference,
  });

  final String itemId;
  final EnrichmentMatchState matchState;
  final String? providerId;
  final String? providerRecordId;
  final String? providerMediaType;
  final EnrichmentMatchMethod? matchMethod;
  final double? confidence;
  final Map<String, EnrichmentFieldValue> fields;
  final DateTime? fetchedAt;
  final DateTime? expiresAt;
  final List<String> lockedFields;
  final EnrichmentLastErrorCategory? lastErrorCategory;
  final MetadataArtworkReference? artworkReference;

  bool get ignored => matchState == EnrichmentMatchState.ignored;

  MetadataEnrichmentRecord copyWith({
    String? itemId,
    EnrichmentMatchState? matchState,
    String? providerId,
    String? providerRecordId,
    String? providerMediaType,
    EnrichmentMatchMethod? matchMethod,
    double? confidence,
    Map<String, EnrichmentFieldValue>? fields,
    DateTime? fetchedAt,
    DateTime? expiresAt,
    List<String>? lockedFields,
    EnrichmentLastErrorCategory? lastErrorCategory,
    MetadataArtworkReference? artworkReference,
    bool clearProviderId = false,
    bool clearProviderRecordId = false,
    bool clearProviderMediaType = false,
    bool clearMatchMethod = false,
    bool clearConfidence = false,
    bool clearFetchedAt = false,
    bool clearExpiresAt = false,
    bool clearLastErrorCategory = false,
    bool clearArtworkReference = false,
  }) {
    return MetadataEnrichmentRecord(
      itemId: itemId ?? this.itemId,
      matchState: matchState ?? this.matchState,
      providerId: clearProviderId ? null : (providerId ?? this.providerId),
      providerRecordId: clearProviderRecordId
          ? null
          : (providerRecordId ?? this.providerRecordId),
      providerMediaType: clearProviderMediaType
          ? null
          : (providerMediaType ?? this.providerMediaType),
      matchMethod:
          clearMatchMethod ? null : (matchMethod ?? this.matchMethod),
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      fields: fields ?? this.fields,
      fetchedAt: clearFetchedAt ? null : (fetchedAt ?? this.fetchedAt),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      lockedFields: lockedFields ?? this.lockedFields,
      lastErrorCategory: clearLastErrorCategory
          ? null
          : (lastErrorCategory ?? this.lastErrorCategory),
      artworkReference: clearArtworkReference
          ? null
          : (artworkReference ?? this.artworkReference),
    );
  }

  MetadataEnrichmentRecord normalized() {
    final normalizedFields = <String, EnrichmentFieldValue>{};
    for (final entry in fields.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      normalizedFields[key] = entry.value.normalized();
    }

    final normalizedLocks = lockedFields
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();

    final lockSet = normalizedLocks.toSet();
    final syncedFields = <String, EnrichmentFieldValue>{};
    for (final entry in normalizedFields.entries) {
      syncedFields[entry.key] = entry.value.copyWith(
        locked: lockSet.contains(entry.key),
      );
    }

    double? normalizedConfidence;
    if (confidence != null && confidence!.isFinite) {
      normalizedConfidence = confidence!.clamp(0.0, 1.0);
    }

    return MetadataEnrichmentRecord(
      itemId: itemId.trim(),
      matchState: matchState,
      providerId: _trimOrNull(providerId),
      providerRecordId: _trimOrNull(providerRecordId),
      providerMediaType: _trimOrNull(providerMediaType),
      matchMethod: matchMethod,
      confidence: normalizedConfidence,
      fields: syncedFields,
      fetchedAt: fetchedAt?.toUtc(),
      expiresAt: expiresAt?.toUtc(),
      lockedFields: normalizedLocks,
      lastErrorCategory: lastErrorCategory,
      artworkReference: artworkReference?.normalized(),
    );
  }

  static MetadataEnrichmentRecord? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final itemId = json['itemId'];
    if (itemId is! String || itemId.trim().isEmpty) {
      warnings?.add('Skipped enrichment record with missing itemId.');
      return null;
    }

    final matchState = EnrichmentMatchState.fromJson(json['matchState']);

    final fields = _parseFields(json['fields'], warnings: warnings);

    DateTime? fetchedAt;
    final rawFetchedAt = json['fetchedAt'];
    if (rawFetchedAt is String && rawFetchedAt.isNotEmpty) {
      fetchedAt = DateTime.tryParse(rawFetchedAt)?.toUtc();
      if (fetchedAt == null) {
        warnings?.add('Ignored invalid fetchedAt on item "${itemId.trim()}".');
      }
    }

    DateTime? expiresAt;
    final rawExpiresAt = json['expiresAt'];
    if (rawExpiresAt is String && rawExpiresAt.isNotEmpty) {
      expiresAt = DateTime.tryParse(rawExpiresAt)?.toUtc();
      if (expiresAt == null) {
        warnings?.add('Ignored invalid expiresAt on item "${itemId.trim()}".');
      }
    }

    double? confidence;
    final rawConfidence = json['confidence'];
    if (rawConfidence is num && rawConfidence.isFinite) {
      confidence = rawConfidence.toDouble().clamp(0.0, 1.0);
    } else if (rawConfidence != null) {
      warnings?.add('Ignored invalid confidence on item "${itemId.trim()}".');
    }

    final lockedFields = _parseLockedFields(json['lockedFields'], warnings);

    MetadataArtworkReference? artworkReference;
    final rawArtworkReference = json['artworkReference'];
    if (rawArtworkReference != null) {
      if (rawArtworkReference is Map<String, dynamic>) {
        artworkReference = MetadataArtworkReference.fromJsonWithRecovery(
          rawArtworkReference,
          warnings: warnings,
          recordItemId: itemId.trim(),
        );
      } else {
        warnings?.add(
          'Ignored invalid artworkReference on item "${itemId.trim()}".',
        );
      }
    }

    return MetadataEnrichmentRecord(
      itemId: itemId.trim(),
      matchState: matchState,
      providerId: _optionalString(json['providerId']),
      providerRecordId: _optionalString(json['providerRecordId']),
      providerMediaType: _optionalString(json['providerMediaType']),
      matchMethod: EnrichmentMatchMethod.fromJson(json['matchMethod']),
      confidence: confidence,
      fields: fields,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
      lockedFields: lockedFields,
      lastErrorCategory:
          EnrichmentLastErrorCategory.fromJson(json['lastErrorCategory']),
      artworkReference: artworkReference,
    ).normalized();
  }

  Map<String, Object?> toJson() {
    final sortedFieldKeys = fields.keys.toList()..sort();
    return {
      'itemId': itemId,
      'matchState': matchState.toJson(),
      if (providerId != null) 'providerId': providerId,
      if (providerRecordId != null) 'providerRecordId': providerRecordId,
      if (providerMediaType != null) 'providerMediaType': providerMediaType,
      if (matchMethod != null) 'matchMethod': matchMethod!.toJson(),
      if (confidence != null) 'confidence': confidence,
      if (fields.isNotEmpty)
        'fields': {
          for (final key in sortedFieldKeys) key: fields[key]!.toJson(),
        },
      if (fetchedAt != null) 'fetchedAt': fetchedAt!.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (lockedFields.isNotEmpty) 'lockedFields': lockedFields,
      if (lastErrorCategory != null)
        'lastErrorCategory': lastErrorCategory!.toJson(),
      if (artworkReference != null)
        'artworkReference': artworkReference!.toJson(),
    };
  }

  static Map<String, EnrichmentFieldValue> _parseFields(
    dynamic raw, {
    List<String>? warnings,
  }) {
    if (raw == null) return const {};
    if (raw is! Map) {
      warnings?.add('Enrichment field map was invalid.');
      return const {};
    }

    final parsed = <String, EnrichmentFieldValue>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) continue;
      final key = (entry.key as String).trim();
      if (key.isEmpty) continue;
      if (entry.value is! Map<String, dynamic>) {
        warnings?.add('Skipped malformed enriched field "$key".');
        continue;
      }
      final field = EnrichmentFieldValue.fromJsonWithRecovery(
        entry.value as Map<String, dynamic>,
        warnings: warnings,
        fieldKey: key,
      );
      if (field != null) {
        parsed[key] = field;
      }
    }
    return parsed;
  }

  static List<String> _parseLockedFields(
    dynamic raw,
    List<String>? warnings,
  ) {
    if (raw == null) return const [];
    if (raw is! List) {
      warnings?.add('lockedFields was invalid.');
      return const [];
    }
    final parsed = <String>{};
    for (final entry in raw) {
      if (entry is! String || entry.trim().isEmpty) {
        warnings?.add('Skipped invalid lockedFields entry.');
        continue;
      }
      parsed.add(entry.trim());
    }
    final sorted = parsed.toList()..sort();
    return sorted;
  }

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    return _trimOrNull(value);
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) {
    return other is MetadataEnrichmentRecord &&
        other.itemId == itemId &&
        other.matchState == matchState &&
        other.providerId == providerId &&
        other.providerRecordId == providerRecordId &&
        other.providerMediaType == providerMediaType &&
        other.matchMethod == matchMethod &&
        other.confidence == confidence &&
        _mapEquals(other.fields, fields) &&
        other.fetchedAt == fetchedAt &&
        other.expiresAt == expiresAt &&
        _listEquals(other.lockedFields, lockedFields) &&
        other.lastErrorCategory == lastErrorCategory &&
        other.artworkReference == artworkReference;
  }

  @override
  int get hashCode => Object.hash(
        itemId,
        matchState,
        providerId,
        providerRecordId,
        providerMediaType,
        matchMethod,
        confidence,
        Object.hashAllUnordered(fields.entries),
        fetchedAt,
        expiresAt,
        Object.hashAll(lockedFields),
        lastErrorCategory,
        artworkReference,
      );

  static bool _mapEquals(
    Map<String, EnrichmentFieldValue> a,
    Map<String, EnrichmentFieldValue> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
