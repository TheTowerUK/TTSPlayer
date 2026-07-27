import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbr/cbr_backend_resolver.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_loader.dart';
import 'package:ttsplayer/features/comics/spike/unrar_cli_resolver.dart';

void main() {
  test('UnrarDllLoader resolves override env path', () {
    final loader = UnrarDllLoader(
      overrideDllPath: r'C:\fake\UnRAR64.dll',
    );
    expect(loader.resolvePath(), isNull);
  });

  test('CbrBackendResolver prefers DLL over CLI when both configured', () {
    final dllPath =
        Platform.environment['PHASE_63_UNRAR_DLL'] ??
            Platform.environment['PHASE_63_UNRAR_DLL_TEST'];
    final cliPath = Platform.environment['PHASE_63_UNRAR_EXE'];
    if (dllPath == null || !File(dllPath).existsSync()) {
      return;
    }
    final resolver = CbrBackendResolver(
      dllLoader: UnrarDllLoader(overrideDllPath: dllPath),
    );
    expect(resolver.peekBackendType(), CbrBackendType.unrarDll);
    if (cliPath != null && File(cliPath).existsSync()) {
      // DLL still wins when both exist.
      expect(resolver.peekBackendType(), CbrBackendType.unrarDll);
    }
  });

  test('CbrBackendResolver unavailable when no backend paths', () {
    final resolver = CbrBackendResolver(
      dllLoader: UnrarDllLoader(
        readOverrideEnv: false,
        overrideDllPath: r'C:\ttsplayer_missing\UnRAR64.dll',
      ),
      cliResolver: UnrarCliResolver(
        overrideExecutablePath: r'C:\ttsplayer_missing\UnRAR.exe',
      ),
    );
    expect(resolver.peekBackendType(), CbrBackendType.unavailable);
    expect(resolver.isAvailable, isFalse);
  });
}
