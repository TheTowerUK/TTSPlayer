@Tags(['phase63-cbr-production'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_loader.dart';

import 'support/cbr_gate1_harness.dart';
import 'support/cbr_gate1_scenarios.dart';

/// Windows Gate 1 — full production CBR backend matrix (43 scenarios).
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_63_CBR_PRODUCTION='1'
/// $env:PHASE_63_UNRAR_DLL=(Resolve-Path 'third_party\_gate1_eval\unrardll-723\x64\UnRAR64.dll').Path
/// flutter test test/phase_63_cbr_production_windows_runtime_test.dart --tags phase63-cbr-production
/// ```
///
/// Release-layout bundled resolution (no override):
/// ```powershell
/// $env:PHASE_63_RELEASE_APP_DIR='D:\...\build\windows\x64\runner\Release'
/// Remove-Item Env:PHASE_63_UNRAR_DLL
/// ```
void main() {
  if (Platform.environment['PHASE_63_CBR_PRODUCTION'] != '1') {
    test('skipped — set PHASE_63_CBR_PRODUCTION=1', () {}, skip: true);
    return;
  }

  final matrix = Gate1Matrix();
  final gate0 = Platform.environment['PHASE_63_GATE0_FIXTURE_DIR'] ??
      'test/support/cbr_gate0_fixtures';
  final ctx = Gate1Context(
    fixtureDir: gate0.replaceAll('/', Platform.pathSeparator),
    gate1Dir: gate1FixtureDir().replaceAll('/', Platform.pathSeparator),
    dllPath: Platform.environment[UnrarDllLoader.overrideEnvKey],
    releaseAppDir: gate1ReleaseAppDir(),
  );

  tearDownAll(() {
    matrix.printSummary();
    final failed = matrix.reports
        .where((r) => r.status == Gate1ScenarioStatus.failed)
        .toList();
    if (failed.isNotEmpty) {
      fail(
        'Gate 1 failures: ${failed.map((f) => 'G1-${f.id.toString().padLeft(2, '0')}').join(', ')}',
      );
    }
  });

  test('Gate 1 production matrix (43 scenarios)', () async {
    await runGate1Matrix(ctx, matrix);
  });
}
