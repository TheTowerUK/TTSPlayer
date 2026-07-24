import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Observational metrics for opt-in Phase 5.6 Windows runtime validation.
///
/// Printed at suite end — informational only, not pass/fail gates.
class Phase56RuntimeBaseline {
  Phase56RuntimeBaseline();

  final Stopwatch suiteStopwatch = Stopwatch()..start();
  final Map<String, Object?> observations = {};
  final List<String> scenarioResults = [];

  String? appVersion;
  String? flutterVersionHint;
  String? fixtureProfile;
  String? liveCatalogStatus;

  void observe(String key, Object? value) {
    observations[key] = value;
  }

  void recordScenario(String id, String status, {String? notes}) {
    final note = notes == null || notes.isEmpty ? '' : ' | $notes';
    scenarioResults.add('$id | $status$note');
  }

  /// Warm-up + [iterations] samples; returns median milliseconds.
  int measureSyncMedianMs({
    required void Function() operation,
    int iterations = 3,
    void Function()? prepare,
  }) {
    prepare?.call();
    operation(); // warm-up (untimed)
    final samples = <int>[];
    for (var i = 0; i < iterations; i++) {
      prepare?.call();
      final sw = Stopwatch()..start();
      operation();
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  Future<int> measureAsyncMedianMs({
    required Future<void> Function() operation,
    int iterations = 3,
    Future<void> Function()? prepare,
  }) async {
    if (prepare != null) await prepare();
    await operation();
    final samples = <int>[];
    for (var i = 0; i < iterations; i++) {
      if (prepare != null) await prepare();
      final sw = Stopwatch()..start();
      await operation();
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  Future<void> captureEnvironment() async {
    PackageInfo.setMockInitialValues(
      appName: 'TTSPlayer',
      packageName: 'ttsplayer',
      version: '0.5.0-dev',
      buildNumber: '1',
      buildSignature: 'runtime',
      installerStore: null,
    );
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version} (${info.buildNumber})';
    } catch (_) {
      appVersion = 'unavailable';
    }
    flutterVersionHint = Platform.version.split(' ').first;
  }

  void printReport() {
    // ignore: avoid_print
    print('=== Phase 5.6 Windows Runtime Baseline ===');
    // ignore: avoid_print
    print(
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    // ignore: avoid_print
    print('Dart: ${flutterVersionHint ?? Platform.version.split(' ').first}');
    // ignore: avoid_print
    print('App: ${appVersion ?? 'unknown'}');
    // ignore: avoid_print
    print('Mode: flutter test (PHASE_56_RUNTIME=1)');
    // ignore: avoid_print
    print('Fixture profile: ${fixtureProfile ?? 'n/a'}');
    // ignore: avoid_print
    print('Live catalogue: ${liveCatalogStatus ?? 'skipped'}');
    for (final entry in observations.entries) {
      // ignore: avoid_print
      print('${entry.key}: ${entry.value}');
    }
    // ignore: avoid_print
    print('--- P56-RT scenario results ---');
    for (final line in scenarioResults) {
      // ignore: avoid_print
      print(line);
    }
    // ignore: avoid_print
    print(
      'suite_duration_ms: ${suiteStopwatch.elapsedMilliseconds} (informational)',
    );
  }
}
