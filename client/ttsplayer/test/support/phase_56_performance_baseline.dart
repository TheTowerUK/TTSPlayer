import 'dart:io';

/// Structured Phase 5.6 Step 2 performance baseline measurement helpers.
///
/// Timing results are informational — correctness assertions remain blocking.

class Phase56BaselineResult {
  Phase56BaselineResult({
    required this.scenarioId,
    required this.operation,
    required this.catalogueItemCount,
    required this.audioItemCount,
    required this.artistCount,
    required this.albumCount,
    required this.samples,
    required this.classification,
    this.notes,
  }) : median = _median(samples);

  final String scenarioId;
  final String operation;
  final int catalogueItemCount;
  final int audioItemCount;
  final int artistCount;
  final int albumCount;
  final List<Duration> samples;
  final Duration median;
  final String classification;
  final String? notes;

  String get sampleSummary =>
      samples.map((d) => '${d.inMilliseconds}').join('/');

  String toReportLine() {
    final note = notes == null || notes!.isEmpty ? '' : ' | $notes';
    return '$scenarioId | $audioItemCount audio / '
        '$artistCount artists / $albumCount albums | $operation | '
        'samples $sampleSummary ms | median ${median.inMilliseconds} ms | '
        '$classification$note';
  }

  static Duration _median(List<Duration> samples) {
    if (samples.isEmpty) return Duration.zero;
    final sorted = List<Duration>.from(samples)..sort((a, b) => a.compareTo(b));
    return sorted[sorted.length ~/ 2];
  }
}

/// Collects informational baseline rows and prints a suite report.
class Phase56PerformanceBaseline {
  Phase56PerformanceBaseline();

  final Stopwatch suiteStopwatch = Stopwatch()..start();
  final List<Phase56BaselineResult> results = [];
  final Map<String, Object?> observations = {};

  String? flutterVersionHint;
  String? liveCatalogStatus;

  void observe(String key, Object? value) {
    observations[key] = value;
  }

  void add(Phase56BaselineResult result) {
    results.add(result);
  }

  Future<void> captureEnvironment() async {
    flutterVersionHint = Platform.version.split(' ').first;
  }

  /// Runs one untimed warm-up, then [iterations] timed samples.
  ///
  /// Fixture preparation must occur outside this helper (or inside [prepare]
  /// before warm-up) so generation cost is not mixed into projection samples
  /// unless [includePrepareInSamples] is true.
  Future<List<Duration>> measureSamples({
    required Future<void> Function() operation,
    Future<void> Function()? prepare,
    int iterations = 3,
    bool includePrepareInSamples = false,
  }) async {
    if (prepare != null && !includePrepareInSamples) {
      await prepare();
    }

    // Untimed warm-up.
    if (prepare != null && includePrepareInSamples) {
      await prepare();
    }
    await operation();

    final samples = <Duration>[];
    for (var i = 0; i < iterations; i++) {
      if (prepare != null && includePrepareInSamples) {
        await prepare();
      }
      final sw = Stopwatch()..start();
      await operation();
      sw.stop();
      samples.add(sw.elapsed);
    }
    return samples;
  }

  /// Synchronous variant for pure CPU operations (projection build, search).
  List<Duration> measureSyncSamples({
    required void Function() operation,
    void Function()? prepare,
    int iterations = 3,
    bool includePrepareInSamples = false,
  }) {
    if (prepare != null && !includePrepareInSamples) {
      prepare();
    }

    if (prepare != null && includePrepareInSamples) {
      prepare();
    }
    operation();

    final samples = <Duration>[];
    for (var i = 0; i < iterations; i++) {
      if (prepare != null && includePrepareInSamples) {
        prepare();
      }
      final sw = Stopwatch()..start();
      operation();
      sw.stop();
      samples.add(sw.elapsed);
    }
    return samples;
  }

  void printReport() {
    // ignore: avoid_print
    print('=== Phase 5.6 Large-Library Baseline ===');
    // ignore: avoid_print
    print(
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    // ignore: avoid_print
    print('Dart: ${flutterVersionHint ?? Platform.version.split(' ').first}');
    // ignore: avoid_print
    print('Mode: flutter test (informational timings)');
    // ignore: avoid_print
    print(
      'Warm-up: 1 untimed + 3 timed samples; median of timed samples reported',
    );
    if (liveCatalogStatus != null) {
      // ignore: avoid_print
      print('Live catalogue: $liveCatalogStatus');
    }
    for (final entry in observations.entries) {
      // ignore: avoid_print
      print('${entry.key}: ${entry.value}');
    }
    // ignore: avoid_print
    print('--- MP scenario results ---');
    for (final result in results) {
      // ignore: avoid_print
      print(result.toReportLine());
    }
    // ignore: avoid_print
    print(
      'suite_duration_ms: ${suiteStopwatch.elapsedMilliseconds} (informational)',
    );
  }
}
