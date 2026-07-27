import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_adapter.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_loader.dart';
import 'package:ttsplayer/features/comics/spike/cbr_gate0_models.dart';

String? _fixtureDir() {
  return Platform.environment['PHASE_63_GATE0_FIXTURE_DIR'] ??
      'test/support/cbr_gate0_fixtures';
}

void main() {
  final dllOverride = Platform.environment['PHASE_63_UNRAR_DLL'];
  final hasDll = dllOverride != null && File(dllOverride).existsSync();

  group('UnrarDllCbrAdapter', () {
    late UnrarDllCbrAdapter adapter;

    setUp(() {
      if (!hasDll) return;
      adapter = UnrarDllCbrAdapter(
        loader: UnrarDllLoader(
          overrideDllPath: dllOverride,
          expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
        ),
      );
    });

    tearDown(() async {
      if (hasDll) await adapter.dispose();
    });

    test('lists RAR4 fixture', () async {
      if (!hasDll) return;
      final path = '${_fixtureDir()}/rar4_pages.cbr';
      final listing = await adapter.listEntries(path);
      expect(listing.imageEntries.length, greaterThan(0));
    }, skip: hasDll ? false : 'PHASE_63_UNRAR_DLL not set');

    test('lists RAR5 fixture', () async {
      if (!hasDll) return;
      final path = '${_fixtureDir()}/rar5_pages.cbr';
      final listing = await adapter.listEntries(path);
      expect(listing.imageEntries.length, greaterThan(0));
    }, skip: hasDll ? false : 'PHASE_63_UNRAR_DLL not set');

    test('extracts first image page from RAR4', () async {
      if (!hasDll) return;
      final path = '${_fixtureDir()}/rar4_pages.cbr';
      final listing = await adapter.listEntries(path);
      final first = listing.imageEntries.first;
      final page = await adapter.extractEntry(path, first.name);
      expect(page.bytes.length, greaterThan(0));
      expect(page.usedTemporaryDirectory, isTrue);
    }, skip: hasDll ? false : 'PHASE_63_UNRAR_DLL not set');

    test('encrypted fixture returns passwordRequired', () async {
      if (!hasDll) return;
      final path = '${_fixtureDir()}/encrypted.cbr';
      try {
        await adapter.listEntries(path);
        fail('expected encrypted failure');
      } on CbrArchiveException catch (e) {
        expect(
          e.kind,
          anyOf(
            CbrArchiveErrorKind.passwordRequired,
            CbrArchiveErrorKind.encryptedArchive,
          ),
        );
      }
    }, skip: hasDll ? false : 'PHASE_63_UNRAR_DLL not set');

    test('corrupt fixture fails safely', () async {
      if (!hasDll) return;
      final path = '${_fixtureDir()}/corrupt_synthetic.rar';
      try {
        await adapter.listEntries(path);
        fail('expected corrupt failure');
      } on CbrArchiveException catch (e) {
        expect(
          e.kind,
          anyOf(
            CbrArchiveErrorKind.corruptArchive,
            CbrArchiveErrorKind.notAnArchive,
            CbrArchiveErrorKind.emptyArchive,
          ),
        );
      }
    }, skip: hasDll ? false : 'PHASE_63_UNRAR_DLL not set');

    test('rejects wrong hash when configured', () async {
      if (!hasDll) return;
      final badLoader = UnrarDllLoader(
        overrideDllPath: dllOverride,
        expectedSha256Hex: '0' * 64,
      );
      final badAdapter = UnrarDllCbrAdapter(loader: badLoader);
      try {
        await badAdapter.listEntries('${_fixtureDir()}/rar4_pages.cbr');
        fail('expected hash mismatch');
      } on CbrArchiveException catch (e) {
        expect(e.kind, CbrArchiveErrorKind.nativeLibraryLoadFailed);
      } finally {
        await badAdapter.dispose();
      }
    }, skip: hasDll ? false : 'PHASE_63_UNRAR_DLL not set');
  });
}
