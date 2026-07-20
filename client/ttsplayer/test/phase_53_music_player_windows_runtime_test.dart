@Tags(['phase53-runtime'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:video_player/video_player.dart';

import 'support/audio_gate_fixtures.dart';

/// Windows single-track music player validation (M5.3 Step 1).
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows
/// $env:PHASE_53_RUNTIME='1'
/// flutter test test/phase_53_music_player_windows_runtime_test.dart --tags phase53-runtime
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_53_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_53_RUNTIME=1 to run Phase 5.3 music player runtime',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.3 music player runtime is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final libmpv = _resolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  group('Phase 5.3 Step 1 — MusicPlayerScreen runtime', () {
    late GeneratedAudioFixture wav;
    late PlaybackService service;
    late MediaItem track;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wav = await writeMonoWavFixture(duration: const Duration(seconds: 2));
      track = MediaItem(
        id: 'runtime-track',
        title: 'Runtime Track',
        filePath: wav.path,
        mediaKindRaw: 'audio',
        artist: 'Runtime Artist',
        album: 'Runtime Album',
        year: 2026,
        genre: 'Test',
      );
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

    testWidgets('single-track UI and transport', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<MediaLocationResolver>.value(
              value: MediaLocationResolver(
                config: MediaAccessConfig.development(),
                isWindowsDesktop: true,
              ),
            ),
            Provider<ArtworkService>.value(
              value: ArtworkService(fileExists: (_) => false),
            ),
            ChangeNotifierProvider<PlaybackService>.value(value: service),
          ],
          child: MaterialApp(
            home: MusicPlayerScreen(item: track),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Runtime Track'), findsWidgets);

      await _waitFor(() => service.isReady);
      await tester.pumpAndSettle();

      expect(find.text('Runtime Artist'), findsOneWidget);
      expect(find.text('Runtime Album'), findsOneWidget);
      expect(find.byType(Video), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.byIcon(Icons.shuffle), findsNothing);

      final playPause = find.byKey(const Key('music_player_play_pause'));
      await tester.scrollUntilVisible(playPause, 100);

      if (!service.isPlaying) {
        await tester.tap(playPause);
        await tester.pump();
      }
      expect(service.isPlaying, isTrue);

      await service.togglePlayPause();
      expect(service.isPlaying, isFalse);

      await service.togglePlayPause();
      await service.seekToPosition(const Duration(milliseconds: 500));
      await _waitFor(() => service.position >= const Duration(milliseconds: 400));

      await _waitFor(() => service.isCompleted, timeout: const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('music_player_completed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('music_player_replay')));
      await tester.pumpAndSettle();
      expect(service.isCompleted, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_${track.id}'), isNull);

      await service.stop();
      expect(service.currentItem, isNull);

      final video = MediaItem(
        id: 'runtime-video',
        title: 'Runtime Video',
        filePath: wav.path,
        mediaKindRaw: 'video',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<MediaLocationResolver>.value(
              value: MediaLocationResolver(
                config: MediaAccessConfig.development(),
                isWindowsDesktop: true,
              ),
            ),
            Provider<ArtworkService>.value(
              value: ArtworkService(fileExists: (_) => false),
            ),
            ChangeNotifierProvider<PlaybackService>.value(value: service),
          ],
          child: MaterialApp(
            home: PlayerScreen(item: video, autoPlay: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerScreen), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 3)));
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
