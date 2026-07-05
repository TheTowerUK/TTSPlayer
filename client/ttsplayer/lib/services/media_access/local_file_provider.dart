import 'media_access_provider.dart';
import 'media_path_utils.dart';
import 'resolved_media_location.dart';

/// Maps catalogue filesystem paths to local file URIs on desktop.
abstract final class LocalFileProvider {
  static ResolvedMediaLocation resolve({
    required String filePath,
    required bool isWindowsDesktop,
  }) {
    if (filePath.isEmpty) {
      return const ResolvedMediaLocation.unresolved(
        providerType: MediaAccessProviderType.localFile,
        errorReason: 'File path is empty.',
      );
    }

    if (!isWindowsDesktop) {
      return const ResolvedMediaLocation.unresolved(
        providerType: MediaAccessProviderType.localFile,
        errorReason: 'Local file access is not available on this platform.',
      );
    }

    if (MediaPathUtils.isRemoteUrl(filePath)) {
      return const ResolvedMediaLocation.unresolved(
        providerType: MediaAccessProviderType.localFile,
        errorReason: 'Path is already a remote URL.',
      );
    }

    final uri = Uri.file(filePath.replaceAll('/', r'\')).toString();
    return ResolvedMediaLocation.resolved(
      uri: uri,
      providerType: MediaAccessProviderType.localFile,
    );
  }
}
