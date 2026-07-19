/// Media kind emitted by the scanner (`media_kind` in catalog.json).
enum MediaKind {
  video,
  audio,
  image,
  unknown;

  static MediaKind fromString(String? value) {
    if (value == null || value.isEmpty) {
      return MediaKind.unknown;
    }
    return MediaKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => MediaKind.unknown,
    );
  }

  /// JSON/catalogue string for this kind.
  String get catalogueValue => name;
}
