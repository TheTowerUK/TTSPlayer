/// Development gating for metadata enrichment UI (M7.3.3).
///
/// Default is off so unfinished provider workflows do not appear in normal
/// builds. Enable explicitly in widget tests or controlled development setups.
class MetadataEnrichmentFeatureConfig {
  const MetadataEnrichmentFeatureConfig({
    this.metadataEnrichmentDevelopmentEnabled = false,
  });

  final bool metadataEnrichmentDevelopmentEnabled;

  static const defaults = MetadataEnrichmentFeatureConfig();

  static const developmentEnabled = MetadataEnrichmentFeatureConfig(
    metadataEnrichmentDevelopmentEnabled: true,
  );
}
