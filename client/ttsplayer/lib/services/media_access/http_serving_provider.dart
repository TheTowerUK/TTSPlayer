import 'media_access_config.dart';
import 'media_access_provider.dart';
import 'media_path_utils.dart';
import 'resolved_media_location.dart';

/// Maps catalogue filesystem paths to HTTP media URLs.
abstract final class HttpServingProvider {
  static ResolvedMediaLocation resolve({
    required String filePath,
    required MediaAccessConfig config,
  }) {
    final base = config.httpMediaBaseUrl?.trim();
    if (base == null || base.isEmpty) {
      return const ResolvedMediaLocation.unresolved(
        providerType: MediaAccessProviderType.httpServing,
        errorReason: 'HTTP media base URL is not configured.',
      );
    }

    final relative = MediaPathUtils.relativePathUnderRoots(
      filePath,
      config.mediaRoots,
    );
    if (relative == null) {
      return const ResolvedMediaLocation.unresolved(
        providerType: MediaAccessProviderType.httpServing,
        errorReason: 'Path is not under a configured media root.',
      );
    }

    final uri = MediaPathUtils.joinHttpBaseAndRelative(base, relative);
    return ResolvedMediaLocation.resolved(
      uri: uri,
      providerType: MediaAccessProviderType.httpServing,
    );
  }
}
