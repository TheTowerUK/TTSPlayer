import 'dart:io';

import 'phase_736_metadata_fixtures.dart';

/// Observational metrics for opt-in Phase 7.3.6 Windows runtime validation.
class Phase736MetadataRuntimeBaseline {
  Phase736MetadataRuntimeBaseline();

  final Stopwatch suiteStopwatch = Stopwatch()..start();
  final Map<String, Object?> observations = {};
  final Map<String, String> scenarioClassifications = {};

  int totalProviderSearches = 0;
  int totalCoordinatorSelects = 0;
  int totalCoordinatorRelinks = 0;
  int totalCoordinatorUnlinks = 0;
  int totalCoordinatorIgnores = 0;
  int totalCoordinatorResumes = 0;

  void observe(String key, Object? value) {
    observations[key] = value;
  }

  void classifyScenario(String id, String classification) {
    scenarioClassifications[id] = classification;
  }

  void captureEnvironment() {
    observe('platform', Platform.operatingSystem);
    observe('dart', Platform.version.split(' ').first);
    observe('catalog_identity', Phase736Fixtures.catalogIdentity);
  }

  void printReport() {
    // ignore: avoid_print
    print('=== Phase 7.3.6 Metadata Matching Runtime Summary (M30) ===');
    // ignore: avoid_print
    print('Mode: flutter test (PHASE_736_RUNTIME=1)');
    // ignore: avoid_print
    print('Provider search invocations (total): $totalProviderSearches');
    // ignore: avoid_print
    print('Coordinator select invocations (total): $totalCoordinatorSelects');
    // ignore: avoid_print
    print('Coordinator relink invocations (total): $totalCoordinatorRelinks');
    // ignore: avoid_print
    print('Coordinator unlink invocations (total): $totalCoordinatorUnlinks');
    // ignore: avoid_print
    print('Coordinator ignore invocations (total): $totalCoordinatorIgnores');
    // ignore: avoid_print
    print('Coordinator resume invocations (total): $totalCoordinatorResumes');
    for (final entry in observations.entries) {
      // ignore: avoid_print
      print('${entry.key}: ${entry.value}');
    }
    // ignore: avoid_print
    print('Scenario classifications:');
    for (final entry in scenarioClassifications.entries) {
      // ignore: avoid_print
      print('  ${entry.key}: ${entry.value}');
    }
    // ignore: avoid_print
    print(
      'suite_duration_ms: ${suiteStopwatch.elapsedMilliseconds} (informational)',
    );
  }
}
