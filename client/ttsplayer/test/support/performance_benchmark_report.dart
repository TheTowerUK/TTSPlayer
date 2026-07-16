/// Prints observational timing samples for opt-in micro-benchmarks.
///
/// Timing output is informational only — never used as pass/fail gates.
class PerformanceBenchmarkReport {
  PerformanceBenchmarkReport({required this.suiteName});

  final String suiteName;
  final List<_BenchmarkRow> _rows = [];

  void measure({
    required String operation,
    required int fixtureSize,
    required void Function() run,
    int warmupIterations = 3,
    int measureIterations = 10,
    Map<String, Object?> extra = const {},
  }) {
    for (var i = 0; i < warmupIterations; i++) {
      run();
    }

    final samples = <int>[];
    for (var i = 0; i < measureIterations; i++) {
      final stopwatch = Stopwatch()..start();
      run();
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }

    samples.sort();
    final total = samples.fold<int>(0, (sum, v) => sum + v);
    final median = samples[samples.length ~/ 2];
    final min = samples.first;
    final max = samples.last;

    _rows.add(
      _BenchmarkRow(
        operation: operation,
        fixtureSize: fixtureSize,
        warmupIterations: warmupIterations,
        measureIterations: measureIterations,
        minMicros: min,
        medianMicros: median,
        maxMicros: max,
        totalMicros: total,
        extra: extra,
      ),
    );
  }

  void printReport() {
    // ignore: avoid_print
    print('=== $suiteName ===');
    for (final row in _rows) {
      // ignore: avoid_print
      print(row.format());
    }
    // ignore: avoid_print
    print('(Informational only — not pass/fail gates)');
  }
}

final class _BenchmarkRow {
  const _BenchmarkRow({
    required this.operation,
    required this.fixtureSize,
    required this.warmupIterations,
    required this.measureIterations,
    required this.minMicros,
    required this.medianMicros,
    required this.maxMicros,
    required this.totalMicros,
    required this.extra,
  });

  final String operation;
  final int fixtureSize;
  final int warmupIterations;
  final int measureIterations;
  final int minMicros;
  final int medianMicros;
  final int maxMicros;
  final int totalMicros;
  final Map<String, Object?> extra;

  String format() {
    final extras = extra.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    final extraSuffix = extras.isEmpty ? '' : ' | $extras';
    return '$operation [n=$fixtureSize, warm=$warmupIterations, '
        'iter=$measureIterations] '
        'min=${_formatMicros(minMicros)} '
        'median=${_formatMicros(medianMicros)} '
        'max=${_formatMicros(maxMicros)} '
        'total=${_formatMicros(totalMicros)}$extraSuffix';
  }

  static String _formatMicros(int micros) {
    if (micros < 1000) return '$microsµs';
    final ms = micros / 1000;
    if (ms < 1000) return '${ms.toStringAsFixed(2)}ms';
    return '${(ms / 1000).toStringAsFixed(2)}s';
  }
}
