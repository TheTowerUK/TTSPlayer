@Tags(['phase63-gate0'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/spike/cbr_gate0.dart';

/// Windows Gate 0 evidence harness for CBR / RAR.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_63_GATE0='1'
/// flutter test test/phase_63_cbr_gate0_windows_runtime_test.dart --tags phase63-gate0
/// ```
///
/// Current Gate 0 outcome: **Fail** for published `package:unrar` 0.1.2 on
/// Windows MSVC (native hook GCC flags → D8021). This harness records that
/// failure classification and validates path-safety / fixture presence without
/// a working DLL. Failure is compile-time, independent of antivirus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_63_GATE0'] != '1') {
    test(
      'skipped — set PHASE_63_GATE0=1 to run CBR Gate 0 spike',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test('skipped — CBR Gate 0 spike is Windows-only', () {}, skip: true);
    return;
  }

  final fixtureDir = Directory(
    Platform.environment['PHASE_63_GATE0_FIXTURE_DIR'] ??
        'test/support/cbr_gate0_fixtures',
  );
  String fixture(String name) =>
      '${fixtureDir.path}${Platform.pathSeparator}$name';

  late UnrarCbrAdapter adapter;

  setUp(() {
    adapter = UnrarCbrAdapter();
  });

  test('G0-N1 records native stack blocked on Windows MSVC hook', () async {
    expect(File(fixture('corrupt_synthetic.rar')).existsSync(), isTrue);
    expect(UnrarCbrAdapter.gate0BlockingDetail, contains('MSVC'));
    expect(UnrarCbrAdapter.gate0BlockingDetail, contains('D8021'));
    try {
      await adapter.listEntries(fixture('corrupt_synthetic.rar'));
      fail('expected gate0 blocked failure');
    } on CbrArchiveException catch (e) {
      expect(e.kind, CbrArchiveErrorKind.nativeLibraryLoadFailed);
      expect(e.userMessage, isNotEmpty);
      expect(e.diagnosticDetail ?? '', isNot(contains(r'Y:\')));
      // ignore: avoid_print
      print('G0-N1 BLOCKED detail=${e.diagnosticDetail}');
      // ignore: avoid_print
      print('G0-N1 reason=${UnrarCbrAdapter.gate0BlockingDetail}');
    }
  });

  test('G0-F4 path traversal rejected without native library', () async {
    await expectLater(
      adapter.extractEntry(fixture('corrupt_synthetic.rar'), '../evil.txt'),
      throwsA(
        isA<CbrArchiveException>().having(
          (e) => e.kind,
          'kind',
          CbrArchiveErrorKind.pathTraversalRejected,
        ),
      ),
    );
  });

  test('G0-F2 TTSPlayer-owned failure fixtures exist', () {
    expect(File(fixture('empty.rar')).existsSync(), isTrue);
    expect(File(fixture('corrupt_synthetic.rar')).existsSync(), isTrue);
    expect(File(fixture('not_rar.bin')).existsSync(), isTrue);
    expect(File(fixture('page_001.png')).existsSync(), isTrue);
  });

  test('G0-P1 image helpers', () {
    expect(cbrIsImageEntryName('a.png'), isTrue);
    expect(cbrIsImageEntryName('a.txt'), isFalse);
  });
}
