/// What kind of catalogue entity artwork is being resolved for.
enum ArtworkKind {
  library,
  folder,
  mediaItem,
}

/// Where a resolved artwork path came from.
enum ArtworkSource {
  /// `thumbnail_path` from catalog.json.
  catalogThumbnail,

  /// Sidecar image beside the media file (stem match or named sidecar).
  sidecar,

  /// Named artwork file in a parent or containing folder.
  folderArt,

  /// No file found — UI should render [MediaPlaceholder].
  placeholder,
}
