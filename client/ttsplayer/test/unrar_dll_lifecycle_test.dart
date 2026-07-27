import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_adapter.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_lifecycle.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_loader.dart';
import 'package:ttsplayer/features/comics/spike/cbr_gate0_models.dart';

void main() {
  final dll = Platform.environment['PHASE_63_UNRAR_DLL'];
  final hasDll = dll != null && File(dll).existsSync();
  final fixture = '${Platform.environment['PHASE_63_GATE0_FIXTURE_DIR'] ?? 'test/support/cbr_gate0_fixtures'}/rar4_pages.cbr';

  setUp(() => UnrarDllLifecycle.instance.resetForTest());

  test('load failure does not leave partial backend', () async {
    if (dll == null || !File(dll).existsSync()) return;
    UnrarDllLifecycle.instance.resetForTest();
    final loader = UnrarDllLoader(
      overrideDllPath: dll,
      readOverrideEnv: false,
      expectedSha256Hex: '0' * 64,
    );
    try {
      await loader.tryLoad();
      fail('expected hash failure');
    } on CbrArchiveException catch (_) {}
    expect(UnrarDllLifecycle.instance.loadFailures, greaterThan(0));
  }, skip: dll == null ? 'PHASE_63_UNRAR_DLL not set' : false);

  test('repeated open/close leaves zero handles', () async {
    if (!hasDll || !File(fixture).existsSync()) return;
    final adapter = UnrarDllCbrAdapter(
      loader: UnrarDllLoader(
        overrideDllPath: dll,
        expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
      ),
    );
    for (var i = 0; i < 20; i++) {
      await adapter.listEntries(fixture);
    }
    await adapter.dispose();
    expect(UnrarDllLifecycle.instance.activeArchiveHandles, 0);
    expect(UnrarDllLifecycle.instance.totalOpens, UnrarDllLifecycle.instance.totalCloses);
  }, skip: !hasDll ? 'PHASE_63_UNRAR_DLL not set' : false);

  test('extraction failure cleans temp residue', () async {
    if (!hasDll || !File(fixture).existsSync()) return;
    final adapter = UnrarDllCbrAdapter(
      loader: UnrarDllLoader(
        overrideDllPath: dll,
        expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
      ),
    );
    try {
      await adapter.extractEntry(fixture, 'missing/page.png');
      fail('expected missing entry');
    } on CbrArchiveException catch (_) {}
    await adapter.dispose();
    expect(UnrarDllLifecycle.instance.extractionTempResidue, 0);
  }, skip: !hasDll ? 'PHASE_63_UNRAR_DLL not set' : false);
}
