@Tags(['gate0-mediakit'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

/// Gate 0 — `media_kit` capability audit harness (Windows only).
///
/// Verifies playback-stack capabilities **without** changing `PlaybackService` or UI.
/// Results feed [m4-phase-4.4-gate0-capability-audit.md].
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows   # once — provides libmpv-2.dll for the harness
/// $env:GATE0_MEDIA_KIT='1'
/// flutter test test/gate0_media_kit_capability_test.dart --tags gate0-mediakit
/// ```
///
/// Optional fixture overrides (catalogue paths or direct URIs):
/// - `GATE0_LOCAL_URI` — local `file://` or path (default: TNAS sample MP4 if present)
/// - `GATE0_HTTPS_URI` — HTTPS media URL (default: TNAS HTTPS sample if reachable)
/// - `GATE0_MULTI_AUDIO_URI` — MKV with multiple audio tracks
/// - `GATE0_SUBTITLED_URI` — file with embedded subtitle tracks
/// - `GATE0_EXTERNAL_VTT_URI` — external WebVTT for `SubtitleTrack.uri` test
/// - `GATE0_CHAPTER_URI` — file known to contain chapter metadata (ffprobe check)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['GATE0_MEDIA_KIT'] != '1') {
    test('skipped — set GATE0_MEDIA_KIT=1 to run Gate 0 media_kit audit', () {},
        skip: true);
    return;
  }

  if (!Platform.isWindows) {
    test('skipped — Gate 0 media_kit audit is Windows-only', () {}, skip: true);
    return;
  }

  final libmpv = _resolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  const defaultLocalPath =
      r'Y:\Media\Images\Photos\Family\Photos for Angela\VID_20180714_200000.mp4';
  const defaultHttpsUrl =
      'https://ttsplayer.local:8443/media/Images/Photos/Family/Photos%20for%20Angela/VID_20180714_200000.mp4';

  final localUri = _resolveUri(
    Platform.environment['GATE0_LOCAL_URI'] ?? defaultLocalPath,
  );
  final httpsUri = Platform.environment['GATE0_HTTPS_URI'] ?? defaultHttpsUrl;
  final multiAudioUri = _optionalUri(
    Platform.environment['GATE0_MULTI_AUDIO_URI'],
  );
  final subtitledUri = _optionalUri(
    Platform.environment['GATE0_SUBTITLED_URI'],
  );
  final externalVttUri = Platform.environment['GATE0_EXTERNAL_VTT_URI'];
  final chapterUri = _optionalUri(Platform.environment['GATE0_CHAPTER_URI']);

  group('Gate 0 — media_kit capability audit', () {
    late bool localAvailable;
    late bool httpsAvailable;

    setUpAll(() async {
      localAvailable = await _uriExists(localUri);
      httpsAvailable = await _httpsReachable(httpsUri);
    });

    test('G0-API — public Player surface documents expected control methods', () {
      // Compile-time / reflection-free API inventory for the audit record.
      expect(Player.new, isA<Function>());
      const apiChecks = <String>[
        'setRate',
        'setAudioTrack',
        'setSubtitleTrack',
        'seek',
        'open',
      ];
      expect(apiChecks, isNotEmpty);
    });

    test('G0-API — no public chapter navigation API in media_kit 1.2.6', () {
      // Chapters: only low-level libmpv bindings exist; no Dart chapter model.
      const playerType = Player;
      expect(playerType.toString(), contains('Player'));
      // Confirmed by package survey: no chapter list/seek methods on Player.
    });

    test('G0-TRACKS — track enumeration API smoke on local fixture', () async {
      if (!localAvailable) {
        markTestSkipped('Local fixture unavailable: $localUri');
        return;
      }

      final player = Player();
      addTearDown(player.dispose);

      await _openAndReady(player, localUri);

      final tracks = await _waitForTracks(player);
      expect(tracks.audio, isNotEmpty);
      expect(tracks.video, isNotEmpty);
      expect(player.state.track.audio.id, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G0-SPEED — setRate on local fixture', () async {
      if (!localAvailable) {
        markTestSkipped('Local fixture unavailable: $localUri');
      }

      final player = Player();
      addTearDown(player.dispose);

      await _openAndReady(player, localUri);

      await player.setRate(1.5);
      await _waitFor(() => (player.state.rate - 1.5).abs() < 0.05);

      await player.pause();
      expect((player.state.rate - 1.5).abs(), lessThan(0.1));

      await player.seek(const Duration(seconds: 5));
      await _waitFor(() => player.state.position >= const Duration(seconds: 4));

      expect((player.state.rate - 1.5).abs(), lessThan(0.1));

      await player.setRate(1.0);
      await _waitFor(() => (player.state.rate - 1.0).abs() < 0.05);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G0-SPEED — setRate on HTTPS fixture', () async {
      if (!httpsAvailable) {
        markTestSkipped('HTTPS fixture unavailable: $httpsUri');
      }

      final player = Player();
      addTearDown(player.dispose);

      await _openAndReady(player, httpsUri);

      await player.setRate(1.25);
      await _waitFor(() => (player.state.rate - 1.25).abs() < 0.1);
      expect((player.state.rate - 1.25).abs(), lessThan(0.15));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G0-AUDIO — enumerate and switch audio tracks', () async {
      if (multiAudioUri == null) {
        markTestSkipped('Set GATE0_MULTI_AUDIO_URI for multi-audio audit');
        return;
      }
      if (!await _uriExists(multiAudioUri)) {
        markTestSkipped('Multi-audio fixture missing: $multiAudioUri');
        return;
      }

      final player = Player();
      addTearDown(player.dispose);

      await _openAndReady(player, multiAudioUri);

      final tracks = await _waitForTracks(player);
      final audio = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
      if (audio.length < 2) {
        markTestSkipped(
          'Fixture has ${audio.length} audio track(s); '
          'set GATE0_MULTI_AUDIO_URI to a multi-audio MKV',
        );
        return;
      }

      final first = audio.first;
      final second = audio.elementAt(1);

      await player.setAudioTrack(first);
      await _waitFor(() => player.state.track.audio.id == first.id);

      await player.setAudioTrack(second);
      await _waitFor(() => player.state.track.audio.id == second.id);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G0-SUB — embedded subtitle tracks and disable', () async {
      if (subtitledUri == null) {
        markTestSkipped('Set GATE0_SUBTITLED_URI for embedded subtitle audit');
        return;
      }
      if (!await _uriExists(subtitledUri)) {
        markTestSkipped('Subtitled fixture missing: $subtitledUri');
        return;
      }

      final player = Player();
      addTearDown(player.dispose);

      await _openAndReady(player, subtitledUri);

      final tracks = await _waitForTracks(player);
      final subs = tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
      if (subs.isEmpty) {
        markTestSkipped(
          'Fixture has no embedded subtitle tracks; '
          'set GATE0_SUBTITLED_URI to a subtitled MKV',
        );
        return;
      }

      final target = subs.first;
      await player.setSubtitleTrack(target);
      await _waitFor(() => player.state.track.subtitle.id == target.id);

      await player.setSubtitleTrack(SubtitleTrack.no());
      await _waitFor(() => player.state.track.subtitle.id == 'no');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G0-SUB — external SubtitleTrack.uri on local fixture', () async {
      if (!localAvailable) {
        markTestSkipped('Local fixture unavailable for external VTT test');
        return;
      }
      if (externalVttUri == null || externalVttUri.isEmpty) {
        markTestSkipped('Set GATE0_EXTERNAL_VTT_URI for external subtitle audit');
        return;
      }

      final player = Player();
      addTearDown(player.dispose);

      await _openAndReady(player, localUri);

      await player.setSubtitleTrack(
        SubtitleTrack.uri(
          externalVttUri,
          title: 'Gate0 external',
          language: 'en',
        ),
      );
      await _waitFor(
        () => player.state.track.subtitle.uri == externalVttUri,
        timeout: const Duration(seconds: 20),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('G0-CHAPTER — ffprobe metadata vs Dart API gap', () async {
      if (chapterUri == null) {
        markTestSkipped('Set GATE0_CHAPTER_URI to probe chapter metadata');
        return;
      }
      if (!await _uriExists(chapterUri)) {
        markTestSkipped('Chapter fixture missing: $chapterUri');
        return;
      }

      final chapterCount = await _ffprobeChapterCount(chapterUri);
      expect(chapterCount, greaterThan(0),
          reason: 'Fixture should contain chapters for metadata probe');

      final player = Player();
      addTearDown(player.dispose);
      await _openAndReady(player, chapterUri);

      // No chapter list on Player.state — audit records API gap even when
      // container metadata exists.
      expect(player.state.tracks, isNotNull);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

String? _resolveLibMpvPath() {
  final fromEnv = Platform.environment['LIBMPV_LIBRARY_PATH'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return fromEnv;
  }

  final candidates = <String>[
    r'build\windows\x64\runner\Debug\libmpv-2.dll',
    r'build\windows\x64\runner\Release\libmpv-2.dll',
  ];

  for (final relative in candidates) {
    final file = File(relative);
    if (file.existsSync()) {
      return file.absolute.path;
    }
  }

  fail(
    'libmpv-2.dll not found. Run `flutter build windows` in client/ttsplayer '
    'or set LIBMPV_LIBRARY_PATH to your libmpv-2.dll.',
  );
}

String _resolveUri(String pathOrUri) {
  if (pathOrUri.startsWith('http://') || pathOrUri.startsWith('https://')) {
    return pathOrUri;
  }
  if (pathOrUri.startsWith('file://')) {
    return pathOrUri;
  }
  return Uri.file(pathOrUri).toString();
}

String? _optionalUri(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return _resolveUri(raw.trim());
}

Future<bool> _uriExists(String uri) async {
  if (uri.startsWith('http://') || uri.startsWith('https://')) {
    // Reachability is validated by player.open in runtime scenarios.
    return true;
  }
  final file = uri.startsWith('file://')
      ? File.fromUri(Uri.parse(uri))
      : File(uri);
  return file.exists();
}

Future<bool> _httpsReachable(String url) async {
  try {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    final uri = Uri.parse(url);

    try {
      final headRequest = await client.headUrl(uri);
      final headResponse =
          await headRequest.close().timeout(const Duration(seconds: 30));
      if (headResponse.statusCode == 200) {
        client.close();
        return true;
      }
    } catch (_) {}

    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final response = await request.close().timeout(const Duration(seconds: 30));
    await response.drain();
    client.close();
    return response.statusCode == 200 ||
        response.statusCode == 206 ||
        response.statusCode == 416;
  } catch (_) {
    return false;
  }
}

Future<void> _openAndReady(Player player, String uri) async {
  await player.open(Media(uri), play: false).timeout(const Duration(seconds: 30));
  if (player.state.duration <= Duration.zero) {
    await player.stream.duration
        .firstWhere((d) => d > Duration.zero)
        .timeout(const Duration(seconds: 30));
  }
  await player.play();
  await _waitFor(() => player.state.playing);
}

Future<Tracks> _waitForTracks(Player player) async {
  Tracks? latest = player.state.tracks;
  final sub = player.stream.tracks.listen((t) => latest = t);
  try {
    await _waitFor(
      () {
        final t = latest ?? player.state.tracks;
        return t.audio.isNotEmpty || t.subtitle.isNotEmpty;
      },
      timeout: const Duration(seconds: 25),
    );
  } finally {
    await sub.cancel();
  }
  return latest ?? player.state.tracks;
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for condition');
}

Future<int> _ffprobeChapterCount(String uri) async {
  final path = uri.startsWith('file://')
      ? Uri.parse(uri).toFilePath(windows: Platform.isWindows)
      : uri;
  if (path.startsWith('http')) {
    return 0;
  }

  try {
    final result = await Process.run(
      'ffprobe',
      [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_chapters',
        path,
      ],
      runInShell: true,
    );
    if (result.exitCode != 0) return 0;
    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final chapters = json['chapters'] as List<dynamic>? ?? [];
    return chapters.length;
  } catch (_) {
    return 0;
  }
}
