import 'dart:io';

import 'cbr_archive_adapter.dart';
import 'cbr_gate0_models.dart';
import 'cbr_path_safety.dart';
import 'unrar_cli_list_parser.dart';
import 'unrar_cli_process.dart';
import 'unrar_cli_resolver.dart';

/// Gate 0 Candidate E — official RARLab `UnRAR.exe` via structured Process spawn.
///
/// Not wired to browse, search, detail, or reader UI.
class UnrarCliCbrAdapter implements CbrArchiveAdapter {
  UnrarCliCbrAdapter({
    UnrarCliResolver? resolver,
    UnrarCliProcessRunner? runner,
    this.listTimeout = const Duration(seconds: 30),
    this.extractTimeout = const Duration(seconds: 60),
    this.testTimeout = const Duration(seconds: 60),
  })  : _resolver = resolver ?? UnrarCliResolver(),
        _runner = runner ?? UnrarCliProcessRunner();

  final UnrarCliResolver _resolver;
  final UnrarCliProcessRunner _runner;
  final Duration listTimeout;
  final Duration extractTimeout;
  final Duration testTimeout;

  Directory? _sessionTemp;
  int _processInvocations = 0;

  /// Gate 0 observability (not for UI).
  int get processInvocations => _processInvocations;

  /// Subdirectories remaining under the session temp root (best-effort).
  int get sessionTempResidueCount {
    final dir = _sessionTemp;
    if (dir == null || !dir.existsSync()) return 0;
    return dir.listSync().whereType<Directory>().length;
  }

  String _requireExecutable() {
    final path = _resolver.resolvePath();
    if (path == null) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.nativeLibraryMissing,
        userMessage:
            'CBR support unavailable in this installation.',
        diagnosticDetail: 'unrar_cli_missing',
      );
    }
    return path;
  }

  Future<void> _assertExecutableAuthentic(String exe) async {
    final ok = await _resolver.matchesExpectedHash(exe);
    if (ok == false) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.nativeLibraryLoadFailed,
        userMessage:
            'CBR support unavailable in this installation.',
        diagnosticDetail: 'unrar_cli_hash_mismatch',
      );
    }
  }

  Directory _tempRoot() {
    return _sessionTemp ??= createOwnedTempDirectory('ttsplayer_cbr');
  }

  @override
  Future<CbrArchiveListing> listEntries(String archivePath) async {
    final label = cbrBasename(archivePath);
    final archiveFile = File(archivePath);
    if (!archiveFile.existsSync()) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.ioFailure,
        userMessage: 'This comic archive could not be opened.',
        diagnosticDetail: 'missing_file:$label',
      );
    }
    if (archiveFile.lengthSync() == 0) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.emptyArchive,
        userMessage: 'This comic archive has no readable pages.',
        diagnosticDetail: 'zero_byte:$label',
      );
    }

    final exe = _requireExecutable();
    await _assertExecutableAuthentic(exe);

    final sw = Stopwatch()..start();
    // Technical list: size + name; still no full extraction.
    final result = await _run(
      exe,
      ['lt', '-p-', '--', archivePath],
      timeout: listTimeout,
    );
    sw.stop();

    _throwIfProcessFailed(
      result,
      archiveLabel: label,
      context: 'list',
    );
    _throwIfNotRarMessage(result, archiveLabel: label, context: 'list');
    _throwIfMultiVolumeListing(result, archiveLabel: label);

    final parsed = parseUnrarTechnicalList(result.stdout);
    final entries = <CbrArchiveEntry>[];
    var index = 0;
    for (final row in parsed) {
      final name = row.name.replaceAll('\\', '/');
      if (row.isDirectory) continue;
      final isImage =
          !cbrIsUnsafeEntryName(name) && cbrIsImageEntryName(name);
      entries.add(
        CbrArchiveEntry(
          name: name,
          index: index,
          sizeBytes: row.sizeBytes,
          packedSizeBytes: row.packedSizeBytes,
          isDirectory: false,
          isImage: isImage,
        ),
      );
      index++;
    }

    final images = entries.where((e) => e.isImage).toList()
      ..sort((a, b) => cbrNaturalCompare(a.name, b.name));

    // Re-index image order as natural page order for reader convenience.
    final ordered = <CbrArchiveEntry>[
      ...images,
      ...entries.where((e) => !e.isImage),
    ];
    final withStableIndex = <CbrArchiveEntry>[];
    for (var i = 0; i < ordered.length; i++) {
      final e = ordered[i];
      withStableIndex.add(
        CbrArchiveEntry(
          name: e.name,
          index: i,
          sizeBytes: e.sizeBytes,
          packedSizeBytes: e.packedSizeBytes,
          isDirectory: e.isDirectory,
          isImage: e.isImage,
        ),
      );
    }

    final imageEntries =
        withStableIndex.where((e) => e.isImage).toList(growable: false);

    if (withStableIndex.isEmpty) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.emptyArchive,
        userMessage: 'This comic archive has no readable pages.',
        diagnosticDetail: 'empty:$label',
        diagnosticCode: result.exitCode,
      );
    }
    if (imageEntries.isEmpty) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.noSupportedImages,
        userMessage: 'This comic archive has no supported image pages.',
        diagnosticDetail: 'no_images:$label',
        diagnosticCode: result.exitCode,
      );
    }

    return CbrArchiveListing(
      entries: withStableIndex,
      imageEntries: imageEntries,
      listDuration: sw.elapsed,
      archiveLabel: label,
    );
  }

  @override
  Future<CbrExtractedPage> extractEntry(
    String archivePath,
    String entryName,
  ) async {
    final label = cbrBasename(archivePath);
    final normalized = entryName.replaceAll('\\', '/');
    if (cbrIsUnsafeEntryName(normalized)) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.pathTraversalRejected,
        userMessage: 'This comic page path is not allowed.',
        diagnosticDetail: 'unsafe_extract:$label',
      );
    }

    final exe = _requireExecutable();
    await _assertExecutableAuthentic(exe);

    final temp = Directory(
      '${_tempRoot().path}${Platform.pathSeparator}'
      'x_${DateTime.now().microsecondsSinceEpoch}',
    );
    temp.createSync(recursive: true);

    final sw = Stopwatch()..start();
    try {
      // Extract only the named entry into a controlled temp directory.
      // Prefer `e` (flat extract) with the archive-relative mask UnRAR listed.
      // `-o+` overwrite within temp; `-p-` do not prompt for password.
      final entryArg = normalized.contains('/')
          ? normalized.replaceAll('/', '\\')
          : normalized;
      final result = await _run(
        exe,
        [
          'x',
          '-o+',
          '-p-',
          '-y',
          '--',
          archivePath,
          entryArg,
          '${temp.path}\\',
        ],
        timeout: extractTimeout,
      );
      sw.stop();

      _throwIfProcessFailed(
        result,
        archiveLabel: label,
        context: 'extract',
      );

      final extracted = _findExtractedFile(temp, normalized);
      if (extracted == null) {
        throw CbrArchiveException(
          kind: CbrArchiveErrorKind.entryNotFound,
          userMessage: 'That comic page could not be opened.',
          diagnosticDetail: 'missing_entry:$label',
          diagnosticCode: result.exitCode,
        );
      }

      // Refuse unexpected writes outside the temp root.
      final tempRoot = _tempRoot().resolveSymbolicLinksSync();
      final resolved = extracted.resolveSymbolicLinksSync();
      if (!resolved.toLowerCase().startsWith(tempRoot.toLowerCase())) {
        throw CbrArchiveException(
          kind: CbrArchiveErrorKind.pathTraversalRejected,
          userMessage: 'This comic page path is not allowed.',
          diagnosticDetail: 'extract_escape:$label',
        );
      }

      final bytes = await extracted.readAsBytes();
      return CbrExtractedPage(
        entryName: normalized,
        bytes: bytes,
        duration: sw.elapsed,
        usedTemporaryDirectory: true,
      );
    } finally {
      try {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      } catch (_) {
        // Best-effort cleanup; dispose() sweeps session root.
      }
    }
  }

  @override
  Future<void> testArchive(String archivePath) async {
    final label = cbrBasename(archivePath);
    final exe = _requireExecutable();
    await _assertExecutableAuthentic(exe);
    final result = await _run(
      exe,
      ['t', '-p-', '--', archivePath],
      timeout: testTimeout,
    );
    _throwIfProcessFailed(
      result,
      archiveLabel: label,
      context: 'test',
    );
  }

  @override
  Future<void> dispose() async {
    final dir = _sessionTemp;
    _sessionTemp = null;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<UnrarCliProcessResult> _run(
    String exe,
    List<String> args, {
    required Duration timeout,
  }) async {
    _processInvocations++;
    return _runner.run(
      executablePath: exe,
      arguments: args,
      timeout: timeout,
    );
  }

  void _throwIfNotRarMessage(
    UnrarCliProcessResult result, {
    required String archiveLabel,
    required String context,
  }) {
    final combined = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (combined.contains('is not rar archive') ||
        combined.contains('unknown archive format')) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.notAnArchive,
        userMessage: 'This file is not a readable comic archive.',
        diagnosticDetail: 'not_rar:$context:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }
  }

  void _throwIfMultiVolumeListing(
    UnrarCliProcessResult result, {
    required String archiveLabel,
  }) {
    final combined = '${result.stdout}\n${result.stderr}'.toLowerCase();
    // UnRAR technical list marks split archives as "volume N" in Details.
    if (RegExp(r'details:.*\bvolume\b').hasMatch(combined) ||
        combined.contains('cannot find volume') ||
        combined.contains('next volume')) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.multiVolumeUnsupported,
        userMessage: 'Multi-volume comic archives are not supported.',
        diagnosticDetail: 'multivolume:list:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }
  }

  void _throwIfProcessFailed(
    UnrarCliProcessResult result, {
    required String archiveLabel,
    required String context,
  }) {
    if (result.timedOut) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.ioFailure,
        userMessage: 'Opening this comic took too long and was cancelled.',
        diagnosticDetail: 'timeout:$context:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }

    final combined = '${result.stdout}\n${result.stderr}'.toLowerCase();

    if (result.exitCode == 0) return;

    // UnRAR exit codes (documented by RARLab).
    switch (result.exitCode) {
      case 1:
        // Warning — allow only when listing produced usable technical rows.
        // Truncated/corrupt archives often exit 1 with no Name: rows.
        if (context == 'list' &&
            !RegExp(r'^\s*Name:\s*\S', multiLine: true)
                .hasMatch(result.stdout)) {
          throw CbrArchiveException(
            kind: CbrArchiveErrorKind.corruptArchive,
            userMessage: 'This comic archive appears to be damaged.',
            diagnosticDetail: 'exit1_empty_list:$archiveLabel',
            diagnosticCode: 1,
          );
        }
        return;
      case 10:
        throw CbrArchiveException(
          kind: context == 'extract'
              ? CbrArchiveErrorKind.entryNotFound
              : CbrArchiveErrorKind.emptyArchive,
          userMessage: context == 'extract'
              ? 'That comic page could not be opened.'
              : 'This comic archive has no readable pages.',
          diagnosticDetail: 'exit10:$context:$archiveLabel',
          diagnosticCode: 10,
        );
      case 11:
        throw CbrArchiveException(
          kind: CbrArchiveErrorKind.passwordRequired,
          userMessage: 'This comic archive is password-protected.',
          diagnosticDetail: 'exit11:$context:$archiveLabel',
          diagnosticCode: 11,
        );
      case 3:
        throw CbrArchiveException(
          kind: CbrArchiveErrorKind.corruptArchive,
          userMessage: 'This comic archive appears to be damaged.',
          diagnosticDetail: 'exit3:$context:$archiveLabel',
          diagnosticCode: 3,
        );
    }

    if (combined.contains('wrong password') ||
        combined.contains('encrypted') ||
        combined.contains('password')) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.encryptedArchive,
        userMessage: 'This comic archive is password-protected.',
        diagnosticDetail: 'encrypted:$context:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }
    if (combined.contains('volume') ||
        combined.contains('cannot find volume') ||
        combined.contains('next volume')) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.multiVolumeUnsupported,
        userMessage: 'Multi-volume comic archives are not supported.',
        diagnosticDetail: 'multivolume:$context:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }
    if (combined.contains('is not rar') ||
        combined.contains('unknown archive format') ||
        combined.contains('cannot open')) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.notAnArchive,
        userMessage: 'This file is not a readable comic archive.',
        diagnosticDetail: 'not_rar:$context:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }
    if (combined.contains('corrupt') ||
        combined.contains('checksum') ||
        combined.contains('crc failed')) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.corruptArchive,
        userMessage: 'This comic archive appears to be damaged.',
        diagnosticDetail: 'corrupt:$context:$archiveLabel',
        diagnosticCode: result.exitCode,
      );
    }

    throw CbrArchiveException(
      kind: CbrArchiveErrorKind.unknown,
      userMessage: 'This comic archive could not be opened.',
      diagnosticDetail: 'exit${result.exitCode}:$context:$archiveLabel',
      diagnosticCode: result.exitCode,
    );
  }

  File? _findExtractedFile(Directory temp, String entryName) {
    final direct = File(
      '${temp.path}${Platform.pathSeparator}${entryName.replaceAll('/', Platform.pathSeparator)}',
    );
    if (direct.existsSync()) return direct;

    final base = entryName.split('/').last;
    final matches = temp
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => cbrBasename(f.path) == base)
        .toList();
    if (matches.length == 1) return matches.first;
    return null;
  }
}

