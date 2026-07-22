import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';

/// Observational metrics for opt-in Phase 5.4 Windows runtime validation.
///
/// Printed at suite end — informational only, not pass/fail gates.
class Phase54ListeningHistoryRuntimeBaseline {
  Phase54ListeningHistoryRuntimeBaseline();

  final Stopwatch suiteStopwatch = Stopwatch()..start();
  final Map<String, Object?> _observations = {};

  String? appVersion;
  String? flutterVersionHint;
  String? catalogueIdentity;
  bool realAudioExercised = false;
  bool optionalLocalCatalogExercised = false;
  String? optionalLocalCatalogResult;

  void observe(String key, Object? value) {
    _observations[key] = value;
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
    print('=== Phase 5.4 Windows Runtime Baseline ===');
    // ignore: avoid_print
    print(
      'Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}',
    );
    // ignore: avoid_print
    print('Dart: ${Platform.version.split(' ').first}');
    // ignore: avoid_print
    print('App: ${appVersion ?? 'unknown'}');
    // ignore: avoid_print
    print('Mode: flutter test (PHASE_54_RUNTIME=1)');
    // ignore: avoid_print
    print('Repository key: ${MusicListeningRepository.storageKey}');
    // ignore: avoid_print
    print(
      'Repository stateVersion: ${MusicListeningRepository.currentStateVersion}',
    );
    // ignore: avoid_print
    print('Catalogue identity: ${catalogueIdentity ?? 'unknown'}');
    // ignore: avoid_print
    print('Real audio exercised: $realAudioExercised');
    // ignore: avoid_print
    print('Optional local catalogue: $optionalLocalCatalogExercised');
    if (optionalLocalCatalogResult != null) {
      // ignore: avoid_print
      print('Optional local catalogue result: $optionalLocalCatalogResult');
    }
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
      'Manual checkpoints: wall-clock 15s/30s thresholds, keyboard focus on '
      'Continue Listening carousel, long-title layout, Release binary smoke, '
      'external clipboard paste, high-DPI layout',
    );
  }
}
