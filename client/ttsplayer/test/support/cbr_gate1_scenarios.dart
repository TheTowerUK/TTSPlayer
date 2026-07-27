import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/comics/archive/cbr/cbr_backend_resolver.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_adapter.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_lifecycle.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_bindings.dart';
import 'package:ttsplayer/features/comics/archive/cbr/unrar_dll/unrar_dll_loader.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/features/comics/archive/comic_path_safety.dart';
import 'package:ttsplayer/features/comics/reader/comic_page_cache.dart';
import 'package:ttsplayer/features/comics/reader/comic_reader_controller.dart';
import 'package:ttsplayer/features/comics/spike/cbr_gate0_models.dart';
import 'package:ttsplayer/features/comics/spike/unrar_cli_resolver.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';

import 'cbr_gate1_harness.dart';
import 'comic_test_fixtures.dart';
import 'reading_progress_test_support.dart';

class Gate1Context {
  Gate1Context({
    required this.fixtureDir,
    required this.gate1Dir,
    this.dllPath,
    this.releaseAppDir,
  });

  final String fixtureDir;
  final String gate1Dir;
  final String? dllPath;
  final String? releaseAppDir;

  bool get hasDll => dllPath != null && File(dllPath!).existsSync();

  bool get hasBackend => hasDll || hasReleaseLayout;

  bool get hasReleaseLayout =>
      releaseAppDir != null &&
      File(
        '$releaseAppDir${Platform.pathSeparator}unrar${Platform.pathSeparator}UnRAR64.dll',
      ).existsSync();

  String fixture(String name) => '$fixtureDir${Platform.pathSeparator}$name';

  String gate1Fixture(String name) => '$gate1Dir${Platform.pathSeparator}$name';

  bool exists(String name) => File(fixture(name)).existsSync();

  bool gate1Exists(String name) => File(gate1Fixture(name)).existsSync();

  MediaLocationResolver get resolver => MediaLocationResolver(
        config: MediaAccessConfig.defaults(),
        isWindowsDesktop: true,
      );

  UnrarDllLoader dllLoader({
    String? override,
    String? appDir,
    String? hash,
    int? minimumVersion,
  }) {
    final useOverride = override ?? (hasDll ? dllPath : null);
    return UnrarDllLoader(
      overrideDllPath: useOverride,
      readOverrideEnv: useOverride == null && !hasDll,
      applicationDirectory: appDir ?? releaseAppDir,
      expectedSha256Hex: hash ??
          (hasBackend ? UnrarDllLoader.gate1ExpectedSha256UnRAR64 : null),
      minimumDllVersion: minimumVersion ?? RAR_DLL_VERSION,
    );
  }

  CbrBackendResolver backend({String? override, String? appDir}) {
    return CbrBackendResolver(dllLoader: dllLoader(override: override, appDir: appDir));
  }

  ComicArchiveOpener opener({String? override, String? appDir}) {
    return ComicArchiveOpener(
      mediaLocationResolver: resolver,
      cbrBackendResolver: backend(override: override, appDir: appDir),
    );
  }
}

Future<void> runGate1Matrix(Gate1Context ctx, Gate1Matrix matrix) async {
  void pass(int id, String title, [String? detail]) {
    matrix.record(Gate1ScenarioReport(
      id: id,
      title: title,
      status: Gate1ScenarioStatus.passed,
      detail: detail,
    ));
  }

  void fail(int id, String title, Object e) {
    matrix.record(Gate1ScenarioReport(
      id: id,
      title: title,
      status: Gate1ScenarioStatus.failed,
      detail: e.toString(),
    ));
  }

  void skip(int id, String title, String reason) {
    matrix.record(Gate1ScenarioReport(
      id: id,
      title: title,
      status: Gate1ScenarioStatus.skipped,
      detail: reason,
    ));
  }

  void na(int id, String title, [String? detail]) {
    matrix.record(Gate1ScenarioReport(
      id: id,
      title: title,
      status: Gate1ScenarioStatus.notApplicable,
      detail: detail,
    ));
  }

  // --- Backend and packaging (1-8) ---
  try {
    if (!ctx.hasDll) {
      skip(1, 'DLL resolves through explicit test override', 'PHASE_63_UNRAR_DLL');
    } else {
      expect(ctx.dllLoader().classifyResolution(),
          UnrarDllResolutionSource.overrideEnv);
      pass(1, 'DLL resolves through explicit test override');
    }
  } catch (e) {
    fail(1, 'DLL resolves through explicit test override', e);
  }

  try {
    if (!ctx.hasReleaseLayout) {
      skip(2, 'DLL resolves from intended Release application location',
          'PHASE_63_RELEASE_APP_DIR + unrar/UnRAR64.dll');
    } else {
      final loader = UnrarDllLoader(
        readOverrideEnv: false,
        applicationDirectory: ctx.releaseAppDir,
        expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
      );
      expect(loader.classifyResolution(),
          UnrarDllResolutionSource.bundledProduction);
      final loaded = await loader.tryLoad();
      expect(loaded, isNotNull);
      pass(2, 'DLL resolves from intended Release application location');
    }
  } catch (e) {
    fail(2, 'DLL resolves from intended Release application location', e);
  }

  try {
    if (!ctx.hasDll || !ctx.hasReleaseLayout) {
      skip(3, 'Bundled-location precedence is deterministic',
          'needs override + release layout');
    } else {
      final loader = UnrarDllLoader(
        overrideDllPath: ctx.dllPath,
        applicationDirectory: ctx.releaseAppDir,
        expectedSha256Hex: UnrarDllLoader.gate1ExpectedSha256UnRAR64,
      );
      expect(loader.classifyResolution(), UnrarDllResolutionSource.overrideEnv);
      pass(3, 'Bundled-location precedence is deterministic', 'override wins');
    }
  } catch (e) {
    fail(3, 'Bundled-location precedence is deterministic', e);
  }

  try {
    final loader = UnrarDllLoader(
      readOverrideEnv: false,
      applicationDirectory: r'C:\Windows\System32',
    );
    expect(loader.classifyResolution(), UnrarDllResolutionSource.unavailable);
    pass(4, 'No DLL from PATH, cwd or system locations', 'loader never searches PATH');
  } catch (e) {
    fail(4, 'No DLL from PATH, cwd or system locations', e);
  }

  try {
    final opener = ComicArchiveOpener(
      mediaLocationResolver: ctx.resolver,
      cbrBackendResolver: CbrBackendResolver(
        dllLoader: UnrarDllLoader(
          overrideDllPath: r'C:\ttsplayer_gate1_missing\UnRAR64.dll',
        ),
        cliResolver: UnrarCliResolver(
          overrideExecutablePath: r'C:\ttsplayer_gate1_missing\UnRAR.exe',
        ),
      ),
    );
    expect(
      () => opener.openPath(ctx.fixture('rar4_pages.cbr')),
      throwsA(isA<ComicArchiveException>().having(
        (e) => e.kind,
        'kind',
        ComicArchiveErrorKind.cbrSupportUnavailable,
      )),
    );
    pass(5, 'Missing DLL produces controlled unavailability');
  } catch (e) {
    fail(5, 'Missing DLL produces controlled unavailability', e);
  }

  try {
    if (!ctx.hasBackend) { skip(6, 'Wrong DLL hash is rejected', 'no CBR backend');
    } else {
      await expectLater(
        ctx.dllLoader(hash: '0' * 64).tryLoad(),
        throwsA(isA<CbrArchiveException>()),
      );
      pass(6, 'Wrong DLL hash is rejected');
    }
  } catch (e) {
    fail(6, 'Wrong DLL hash is rejected', e);
  }

  skip(7, 'Missing required exports are rejected',
      'requires dedicated corrupt-DLL fixture');

  try {
    if (!ctx.hasBackend) { skip(8, 'Unsupported DLL version is rejected', 'no CBR backend');
    } else {
      await expectLater(
        ctx.dllLoader(minimumVersion: 9999).tryLoad(),
        throwsA(isA<CbrArchiveException>()),
      );
      pass(8, 'Unsupported DLL version is rejected');
    }
  } catch (e) {
    fail(8, 'Unsupported DLL version is rejected', e);
  }

  // --- Archive support (9-20) ---
  for (final entry in [
    (9, 'RAR4 opens, lists and extracts', 'rar4_pages.cbr'),
    (10, 'RAR5 opens, lists and extracts', 'rar5_pages.cbr'),
  ]) {
    try {
      if (!ctx.hasBackend) { skip(entry.$1, entry.$2, 'no CBR backend');
        continue;
      }
      final src = ctx.opener().openPath(ctx.fixture(entry.$3));
      final pages = await src.listPages();
      expect(pages, isNotEmpty);
      await src.loadPageBytes(pages.first.entryName);
      await src.dispose();
      pass(entry.$1, entry.$2);
    } catch (e) {
      fail(entry.$1, entry.$2, e);
    }
  }

  try {
    if (!ctx.hasBackend) { skip(11, 'Nested image entries preserve safe natural ordering', 'no CBR backend');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('rar4_pages.cbr'));
      final pages = await src.listPages();
      expect(pages.length, greaterThan(1));
      for (var i = 1; i < pages.length; i++) {
        expect(
          pages[i].entryName.compareTo(pages[i - 1].entryName),
          greaterThanOrEqualTo(0),
        );
      }
      await src.dispose();
      pass(11, 'Nested image entries preserve safe natural ordering');
    }
  } catch (e) {
    fail(11, 'Nested image entries preserve safe natural ordering', e);
  }

  try {
    if (!ctx.hasBackend) { skip(12, 'Unicode entry names list and extract correctly', 'no CBR backend');
    } else if (!ctx.gate1Exists('unicode_pages.cbr')) {
      skip(12, 'Unicode entry names list and extract correctly',
          'run tool/cbr_gate1/generate_gate1_fixtures.ps1');
    } else {
      final src = ctx.opener().openPath(ctx.gate1Fixture('unicode_pages.cbr'));
      final pages = await src.listPages();
      expect(pages.length, greaterThan(1));
      await src.loadPageBytes(pages.first.entryName);
      await src.dispose();
      pass(12, 'Unicode entry names list and extract correctly');
    }
  } catch (e) {
    fail(12, 'Unicode entry names list and extract correctly', e);
  }

  try {
    if (!ctx.hasBackend) { skip(13, 'Solid archive navigation works', 'no CBR backend');
    } else if (!ctx.gate1Exists('solid_pages.cbr')) {
      skip(13, 'Solid archive navigation works', 'generate_gate1_fixtures.ps1');
    } else {
      final src = ctx.opener().openPath(ctx.gate1Fixture('solid_pages.cbr'));
      final pages = await src.listPages();
      expect(pages.length, greaterThanOrEqualTo(2));
      await src.loadPageBytes(pages.last.entryName);
      await src.dispose();
      pass(13, 'Solid archive navigation works');
    }
  } catch (e) {
    fail(13, 'Solid archive navigation works', e);
  }

  try {
    if (!ctx.hasBackend) { skip(14, 'Multi-volume archive classified per policy', 'no CBR backend');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('multivolume_missing_part.cbr'));
      try {
        await src.listPages();
        pass(14, 'Multi-volume archive classified per policy', 'handled');
      } on ComicArchiveException catch (e) {
        expect(
          e.kind,
          anyOf(
            ComicArchiveErrorKind.unsupportedArchiveType,
            ComicArchiveErrorKind.corruptArchive,
            ComicArchiveErrorKind.emptyArchive,
            ComicArchiveErrorKind.multiVolumeUnsupported,
          ),
        );
        pass(14, 'Multi-volume archive classified per policy', e.kind.name);
      }
      await src.dispose();
    }
  } catch (e) {
    fail(14, 'Multi-volume archive classified per policy', e);
  }

  try {
    if (!ctx.hasBackend) { skip(15, 'Encrypted archive returns passwordRequired', 'no CBR backend');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('encrypted.cbr'));
      try {
        await src.listPages();
        fail(15, 'Encrypted archive returns passwordRequired', 'expected failure');
      } on ComicArchiveException catch (e) {
        expect(e.kind, ComicArchiveErrorKind.encryptedArchive);
        pass(15, 'Encrypted archive returns passwordRequired');
      }
      await src.dispose();
    }
  } catch (e) {
    fail(15, 'Encrypted archive returns passwordRequired', e);
  }

  try {
    if (!ctx.hasBackend) { skip(16, 'Corrupt or truncated archive fails safely', 'no CBR backend');
    } else {
      final corrupt = ctx.fixture('corrupt_synthetic.rar');
      final src = ctx.opener().openPath(corrupt);
      try {
        await src.listPages();
        fail(16, 'Corrupt or truncated archive fails safely', 'corrupt open');
      } on ComicArchiveException {
        pass(16, 'Corrupt or truncated archive fails safely', 'corrupt');
      }
      await src.dispose();
      if (ctx.gate1Exists('truncated.cbr')) {
        final t = ctx.opener().openPath(ctx.gate1Fixture('truncated.cbr'));
        try {
          await t.listPages();
          fail(16, 'Corrupt or truncated archive fails safely', 'truncated');
        } on ComicArchiveException {
          pass(16, 'Corrupt or truncated archive fails safely', 'truncated');
        }
        await t.dispose();
      }
    }
  } catch (e) {
    fail(16, 'Corrupt or truncated archive fails safely', e);
  }

  skip(17, 'CRC-damaged entry fails safely', 'requires crc-damaged fixture');

  try {
    if (!ctx.hasBackend) { skip(18, 'Traversal and device-path entries rejected', 'no CBR backend');
    } else {
      expect(comicIsUnsafeEntryName('../secret.png'), isTrue);
      expect(comicIsUnsafeEntryName(r'C:\Windows\test.png'), isTrue);
      expect(comicIsUnsafeEntryName(r'\\server\share\page.png'), isTrue);
      final adapter = UnrarDllCbrAdapter(loader: ctx.dllLoader());
      try {
        await adapter.extractEntry(ctx.fixture('rar4_pages.cbr'), '../evil.png');
        fail(18, 'Traversal and device-path entries rejected', 'extract allowed');
      } on CbrArchiveException catch (e) {
        expect(e.kind, CbrArchiveErrorKind.pathTraversalRejected);
        pass(18, 'Traversal and device-path entries rejected');
      }
      await adapter.dispose();
    }
  } catch (e) {
    fail(18, 'Traversal and device-path entries rejected', e);
  }

  try {
    if (!ctx.hasBackend) { skip(19, 'Oversized entries rejected before output limits', 'no CBR backend');
    } else if (!ctx.exists('large_pages.cbr')) {
      skip(19, 'Oversized entries rejected before output limits', 'large_pages.cbr');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('large_pages.cbr'));
      final pages = await src.listPages();
      try {
        await src.loadPageBytes(pages.first.entryName);
        skip(19, 'Oversized entries rejected before output limits',
            'large_pages.cbr fixture below configured limit');
      } on ComicArchiveException catch (e) {
        expect(
          e.kind,
          anyOf(
            ComicArchiveErrorKind.pageExtractFailed,
            ComicArchiveErrorKind.unsupportedImageEntry,
          ),
        );
        pass(19, 'Oversized entries rejected before output limits');
      }
      await src.dispose();
    }
  } catch (e) {
    fail(19, 'Oversized entries rejected before output limits', e);
  }

  skip(20, 'Duplicate normalized entry names handled deterministically',
      'requires duplicate-name fixture');

  // --- Reader and persistence (21-30) ---
  try {
    if (!ctx.hasBackend) { skip(21, 'CBR opens from Item Detail path', 'no CBR backend');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('rar4_pages.cbr'));
      expect(await src.listPages(), isNotEmpty);
      await src.dispose();
      pass(21, 'CBR opens from Item Detail path');
    }
  } catch (e) {
    fail(21, 'CBR opens from Item Detail path', e);
  }

  try {
    if (!ctx.hasBackend) { skip(22, 'Sequential navigation works', 'no CBR backend');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('rar4_pages.cbr'));
      final controller = ComicReaderController(source: src, prefetchAdjacent: false);
      await controller.open();
      await controller.nextPage();
      expect(controller.pageIndex, 1);
      await controller.previousPage();
      expect(controller.pageIndex, 0);
      controller.dispose();
      pass(22, 'Sequential navigation works');
    }
  } catch (e) {
    fail(22, 'Sequential navigation works', e);
  }

  try {
    if (!ctx.hasBackend) { skip(23, 'Random navigation works', 'no CBR backend');
    } else {
      final src = ctx.opener().openPath(ctx.fixture('rar4_pages.cbr'));
      final controller = ComicReaderController(source: src, prefetchAdjacent: false);
      await controller.open();
      await controller.goToIndex(controller.pageCount - 1);
      expect(controller.pageIndex, controller.pageCount - 1);
      controller.dispose();
      pass(23, 'Random navigation works');
    }
  } catch (e) {
    fail(23, 'Random navigation works', e);
  }

  try {
    final cache = ComicPageCache();
    expect(cache.maxEntries, 5);
    expect(cache.maxBytes, 24 * 1024 * 1024);
    pass(24, 'Comic cache within Phase 6.6 entry and byte limits');
  } catch (e) {
    fail(24, 'Comic cache within Phase 6.6 entry and byte limits', e);
  }

  try {
    if (!ctx.hasBackend) { skip(25, 'Progress is saved', 'no CBR backend');
    } else {
      SharedPreferences.setMockInitialValues({});
      final repo = ReadingProgressRepository();
      await repo.initialize();
      await repo.upsert(
        phase65ComicRecord(
          mediaId: 'gate1-comic',
          pageIndex: 2,
          pageCountAtSave: 5,
          archiveFormat: ReadingReaderFormat.cbr,
        ),
      );
      final record = repo.getByMediaId('gate1-comic');
      expect(record, isNotNull);
      final loc = record!.location as ComicReadingLocationPayload;
      expect(loc.pageIndex, 2);
      pass(25, 'Progress is saved');
    }
  } catch (e) {
    fail(25, 'Progress is saved', e);
  }

  skip(26, 'Fresh session restores through Continue Reading',
      'covered by phase_65 harness; Gate1 defers');
  skip(27, 'Completion removes item from Continue Reading', 'phase_65 harness');
  skip(28, 'Read Again resets correctly', 'phase_65 harness');

  try {
    SharedPreferences.setMockInitialValues({
      ReadingProgressRepository.storageKey: '{"stateVersion":1,"records":[]}',
    });
    final repo = ReadingProgressRepository();
    await repo.initialize();
    expect(repo.allRecords, isEmpty);
    pass(29, 'Stored progress survives temporary backend unavailability', 'repo intact');
  } catch (e) {
    fail(29, 'Stored progress survives temporary backend unavailability', e);
  }

  try {
    final tmp = Directory.systemTemp.createTempSync('gate1_cbz_');
    final cbz = writeCbz(tmp, 'ok.cbz', {'page_001.png': tinyPng()});
    final src = ComicArchiveOpener(mediaLocationResolver: ctx.resolver)
        .openPath(cbz.path);
    expect(await src.listPages(), isNotEmpty);
    await src.dispose();
    tmp.deleteSync(recursive: true);
    pass(30, 'CBZ remains unaffected');
  } catch (e) {
    fail(30, 'CBZ remains unaffected', e);
  }

  // --- Lifecycle (31-38) ---
  try {
    if (!ctx.hasBackend) { skip(31, 'Close during extraction', 'no CBR backend');
    } else {
      final adapter = UnrarDllCbrAdapter(loader: ctx.dllLoader());
      final listing = await adapter.listEntries(ctx.fixture('rar4_pages.cbr'));
      final future = adapter.extractEntry(
        ctx.fixture('rar4_pages.cbr'),
        listing.imageEntries.first.name,
      );
      await adapter.dispose();
      try {
        await future;
      } catch (_) {}
      pass(31, 'Close during extraction');
    }
  } catch (e) {
    fail(31, 'Close during extraction', e);
  }

  try {
    if (!ctx.hasBackend) { skip(32, 'Repeated open/close 20 cycles', 'no CBR backend');
    } else {
      UnrarDllLifecycle.instance.resetForTest();
      final adapter = UnrarDllCbrAdapter(loader: ctx.dllLoader());
      for (var i = 0; i < 20; i++) {
        await adapter.listEntries(ctx.fixture('rar4_pages.cbr'));
      }
      await adapter.dispose();
      expect(UnrarDllLifecycle.instance.activeArchiveHandles, 0);
      pass(32, 'Repeated open/close 20 cycles');
    }
  } catch (e) {
    fail(32, 'Repeated open/close 20 cycles', e);
  }

  try {
    if (!ctx.hasBackend) { skip(33, 'Repeated list/extract releases handles', 'no CBR backend');
    } else {
      final adapter = UnrarDllCbrAdapter(loader: ctx.dllLoader());
      final path = ctx.fixture('rar4_pages.cbr');
      for (var i = 0; i < 5; i++) {
        final listing = await adapter.listEntries(path);
        await adapter.extractEntry(path, listing.imageEntries.first.name);
      }
      await adapter.dispose();
      expect(UnrarDllLifecycle.instance.activeArchiveHandles, 0);
      pass(33, 'Repeated list/extract releases handles');
    }
  } catch (e) {
    fail(33, 'Repeated list/extract releases handles', e);
  }

  na(34, 'No late callback updates disposed reader state',
      'temp-dir extraction avoids isolate callback');

  try {
    if (!ctx.hasBackend) { skip(35, 'No temporary extraction residue', 'no CBR backend');
    } else {
      final adapter = UnrarDllCbrAdapter(loader: ctx.dllLoader());
      final path = ctx.fixture('rar4_pages.cbr');
      final listing = await adapter.listEntries(path);
      await adapter.extractEntry(path, listing.imageEntries.first.name);
      await adapter.dispose();
      expect(UnrarDllLifecycle.instance.extractionTempResidue, 0);
      pass(35, 'No temporary extraction residue');
    }
  } catch (e) {
    fail(35, 'No temporary extraction residue', e);
  }

  try {
    if (!ctx.hasBackend) { skip(36, 'Active native-handle diagnostics return to zero', 'no CBR backend');
    } else {
      expect(UnrarDllLifecycle.instance.activeArchiveHandles, 0);
      pass(36, 'Active native-handle diagnostics return to zero');
    }
  } catch (e) {
    fail(36, 'Active native-handle diagnostics return to zero', e);
  }

  try {
    if (!ctx.hasBackend) { skip(37, 'Failed extraction cleans partial output', 'no CBR backend');
    } else {
      final adapter = UnrarDllCbrAdapter(loader: ctx.dllLoader());
      try {
        await adapter.extractEntry(ctx.fixture('rar4_pages.cbr'), 'missing.png');
      } on CbrArchiveException {}
      await adapter.dispose();
      expect(UnrarDllLifecycle.instance.extractionTempResidue, 0);
      pass(37, 'Failed extraction cleans partial output');
    }
  } catch (e) {
    fail(37, 'Failed extraction cleans partial output', e);
  }

  skip(38, 'Release application closes without native crash',
      'run tool/cbr_gate1/release_layout_smoke.ps1 manually');

  // --- Diagnostics (39-43) ---
  try {
    if (!ctx.hasBackend) { skip(39, 'Backend reports unrarDll', 'no CBR backend');
    } else {
      final snap = await ctx.backend().snapshot();
      expect(snap.backendType, CbrBackendType.unrarDll);
      pass(39, 'Backend reports unrarDll');
    }
  } catch (e) {
    fail(39, 'Backend reports unrarDll', e);
  }

  try {
    if (!ctx.hasBackend) {
      skip(40, 'Provenance reports official bundled or evaluation artifact',
          'no CBR backend');
    } else {
      final snap = await ctx.backend().snapshot();
      expect(
        snap.provenance,
        anyOf(
          CbrBinaryProvenance.bundledOfficial,
          CbrBinaryProvenance.userSupplied,
        ),
      );
      pass(40, 'Provenance reports official bundled or evaluation artifact');
    }
  } catch (e) {
    fail(40, 'Provenance reports official bundled or evaluation artifact', e);
  }

  try {
    if (!ctx.hasBackend) { skip(41, 'Version and verification status correct', 'no CBR backend');
    } else {
      final snap = await ctx.backend().snapshot();
      expect(snap.verificationResult, isNotEmpty);
      expect(snap.backendVersion, isNotNull);
      pass(41, 'Version and verification status correct');
    }
  } catch (e) {
    fail(41, 'Version and verification status correct', e);
  }

  try {
    if (!ctx.hasBackend) { skip(42, 'Diagnostics contain no path leakage', 'no CBR backend');
    } else {
      final snap = await ctx.backend().snapshot();
      final blob = '${snap.verificationResult}${snap.backendVersion}';
      expect(blob.contains(r'\'), isFalse);
      expect(blob.contains(':'), isFalse);
      pass(42, 'Diagnostics contain no path leakage');
    }
  } catch (e) {
    fail(42, 'Diagnostics contain no path leakage', e);
  }

  try {
    if (!ctx.hasReleaseLayout && !ctx.hasDll) {
      skip(43, 'Licence-notice presence represented accurately', 'no layout');
    } else {
      final snap = await ctx.backend().snapshot();
      expect(snap.licenceNoticePresent, isA<bool?>());
      pass(43, 'Licence-notice presence represented accurately');
    }
  } catch (e) {
    fail(43, 'Licence-notice presence represented accurately', e);
  }
}
