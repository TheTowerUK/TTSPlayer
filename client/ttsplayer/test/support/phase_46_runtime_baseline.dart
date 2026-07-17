import 'dart:io';

/// Observational metrics captured during opt-in Phase 4.6 Windows runtime validation.
///
/// Printed at suite end — informational only, not pass/fail gates.
class Phase46RuntimeBaseline {
  Phase46RuntimeBaseline();

  final Stopwatch suiteStopwatch = Stopwatch()..start();
  final Map<String, Object?> _observations = {};

  void observe(String key, Object? value) {
    _observations[key] = value;
  }

  void printReport() {
    // ignore: avoid_print
    print('=== Phase 4.6 Windows Runtime Baseline ===');
    // ignore: avoid_print
    print(
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    // ignore: avoid_print
    print('Dart: ${Platform.version.split(' ').first}');
    // ignore: avoid_print
    print('Mode: flutter test (PHASE_46_RUNTIME=1)');
    for (final entry in _observations.entries) {
      // ignore: avoid_print
      print('${entry.key}: ${entry.value}');
    }
    // ignore: avoid_print
    print(
      'suite_duration_ms: ${suiteStopwatch.elapsedMilliseconds} (informational)',
    );
    // ignore: avoid_print
    print(
      'Manual checkpoints: narrow/wide layout, keyboard focus, scroll, '
      'Snackbar visibility, external clipboard paste, long identity wrap, '
      'high-DPI layout',
    );
  }
}
