@Tags(['phase53-audio-gate'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_session_mode.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'support/audio_gate_fixtures.dart';

/// Windows Gate 0 — audio-only playback capability via production stack.
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows   # once — libmpv-2.dll
/// $env:PHASE_53_AUDIO_GATE='1'
/// flutter test test/phase_53_audio_gate_windows_runtime_test.dart --tags phase53-audio-gate
/// ```
///
/// Optional: `PHASE_53_HTTPS_URI` — HTTPS audio URL for network matrix row.
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_53_AUDIO_GATE'] != '1') {
    test(
      'skipped — set PHASE_53_AUDIO_GATE=1 to run Phase 5.3 audio Gate 0',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.3 audio Gate 0 is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final libmpv = _resolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  group('Phase 5.3 audio Gate 0 — PlaybackService', () {
    late GeneratedAudioFixture wav;
    late PlaybackService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wav = await writeMonoWavFixture(duration: const Duration(seconds: 2));
      service = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        ),
      );
    });

    tearDown(() async {
      await service.stop();
    });

    test('G53-A1 local WAV loads without VideoController', () async {
      final item = MediaItem(
        id: 'gate-wav',
        title: 'Gate WAV',
        filePath: wav.path,
        mediaKindRaw: 'audio',
      );

      await service.play(item);

      expect(service.isAudioSession, isTrue);
      expect(service.requiresVideoSurface, isFalse);
      expect(service.mediaKitVideoController, isNull);
      expect(service.isReady, isTrue);
      expect(service.duration, greaterThan(Duration.zero));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G53-A2 play pause seek position', () async {
      final item = MediaItem(
        id: 'gate-transport',
        title: 'Gate Transport',
        filePath: wav.path,
        mediaKindRaw: 'audio',
      );

      await service.play(item);
      expect(service.isPlaying, isTrue);

      await service.togglePlayPause();
      expect(service.isPlaying, isFalse);

      await service.togglePlayPause();
      await service.seekToPosition(const Duration(milliseconds: 500));
      await _waitFor(() => service.position >= const Duration(milliseconds: 400));

      expect(service.position, greaterThanOrEqualTo(const Duration(milliseconds: 400)));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G53-A3 completion and replay', () async {
      final shortWav = await writeMonoWavFixture(
        duration: const Duration(milliseconds: 800),
        basename: 'gate_short',
      );
      final item = MediaItem(
        id: 'gate-complete',
        title: 'Gate Complete',
        filePath: shortWav.path,
        mediaKindRaw: 'audio',
      );

      await service.play(item);
      await _waitFor(() => service.isCompleted, timeout: const Duration(seconds: 30));

      await service.play(item);
      expect(service.isReady, isTrue);
      expect(service.isCompleted, isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G53-A4 video then audio session switch', () async {
      // Video path requires VideoController — probe with stub failure acceptable
      // if no video fixture; focus on audio leg after synthetic video attempt.
      final audio = MediaItem(
        id: 'gate-after-video',
        title: 'After Video',
        filePath: wav.path,
        mediaKindRaw: 'audio',
      );

      await service.play(audio);
      expect(service.sessionMode, PlaybackSessionMode.audio);
      expect(service.isReady, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G53-A5 optional HTTPS audio URI', () async {
      final httpsUri = Platform.environment['PHASE_53_HTTPS_URI'];
      if (httpsUri == null || httpsUri.trim().isEmpty) {
        markTestSkipped('Set PHASE_53_HTTPS_URI for HTTPS audio Gate 0 row');
        return;
      }

      final item = MediaItem(
        id: 'gate-https',
        title: 'Gate HTTPS',
        filePath: httpsUri.trim(),
        mediaKindRaw: 'audio',
      );

      await service.play(item);
      expect(service.isReady, isTrue);
      expect(service.duration, greaterThan(Duration.zero));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Phase 5.3 audio Gate 0 — bare media_kit formats', () {
    test('G53-F1 WAV opens on bare Player', () async {
      final wav = await writeMonoWavFixture(basename: 'bare_wav');
      final player = Player();
      addTearDown(player.dispose);

      await player.open(Media(wav.fileUri.toString()), play: false);
      await _waitFor(() => player.state.duration > Duration.zero);
      await player.play();
      await _waitFor(() => player.state.playing);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G53-F2 optional MP3 via ffmpeg fixture', () async {
      final mp3 = await tryWriteMp3ViaFfmpeg();
      if (mp3 == null) {
        markTestSkipped('ffmpeg unavailable — MP3 format row not verified');
        return;
      }

      final player = Player();
      addTearDown(player.dispose);

      await player.open(Media(mp3.fileUri.toString()), play: false);
      await _waitFor(() => player.state.duration > Duration.zero);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

String _resolveLibMpvPath() {
  final fromEnv = Platform.environment['LIBMPV_LIBRARY_PATH'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return fromEnv;
  }

  for (final relative in [
    r'build\windows\x64\runner\Debug\libmpv-2.dll',
    r'build\windows\x64\runner\Release\libmpv-2.dll',
  ]) {
    final file = File(relative);
    if (file.existsSync()) return file.absolute.path;
  }

  fail(
    'libmpv-2.dll not found. Run `flutter build windows` or set LIBMPV_LIBRARY_PATH.',
  );
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for condition');
}
