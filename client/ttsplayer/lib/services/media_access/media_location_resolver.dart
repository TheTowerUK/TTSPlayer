import 'media_access_config.dart';
import 'media_access_provider.dart';
import 'http_serving_provider.dart';
import 'local_file_provider.dart';
import 'media_path_utils.dart';
import 'resolved_media_location.dart';

/// Resolves catalogue [file_path] values to playable URIs via access providers.
///
/// Playback and artwork resolve catalogue [file_path] values at consumption time.
class MediaLocationResolver {
  final MediaAccessConfig config;

  /// Injectable for tests; defaults to `Platform.isWindows` at call sites later.
  final bool isWindowsDesktop;

  const MediaLocationResolver({
    required this.config,
    this.isWindowsDesktop = false,
  });

  ResolvedMediaLocation resolve(String filePath) {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) {
      return const ResolvedMediaLocation.unresolved(
        providerType: MediaAccessProviderType.localFile,
        errorReason: 'File path is empty.',
      );
    }

    if (MediaPathUtils.isRemoteUrl(trimmed)) {
      return ResolvedMediaLocation.resolved(
        uri: trimmed,
        providerType: MediaAccessProviderType.passThrough,
      );
    }

    if (config.mode == MediaAccessMode.localPreferred && isWindowsDesktop) {
      return LocalFileProvider.resolve(
        filePath: trimmed,
        isWindowsDesktop: true,
      );
    }

    final httpResult = HttpServingProvider.resolve(
      filePath: trimmed,
      config: config,
    );
    if (httpResult.isPlayable) return httpResult;

    if (config.mode == MediaAccessMode.httpRequired) {
      return httpResult;
    }

    return httpResult;
  }
}
