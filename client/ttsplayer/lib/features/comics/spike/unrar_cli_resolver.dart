import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Deterministic resolution of the bundled official UnRAR CLI.
///
/// Order:
/// 1. Explicit Gate 0 / test override (`PHASE_63_UNRAR_EXE` or constructor)
/// 2. Executable beside the running application (`UnRAR.exe`)
/// 3. Approved subdirectory `unrar/UnRAR.exe` beside the application
///
/// Never searches PATH or WinRAR install locations.
class UnrarCliResolver {
  UnrarCliResolver({
    this.overrideExecutablePath,
    this.expectedSha256Hex,
    this.applicationDirectory,
  });

  /// Absolute path override (tests / Gate 0 harness).
  final String? overrideExecutablePath;

  /// Optional expected SHA-256 (lowercase hex) for authenticity check.
  final String? expectedSha256Hex;

  /// Override for unit tests (normally derived from [Platform.resolvedExecutable]).
  final String? applicationDirectory;

  static const bundledFileName = 'UnRAR.exe';
  static const bundledSubdirName = 'unrar';

  /// Environment variable for Gate 0 / development override.
  static const overrideEnvKey = 'PHASE_63_UNRAR_EXE';

  /// SHA-256 of Gate 0 validated `UNRAR 7.23 x64 freeware` from WinRAR 7.23 package.
  static const gate0ExpectedSha256 =
      '0d3715001790f0fd18d3e850f947b540530b2d2deb9a2e6a9e84f2ed7b234235';

  String? resolvePath() {
    final override = overrideExecutablePath ??
        Platform.environment[overrideEnvKey]?.trim();
    if (override != null && override.isNotEmpty) {
      if (File(override).existsSync()) return override;
      return null;
    }

    final appDir = applicationDirectory ??
        File(Platform.resolvedExecutable).parent.path;
    final beside = '$appDir${Platform.pathSeparator}$bundledFileName';
    if (File(beside).existsSync()) return beside;

    final nested =
        '$appDir${Platform.pathSeparator}$bundledSubdirName${Platform.pathSeparator}$bundledFileName';
    if (File(nested).existsSync()) return nested;

    return null;
  }

  /// Returns null when no expected hash is configured.
  Future<bool?> matchesExpectedHash(String executablePath) async {
    final expected = expectedSha256Hex?.trim().toLowerCase();
    if (expected == null || expected.isEmpty) return null;
    final bytes = await File(executablePath).readAsBytes();
    final digest = sha256.convert(bytes).toString();
    return digest == expected;
  }

  /// Best-effort version probe (`UnRAR` with no args prints banner).
  Future<String?> readVersionBanner(String executablePath) async {
    try {
      final result = await Process.run(
        executablePath,
        const <String>[],
        runInShell: false,
      );
      final out = '${result.stdout}\n${result.stderr}';
      final match = RegExp(
        r'UNRAR\s+[^\r\n]+',
        caseSensitive: false,
      ).firstMatch(out);
      return match?.group(0)?.trim();
    } catch (e, st) {
      debugPrint('UnrarCliResolver version probe failed: $e\n$st');
      return null;
    }
  }
}
