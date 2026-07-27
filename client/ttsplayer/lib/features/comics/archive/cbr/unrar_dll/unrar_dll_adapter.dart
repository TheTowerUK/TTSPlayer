import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../../spike/cbr_path_safety.dart';
import '../cbr_resource_limits.dart';
import '../cbr_archive_adapter.dart';
import 'unrar_dll_bindings.dart';
import 'unrar_dll_error_mapper.dart';
import 'unrar_dll_lifecycle.dart';
import 'unrar_dll_loader.dart';

/// Gate 1 Candidate A — official RARLab UnRAR64.dll via FFI.
class UnrarDllCbrAdapter implements CbrArchiveAdapter {
  UnrarDllCbrAdapter({
    UnrarDllLoader? loader,
    UnrarDllResolution? preloaded,
  })  : _loader = loader ?? UnrarDllLoader(),
        _preloaded = preloaded;

  final UnrarDllLoader _loader;
  UnrarDllResolution? _preloaded;
  UnrarDllBindings? _bindings;

  int get activeHandleCount => UnrarDllLifecycle.instance.activeArchiveHandles;

  Future<UnrarDllBindings> _bindingsOrLoad() async {
    if (_bindings != null) return _bindings!;
    _preloaded ??= await _loader.tryLoad();
    final loaded = _preloaded;
    if (loaded == null) {
      throw unrarDllMissing();
    }
    _bindings = UnrarDllBindings(loaded.library);
    return _bindings!;
  }

  @override
  Future<CbrArchiveListing> listEntries(String archivePath) async {
    final label = cbrBasename(archivePath);
    _validateArchiveFile(archivePath, label);
    final bindings = await _bindingsOrLoad();
    final sw = Stopwatch()..start();

    final openData = calloc<RAROpenArchiveDataEx>();
    final header = calloc<RARHeaderDataEx>();
    final fileNameEx = calloc<Uint16>(cbrMaxEntryNameLength);
    final arcNameEx = calloc<Uint16>(cbrMaxEntryNameLength);
    final redirName = calloc<Uint16>(cbrMaxEntryNameLength);

    Pointer<Void>? handle;
    try {
      final archiveName = archivePath.toNativeUtf8();
      try {
        openData.ref
          ..ArcName = archiveName
          ..OpenMode = RAR_OM_LIST
          ..Callback = nullptr
          ..UserData = 0
          ..MarkOfTheWeb = nullptr;

        handle = bindings.openArchiveEx(openData);
        UnrarDllLifecycle.instance.recordArchiveOpened();
        _throwOpenResult(openData.ref.OpenResult, label, 'list');

        if ((openData.ref.Flags & ROADF_VOLUME) != 0 ||
            (openData.ref.Flags & ROADF_FIRSTVOLUME) != 0) {
          throw mapUnrarDllError(
            code: ERAR_EOPEN,
            archiveLabel: label,
            context: 'multivolume_list',
          );
        }

        header.ref
          ..FileNameEx = fileNameEx
          ..FileNameExSize = cbrMaxEntryNameLength
          ..ArcNameEx = arcNameEx
          ..ArcNameExSize = cbrMaxEntryNameLength
          ..RedirName = redirName
          ..RedirNameSize = cbrMaxEntryNameLength;

        final entries = <CbrArchiveEntry>[];
        var totalListed = 0;
        var index = 0;

        while (true) {
          final rh = bindings.readHeaderEx(handle, header);
          if (rh == ERAR_END_ARCHIVE) break;
          if (rh != ERAR_SUCCESS) {
            throw mapUnrarDllError(code: rh, archiveLabel: label, context: 'list_header');
          }

          final flags = header.ref.Flags;
          final isDirectory = (flags & RHDF_DIRECTORY) != 0;
          final name = readWideString(header.ref.FileNameEx, cbrMaxEntryNameLength)
              .replaceAll('\\', '/');
          if (name.length > cbrMaxEntryNameLength) {
            throw CbrArchiveException(
              kind: CbrArchiveErrorKind.pathTraversalRejected,
              userMessage: 'This comic page path is not allowed.',
              diagnosticDetail: 'name_too_long:$label',
            );
          }

          final sizeBytes =
              combineSize64(header.ref.UnpSize, header.ref.UnpSizeHigh);
          totalListed += sizeBytes;
          if (entries.length >= cbrMaxEntryCount ||
              totalListed > cbrMaxTotalListedUncompressedBytes) {
            throw CbrArchiveException(
              kind: CbrArchiveErrorKind.unsupported,
              userMessage: 'This comic archive exceeds supported limits.',
              diagnosticDetail: 'entry_limit:$label',
            );
          }

          if ((flags & RHDF_SPLITBEFORE) != 0 || (flags & RHDF_SPLITAFTER) != 0) {
            throw mapUnrarDllError(
              code: ERAR_EOPEN,
              archiveLabel: label,
              context: 'multivolume_entry',
            );
          }

          if (!isDirectory) {
            final isImage =
                !cbrIsUnsafeEntryName(name) && cbrIsImageEntryName(name);
            entries.add(
              CbrArchiveEntry(
                name: name,
                index: index,
                sizeBytes: sizeBytes,
                packedSizeBytes: combineSize64(
                  header.ref.PackSize,
                  header.ref.PackSizeHigh,
                ),
                isDirectory: false,
                isImage: isImage,
              ),
            );
            index++;
          }

          final pf = bindings.processFile(handle, RAR_SKIP, nullptr, nullptr);
          if (pf != ERAR_SUCCESS) {
            throw mapUnrarDllError(code: pf, archiveLabel: label, context: 'list_skip');
          }
        }

        final images = entries.where((e) => e.isImage).toList()
          ..sort((a, b) => cbrNaturalCompare(a.name, b.name));
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
          );
        }
        if (imageEntries.isEmpty) {
          throw CbrArchiveException(
            kind: CbrArchiveErrorKind.noSupportedImages,
            userMessage: 'This comic archive has no supported image pages.',
            diagnosticDetail: 'no_images:$label',
          );
        }

        sw.stop();
        return CbrArchiveListing(
          entries: withStableIndex,
          imageEntries: imageEntries,
          listDuration: sw.elapsed,
          archiveLabel: label,
        );
      } finally {
        calloc.free(archiveName);
      }
    } finally {
      if (handle != null) {
        bindings.closeArchive(handle);
        UnrarDllLifecycle.instance.recordArchiveClosed();
      }
      calloc.free(openData);
      calloc.free(header);
      calloc.free(fileNameEx);
      calloc.free(arcNameEx);
      calloc.free(redirName);
    }
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

    _validateArchiveFile(archivePath, label);
    final bindings = await _bindingsOrLoad();
    final sw = Stopwatch()..start();

    final openData = calloc<RAROpenArchiveDataEx>();
    final header = calloc<RARHeaderDataEx>();
    final fileNameEx = calloc<Uint16>(cbrMaxEntryNameLength);
    final arcNameEx = calloc<Uint16>(cbrMaxEntryNameLength);
    final redirName = calloc<Uint16>(cbrMaxEntryNameLength);

    final temp = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'ttsplayer_cbr_dll_${DateTime.now().microsecondsSinceEpoch}',
    );
    temp.createSync(recursive: true);
    UnrarDllLifecycle.instance.recordTempDirCreated();

    Pointer<Void>? handle;
    try {
      final archiveName = archivePath.toNativeUtf8();
      final destPath = temp.path.toNativeUtf8();
      try {
        openData.ref
          ..ArcName = archiveName
          ..OpenMode = RAR_OM_EXTRACT
          ..Callback = nullptr
          ..UserData = 0
          ..MarkOfTheWeb = nullptr;

        handle = bindings.openArchiveEx(openData);
        UnrarDllLifecycle.instance.recordArchiveOpened();
        _throwOpenResult(openData.ref.OpenResult, label, 'extract');

        header.ref
          ..FileNameEx = fileNameEx
          ..FileNameExSize = cbrMaxEntryNameLength
          ..ArcNameEx = arcNameEx
          ..ArcNameExSize = cbrMaxEntryNameLength
          ..RedirName = redirName
          ..RedirNameSize = cbrMaxEntryNameLength;

        var found = false;
        while (true) {
          final rh = bindings.readHeaderEx(handle, header);
          if (rh == ERAR_END_ARCHIVE) break;
          if (rh != ERAR_SUCCESS) {
            throw mapUnrarDllError(
              code: rh,
              archiveLabel: label,
              context: 'extract_header',
            );
          }

          final flags = header.ref.Flags;
          if ((flags & RHDF_ENCRYPTED) != 0) {
            throw CbrArchiveException(
              kind: CbrArchiveErrorKind.passwordRequired,
              userMessage: 'This comic archive is password-protected.',
              diagnosticDetail: 'encrypted_entry:$label',
            );
          }

          final currentName = readWideString(
            header.ref.FileNameEx,
            cbrMaxEntryNameLength,
          ).replaceAll('\\', '/');

          if (currentName == normalized) {
            found = true;
            final declared =
                combineSize64(header.ref.UnpSize, header.ref.UnpSizeHigh);
            if (declared > cbrMaxSinglePageUncompressedBytes) {
              throw CbrArchiveException(
                kind: CbrArchiveErrorKind.unsupported,
                userMessage: 'This comic page exceeds supported size limits.',
                diagnosticDetail: 'oversized_declared:$label',
              );
            }
            final pf = bindings.processFile(handle, RAR_EXTRACT, destPath, nullptr);
            if (pf == ERAR_MISSING_PASSWORD || pf == ERAR_BAD_PASSWORD) {
              throw mapUnrarDllError(
                code: pf,
                archiveLabel: label,
                context: 'extract_password',
              );
            }
            if (pf != ERAR_SUCCESS) {
              throw mapUnrarDllError(
                code: pf,
                archiveLabel: label,
                context: 'extract_process',
              );
            }
            break;
          }

          final skip = bindings.processFile(handle, RAR_SKIP, nullptr, nullptr);
          if (skip != ERAR_SUCCESS) {
            throw mapUnrarDllError(
              code: skip,
              archiveLabel: label,
              context: 'extract_skip',
            );
          }
        }

        if (!found) {
          throw CbrArchiveException(
            kind: CbrArchiveErrorKind.entryNotFound,
            userMessage: 'That comic page could not be opened.',
            diagnosticDetail: 'missing_entry:$label',
          );
        }

        final extracted = _findExtractedFile(temp, normalized);
        if (extracted == null) {
          throw CbrArchiveException(
            kind: CbrArchiveErrorKind.entryNotFound,
            userMessage: 'That comic page could not be opened.',
            diagnosticDetail: 'missing_output:$label',
          );
        }

        final bytes = await extracted.readAsBytes();
        if (bytes.length > cbrMaxSinglePageUncompressedBytes) {
          throw CbrArchiveException(
            kind: CbrArchiveErrorKind.unsupported,
            userMessage: 'This comic page exceeds supported size limits.',
            diagnosticDetail: 'oversized_actual:$label',
          );
        }

        sw.stop();
        return CbrExtractedPage(
          entryName: normalized,
          bytes: bytes,
          duration: sw.elapsed,
          usedTemporaryDirectory: true,
        );
      } finally {
        calloc.free(archiveName);
        calloc.free(destPath);
      }
    } finally {
      if (handle != null) {
        bindings.closeArchive(handle);
        UnrarDllLifecycle.instance.recordArchiveClosed();
      }
      calloc.free(openData);
      calloc.free(header);
      calloc.free(fileNameEx);
      calloc.free(arcNameEx);
      calloc.free(redirName);
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        UnrarDllLifecycle.instance.recordTempDirRemoved();
      } catch (_) {}
    }
  }

  @override
  Future<void> testArchive(String archivePath) async {
    final label = cbrBasename(archivePath);
    _validateArchiveFile(archivePath, label);
    final bindings = await _bindingsOrLoad();

    final openData = calloc<RAROpenArchiveDataEx>();
    final header = calloc<RARHeaderDataEx>();
    Pointer<Void>? handle;
    try {
      final archiveName = archivePath.toNativeUtf8();
      try {
        openData.ref
          ..ArcName = archiveName
          ..OpenMode = RAR_OM_EXTRACT
          ..Callback = nullptr;
        handle = bindings.openArchiveEx(openData);
        UnrarDllLifecycle.instance.recordArchiveOpened();
        _throwOpenResult(openData.ref.OpenResult, label, 'test');

        while (true) {
          final rh = bindings.readHeaderEx(handle, header);
          if (rh == ERAR_END_ARCHIVE) break;
          if (rh != ERAR_SUCCESS) {
            throw mapUnrarDllError(code: rh, archiveLabel: label, context: 'test_header');
          }
          final pf = bindings.processFile(handle, RAR_TEST, nullptr, nullptr);
          if (pf != ERAR_SUCCESS) {
            throw mapUnrarDllError(code: pf, archiveLabel: label, context: 'test_process');
          }
        }
      } finally {
        calloc.free(archiveName);
      }
    } finally {
      if (handle != null) {
        bindings.closeArchive(handle);
        UnrarDllLifecycle.instance.recordArchiveClosed();
      }
      calloc.free(openData);
      calloc.free(header);
    }
  }

  @override
  Future<void> dispose() async {
    _bindings = null;
    _preloaded = null;
  }

  void _validateArchiveFile(String archivePath, String label) {
    final file = File(archivePath);
    if (!file.existsSync()) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.ioFailure,
        userMessage: 'This comic archive could not be opened.',
        diagnosticDetail: 'missing_file:$label',
      );
    }
    if (file.lengthSync() == 0) {
      throw CbrArchiveException(
        kind: CbrArchiveErrorKind.emptyArchive,
        userMessage: 'This comic archive has no readable pages.',
        diagnosticDetail: 'zero_byte:$label',
      );
    }
  }

  void _throwOpenResult(int code, String label, String context) {
    if (code == ERAR_SUCCESS) return;
    throw mapUnrarDllError(code: code, archiveLabel: label, context: context);
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
