import 'dart:io';

import '../../spike/unrar_cli_resolver.dart';
import 'unrar_dll/unrar_dll_loader.dart';

/// Selected CBR extraction backend for production wiring.
enum CbrBackendType {
  unrarDll,
  unrarCli,
  unavailable,
}

/// Classification of the native binary provenance (redacted in UI).
enum CbrBinaryProvenance {
  bundledOfficial,
  builtFromSource,
  userSupplied,
  unavailable,
}

/// Snapshot of CBR backend resolution for diagnostics (no full paths).
class CbrBackendSnapshot {
  const CbrBackendSnapshot({
    required this.backendType,
    required this.available,
    required this.provenance,
    required this.verificationResult,
    this.backendVersion,
    this.lastErrorClassification,
    this.activeArchiveHandleCount,
    this.licenceNoticePresent,
  });

  final CbrBackendType backendType;
  final bool available;
  final CbrBinaryProvenance provenance;
  final String verificationResult;
  final String? backendVersion;
  final String? lastErrorClassification;
  final int? activeArchiveHandleCount;
  final bool? licenceNoticePresent;
}

/// Resolves the production CBR backend: DLL → CLI → unavailable.
class CbrBackendResolver {
  CbrBackendResolver({
    UnrarDllLoader? dllLoader,
    UnrarCliResolver? cliResolver,
  })  : _dllLoader = dllLoader ??
            UnrarDllLoader(
              expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
            ),
        _cliResolver = cliResolver ??
            UnrarCliResolver(
              expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
            );

  final UnrarDllLoader _dllLoader;
  final UnrarCliResolver _cliResolver;

  /// Environment override for Gate 1 DLL harness.
  static const dllOverrideEnvKey = UnrarDllLoader.overrideEnvKey;

  /// Returns the selected backend type without loading native libraries.
  CbrBackendType peekBackendType() {
    if (_dllLoader.resolvePath() != null) return CbrBackendType.unrarDll;
    if (_cliResolver.resolvePath() != null) return CbrBackendType.unrarCli;
    return CbrBackendType.unavailable;
  }

  bool get isAvailable => peekBackendType() != CbrBackendType.unavailable;

  UnrarDllLoader get dllLoader => _dllLoader;

  UnrarCliResolver get cliResolver => _cliResolver;

  /// Whether the CLI path came from an explicit override env var.
  bool get cliIsUserSupplied {
    final env = Platform.environment[UnrarCliResolver.overrideEnvKey];
    return env != null && env.trim().isNotEmpty;
  }

  /// Whether the DLL path came from an explicit override env var.
  bool get dllIsOverride {
    final env = Platform.environment[UnrarDllLoader.overrideEnvKey];
    return env != null && env.trim().isNotEmpty;
  }

  CbrBinaryProvenance provenanceFor(CbrBackendType type) {
    switch (type) {
      case CbrBackendType.unrarDll:
        switch (_dllLoader.classifyResolution()) {
          case UnrarDllResolutionSource.overrideEnv:
            return CbrBinaryProvenance.userSupplied;
          case UnrarDllResolutionSource.bundledProduction:
            return CbrBinaryProvenance.bundledOfficial;
          case UnrarDllResolutionSource.unavailable:
          case null:
            return CbrBinaryProvenance.unavailable;
        }
      case CbrBackendType.unrarCli:
        return cliIsUserSupplied
            ? CbrBinaryProvenance.userSupplied
            : CbrBinaryProvenance.bundledOfficial;
      case CbrBackendType.unavailable:
        return CbrBinaryProvenance.unavailable;
    }
  }

  Future<CbrBackendSnapshot> snapshot({
    int? activeArchiveHandleCount,
    String? lastErrorClassification,
  }) async {
    final type = peekBackendType();
    if (type == CbrBackendType.unavailable) {
      return CbrBackendSnapshot(
        backendType: type,
        available: false,
        provenance: CbrBinaryProvenance.unavailable,
        verificationResult: 'unavailable',
        lastErrorClassification: lastErrorClassification,
      );
    }

    if (type == CbrBackendType.unrarDll) {
      try {
        final loaded = await _dllLoader.tryLoad();
        if (loaded == null) {
          return CbrBackendSnapshot(
            backendType: CbrBackendType.unavailable,
            available: false,
            provenance: CbrBinaryProvenance.unavailable,
            verificationResult: 'dll_load_null',
          );
        }
        final appDir = File(Platform.resolvedExecutable).parent.path;
        final noticeBeside = File(
          '$appDir${Platform.pathSeparator}license.txt',
        );
        final noticeUnrar = File(
          '$appDir${Platform.pathSeparator}unrar${Platform.pathSeparator}license.txt',
        );
        return CbrBackendSnapshot(
          backendType: CbrBackendType.unrarDll,
          available: true,
          provenance: provenanceFor(type),
          verificationResult: loaded.verificationResult.name,
          backendVersion: 'RAR_DLL_${loaded.dllVersion}',
          lastErrorClassification: lastErrorClassification,
          activeArchiveHandleCount: activeArchiveHandleCount,
          licenceNoticePresent:
              noticeBeside.existsSync() || noticeUnrar.existsSync(),
        );
      } catch (e) {
        return CbrBackendSnapshot(
          backendType: CbrBackendType.unrarDll,
          available: false,
          provenance: provenanceFor(type),
          verificationResult: 'dll_load_failed',
          lastErrorClassification: lastErrorClassification ?? 'dll_load_failed',
        );
      }
    }

    // CLI fallback
    final cliPath = _cliResolver.resolvePath();
    final hashOk = cliPath != null
        ? await _cliResolver.matchesExpectedHash(cliPath)
        : null;
    final version =
        cliPath != null ? await _cliResolver.readVersionBanner(cliPath) : null;
    return CbrBackendSnapshot(
      backendType: CbrBackendType.unrarCli,
      available: cliPath != null && hashOk != false,
      provenance: provenanceFor(type),
      verificationResult: hashOk == false
          ? 'hash_mismatch'
          : (hashOk == true ? 'verified_hash' : 'hash_not_configured'),
      backendVersion: version,
      lastErrorClassification: lastErrorClassification,
      activeArchiveHandleCount: activeArchiveHandleCount,
      licenceNoticePresent: null,
    );
  }
}
