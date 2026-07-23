import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';

/// Observational metrics for opt-in Phase 5.5 Windows runtime validation.
///
/// Printed at suite end — informational only, not pass/fail gates.
class Phase55PlaybackSessionRuntimeBaseline {
  Phase55PlaybackSessionRuntimeBaseline();

  final Stopwatch suiteStopwatch = Stopwatch()..start();
  final Map<String, Object?> _observations = {};

  String? appVersion;
  String? flutterVersionHint;
  String? catalogueIdentity;
  bool realAudioExercised = false;
  String positionToleranceLabel =
      'simulated ±0 ms; MediaKit seek ±2 s when exercised';

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
    print('=== Phase 5.5 Windows Runtime Baseline ===');
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
    print('Mode: flutter test (PHASE_55_RUNTIME=1)');
    // ignore: avoid_print
    print('Repository key: ${MusicPlaybackSessionRepository.storageKey}');
    // ignore: avoid_print
    print(
      'Repository stateVersion: '
      '${MusicPlaybackSessionRepository.currentStateVersion}',
    );
    // ignore: avoid_print
    print('Catalogue identity: ${catalogueIdentity ?? 'unknown'}');
    // ignore: avoid_print
    print('Real audio exercised: $realAudioExercised');
    // ignore: avoid_print
    print('Position tolerance: $positionToleranceLabel');
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
      'Manual checkpoints: Release binary cold restart, audible no-autoplay, '
      'deferred seek from Play, Next/Previous after restore, diagnostics UI, '
      'video resume + Continue Listening isolation',
    );
  }
}
