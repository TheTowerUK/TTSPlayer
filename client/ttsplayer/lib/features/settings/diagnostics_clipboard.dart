import 'package:flutter/services.dart';

/// Platform boundary for writing redacted diagnostics text (ADR-019).
abstract interface class DiagnosticsClipboardWriter {
  Future<void> writeText(String text);
}

/// Production clipboard writer using Flutter's system clipboard API.
class FlutterDiagnosticsClipboardWriter implements DiagnosticsClipboardWriter {
  const FlutterDiagnosticsClipboardWriter();

  @override
  Future<void> writeText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
