import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/services/playback/playback_error_messages.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:video_player/video_player.dart';

import 'support/music_catalog_fixtures.dart';
import 'support/music_playback_test_harness.dart';

MediaItem get _audioTrack => musicTrackComplete();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MusicPlayerScreen', () {
    testWidgets('renders track metadata and artwork placeholder', (tester) async {
      final service = PlaybackService();
      readyMusicPlayer(service, item: _audioTrack);
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
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
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_player_loading')), findsOneWidget);
      expect(find.text('Preparing track…'), findsOneWidget);
    });

    testWidgets('play and pause toggle', (tester) async {
      final service = PlaybackService();
      readyMusicPlayer(service, item: _audioTrack, playing: true);
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
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
      readyMusicPlayer(
        service,
        item: _audioTrack,
        duration: const Duration(minutes: 4),
      );
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
      await tester.pump();

      await service.seekTo(const Duration(minutes: 1));
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 1),
      );
      service.notifyListeners();
      await tester.pump();

      expect(find.byKey(const Key('music_player_elapsed')), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);
      expect(find.text('-03:00'), findsOneWidget);
    });

    testWidgets('completion shows replay', (tester) async {
      final service = PlaybackService();
      readyMusicPlayer(service, item: _audioTrack);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 4),
        completed: true,
      );
      service.notifyListeners();
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_player_completed')), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
      expect(find.byKey(const Key('music_player_replay')), findsOneWidget);
    });

    testWidgets('replay restarts playback', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      readyMusicPlayer(service, item: _audioTrack);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 4),
        position: const Duration(minutes: 4),
        completed: true,
      );
      service.notifyListeners();
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: _audioTrack,
          queueController: queue,
        ),
      );
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
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_player_error')), findsOneWidget);
      expect(
        find.text(PlaybackErrorMessages.forKind(PlaybackErrorKind.network)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('music_player_retry')), findsOneWidget);
    });

    testWidgets('excludes video surface and deferred queue features', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      readyMusicPlayer(service, item: _audioTrack, playing: true);
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: _audioTrack,
          queueController: queue,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Video), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('Subtitles'), findsNothing);
      expect(find.text('Audio track'), findsNothing);
      expect(find.byIcon(Icons.shuffle), findsNothing);
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.text('Queue'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('music_player_previous')),
        100,
      );
      expect(find.byKey(const Key('music_player_previous')), findsOneWidget);
      expect(find.byKey(const Key('music_player_next')), findsOneWidget);
    });

    testWidgets('one-item queue disables next and previous transport', (tester) async {
      final service = PlaybackService();
      readyMusicPlayer(
        service,
        item: _audioTrack,
        position: Duration.zero,
      );
      await tester.pumpWidget(
        musicPlayerScreenHarness(service, track: _audioTrack),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('music_player_previous')),
        100,
      );

      final previous = tester.widget<IconButton>(
        find.byKey(const Key('music_player_previous')),
      );
      final next = tester.widget<IconButton>(
        find.byKey(const Key('music_player_next')),
      );
      expect(previous.onPressed, isNull);
      expect(next.onPressed, isNull);
    });

    testWidgets('next updates metadata for multi-item queue', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      final tracks = [_audioTrack, musicTrackPartial()];
      queue.replaceQueue(tracks, startIndex: 1);
      queue.onPlayerRouteOpened();
      readyMusicPlayer(service, item: musicTrackPartial(), playing: true);
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: musicTrackPartial(),
          queueController: queue,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something'), findsWidgets);
      expect(find.byKey(const Key('music_player_queue_position')), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('previous updates metadata for multi-item queue', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      final tracks = [_audioTrack, musicTrackPartial()];
      queue.replaceQueue(tracks, startIndex: 0);
      queue.onPlayerRouteOpened();
      readyMusicPlayer(service, item: _audioTrack, playing: true);
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: _audioTrack,
          queueController: queue,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Come Together'), findsWidgets);
      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets('transport controls expose semantic labels', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      queue.replaceQueue([_audioTrack, musicTrackPartial()]);
      readyMusicPlayer(
        service,
        item: _audioTrack,
        playing: true,
        position: const Duration(seconds: 10),
      );
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: _audioTrack,
          queueController: queue,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('music_player_previous')),
        100,
      );

      expect(
        find.ancestor(
          of: find.byKey(const Key('music_player_previous')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Previous track',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('music_player_next')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Next track',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('music_player_play_pause')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Pause',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('leaving the screen stops playback and clears queue', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      readyMusicPlayer(service, item: _audioTrack, playing: true);
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: _audioTrack,
          queueController: queue,
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(service, queueController: queue),
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await queue.onPlayerRouteClosed();

      expect(service.currentItem, isNull);
      expect(service.isReady, isFalse);
      expect(queue.isEmpty, isTrue);
    });

    testWidgets('no state update after disposal', (tester) async {
      final service = PlaybackService();
      final queue = MusicPlaybackQueueController(playbackService: service);
      readyMusicPlayer(service, item: _audioTrack);
      await tester.pumpWidget(
        musicPlayerScreenHarness(
          service,
          track: _audioTrack,
          queueController: queue,
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(service, queueController: queue),
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      service.simulatePlayingForTest(playing: true);
      service.notifyListeners();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
