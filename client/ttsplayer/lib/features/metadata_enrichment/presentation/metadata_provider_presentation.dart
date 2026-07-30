/// Bounded user-facing provider attribution (M7.3.3).
class MetadataProviderPresentation {
  const MetadataProviderPresentation({
    required this.displayName,
    this.attributionLine,
  });

  final String displayName;
  final String? attributionLine;

  static MetadataProviderPresentation forProviderId(String? providerId) {
    if (providerId == null || providerId.trim().isEmpty) {
      return const MetadataProviderPresentation(
        displayName: 'External metadata provider',
      );
    }
    switch (providerId) {
      case 'open_library':
        return const MetadataProviderPresentation(
          displayName: 'Open Library',
          attributionLine: 'Metadata from Open Library',
        );
      case 'fake_books':
        return const MetadataProviderPresentation(
          displayName: 'Fake Books',
          attributionLine: 'Metadata from Fake Books',
        );
      default:
        return const MetadataProviderPresentation(
          displayName: 'External metadata provider',
        );
    }
  }
}
