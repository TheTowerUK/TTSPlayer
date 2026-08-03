import 'metadata_artwork_cache_state.dart';

/// Persistent disk-cache metadata for one provider artwork file (M7.4.3).
///
/// Stored in the cache index — never contains image bytes.
class MetadataArtworkCacheEntry {
  const MetadataArtworkCacheEntry({
    required this.cacheKey,
    required this.providerId,
    required this.providerRecordId,
    required this.artworkId,
    required this.relativePath,
    required this.contentType,
    required this.byteSize,
    required this.createdAt,
    required this.lastValidatedAt,
    required this.lastAccessedAt,
    required this.cacheState,
    this.width,
    this.height,
    this.validator,
  });

  final String cacheKey;
  final String providerId;
  final String providerRecordId;
  final String artworkId;
  final String relativePath;
  final String contentType;
  final int? width;
  final int? height;
  final int byteSize;
  final DateTime createdAt;
  final DateTime lastValidatedAt;
  final DateTime lastAccessedAt;
  final String? validator;
  final MetadataArtworkCacheState cacheState;

  MetadataArtworkCacheEntry copyWith({
    String? cacheKey,
    String? providerId,
    String? providerRecordId,
    String? artworkId,
    String? relativePath,
    String? contentType,
    int? width,
    int? height,
    int? byteSize,
    DateTime? createdAt,
    DateTime? lastValidatedAt,
    DateTime? lastAccessedAt,
    String? validator,
    MetadataArtworkCacheState? cacheState,
    bool clearWidth = false,
    bool clearHeight = false,
    bool clearValidator = false,
  }) {
    return MetadataArtworkCacheEntry(
      cacheKey: cacheKey ?? this.cacheKey,
      providerId: providerId ?? this.providerId,
      providerRecordId: providerRecordId ?? this.providerRecordId,
      artworkId: artworkId ?? this.artworkId,
      relativePath: relativePath ?? this.relativePath,
      contentType: contentType ?? this.contentType,
      width: clearWidth ? null : (width ?? this.width),
      height: clearHeight ? null : (height ?? this.height),
      byteSize: byteSize ?? this.byteSize,
      createdAt: createdAt ?? this.createdAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      validator: clearValidator ? null : (validator ?? this.validator),
      cacheState: cacheState ?? this.cacheState,
    );
  }

  MetadataArtworkCacheEntry normalized() {
    final normalizedKey = cacheKey.trim();
    final normalizedPath = relativePath.trim();
    if (normalizedKey.isEmpty || normalizedPath.isEmpty) {
      throw ArgumentError('cacheKey and relativePath must be non-empty.');
    }
    if (byteSize <= 0) {
      throw ArgumentError('byteSize must be positive.');
    }
    return MetadataArtworkCacheEntry(
      cacheKey: normalizedKey,
      providerId: _requireTrimmed(providerId, 'providerId'),
      providerRecordId: _requireTrimmed(providerRecordId, 'providerRecordId'),
      artworkId: _requireTrimmed(artworkId, 'artworkId'),
      relativePath: _sanitizeRelativePath(normalizedPath),
      contentType: _requireTrimmed(contentType, 'contentType'),
      width: width != null && width! > 0 ? width : null,
      height: height != null && height! > 0 ? height : null,
      byteSize: byteSize,
      createdAt: createdAt.toUtc(),
      lastValidatedAt: lastValidatedAt.toUtc(),
      lastAccessedAt: lastAccessedAt.toUtc(),
      validator: _trimOrNull(validator),
      cacheState: cacheState,
    );
  }

  static MetadataArtworkCacheEntry? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final cacheKey = _optionalString(json['cacheKey']);
    final relativePath = _optionalString(json['relativePath']);
    if (cacheKey == null || relativePath == null) {
      warnings?.add('Skipped cache entry with missing cacheKey or relativePath.');
      return null;
    }

    final providerId = _optionalString(json['providerId']);
    final providerRecordId = _optionalString(json['providerRecordId']);
    final artworkId = _optionalString(json['artworkId']);
    final contentType = _optionalString(json['contentType']);
    if (providerId == null ||
        providerRecordId == null ||
        artworkId == null ||
        contentType == null) {
      warnings?.add('Skipped cache entry "$cacheKey" with missing identity fields.');
      return null;
    }

    final byteSize = _readPositiveInt(json['byteSize']);
    if (byteSize == null) {
      warnings?.add('Skipped cache entry "$cacheKey" with invalid byteSize.');
      return null;
    }

    final createdAt = _readDateTime(json['createdAt'], warnings, 'createdAt');
    final lastValidatedAt =
        _readDateTime(json['lastValidatedAt'], warnings, 'lastValidatedAt');
    final lastAccessedAt =
        _readDateTime(json['lastAccessedAt'], warnings, 'lastAccessedAt');
    if (createdAt == null || lastValidatedAt == null || lastAccessedAt == null) {
      warnings?.add('Skipped cache entry "$cacheKey" with invalid timestamps.');
      return null;
    }

    try {
      return MetadataArtworkCacheEntry(
        cacheKey: cacheKey,
        providerId: providerId,
        providerRecordId: providerRecordId,
        artworkId: artworkId,
        relativePath: relativePath,
        contentType: contentType,
        width: _readOptionalPositiveInt(json['width']),
        height: _readOptionalPositiveInt(json['height']),
        byteSize: byteSize,
        createdAt: createdAt,
        lastValidatedAt: lastValidatedAt,
        lastAccessedAt: lastAccessedAt,
        validator: _optionalString(json['validator']),
        cacheState: MetadataArtworkCacheState.fromJson(json['cacheState']),
      ).normalized();
    } on ArgumentError {
      warnings?.add('Skipped cache entry "$cacheKey" during normalization.');
      return null;
    }
  }

  Map<String, Object?> toJson() {
    return {
      'cacheKey': cacheKey,
      'providerId': providerId,
      'providerRecordId': providerRecordId,
      'artworkId': artworkId,
      'relativePath': relativePath,
      'contentType': contentType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      'byteSize': byteSize,
      'createdAt': createdAt.toIso8601String(),
      'lastValidatedAt': lastValidatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      if (validator != null) 'validator': validator,
      'cacheState': cacheState.toJson(),
    };
  }

  static String _sanitizeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('..')) {
      throw ArgumentError('relativePath must stay within cache root.');
    }
    return normalized;
  }

  static String _requireTrimmed(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$label must be non-empty.');
    }
    return trimmed;
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    return _trimOrNull(value);
  }

  static int? _readPositiveInt(dynamic value) {
    if (value is! num || !value.isFinite || value <= 0) return null;
    return value.toInt();
  }

  static int? _readOptionalPositiveInt(dynamic value) {
    if (value == null) return null;
    return _readPositiveInt(value);
  }

  static DateTime? _readDateTime(
    dynamic value,
    List<String>? warnings,
    String label,
  ) {
    if (value is! String || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value)?.toUtc();
    if (parsed == null) {
      warnings?.add('Ignored invalid cache entry $label.');
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) {
    return other is MetadataArtworkCacheEntry &&
        other.cacheKey == cacheKey &&
        other.providerId == providerId &&
        other.providerRecordId == providerRecordId &&
        other.artworkId == artworkId &&
        other.relativePath == relativePath &&
        other.contentType == contentType &&
        other.width == width &&
        other.height == height &&
        other.byteSize == byteSize &&
        other.createdAt == createdAt &&
        other.lastValidatedAt == lastValidatedAt &&
        other.lastAccessedAt == lastAccessedAt &&
        other.validator == validator &&
        other.cacheState == cacheState;
  }

  @override
  int get hashCode => Object.hash(
        cacheKey,
        providerId,
        providerRecordId,
        artworkId,
        relativePath,
        contentType,
        width,
        height,
        byteSize,
        createdAt,
        lastValidatedAt,
        lastAccessedAt,
        validator,
        cacheState,
      );
}
