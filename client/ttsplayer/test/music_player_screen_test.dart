import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/services/playback/playback_error_messages.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:video_player/video_player.dart';

import 'support/music_catalog_fixtures.dart';

MediaItem get _audioTrack => musicTrackComplete();

_playerTestProviders(PlaybackService service) {
  return [
    Provider<MediaLocationResolver>.value(
      value: MediaLocationResolver(
        config: MediaAccessConfig.defaults(),
        isWindowsDesktop: false,
      ),
    ),
    Provider<ArtworkService>.value(
      value: ArtworkService(fileExists: (_) => false),
    ),
    ChangeNotifierProvider<PlaybackService>.value(value: service),
  ];
}

Widget _musicPlayerHarness(
  PlaybackService service, {
  MediaItem? item,
}) {
  final track = item ?? musicTrackComplete();
  return MultiProvider(
    providers: _playerTestProviders(service),
    child: MaterialApp(
      home: MusicPlayerScreen(item: track, autoPlay: false),
    ),
  );
}

void _readyMusicPlayer(
  PlaybackService service, {
  MediaItem? item,
  Duration position = Duration.zero,
  Duration duration = const Duration(minutes: 4),
  bool playing = false,
}) {
  final track = item ?? musicTrackComplete();
  service.simulateReadyForTest(track);
  service.simulatePlaybackMetricsForTest(
    duration: duration,
    position: position,
    completed: false,
  );
  service.simulatePlayingForTest(playing: playing);
  service.notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlayerScreen', () {
    testWidgets('renders track metadata and artwork placeholder', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service);
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      expect(find.byKey(const Key('music_player_screen')), findsOneWidget);
      expect(find.text('Come Together'), findsWidgets);
      expect(find.text('The Beatles'), findsOneWidget);
      expect(find.text('Abbey Road'), findsOneWidget);
      expect(find.textContaining('Rock'), findsOneWidget);
      expect(find.byType(MusicPlayerScreen), findsOneWidget);
    });

    testWidgets('shows loading state while preparing', (tester) async {
      final service = PlaybackService();
      service.simulatePreparingForTest();
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      expect(find.byKey(const Key('music_player_loading')), findsOneWidget);
      expect(find.text('Preparing track…'), findsOneWidget);
    });

    testWidgets('play and pause toggle', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service, playing: true);
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      final playPause = find.byKey(const Key('music_player_play_pause'));
      await tester.scrollUntilVisible(playPause, 100);

      await tester.tap(playPause);
      await tester.pump();
      expect(service.isPlaying, isFalse);

      await tester.tap(playPause);
      await tester.pump();
      expect(service.isPlaying, isTrue);
    });

    testWidgets('seek updates elapsed and remaining labels', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(
        service,
        duration: const Duration(minutes: 4),
        position: Duration.zero,
      );
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      await service.seekTo(const Duration(minutes: 1));
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 1),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_player_elapsed')), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);
      expect(find.text('-03:00'), findsOneWidget);
    });

    testWidgets('completion shows replay', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 4),
        completed: true,
      );
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      expect(find.byKey(const Key('music_player_completed')), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
      expect(find.byKey(const Key('music_player_replay')), findsOneWidget);
    });

    testWidgets('replay restarts playback', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 4),
        completed: true,
      );
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      await tester.tap(find.byKey(const Key('music_player_replay')));
      await tester.pump();

      expect(service.isCompleted, isFalse);
      expect(service.isPlaying, isTrue);
    });

    testWidgets('recoverable error shows retry', (tester) async {
      final service = PlaybackService();
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      expect(find.byKey(const Key('music_player_error')), findsOneWidget);
      expect(
        find.text(PlaybackErrorMessages.forKind(PlaybackErrorKind.network)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('music_player_retry')), findsOneWidget);
    });

    testWidgets('excludes video surface and video-only controls', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service, playing: true);
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      expect(find.byType(Video), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('Subtitles'), findsNothing);
      expect(find.text('Audio track'), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.shuffle), findsNothing);
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.text('Queue'), findsNothing);
    });

    testWidgets('leaving the screen stops playback', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service, playing: true);
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: _playerTestProviders(service),
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      expect(service.currentItem, isNull);
      expect(service.isReady, isFalse);
    });

    testWidgets('no state update after disposal', (tester) async {
      final service = PlaybackService();
      _readyMusicPlayer(service);
      await tester.pumpWidget(_musicPlayerHarness(service));
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: _playerTestProviders(service),
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      service.simulatePlayingForTest(playing: true);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
