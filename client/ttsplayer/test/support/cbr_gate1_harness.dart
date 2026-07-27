import 'dart:io';

/// Gate 1 production matrix scenario outcomes.
enum Gate1ScenarioStatus {
  passed,
  failed,
  skipped,
  notApplicable,
}

class Gate1ScenarioReport {
  Gate1ScenarioReport({
    required this.id,
    required this.title,
    required this.status,
    this.detail,
  });

  final int id;
  final String title;
  final Gate1ScenarioStatus status;
  final String? detail;
}

/// Prints a summary table at end of harness run.
class Gate1Matrix {
  Gate1Matrix();

  final _reports = <Gate1ScenarioReport>[];

  List<Gate1ScenarioReport> get reports => List.unmodifiable(_reports);

  void record(Gate1ScenarioReport report) {
    _reports.add(report);
    final label = switch (report.status) {
      Gate1ScenarioStatus.passed => 'PASS',
      Gate1ScenarioStatus.failed => 'FAIL',
      Gate1ScenarioStatus.skipped => 'SKIP',
      Gate1ScenarioStatus.notApplicable => 'N/A',
    };
    // ignore: avoid_print
    print(
      'G1-${report.id.toString().padLeft(2, '0')} [$label] ${report.title}${report.detail != null ? ' — ${report.detail}' : ''}',
    );
  }

  void printSummary() {
    var passed = 0, failed = 0, skipped = 0, na = 0;
    for (final r in _reports) {
      switch (r.status) {
        case Gate1ScenarioStatus.passed:
          passed++;
        case Gate1ScenarioStatus.failed:
          failed++;
        case Gate1ScenarioStatus.skipped:
          skipped++;
        case Gate1ScenarioStatus.notApplicable:
          na++;
      }
    }
    // ignore: avoid_print
    print(
      'Gate1 matrix: passed=$passed failed=$failed skipped=$skipped na=$na total=${_reports.length}',
    );
  }
}

String gate1FixtureDir() {
  return Platform.environment['PHASE_63_GATE1_FIXTURE_DIR'] ??
      Platform.environment['PHASE_63_GATE0_FIXTURE_DIR'] ??
      'test/support/cbr_gate0_fixtures';
}

String? gate1EvalDllPath() => Platform.environment['PHASE_63_UNRAR_DLL'];

String? gate1ReleaseAppDir() => Platform.environment['PHASE_63_RELEASE_APP_DIR'];

bool gate1FixtureExists(String name) {
  return File('${gate1FixtureDir()}${Platform.pathSeparator}$name').existsSync();
}
