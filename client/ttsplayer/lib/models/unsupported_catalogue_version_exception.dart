/// Thrown when catalog.json declares a schema version the app cannot load.
class UnsupportedCatalogueVersionException implements Exception {
  UnsupportedCatalogueVersionException({
    required this.version,
    required this.maxSupported,
  });

  final int version;
  final int maxSupported;

  @override
  String toString() =>
      'Unsupported catalogue_version $version '
      '(app supports up to $maxSupported). Rescan with a compatible scanner '
      'or update the app.';
}
