import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_loader.dart';
import 'package:ttsplayer/features/comics/spike/cbr_gate0_models.dart';

void main() {
  final dll = Platform.environment['PHASE_63_UNRAR_DLL'];

  test('classifyResolution returns unavailable for missing paths', () {
    final loader = UnrarDllLoader(
      readOverrideEnv: false,
      overrideDllPath: r'C:\ttsplayer_gate1_missing\UnRAR64.dll',
    );
    expect(loader.classifyResolution(), UnrarDllResolutionSource.unavailable);
    expect(loader.resolvePath(), isNull);
  });

  test('wrong hash rejected', () async {
    if (dll == null || !File(dll).existsSync()) return;
    final loader = UnrarDllLoader(
      overrideDllPath: dll,
      expectedSha256Hex: '0' * 64,
    );
    expect(
      loader.tryLoad(),
      throwsA(isA<CbrArchiveException>().having(
        (e) => e.kind,
        'kind',
        CbrArchiveErrorKind.nativeLibraryLoadFailed,
      )),
    );
  }, skip: dll == null ? 'PHASE_63_UNRAR_DLL not set' : false);

  test('unsupported version rejected', () async {
    if (dll == null || !File(dll).existsSync()) return;
    final loader = UnrarDllLoader(
      overrideDllPath: dll,
      minimumDllVersion: 9999,
    );
    expect(
      loader.tryLoad(),
      throwsA(isA<CbrArchiveException>().having(
        (e) => e.kind,
        'kind',
        CbrArchiveErrorKind.nativeLibraryLoadFailed,
      )),
    );
  }, skip: dll == null ? 'PHASE_63_UNRAR_DLL not set' : false);

  test('verified hash loads when configured', () async {
    if (dll == null || !File(dll).existsSync()) return;
    final loader = UnrarDllLoader(
      overrideDllPath: dll,
      expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
    );
    final loaded = await loader.tryLoad();
    expect(loaded, isNotNull);
    expect(loaded!.dllVersion, greaterThanOrEqualTo(UnrarDllLoader().minimumDllVersion));
  }, skip: dll == null ? 'PHASE_63_UNRAR_DLL not set' : false);

  test('bundled production path uses unrar subdirectory', () {
    final loader = UnrarDllLoader(
      readOverrideEnv: false,
      applicationDirectory: r'C:\App\Release',
    );
    expect(
      loader.classifyResolution(),
      UnrarDllResolutionSource.unavailable,
    );
    expect(UnrarDllLoader.bundledRelativePath, 'unrar/UnRAR64.dll');
  });

  test('override takes precedence over release app dir', () {
    if (dll == null || !File(dll).existsSync()) return;
    final loader = UnrarDllLoader(
      overrideDllPath: dll,
      applicationDirectory: r'C:\App\Release',
    );
    expect(loader.classifyResolution(), UnrarDllResolutionSource.overrideEnv);
  }, skip: dll == null ? 'PHASE_63_UNRAR_DLL not set' : false);
}
