/// Outcome of re-reading and parsing the active catalogue file.
class CatalogueValidationResult {
  final bool success;
  final String message;
  final int? itemCount;
  final int? libraryCount;
  final String? catalogueIdentity;

  const CatalogueValidationResult({
    required this.success,
    required this.message,
    this.itemCount,
    this.libraryCount,
    this.catalogueIdentity,
  });

  factory CatalogueValidationResult.unavailable(String reason) {
    return CatalogueValidationResult(success: false, message: reason);
  }
}
