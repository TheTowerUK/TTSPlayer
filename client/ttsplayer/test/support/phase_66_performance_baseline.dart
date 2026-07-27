import 'dart:io';

/// Informational performance baseline collector for Phase 6.6 reader hardening.
class Phase66PerformanceBaseline {
  Phase66PerformanceBaseline();

  final _observations = <String, Object>{};
  final _results = <Phase66BaselineResult>[];

  void observe(String key, Object? value) {
    if (value != null) _observations[key] = value;
  }

  void add(Phase66BaselineResult result) => _results.add(result);

  /// Warm-up + [sampleCount] timed samples; returns median milliseconds.
  int measureSyncMedianMs(
    void Function() action, {
    int sampleCount = 3,
    bool includeWarmUp = true,
  }) {
    if (includeWarmUp) action();
    final samples = <int>[];
    for (var i = 0; i < sampleCount; i++) {
      final sw = Stopwatch()..start();
      action();
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  Future<int> measureAsyncMedianMs(
    Future<void> Function() action, {
    int sampleCount = 3,
    bool includeWarmUp = true,
  }) async {
    if (includeWarmUp) await action();
    final samples = <int>[];
    for (var i = 0; i < sampleCount; i++) {
      final sw = Stopwatch()..start();
      await action();
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  void printReport() {
    // ignore: avoid_print
    print('=== Phase 6.6 reader hardening baseline ===');
    // ignore: avoid_print
    print('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    // ignore: avoid_print
    print('Dart: ${Platform.version.split(' ').first}');
    for (final entry in _observations.entries) {
      // ignore: avoid_print
      print('observe ${entry.key}: ${entry.value}');
    }
    for (final row in _results) {
      // ignore: avoid_print
      print(
        '${row.scenarioId} | ${row.fixtureLabel} | ${row.operation} | '
        'median ${row.medianMs}ms | ${row.classification}',
      );
    }
  }
}

class Phase66BaselineResult {
  const Phase66BaselineResult({
    required this.scenarioId,
    required this.fixtureLabel,
    required this.operation,
    required this.medianMs,
    this.classification = 'informational',
  });

  final String scenarioId;
  final String fixtureLabel;
  final String operation;
  final int medianMs;
  final String classification;
}

int? currentProcessRssKb() {
  if (!Platform.isWindows) return null;
  try {
    final info = ProcessInfo.currentRss;
    return info ~/ 1024;
  } catch (_) {
    return null;
  }
}
