import 'dart:async';
import 'dart:convert';
import 'dart:io';


import 'package:flutter/foundation.dart';

import 'catalog_service.dart';
import '../navigation/app_navigator.dart';

// ---------------------------------------------------------------------------
// ScanProgress
// ---------------------------------------------------------------------------

/// Parsed payload of a single PROGRESS: line from indexer.py.
class ScanProgress {
  /// "folder" during a scan, "complete" when the scan finishes.
  final String type;

  /// Top-level library currently being scanned (e.g. "Videos").
  final String library;

  /// Most recently completed folder name (e.g. "Concerts").
  final String folder;

  final int folders;
  final int items;
  final int warnings;
  final int elapsedSeconds;

  const ScanProgress({
    required this.type,
    this.library = '',
    this.folder = '',
    this.folders = 0,
    this.items = 0,
    this.warnings = 0,
    this.elapsedSeconds = 0,
  });

  factory ScanProgress.fromJson(Map<String, dynamic> json) => ScanProgress(
        type: json['type'] as String? ?? 'folder',
        library: json['library'] as String? ?? '',
        folder: json['folder'] as String? ?? '',
        folders: json['folders'] as int? ?? 0,
        items: json['items'] as int? ?? 0,
        warnings: json['warnings'] as int? ?? 0,
        elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
      );

  bool get isComplete => type == 'complete';
}

// ---------------------------------------------------------------------------
// ScannerService
// ---------------------------------------------------------------------------

/// Runs the Python indexer as a subprocess and reloads the catalogue on success.
///
/// Supports two modes:
///
/// [runScan]         — full rescan of all media roots in ttsplayer.config.json.
/// [runLibraryScan]  — rescan a single top-level library folder and merge the
///                     result into the existing catalog.json.
///
/// Stdout is consumed line-by-line.  Lines beginning with "PROGRESS: " carry
/// a JSON payload that is parsed into [progress] and exposed to the UI.
/// All other lines are collected as diagnostics in [lastOutput].
///
/// Desktop-only (dart:io Process).
class ScannerService extends ChangeNotifier {
  bool _isScanning = false;
  String? _errorMessage;
  String? _lastOutput;
  ScanProgress? _progress;

  // Throttle UI rebuilds to ≤ 4/s.  Progress lines are parsed and stored
  // immediately, but notifyListeners() is deferred until the timer fires.
  // "complete" messages bypass the throttle and notify immediately.
  static const _notifyInterval = Duration(milliseconds: 250);
  Timer? _progressNotifyTimer;

  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  ScanProgress? get progress => _progress;

  /// Combined stdout + stderr from the last scan run.
  String? get lastOutput => _lastOutput;

  // ---------------------------------------------------------------------------
  // Hardcoded for the Windows desktop MVP.
  // Will be read from ttsplayer.config.json when the settings screen arrives.
  // ---------------------------------------------------------------------------
  static const _python = 'python';
  static const _script = r'D:\AppDev\TTSPlayer\backend\indexer.py';
  static const _config = r'D:\AppDev\TTSPlayer\ttsplayer.config.json';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Full rescan — runs the indexer against all configured media roots.
  Future<void> runScan(CatalogService catalogService) =>
      _run(const [], catalogService, navigateHomeOnSuccess: true);

  /// Library rescan — rescans [libraryPath] only and merges the refreshed
  /// branch into the existing catalog.json.
  ///
  /// [libraryPath] is the exact filesystem path stored in the folder node
  /// (e.g. `Y:\Media\Videos`).  Never invented or inferred.
  ///
  /// On success the catalogue is refreshed in place — navigation is unchanged.
  Future<void> runLibraryScan(
    String libraryPath,
    CatalogService catalogService,
  ) =>
      _run(
        ['--library-path', libraryPath],
        catalogService,
        navigateHomeOnSuccess: false,
      );

  /// Whether a successful scan should reset navigation to the dashboard.
  @visibleForTesting
  static bool navigatesHomeAfterSuccess(List<String> extraArgs) =>
      !extraArgs.contains('--library-path');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _run(
    List<String> extraArgs,
    CatalogService catalogService, {
    required bool navigateHomeOnSuccess,
  }) async {
    if (_isScanning) return;

    if (kIsWeb || !Platform.isWindows) {
      _errorMessage = 'Scanner subprocess is only supported on Windows desktop.';
      notifyListeners();
      return;
    }

    _isScanning = true;
    _errorMessage = null;
    _progress = null;
    _lastOutput = null;
    notifyListeners();

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    try {
      final process = await Process.start(
        _python,
        [_script, '--config', _config, ...extraArgs],
      );

      // Consume stdout line by line.  PROGRESS: lines are parsed into
      // ScanProgress and notify listeners immediately.  All lines are
      // also buffered for diagnostics.
      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stdoutBuffer.writeln(line);
        if (line.startsWith('PROGRESS: ')) {
          _handleProgressLine(line.substring('PROGRESS: '.length));
        }
      });

      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(stderrBuffer.writeln);

      final exitCode = await process.exitCode;
      await Future.wait([stdoutSub.cancel(), stderrSub.cancel()]);

      final stdout = stdoutBuffer.toString().trim();
      final stderr = stderrBuffer.toString().trim();
      _lastOutput = [stdout, if (stderr.isNotEmpty) stderr].join('\n').trim();

      debugPrint('[ScannerService] exit $exitCode');

      if (exitCode == 0) {
        await catalogService.rescan();
        if (navigateHomeOnSuccess) {
          popNavigationToHome();
        }
      } else {
        final detail = stderr.isNotEmpty ? stderr : 'No details captured.';
        _errorMessage = 'Scanner exited with code $exitCode. $detail';
      }
    } on ProcessException catch (e) {
      _errorMessage =
          'Could not start scanner: ${e.message}. '
          'Is Python installed and on PATH?';
      debugPrint('[ScannerService] ProcessException: $e');
    } catch (e) {
      _errorMessage = 'Unexpected scanner error: $e';
      debugPrint('[ScannerService] error: $e');
    } finally {
      _progressNotifyTimer?.cancel();
      _progressNotifyTimer = null;
      _isScanning = false;
      notifyListeners();
    }
  }

  void _handleProgressLine(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      _progress = ScanProgress.fromJson(map);

      if (_progress!.isComplete) {
        // Always flush the completion message immediately.
        _progressNotifyTimer?.cancel();
        _progressNotifyTimer = null;
        notifyListeners();
      } else {
        // Schedule a deferred notify if one is not already pending.
        // If the timer is already running, _progress has been updated in place
        // and the pending notify will pick up the latest value when it fires.
        _progressNotifyTimer ??= Timer(_notifyInterval, () {
          _progressNotifyTimer = null;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('[ScannerService] Failed to parse PROGRESS line: $jsonStr');
    }
  }
}
