import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/models/playback/playback_session_mode.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_access_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/resolved_media_location.dart';
import 'package:ttsplayer/models/playback/playback_audio_track.dart';
import 'package:ttsplayer/models/playback/playback_subtitle_track.dart';
import 'package:ttsplayer/services/playback/playback_session_controls.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'playback_service_extensions_test.dart';
import 'support/audio_gate_fixtures.dart';
import 'support/music_catalog_fixtures.dart';

class _StubResolver extends MediaLocationResolver {
  _StubResolver({required this.uriForPath})
      : super(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        );

  final String Function(String path) uriForPath;

  @override
  ResolvedMediaLocation resolve(String cataloguePath) {
    return ResolvedMediaLocation.resolved(
      uri: uriForPath(cataloguePath),
      providerType: MediaAccessProviderType.localFile,
    );
  }
}

MediaItem _audioItem({required String id, required String path}) {
  return MediaItem(
    id: id,
    title: 'Track $id',
    filePath: path,
    mediaKindRaw: 'audio',
    artist: 'Gate Artist',
    album: 'Gate Album',
    artistGroupKey: 'gate artist',
    albumGroupKey: 'gate artist|gate album|scope',
  );
}

MediaItem _videoItem({required String id, required String path}) {
  return MediaItem(
    id: id,
    title: 'Video $id',
    filePath: path,
    mediaKindRaw: 'video',
  );
}

PlaybackService _serviceWithStubInit({
  required MediaLocationResolver resolver,
  FakePlaybackSessionControls? controls,
}) {
  final fake = controls ?? FakePlaybackSessionControls();
  return PlaybackService(
    mediaLocationResolver: resolver,
    mediaKitInitOverride: (service, uri, generation) async {
      fake.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(fake);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(seconds: 120),
        position: Duration.zero,
      );
      final item = service.currentItem;
      if (item != null) {
        service.simulateReadyForTest(item);
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaybackSessionMode', () {
    test('audio item maps to audio session', () {
      expect(
        playbackSessionModeFor(musicTrackComplete()),
        PlaybackSessionMode.audio,
      );
    });

    test('video item maps to video session', () {
      final item = MediaItem(
        id: 'v',
        title: 'Clip',
        filePath: r'Y:\Videos\clip.mp4',
        mediaKindRaw: 'video',
      );
      expect(playbackSessionModeFor(item), PlaybackSessionMode.video);
    });
  });

  group('PlaybackService audio session (stubbed init)', () {
    late GeneratedAudioFixture wav;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wav = await writeMonoWavFixture(duration: const Duration(seconds: 2));
    });

    test('accepts audio item and marks audio session', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      final item = _audioItem(id: 'a1', path: wav.path);

      await service.play(item);

      expect(service.isAudioSession, isTrue);
      expect(service.requiresVideoSurface, isFalse);
      expect(service.isReady, isTrue);
      expect(service.currentItem?.id, 'a1');
    });

    test('video item remains video session with video surface required', () async {
      final resolver = _StubResolver(
        uriForPath: (_) => Uri.file(r'C:\media\clip.mp4').toString(),
      );
      final service = _serviceWithStubInit(resolver: resolver);
      final item = _videoItem(id: 'v1', path: r'C:\media\clip.mp4');

      await service.play(item);

      expect(service.isAudioSession, isFalse);
      expect(service.requiresVideoSurface, isTrue);
    });

    test('play and pause toggles for audio session', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      await service.play(_audioItem(id: 'a2', path: wav.path));

      expect(service.isPlaying, isTrue);
      await service.togglePlayPause();
      expect(service.isPlaying, isFalse);
    });

    test('seek updates position for audio session', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      await service.play(_audioItem(id: 'a3', path: wav.path));

      await service.seekToPosition(const Duration(seconds: 30));
      expect(service.position, const Duration(seconds: 30));
    });

    test('completion clears resume position once', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      final item = _audioItem(id: 'a4', path: wav.path);
      await service.play(item);

      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 3),
        position: const Duration(minutes: 3),
        completed: true,
      );
      service.runPlaybackTickForTest();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_a4'), isNull);
    });

    test('replay after completion via play restarts session', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      final item = _audioItem(id: 'a5', path: wav.path);
      await service.play(item);
      await service.stop();
      await service.play(item);
      expect(service.isReady, isTrue);
      expect(service.currentItem?.id, 'a5');
    });

    test('audio does not enter Continue Watching', () async {
      final catalog = Catalog.fromJson(
        jsonDecode(kCatalogV3MixedFixture) as Map<String, dynamic>,
      );
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);

      await service.persistResumeStateForTest(
        'track-complete',
        const Duration(seconds: 120),
        duration: const Duration(seconds: 3600),
      );

      final entries = await service.getContinueWatching(catalog);
      expect(entries, isEmpty);
    });

    test('switch video to audio resets session mode', () async {
      final resolver = _StubResolver(
        uriForPath: (path) => Uri.file(path).toString(),
      );
      final service = _serviceWithStubInit(resolver: resolver);

      await service.play(
        _videoItem(id: 'v-switch', path: r'C:\media\a.mp4'),
      );
      expect(service.requiresVideoSurface, isTrue);

      await service.play(_audioItem(id: 'a-switch', path: wav.path));
      expect(service.isAudioSession, isTrue);
      expect(service.requiresVideoSurface, isFalse);
    });

    test('switch audio to video resets session mode', () async {
      final resolver = _StubResolver(
        uriForPath: (path) => Uri.file(path).toString(),
      );
      final service = _serviceWithStubInit(resolver: resolver);

      await service.play(_audioItem(id: 'a-switch2', path: wav.path));
      expect(service.isAudioSession, isTrue);

      await service.play(
        _videoItem(id: 'v-switch2', path: r'C:\media\b.mp4'),
      );
      expect(service.requiresVideoSurface, isTrue);
    });

    test('retry after init failure re-attempts play', () async {
      var attempts = 0;
      final service = PlaybackService(
        mediaLocationResolver: _StubResolver(
          uriForPath: (_) => wav.fileUri.toString(),
        ),
        mediaKitInitOverride: (_, __, ___) async {
          attempts++;
          if (attempts == 1) {
            throw const SocketException('Simulated init failure');
          }
          // second attempt succeeds via manual ready simulation not reached
        },
      );

      await service.play(_audioItem(id: 'a-retry', path: wav.path));
      expect(service.playbackErrorKind, isNotNull);

      service.attachSessionControlsForTest(FakePlaybackSessionControls());
      await service.retry();
      expect(attempts, 2);
    });

    test('invalid local source sets file missing error', () async {
      final missingPath = r'C:\missing\gate0-track.mp3';
      final resolver = _StubResolver(
        uriForPath: (_) => Uri.file(missingPath).toString(),
      );
      final service = PlaybackService(mediaLocationResolver: resolver);

      await service.play(_audioItem(id: 'missing', path: missingPath));
      expect(service.playbackErrorKind, PlaybackErrorKind.fileMissing);
      expect(service.isReady, isFalse);
    });

    test('stop disposes session and clears current item', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      await service.play(_audioItem(id: 'a-stop', path: wav.path));
      await service.stop();
      expect(service.currentItem, isNull);
      expect(service.isReady, isFalse);
    });

    test('stop clears capability and ready state', () async {
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          subtitleTracks: [
            PlaybackSubtitleTrack(id: 's1', title: 'Sub'),
          ],
        ),
      );
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver, controls: fake);

      await service.play(_videoItem(id: 'v-tracks', path: r'C:\a.mkv'));
      expect(service.canSelectSubtitleTracks, isTrue);

      await service.stop();
      expect(service.isReady, isFalse);
      expect(service.availableSubtitleTracks, isEmpty);
    });

    test('audio playback does not write Continue Watching keys', () async {
      final resolver = _StubResolver(uriForPath: (_) => wav.fileUri.toString());
      final service = _serviceWithStubInit(resolver: resolver);
      final item = _audioItem(id: 'a-no-cw', path: wav.path);

      await service.play(item);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(seconds: 120),
        position: const Duration(seconds: 30),
      );
      service.runPlaybackTickForTest();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_a-no-cw'), isNull);
      expect(prefs.getInt('duration_a-no-cw'), isNull);
    });
  });

  group('MediaLocationResolver audio paths', () {
    test('resolves local Windows audio path to file URI', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      );
      final result = resolver.resolve(r'Y:\Music\Artist\Album\track.mp3');
      expect(result.isPlayable, isTrue);
      expect(result.uri, startsWith('file:'));
    });

    test('passes through HTTPS audio URL', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.defaults(),
        isWindowsDesktop: true,
      );
      const url = 'https://example.test/media/track.mp3';
      final result = resolver.resolve(url);
      expect(result.uri, url);
      expect(result.isPlayable, isTrue);
    });
  });
}
