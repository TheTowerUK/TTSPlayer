import '../../models/playback/playback_error_kind.dart';
import '../../services/diagnostics/diagnostic_section_status.dart';

/// Presentation-layer formatting for diagnostics UI (Step 4).
abstract final class DiagnosticsFormatters {
  static String sectionStatusLabel(DiagnosticSectionStatus status) {
    switch (status) {
      case DiagnosticSectionStatus.complete:
        return 'Available';
      case DiagnosticSectionStatus.partial:
        return 'Partial';
      case DiagnosticSectionStatus.unavailable:
        return 'Unavailable';
    }
  }

  static String unavailable() => 'Unavailable';

  static String notApplicable() => 'Not applicable';

  static String boolValue(bool? value) {
    if (value == null) return unavailable();
    return value ? 'Yes' : 'No';
  }

  static String intValue(int? value) {
    if (value == null) return unavailable();
    return value.toString();
  }

  static String textValue(String? value) {
    if (value == null || value.isEmpty) return unavailable();
    return value;
  }

  static String dateTimeUtc(DateTime? value) {
    if (value == null) return unavailable();
    return value.toUtc().toIso8601String();
  }

  static String durationValue(Duration? value) {
    if (value == null) return unavailable();
    final seconds = value.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = value.inMinutes;
    final remSeconds = seconds % 60;
    if (minutes < 60) {
      return remSeconds == 0 ? '${minutes}m' : '${minutes}m ${remSeconds}s';
    }
    final hours = value.inHours;
    final remMinutes = minutes % 60;
    return remMinutes == 0 ? '${hours}h' : '${hours}h ${remMinutes}m';
  }

  static String bytesValue(int? bytes) {
    if (bytes == null) return unavailable();
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  static String bytesOfTotal(int? current, int? budget) {
    if (current == null && budget == null) return unavailable();
    if (current == null) return 'Unavailable of ${bytesValue(budget)}';
    if (budget == null) return '${bytesValue(current)} of Unavailable';
    return '${bytesValue(current)} of ${bytesValue(budget)}';
  }

  static String playbackErrorKind(PlaybackErrorKind? kind) {
    if (kind == null) return notApplicable();
    switch (kind) {
      case PlaybackErrorKind.resolverFailed:
        return 'Resolver failed';
      case PlaybackErrorKind.fileMissing:
        return 'File missing';
      case PlaybackErrorKind.network:
        return 'Network';
      case PlaybackErrorKind.tls:
        return 'TLS';
      case PlaybackErrorKind.httpNotFound:
        return 'HTTP not found';
      case PlaybackErrorKind.timeout:
        return 'Timeout';
      case PlaybackErrorKind.permission:
        return 'Permission';
      case PlaybackErrorKind.unsupportedFormat:
        return 'Unsupported format';
      case PlaybackErrorKind.unknown:
        return 'Unknown';
    }
  }

  static String healthLabel(String raw) {
    if (raw.isEmpty) return unavailable();
    switch (raw) {
      case 'idle':
        return 'Idle';
      case 'loading':
        return 'In progress';
      case 'success':
        return 'Success';
      case 'degraded':
        return 'Degraded';
      case 'failed':
        return 'Failed';
      case 'skipped':
        return 'Skipped';
      default:
        return raw;
    }
  }
}
