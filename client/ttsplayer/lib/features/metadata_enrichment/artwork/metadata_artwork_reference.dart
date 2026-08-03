import 'metadata_artwork_cache_key.dart';
import 'metadata_artwork_cache_state.dart';
import 'metadata_artwork_kind.dart';

/// Provider-neutral artwork identity persisted on an enrichment record (M7.4.2).
///
/// Stores reference metadata only — never image bytes or signed download URLs.
class MetadataArtworkReference {
  const MetadataArtworkReference({
    required this.providerId,
    required this.providerRecordId,
    required this.artworkId,
    required this.kind,
    required this.fetchedAt,
    required this.cacheState,
    required this.cacheKey,
    this.contentType,
    this.width,
    this.height,
    this.validatedAt,
    this.localRelativePath,
    this.validator,
  });

  final String providerId;
  final String providerRecordId;
  final String artworkId;
  final MetadataArtworkKind kind;
  final String? contentType;
  final int? width;
  final int? height;
  final DateTime fetchedAt;
  final DateTime? validatedAt;
  final MetadataArtworkCacheState cacheState;
  final String cacheKey;
  final String? localRelativePath;
  final String? validator;

  MetadataArtworkReference copyWith({
    String? providerId,
    String? providerRecordId,
    String? artworkId,
    MetadataArtworkKind? kind,
    String? contentType,
    int? width,
    int? height,
    DateTime? fetchedAt,
    DateTime? validatedAt,
    MetadataArtworkCacheState? cacheState,
    String? cacheKey,
    String? localRelativePath,
    String? validator,
    bool clearContentType = false,
    bool clearWidth = false,
    bool clearHeight = false,
    bool clearValidatedAt = false,
    bool clearLocalRelativePath = false,
    bool clearValidator = false,
  }) {
    return MetadataArtworkReference(
      providerId: providerId ?? this.providerId,
      providerRecordId: providerRecordId ?? this.providerRecordId,
      artworkId: artworkId ?? this.artworkId,
      kind: kind ?? this.kind,
      contentType:
          clearContentType ? null : (contentType ?? this.contentType),
      width: clearWidth ? null : (width ?? this.width),
      height: clearHeight ? null : (height ?? this.height),
      fetchedAt: fetchedAt ?? this.fetchedAt,
      validatedAt:
          clearValidatedAt ? null : (validatedAt ?? this.validatedAt),
      cacheState: cacheState ?? this.cacheState,
      cacheKey: cacheKey ?? this.cacheKey,
      localRelativePath: clearLocalRelativePath
          ? null
          : (localRelativePath ?? this.localRelativePath),
      validator: clearValidator ? null : (validator ?? this.validator),
    );
  }

  MetadataArtworkReference normalized() {
    int? normalizedWidth;
    if (width != null && width! > 0) {
      normalizedWidth = width;
    }

    int? normalizedHeight;
    if (height != null && height! > 0) {
      normalizedHeight = height;
    }

    final normalizedProviderId = _trimOrNull(providerId);
    final normalizedRecordId = _trimOrNull(providerRecordId);
    final normalizedArtworkId = _trimOrNull(artworkId);
    if (normalizedProviderId == null ||
        normalizedRecordId == null ||
        normalizedArtworkId == null) {
      throw ArgumentError(
        'providerId, providerRecordId, and artworkId must be non-empty.',
      );
    }

    final expectedCacheKey = MetadataArtworkCacheKey.compute(
      providerId: normalizedProviderId,
      providerRecordId: normalizedRecordId,
      artworkId: normalizedArtworkId,
    );
    final normalizedCacheKey =
        cacheKey.trim().isEmpty ? expectedCacheKey : cacheKey.trim();
    if (normalizedCacheKey != expectedCacheKey) {
      throw ArgumentError('cacheKey does not match artwork identity.');
    }

    return MetadataArtworkReference(
      providerId: normalizedProviderId,
      providerRecordId: normalizedRecordId,
      artworkId: normalizedArtworkId,
      kind: kind,
      contentType: _trimOrNull(contentType),
      width: normalizedWidth,
      height: normalizedHeight,
      fetchedAt: fetchedAt.toUtc(),
      validatedAt: validatedAt?.toUtc(),
      cacheState: cacheState,
      cacheKey: normalizedCacheKey,
      localRelativePath: _trimOrNull(localRelativePath),
      validator: _trimOrNull(validator),
    );
  }

  static MetadataArtworkReference? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
    String recordItemId = '',
  }) {
    final providerId = _optionalString(json['providerId']);
    final providerRecordId = _optionalString(json['providerRecordId']);
    final artworkId = _optionalString(json['artworkId']);
    if (providerId == null || providerRecordId == null || artworkId == null) {
      warnings?.add(
        recordItemId.isEmpty
            ? 'Skipped artworkReference with missing identity fields.'
            : 'Skipped artworkReference on item "$recordItemId".',
      );
      return null;
    }

    DateTime? fetchedAt;
    final rawFetchedAt = json['fetchedAt'];
    if (rawFetchedAt is String && rawFetchedAt.isNotEmpty) {
      fetchedAt = DateTime.tryParse(rawFetchedAt)?.toUtc();
      if (fetchedAt == null) {
        warnings?.add(
          recordItemId.isEmpty
              ? 'Ignored invalid artworkReference fetchedAt.'
              : 'Ignored invalid artworkReference fetchedAt on item "$recordItemId".',
        );
      }
    }
    if (fetchedAt == null) {
      warnings?.add(
        recordItemId.isEmpty
            ? 'Skipped artworkReference with missing fetchedAt.'
            : 'Skipped artworkReference on item "$recordItemId" (missing fetchedAt).',
      );
      return null;
    }

    DateTime? validatedAt;
    final rawValidatedAt = json['validatedAt'];
    if (rawValidatedAt is String && rawValidatedAt.isNotEmpty) {
      validatedAt = DateTime.tryParse(rawValidatedAt)?.toUtc();
      if (validatedAt == null) {
        warnings?.add(
          recordItemId.isEmpty
              ? 'Ignored invalid artworkReference validatedAt.'
              : 'Ignored invalid artworkReference validatedAt on item "$recordItemId".',
        );
      }
    }

    final cacheKey = _optionalString(json['cacheKey']);
    if (cacheKey == null) {
      warnings?.add(
        recordItemId.isEmpty
            ? 'Skipped artworkReference with missing cacheKey.'
            : 'Skipped artworkReference on item "$recordItemId" (missing cacheKey).',
      );
      return null;
    }

    int? width;
    final rawWidth = json['width'];
    if (rawWidth is num && rawWidth.isFinite && rawWidth > 0) {
      width = rawWidth.toInt();
    } else if (rawWidth != null) {
      warnings?.add(
        recordItemId.isEmpty
            ? 'Ignored invalid artworkReference width.'
            : 'Ignored invalid artworkReference width on item "$recordItemId".',
      );
    }

    int? height;
    final rawHeight = json['height'];
    if (rawHeight is num && rawHeight.isFinite && rawHeight > 0) {
      height = rawHeight.toInt();
    } else if (rawHeight != null) {
      warnings?.add(
        recordItemId.isEmpty
            ? 'Ignored invalid artworkReference height.'
            : 'Ignored invalid artworkReference height on item "$recordItemId".',
      );
    }

    try {
      return MetadataArtworkReference(
        providerId: providerId,
        providerRecordId: providerRecordId,
        artworkId: artworkId,
        kind: MetadataArtworkKind.fromJson(json['kind']),
        contentType: _optionalString(json['contentType']),
        width: width,
        height: height,
        fetchedAt: fetchedAt,
        validatedAt: validatedAt,
        cacheState: MetadataArtworkCacheState.fromJson(json['cacheState']),
        cacheKey: cacheKey,
        localRelativePath: _optionalString(json['localRelativePath']),
        validator: _optionalString(json['validator']),
      ).normalized();
    } on ArgumentError {
      warnings?.add(
        recordItemId.isEmpty
            ? 'Skipped artworkReference with invalid identity or cacheKey.'
            : 'Skipped artworkReference on item "$recordItemId" (invalid identity).',
      );
      return null;
    }
  }

  Map<String, Object?> toJson() {
    return {
      'providerId': providerId,
      'providerRecordId': providerRecordId,
      'artworkId': artworkId,
      'kind': kind.toJson(),
      if (contentType != null) 'contentType': contentType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'fetchedAt': fetchedAt.toIso8601String(),
      if (validatedAt != null) 'validatedAt': validatedAt!.toIso8601String(),
      'cacheState': cacheState.toJson(),
      'cacheKey': cacheKey,
      if (localRelativePath != null) 'localRelativePath': localRelativePath,
      if (validator != null) 'validator': validator,
    };
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
    return other is MetadataArtworkReference &&
        other.providerId == providerId &&
        other.providerRecordId == providerRecordId &&
        other.artworkId == artworkId &&
        other.kind == kind &&
        other.contentType == contentType &&
        other.width == width &&
        other.height == height &&
        other.fetchedAt == fetchedAt &&
        other.validatedAt == validatedAt &&
        other.cacheState == cacheState &&
        other.cacheKey == cacheKey &&
        other.localRelativePath == localRelativePath &&
        other.validator == validator;
  }

  @override
  int get hashCode => Object.hash(
        providerId,
        providerRecordId,
        artworkId,
        kind,
        contentType,
        width,
        height,
        fetchedAt,
        validatedAt,
        cacheState,
        cacheKey,
        localRelativePath,
        validator,
      );
}
