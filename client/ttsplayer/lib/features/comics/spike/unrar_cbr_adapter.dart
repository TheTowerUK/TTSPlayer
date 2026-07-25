import 'cbr_archive_adapter.dart';
import 'cbr_gate0_models.dart';
import 'cbr_path_safety.dart';

/// Gate 0 placeholder for the provisional `package:unrar` adapter.
///
/// **Gate 0 result (2026-07-25):** `package:unrar` 0.1.2 fails to compile its
/// native hook on Windows with MSVC (`cl.exe` rejects GCC flags such as
/// `-Wno-dangling-else` / `-std=c++11` / `-pthread`). The dependency was
/// removed from `pubspec.yaml` so the rest of the Flutter suite remains green.
///
/// The intended wrapper API and path-safety rules remain here for the next
/// candidate (fork with MSVC flags, owned FFI + UnRARDll.vcxproj, or CLI).
class UnrarCbrAdapter implements CbrArchiveAdapter {
  UnrarCbrAdapter();

  static const supportedImageExtensions = kCbrSupportedImageExtensions;

  static const gate0BlockingDetail =
      'package:unrar@0.1.2 hook/build.dart passes GCC/Clang flags to MSVC cl.exe '
      '(D8021 invalid numeric argument /Wno-dangling-else; also -Wno-switch, '
      '-std=c++11, -pthread). Failure is at native compilation before unrar.dll '
      'exists; independent of runtime antivirus. '
      'Windows Release packaging via Dart build hooks is blocked.';

  @override
  Future<CbrArchiveListing> listEntries(String archivePath) async {
    final label = cbrBasename(archivePath);
    throw CbrArchiveException(
      kind: CbrArchiveErrorKind.nativeLibraryLoadFailed,
      userMessage:
          'Comic archive support is not available in this installation.',
      diagnosticDetail: 'gate0_blocked:$label',
    );
  }

  @override
  Future<CbrExtractedPage> extractEntry(
    String archivePath,
    String entryName,
  ) async {
    final normalized = entryName.replaceAll('\\', '/');
    if (cbrIsUnsafeEntryName(normalized)) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.pathTraversalRejected,
        userMessage: 'This comic page path is not allowed.',
        diagnosticDetail: 'unsafe_extract:${cbrBasename(archivePath)}',
      );
    }
    throw CbrArchiveException(
      kind: CbrArchiveErrorKind.nativeLibraryLoadFailed,
      userMessage:
          'Comic archive support is not available in this installation.',
      diagnosticDetail: 'gate0_blocked:${cbrBasename(archivePath)}',
    );
  }

  @override
  Future<void> testArchive(String archivePath) async {
    throw CbrArchiveException(
      kind: CbrArchiveErrorKind.nativeLibraryLoadFailed,
      userMessage:
          'Comic archive support is not available in this installation.',
      diagnosticDetail: 'gate0_blocked:${cbrBasename(archivePath)}',
    );
  }

  @override
  Future<void> dispose() async {}
}
