/// Provider artwork role for enrichment references (M7.4.2).
enum MetadataArtworkKind {
  cover('cover');

  const MetadataArtworkKind(this.serializedValue);

  final String serializedValue;

  static MetadataArtworkKind? fromSerializedValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final kind in MetadataArtworkKind.values) {
      if (kind.serializedValue == value) return kind;
    }
    return null;
  }

  static MetadataArtworkKind fromJson(dynamic value) {
    if (value is MetadataArtworkKind) return value;
    if (value is String) {
      return fromSerializedValue(value) ?? MetadataArtworkKind.cover;
    }
    return MetadataArtworkKind.cover;
  }

  String toJson() => serializedValue;
}
