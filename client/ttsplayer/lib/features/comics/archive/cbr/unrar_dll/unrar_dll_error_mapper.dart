import '../../../spike/cbr_gate0_models.dart';
import 'unrar_dll_bindings.dart';

/// Maps native UnRAR return codes to [CbrArchiveException] classifications.
CbrArchiveException mapUnrarDllError({
  required int code,
  required String archiveLabel,
  required String context,
}) {
  final kind = switch (code) {
    ERAR_BAD_ARCHIVE || ERAR_UNKNOWN_FORMAT => CbrArchiveErrorKind.notAnArchive,
    ERAR_BAD_DATA => CbrArchiveErrorKind.corruptArchive,
    ERAR_MISSING_PASSWORD => CbrArchiveErrorKind.passwordRequired,
    ERAR_BAD_PASSWORD => CbrArchiveErrorKind.encryptedArchive,
    ERAR_EOPEN when context.contains('volume') =>
      CbrArchiveErrorKind.multiVolumeUnsupported,
    ERAR_EOPEN => CbrArchiveErrorKind.ioFailure,
    ERAR_NO_MEMORY => CbrArchiveErrorKind.ioFailure,
    ERAR_ECREATE || ERAR_EWRITE => CbrArchiveErrorKind.ioFailure,
    ERAR_EREAD || ERAR_ECLOSE => CbrArchiveErrorKind.corruptArchive,
    ERAR_LARGE_DICT => CbrArchiveErrorKind.unsupported,
    ERAR_END_ARCHIVE => CbrArchiveErrorKind.unknown,
    _ => CbrArchiveErrorKind.unknown,
  };

  final userMessage = switch (kind) {
    CbrArchiveErrorKind.notAnArchive =>
      'This file is not a readable comic archive.',
    CbrArchiveErrorKind.corruptArchive =>
      'This comic archive appears to be damaged.',
    CbrArchiveErrorKind.passwordRequired ||
    CbrArchiveErrorKind.encryptedArchive =>
      'This comic archive is password-protected.',
    CbrArchiveErrorKind.multiVolumeUnsupported =>
      'Multi-volume comic archives are not supported.',
    CbrArchiveErrorKind.unsupported =>
      'This comic archive uses an unsupported option.',
    _ => 'This comic archive could not be opened.',
  };

  return CbrArchiveException(
    kind: kind,
    userMessage: userMessage,
    diagnosticDetail: 'unrar_dll:$context:$archiveLabel:er$code',
    diagnosticCode: code,
  );
}

CbrArchiveException unrarDllMissing({String detail = 'unrar_dll_missing'}) {
  return CbrArchiveException(
    kind: CbrArchiveErrorKind.nativeLibraryMissing,
    userMessage: 'CBR support unavailable in this installation.',
    diagnosticDetail: detail,
  );
}

CbrArchiveException unrarDllLoadFailed(String detail) {
  return CbrArchiveException(
    kind: CbrArchiveErrorKind.nativeLibraryLoadFailed,
    userMessage: 'CBR support unavailable in this installation.',
    diagnosticDetail: detail,
  );
}
