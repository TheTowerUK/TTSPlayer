@Tags(['phase63-gate0'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/spike/cbr_gate0.dart';

/// Windows Gate 0 Candidate E — official UnRAR CLI evidence harness.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_63_GATE0='1'
/// $env:PHASE_63_UNRAR_EXE=(Resolve-Path 'third_party\unrar_cli\UnRAR.exe').Path
/// flutter test test/phase_63_cbr_gate0_windows_runtime_test.dart --tags phase63-gate0
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_63_GATE0'] != '1') {
    test(
      'skipped — set PHASE_63_GATE0=1 to run CBR Gate 0 Candidate E',
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

  final unrarOverride = Platform.environment[UnrarCliResolver.overrideEnvKey];
  final resolver = UnrarCliResolver(
    overrideExecutablePath: unrarOverride,
    expectedSha256Hex: UnrarCliResolver.gate0ExpectedSha256,
  );

  late UnrarCliCbrAdapter adapter;

  setUp(() {
    adapter = UnrarCliCbrAdapter(resolver: resolver);
  });

  tearDown(() async {
    await adapter.dispose();
  });

  test('G0-E0 executable resolves and matches expected hash', () async {
    final path = resolver.resolvePath();
    expect(path, isNotNull, reason: 'Set PHASE_63_UNRAR_EXE or bundle UnRAR.exe');
    expect(await resolver.matchesExpectedHash(path!), isTrue);
    final banner = await resolver.readVersionBanner(path);
    // ignore: avoid_print
    print('G0-E0 path_basename=${cbrBasename(path)} banner=$banner');
    expect(banner ?? '', contains('UNRAR'));
  });

  test('G0-E1 list RAR4 and RAR5 without full extract', () async {
    for (final name in ['rar4_pages.cbr', 'rar5_pages.cbr']) {
      final path = fixture(name);
      expect(File(path).existsSync(), isTrue, reason: 'generate fixtures first');
      final before = adapter.processInvocations;
      final listing = await adapter.listEntries(path);
      expect(adapter.processInvocations, greaterThan(before));
      expect(listing.imageEntries, isNotEmpty);
      expect(listing.imageEntries.first.name, contains('page_'));
      // ignore: avoid_print
      print(
        'G0-E1 $name images=${listing.imageEntries.length} '
        'listMs=${listing.listDuration.inMilliseconds} '
        'procs=${adapter.processInvocations - before}',
      );
    }
  });

  test('G0-E2 selective extract first/middle/last/repeat/sequence', () async {
    final path = fixture('rar5_pages.cbr');
    final listing = await adapter.listEntries(path);
    final images = listing.imageEntries;
    expect(images.length, greaterThanOrEqualTo(3));

    final first = images.first;
    final middle = images[images.length ~/ 2];
    final last = images.last;

    Future<void> extractOnce(CbrArchiveEntry e, String label) async {
      final before = adapter.processInvocations;
      final page = await adapter.extractEntry(path, e.name);
      expect(page.bytes, isNotEmpty);
      expect(page.usedTemporaryDirectory, isTrue);
      expect(page.entryName, e.name);
      // ignore: avoid_print
      print(
        'G0-E2 $label name=${e.name} bytes=${page.bytes.length} '
        'ms=${page.duration.inMilliseconds} '
        'procs=${adapter.processInvocations - before}',
      );
    }

    await extractOnce(first, 'first');
    await extractOnce(middle, 'middle');
    await extractOnce(last, 'last');
    await extractOnce(first, 'repeat_first');

    final seqStart = adapter.processInvocations;
    for (final e in images.take(3)) {
      await adapter.extractEntry(path, e.name);
    }
    // ignore: avoid_print
    print(
      'G0-E2 sequential3 procs=${adapter.processInvocations - seqStart} '
      '(one process per page expected)',
    );
  });

  test('G0-E3 failure matrix', () async {
    Future<void> expectKind(
      String name,
      CbrArchiveErrorKind kind, {
      Future<void> Function(UnrarCliCbrAdapter a, String path)? action,
    }) async {
      final path = fixture(name);
      expect(File(path).existsSync(), isTrue, reason: name);
      try {
        if (action != null) {
          await action(adapter, path);
        } else {
          await adapter.listEntries(path);
        }
        fail('expected failure for $name');
      } on CbrArchiveException catch (e) {
        expect(e.kind, kind, reason: name);
        expect(e.userMessage, isNotEmpty);
        expect(e.diagnosticDetail ?? '', isNot(contains(r':\')));
        // ignore: avoid_print
        print('G0-E3 $name -> ${e.kind} detail=${e.diagnosticDetail}');
      }
    }

    await expectKind('corrupt_synthetic.rar', CbrArchiveErrorKind.corruptArchive);
    await expectKind('encrypted.cbr', CbrArchiveErrorKind.passwordRequired);
    await expectKind('no_images.cbr', CbrArchiveErrorKind.noSupportedImages);
    await expectKind('empty.rar', CbrArchiveErrorKind.emptyArchive);
    await expectKind('not_rar.bin', CbrArchiveErrorKind.notAnArchive);
    await expectKind(
      'multivolume_missing_part.cbr',
      CbrArchiveErrorKind.multiVolumeUnsupported,
    );

    // Missing executable
    final missing = UnrarCliCbrAdapter(
      resolver: UnrarCliResolver(
        overrideExecutablePath: r'C:\ttsplayer_gate0_missing\UnRAR.exe',
      ),
    );
    try {
      await missing.listEntries(fixture('rar5_pages.cbr'));
      fail('expected missing exe');
    } on CbrArchiveException catch (e) {
      expect(e.kind, CbrArchiveErrorKind.nativeLibraryMissing);
      // ignore: avoid_print
      print('G0-E3 missing_exe -> ${e.kind}');
    } finally {
      await missing.dispose();
    }

    // Hash mismatch
    final badHash = UnrarCliCbrAdapter(
      resolver: UnrarCliResolver(
        overrideExecutablePath: resolver.resolvePath(),
        expectedSha256Hex: '0' * 64,
      ),
    );
    try {
      await badHash.listEntries(fixture('rar5_pages.cbr'));
      fail('expected hash mismatch');
    } on CbrArchiveException catch (e) {
      expect(e.kind, CbrArchiveErrorKind.nativeLibraryLoadFailed);
      // ignore: avoid_print
      print('G0-E3 hash_mismatch -> ${e.kind}');
    } finally {
      await badHash.dispose();
    }
  });

  test('G0-E4 path traversal rejected before extract', () async {
    await expectLater(
      adapter.extractEntry(fixture('rar5_pages.cbr'), '../evil.txt'),
      throwsA(
        isA<CbrArchiveException>().having(
          (e) => e.kind,
          'kind',
          CbrArchiveErrorKind.pathTraversalRejected,
        ),
      ),
    );
  });

  test('G0-E5 large archive list + first page timing', () async {
    final path = fixture('large_pages.cbr');
    expect(File(path).existsSync(), isTrue);
    final listing = await adapter.listEntries(path);
    expect(listing.imageEntries.length, greaterThanOrEqualTo(20));
    final page = await adapter.extractEntry(
      path,
      listing.imageEntries.first.name,
    );
    // ignore: avoid_print
    print(
      'G0-E5 listMs=${listing.listDuration.inMilliseconds} '
      'firstExtractMs=${page.duration.inMilliseconds} '
      'images=${listing.imageEntries.length} '
      'bytes=${page.bytes.length} procs=${adapter.processInvocations}',
    );
  });

  test('G0-E6 Candidate B stub still records prior Fail', () {
    expect(UnrarCbrAdapter.gate0BlockingDetail, contains('D8021'));
  });
}
