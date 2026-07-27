import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';

import 'unrar_dll_bindings.dart';
import 'unrar_dll_error_mapper.dart';
import 'unrar_dll_lifecycle.dart';

/// Result of resolving and verifying the official UnRAR64.dll.
class UnrarDllResolution {
  const UnrarDllResolution({
    required this.library,
    required this.dllPath,
    required this.dllVersion,
    required this.verificationResult,
    this.expectedSha256Hex,
  });

  final DynamicLibrary library;
  final String dllPath;
  final int dllVersion;
  final UnrarDllVerificationResult verificationResult;
  final String? expectedSha256Hex;
}

enum UnrarDllVerificationResult {
  verifiedHash,
  hashNotConfigured,
  hashMismatch,
  missingExports,
  unsupportedVersion,
  wrongArchitecture,
  loadFailed,
}

enum UnrarDllResolutionSource {
  overrideEnv,
  bundledProduction,
  unavailable,
}

/// Deterministic resolution of official RARLab UnRAR64.dll.
///
/// Order:
/// 1. Explicit override (`PHASE_63_UNRAR_DLL` or constructor)
/// 2. Approved production subdirectory `{app}/unrar/UnRAR64.dll`
///
/// Never searches PATH, the process current directory, or system directories.
/// Uses absolute-path [DynamicLibrary.open].
class UnrarDllLoader {
  UnrarDllLoader({
    this.overrideDllPath,
    this.expectedSha256Hex,
    this.applicationDirectory,
    this.minimumDllVersion = RAR_DLL_VERSION,
    this.readOverrideEnv = true,
  });

  final String? overrideDllPath;
  final String? expectedSha256Hex;
  final String? applicationDirectory;
  final int minimumDllVersion;
  final bool readOverrideEnv;

  static const overrideEnvKey = 'PHASE_63_UNRAR_DLL';
  static const bundledSubdirName = 'unrar';

  /// Approved production-relative path segment (for diagnostics, no absolute paths).
  static const bundledRelativePath = 'unrar/UnRAR64.dll';

  /// SHA-256 of official `UnRAR64.dll` from RARLab `unrardll-723.exe` (2026-07-27).
  static const gate1ExpectedSha256UnRAR64 =
      '894b7d2db8d6363eb12f30c7b89f48eab9e71963b8b438675bdd64c12dd59bcc';

  UnrarDllResolutionSource? _lastResolutionSource;

  UnrarDllResolutionSource? get lastResolutionSource => _lastResolutionSource;

  /// Returns how the loader would classify resolution without opening the library.
  UnrarDllResolutionSource classifyResolution() {
    final override = overrideDllPath ??
        (readOverrideEnv
            ? Platform.environment[overrideEnvKey]?.trim()
            : null);
    if (override != null && override.isNotEmpty) {
      return File(override).existsSync()
          ? UnrarDllResolutionSource.overrideEnv
          : UnrarDllResolutionSource.unavailable;
    }
    final bundled = _bundledProductionPath();
    if (bundled != null && File(bundled).existsSync()) {
      return UnrarDllResolutionSource.bundledProduction;
    }
    return UnrarDllResolutionSource.unavailable;
  }

  String? resolvePath() {
    final source = classifyResolution();
    _lastResolutionSource = source;
    switch (source) {
      case UnrarDllResolutionSource.overrideEnv:
        final override = overrideDllPath ??
            (readOverrideEnv
                ? Platform.environment[overrideEnvKey]!.trim()
                : null);
        if (override == null) return null;
        return File(override).absolute.path;
      case UnrarDllResolutionSource.bundledProduction:
        return File(_bundledProductionPath()!).absolute.path;
      case UnrarDllResolutionSource.unavailable:
      case null:
        return null;
    }
  }

  String? _bundledProductionPath() {
    final appDir = applicationDirectory ??
        File(Platform.resolvedExecutable).parent.path;
    final nested =
        '$appDir${Platform.pathSeparator}$bundledSubdirName${Platform.pathSeparator}$unrar64DllFileName';
    return nested;
  }

  Future<UnrarDllResolution?> tryLoad() async {
    final path = resolvePath();
    if (path == null) return null;

    if (!Platform.isWindows) {
      UnrarDllLifecycle.instance.recordLoadAttempt(success: false);
      throw unrarDllLoadFailed('unrar_dll_platform_unsupported');
    }

    try {
      final expected = expectedSha256Hex?.trim().toLowerCase();
      UnrarDllVerificationResult verification =
          UnrarDllVerificationResult.hashNotConfigured;
      if (expected != null && expected.isNotEmpty) {
        final bytes = await File(path).readAsBytes();
        final digest = sha256.convert(bytes).toString();
        verification = digest == expected
            ? UnrarDllVerificationResult.verifiedHash
            : UnrarDllVerificationResult.hashMismatch;
        if (verification == UnrarDllVerificationResult.hashMismatch) {
          throw unrarDllLoadFailed('unrar_dll_hash_mismatch');
        }
      }

      DynamicLibrary lib;
      try {
        lib = DynamicLibrary.open(path);
      } catch (_) {
        throw unrarDllLoadFailed('unrar_dll_load_failed');
      }

      for (final symbol in unrarRequiredExports) {
        try {
          lib.lookup(symbol);
        } catch (_) {
          throw unrarDllLoadFailed('unrar_dll_missing_export:$symbol');
        }
      }

      final versionFn = lib.lookupFunction<Int32 Function(), int Function()>(
        'RARGetDllVersion',
      );
      final version = versionFn();
      if (version < minimumDllVersion) {
        throw unrarDllLoadFailed('unrar_dll_unsupported_version:$version');
      }

      UnrarDllLifecycle.instance.recordLoadAttempt(success: true);
      return UnrarDllResolution(
        library: lib,
        dllPath: path,
        dllVersion: version,
        verificationResult: verification,
        expectedSha256Hex: expected,
      );
    } catch (e) {
      UnrarDllLifecycle.instance.recordLoadAttempt(success: false);
      rethrow;
    }
  }
}

/// Thin typed wrapper over loaded UnRAR64.dll exports.
class UnrarDllBindings {
  UnrarDllBindings(this._lib);

  final DynamicLibrary _lib;

  late final Pointer<Void> Function(Pointer<RAROpenArchiveDataEx>) openArchiveEx =
      _lib.lookupFunction<
          Pointer<Void> Function(Pointer<RAROpenArchiveDataEx>),
          Pointer<Void> Function(Pointer<RAROpenArchiveDataEx>)>(
        'RAROpenArchiveEx',
      );

  late final int Function(Pointer<Void>) closeArchive = _lib.lookupFunction<
      Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('RARCloseArchive');

  late final int Function(Pointer<Void>, Pointer<RARHeaderDataEx>) readHeaderEx =
      _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<RARHeaderDataEx>),
          int Function(Pointer<Void>, Pointer<RARHeaderDataEx>)>(
        'RARReadHeaderEx',
      );

  late final int Function(Pointer<Void>, int, Pointer<Utf8>, Pointer<Utf8>)
      processFile = _lib.lookupFunction<
          Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Pointer<Utf8>),
          int Function(Pointer<Void>, int, Pointer<Utf8>, Pointer<Utf8>)>(
        'RARProcessFile',
      );

  late final int Function() dllVersion = _lib.lookupFunction<
      Int32 Function(),
      int Function()>('RARGetDllVersion');
}

String readWideString(Pointer<Uint16> ptr, int maxUnits) {
  if (ptr.address == 0) return '';
  final units = <int>[];
  for (var i = 0; i < maxUnits; i++) {
    final unit = ptr.elementAt(i).value;
    if (unit == 0) break;
    units.add(unit);
  }
  return String.fromCharCodes(units);
}

int combineSize64(int low, int high) {
  if (high == 0) return low;
  // Dart int is arbitrary precision; avoid overflow for declared sizes.
  return low + (high * 0x100000000);
}
