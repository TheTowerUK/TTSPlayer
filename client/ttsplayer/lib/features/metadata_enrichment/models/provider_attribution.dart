/// Provider attribution metadata for enriched book records (M7.2).
class ProviderAttribution {
  const ProviderAttribution({
    required this.providerId,
    required this.displayName,
    this.homepageUrl,
    this.attributionText,
    this.attributionRequired = false,
  });

  final String providerId;
  final String displayName;
  final String? homepageUrl;
  final String? attributionText;
  final bool attributionRequired;

  @override
  bool operator ==(Object other) {
    return other is ProviderAttribution &&
        other.providerId == providerId &&
        other.displayName == displayName &&
        other.homepageUrl == homepageUrl &&
        other.attributionText == attributionText &&
        other.attributionRequired == attributionRequired;
  }

  @override
  int get hashCode => Object.hash(
        providerId,
        displayName,
        homepageUrl,
        attributionText,
        attributionRequired,
      );
}
