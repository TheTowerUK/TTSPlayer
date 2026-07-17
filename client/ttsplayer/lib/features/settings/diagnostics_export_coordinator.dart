import '../../services/diagnostics/diagnostics_service.dart';
import '../../services/diagnostics/runtime_diagnostics_models.dart';
import 'diagnostics_clipboard.dart';

/// Result of a diagnostics export attempt (capture → format → clipboard).
sealed class DiagnosticsExportResult {
  const DiagnosticsExportResult();
}

final class DiagnosticsExportSuccess extends DiagnosticsExportResult {
  const DiagnosticsExportSuccess(this.snapshot);

  final RuntimeDiagnosticsSnapshot snapshot;
}

final class DiagnosticsExportCaptureFailure extends DiagnosticsExportResult {
  const DiagnosticsExportCaptureFailure();
}

final class DiagnosticsExportFormatFailure extends DiagnosticsExportResult {
  const DiagnosticsExportFormatFailure();
}

final class DiagnosticsExportClipboardFailure extends DiagnosticsExportResult {
  const DiagnosticsExportClipboardFailure();
}

/// Orchestrates fresh capture, formatter export, and clipboard delivery.
class DiagnosticsExportCoordinator {
  const DiagnosticsExportCoordinator({
    required DiagnosticsService diagnosticsService,
    required DiagnosticsClipboardWriter clipboardWriter,
  })  : _diagnosticsService = diagnosticsService,
        _clipboardWriter = clipboardWriter;

  final DiagnosticsService _diagnosticsService;
  final DiagnosticsClipboardWriter _clipboardWriter;

  /// Captures a fresh snapshot, formats it, and writes to the clipboard.
  ///
  /// Returns the captured snapshot on success so the UI can update display
  /// (Option A — copied text matches on-screen snapshot).
  Future<DiagnosticsExportResult> copyDiagnostics() async {
    RuntimeDiagnosticsSnapshot snapshot;
    try {
      snapshot = await _diagnosticsService.captureSnapshot();
    } catch (_) {
      return const DiagnosticsExportCaptureFailure();
    }

    String exportText;
    try {
      exportText = _diagnosticsService.formatExport(snapshot);
    } catch (_) {
      return const DiagnosticsExportFormatFailure();
    }

    try {
      await _clipboardWriter.writeText(exportText);
    } catch (_) {
      return const DiagnosticsExportClipboardFailure();
    }

    return DiagnosticsExportSuccess(snapshot);
  }
}
