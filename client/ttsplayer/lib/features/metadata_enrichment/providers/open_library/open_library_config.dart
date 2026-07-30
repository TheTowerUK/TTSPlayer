/// Open Library adapter configuration (M7.2).
class OpenLibraryConfig {
  const OpenLibraryConfig({
    required this.userAgent,
    this.baseUrl = 'https://openlibrary.org',
    this.defaultTimeout = const Duration(seconds: 15),
  });

  final String userAgent;
  final String baseUrl;
  final Duration defaultTimeout;

  /// Neutral application identifier without a project contact URL.
  ///
  /// Open Library recommends a contact address in the User-Agent for higher
  /// rate limits. Inject an approved identity via [OpenLibraryConfig.userAgent]
  /// before enabling live requests. Optional live validation remains disabled
  /// until a stable project contact identity is formally selected.
  static const defaultUserAgent = 'TTSPlayer/0.8';
}
