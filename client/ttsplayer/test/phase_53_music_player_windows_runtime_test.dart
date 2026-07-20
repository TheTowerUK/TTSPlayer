@Tags(['phase53-runtime'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:video_player/video_player.dart';

import 'support/audio_gate_fixtures.dart';
import 'support/music_playback_test_harness.dart';

/// Windows music queue validation (M5.3 Step 2).
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

  group('Phase 5.3 Step 2 — music queue runtime', () {
    late GeneratedAudioFixture wav1;
    late GeneratedAudioFixture wav2;
    late GeneratedAudioFixture wav3;
    late PlaybackService service;
    late MusicPlaybackQueueController queue;
    late List<MediaItem> tracks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wav1 = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'queue_track_1',
      );
      wav2 = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'queue_track_2',
      );
      wav3 = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'queue_track_3',
      );
      tracks = [
        MediaItem(
          id: 'runtime-track-1',
          title: 'Runtime Track One',
          filePath: wav1.path,
          mediaKindRaw: 'audio',
          artist: 'Runtime Artist',
          album: 'Runtime Album',
        ),
        MediaItem(
          id: 'runtime-track-2',
          title: 'Runtime Track Two',
          filePath: wav2.path,
          mediaKindRaw: 'audio',
          artist: 'Runtime Artist',
          album: 'Runtime Album',
        ),
        MediaItem(
          id: 'runtime-track-3',
          title: 'Runtime Track Three',
          filePath: wav3.path,
          mediaKindRaw: 'audio',
          artist: 'Runtime Artist',
          album: 'Runtime Album',
        ),
      ];
      service = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        ),
      );
      queue = MusicPlaybackQueueController(playbackService: service);
    });

    tearDown(() async {
      await service.stop();
    });

    testWidgets('three-track queue transport and lifecycle', (tester) async {
      queue.replaceQueue(tracks);

      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(service, queueController: queue),
          child: const MaterialApp(home: MusicPlayerScreen()),
        ),
      );
      await tester.pump();

      queue.onPlayerRouteOpened();
      await queue.playCurrent();
      await _waitFor(() => service.isReady);
      await tester.pumpAndSettle();

      expect(find.text('Runtime Track One'), findsWidgets);
      expect(find.text('1 of 3'), findsOneWidget);

      final next = find.byKey(const Key('music_player_next'));
      await tester.scrollUntilVisible(next, 100);
      await tester.tap(next);
      await _waitFor(() => service.currentItem?.id == 'runtime-track-2');
      await tester.pumpAndSettle();

      expect(find.text('Runtime Track Two'), findsWidgets);
      expect(find.text('2 of 3'), findsOneWidget);

      await service.seekToPosition(const Duration(milliseconds: 500));
      await _waitFor(() => service.position >= const Duration(milliseconds: 400));

      final previous = find.byKey(const Key('music_player_previous'));
      await tester.scrollUntilVisible(previous, 100);
      await tester.tap(previous);
      await _waitFor(() => service.currentItem?.id == 'runtime-track-1');
      await tester.pumpAndSettle();
      expect(find.text('Runtime Track One'), findsWidgets);

      await queue.next();
      await queue.next();
      await _waitFor(() => service.currentItem?.id == 'runtime-track-3');
      await tester.pumpAndSettle();
      expect(find.text('Runtime Track Three'), findsWidgets);

      await _waitFor(() => service.isCompleted, timeout: const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('music_player_completed')), findsOneWidget);
      expect(queue.currentTrack?.id, 'runtime-track-3');

      final prefs = await SharedPreferences.getInstance();
      for (final track in tracks) {
        expect(prefs.getInt('position_${track.id}'), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(service.currentItem, isNull);
      expect(queue.isEmpty, isTrue);

      final video = MediaItem(
        id: 'runtime-video',
        title: 'Runtime Video',
        filePath: wav1.path,
        mediaKindRaw: 'video',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(service, queueController: queue),
          child: MaterialApp(home: PlayerScreen(item: video, autoPlay: false)),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(queue.isEmpty, isTrue);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('one-item queue disables next and previous', (tester) async {
      queue.seedSingleTrack(tracks.first);
      queue.onPlayerRouteOpened();
      await queue.playCurrent();
      await _waitFor(() => service.isReady);

      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(service, queueController: queue),
          child: const MaterialApp(home: MusicPlayerScreen(autoPlay: false)),
        ),
      );
      await tester.pumpAndSettle();

      final previous = tester.widget<IconButton>(
        find.byKey(const Key('music_player_previous')),
      );
      final next = tester.widget<IconButton>(
        find.byKey(const Key('music_player_next')),
      );
      expect(previous.onPressed, isNull);
      expect(next.onPressed, isNull);
      expect(find.text('1 of 3'), findsNothing);

      expect(find.byType(Video), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byIcon(Icons.shuffle), findsNothing);
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
