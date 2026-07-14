import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_audio_track.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/models/playback/playback_rate_presets.dart';
import 'package:ttsplayer/models/playback/playback_subtitle_track.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_access_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/resolved_media_location.dart';
import 'package:ttsplayer/services/playback/playback_error_messages.dart';
import 'package:ttsplayer/services/playback/playback_session_controls.dart';
import 'package:ttsplayer/services/playback/unsupported_session_controls.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'playback_service_extensions_test.dart';

class _StubResolver extends MediaLocationResolver {
  _StubResolver()
      : super(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        );

  @override
  ResolvedMediaLocation resolve(String cataloguePath) {
    return ResolvedMediaLocation.resolved(
      uri: Uri.file(cataloguePath).toString(),
      providerType: MediaAccessProviderType.localFile,
    );
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testItem = MediaItem(
  id: 'item-1',
  title: 'Test Movie',
  filePath: r'C:\media\test.mp4',
);

PlaybackSessionSnapshot _richSnapshot({
  double rate = 1.25,
  String? selectedAudio = 'a1',
  String? selectedSubtitle,
}) {
  return PlaybackSessionSnapshot(
    playbackRate: rate,
    audioTracks: const [
      PlaybackAudioTrack(id: 'a1', language: 'English'),
      PlaybackAudioTrack(id: 'a2'),
    ],
    subtitleTracks: const [
      PlaybackSubtitleTrack(id: 's1', language: 'English'),
      PlaybackSubtitleTrack(
        id: 's2',
        title:
            'Very long subtitle track label that should not overflow the menu width when ellipsized',
      ),
    ],
    selectedAudioTrackId: selectedAudio,
    selectedSubtitleTrackId: selectedSubtitle,
  );
}

Widget _playerHarness(
  PlaybackService service, {
  MediaItem item = _testItem,
  String initialRoute = '/player',
}) {
  return ChangeNotifierProvider<PlaybackService>.value(
    value: service,
    child: MaterialApp(
      initialRoute: initialRoute,
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/player': (_) => PlayerScreen(item: item, autoPlay: false),
      },
    ),
  );
}

Widget _stackedPlayerHarness(PlaybackService service) {
  return ChangeNotifierProvider<PlaybackService>.value(
    value: service,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider<PlaybackService>.value(
                  value: service,
                  child: const PlayerScreen(item: _testItem, autoPlay: false),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void _readyPlayer(
  PlaybackService service, {
  PlaybackSessionSnapshot? snapshot,
  FakePlaybackSessionControls? controls,
}) {
  if (controls != null) {
    if (snapshot != null) controls.setSnapshot(snapshot);
    service.attachSessionControlsForTest(controls);
  } else if (service.sessionControls is FakePlaybackSessionControls) {
    final fake = service.sessionControls! as FakePlaybackSessionControls;
    if (snapshot != null) fake.setSnapshot(snapshot);
    service.attachSessionControlsForTest(fake);
  } else if (service.sessionControls is! UnsupportedSessionControls) {
    final fake = FakePlaybackSessionControls(snapshot: snapshot ?? _richSnapshot());
    service.attachSessionControlsForTest(fake);
  }

  service.simulateReadyForTest(_testItem);
  service.simulatePlaybackMetricsForTest(
    duration: const Duration(minutes: 90),
    position: const Duration(minutes: 10),
  );
}

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 420);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<String> _tempMediaFile() async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_player_screen_');
  final file = File('${dir.path}/sample.mp4');
  await file.writeAsBytes([0, 1, 2, 3]);
  return file.path;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('speed control', () {
    testWidgets('1 speed hidden when unsupported', (tester) async {
      final service = PlaybackService(
        initialSessionControls: UnsupportedSessionControls(),
      );
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('1×'), findsNothing);
      expect(find.text('1.25×'), findsNothing);
    });

    testWidgets('2 speed shows current service rate', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service, snapshot: _richSnapshot(rate: 1.5));
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('1.5×'), findsOneWidget);
    });

    testWidgets('3 selecting speed calls PlaybackService', (tester) async {
      final fake = FakePlaybackSessionControls(snapshot: _richSnapshot());
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('1.25×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2×').last);
      await tester.pumpAndSettle();

      expect(fake.lastRequestedRate, 2.0);
      expect(fake.setRateCallCount, greaterThan(0));
    });

    testWidgets('4 speed action failure shows non-fatal feedback', (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: _richSnapshot(),
        rateApplyFails: true,
      );
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('1.25×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2×').last);
      await tester.pumpAndSettle();

      expect(find.text('Playback speed could not be changed.'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('5 saved default is not modified by PlayerScreen', (tester) async {
      final settings = SettingsRepository();
      await settings.load();
      await settings.saveDefaultPlaybackRate(1.5);

      final fake = FakePlaybackSessionControls(snapshot: _richSnapshot(rate: 1.5));
      final service = PlaybackService(
        initialSessionControls: fake,
        defaultPlaybackRateProvider: () => settings.defaultPlaybackRate,
      );
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2×').last);
      await tester.pumpAndSettle();

      expect(settings.defaultPlaybackRate, 1.5);
      expect(service.hasSessionRateOverride, isTrue);
    });
  });

  group('audio track menu', () {
    testWidgets('6 audio hidden for zero or one track', (tester) async {
      final service = PlaybackService();
      _readyPlayer(
        service,
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [PlaybackAudioTrack(id: 'a1')],
        ),
      );
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('Audio'), findsNothing);
    });

    testWidgets('7 multiple audio tracks show friendly labels', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Audio 2'), findsOneWidget);
      expect(find.textContaining('a2'), findsNothing);
    });

    testWidgets('8 selected audio track is marked', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      final selectedRow = find.ancestor(
        of: find.text('English'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: selectedRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('9 selecting audio invokes service API', (tester) async {
      final fake = FakePlaybackSessionControls(snapshot: _richSnapshot());
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio 2'));
      await tester.pumpAndSettle();

      expect(fake.lastAudioTrackId, 'a2');
    });
  });

  group('subtitle track menu', () {
    testWidgets('10 subtitle selector shows Off', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Subtitles'));
      await tester.pumpAndSettle();

      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('11 Off selected when subtitles disabled', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service, snapshot: _richSnapshot(selectedSubtitle: null));
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Subtitles'));
      await tester.pumpAndSettle();

      final offRow = find.ancestor(
        of: find.text('Off'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: offRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('12 selecting subtitle invokes service API', (tester) async {
      final fake = FakePlaybackSessionControls(snapshot: _richSnapshot());
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Subtitles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(fake.lastSubtitleTrackId, 's1');
    });

    testWidgets('13 disable subtitles invokes service API', (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: _richSnapshot(selectedSubtitle: 's1'),
      );
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Subtitles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();

      expect(fake.disableSubtitlesCalled, isTrue);
    });

    testWidgets('14 track action failure does not replace player content',
        (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: _richSnapshot(),
        audioSelectFails: true,
      );
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio 2'));
      await tester.pumpAndSettle();

      expect(find.text('Audio track could not be changed.'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text(PlaybackErrorMessages.forKind(PlaybackErrorKind.unknown)),
          findsNothing);
    });
  });

  group('track lifecycle', () {
    testWidgets('15 tracks reset when new media begins', (tester) async {
      final fake = FakePlaybackSessionControls(snapshot: _richSnapshot());
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();
      expect(find.text('Audio'), findsOneWidget);

      fake.setSnapshot(const PlaybackSessionSnapshot(playbackRate: 1.0));
      service.attachSessionControlsForTest(fake);
      await tester.pump();

      expect(find.text('Audio'), findsNothing);
    });

    testWidgets('16 preparing state does not show stale tracks', (tester) async {
      final fake = FakePlaybackSessionControls(snapshot: _richSnapshot());
      final service = PlaybackService(initialSessionControls: fake);
      service.simulatePreparingForTest();
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('Audio'), findsNothing);
      expect(find.text('Preparing video…'), findsOneWidget);
    });
  });

  group('keyboard shortcuts', () {
    testWidgets('17 space toggles play pause', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlayingForTest(playing: true);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(service.isPlaying, isFalse);
    });

    testWidgets('18 left arrow seeks minus 10 seconds', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(service.position, const Duration(minutes: 9, seconds: 50));
    });

    testWidgets('19 right arrow seeks plus 30 seconds', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(service.position, const Duration(minutes: 10, seconds: 30));
    });

    testWidgets('20 rate shortcuts change presets when supported',
        (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: _richSnapshot(rate: 1.0),
      );
      final service = PlaybackService(initialSessionControls: fake);
      _readyPlayer(service, controls: fake);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.pumpAndSettle();

      expect(fake.lastRequestedRate, 1.25);
    });

    testWidgets('21 unsupported rate shortcuts are safe', (tester) async {
      final service = PlaybackService(
        initialSessionControls: UnsupportedSessionControls(),
      );
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.pump();

      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
    });

    testWidgets('22 shortcuts ignored while menu owns focus', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlayingForTest(playing: true);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(service.isPlaying, isTrue);
    });

    testWidgets('23 escape stops and pops route', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_stackedPlayerHarness(service));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('24 shortcut interaction reveals controls', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlayingForTest(playing: true);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.byType(AspectRatio));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 5));

      final hiddenOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(hiddenOpacity.opacity, 0.0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));

      final shownOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(shownOpacity.opacity, 1.0);
    });
  });

  group('layout and menus', () {
    testWidgets('25 controls remain visible while menu is open', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlayingForTest(playing: true);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(opacity.opacity, 1.0);
    });

    testWidgets('26 controls fit at 900x420', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await _setCompactViewport(tester);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('27 long track labels do not overflow', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Subtitles'));
      await tester.pumpAndSettle();

      final longLabel = find.textContaining('Very long subtitle');
      expect(longLabel, findsOneWidget);
      final text = tester.widget<Text>(longLabel);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('error presentation', () {
    testWidgets('28 resolver error copy is correct', (tester) async {
      final service = PlaybackService();
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.resolverFailed,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.resolverFailed),
      );
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(
        find.text(PlaybackErrorMessages.forKind(PlaybackErrorKind.resolverFailed)),
        findsOneWidget,
      );
      expect(
        find.textContaining('Provider Status'),
        findsOneWidget,
      );
    });

    testWidgets('29 missing file error copy is correct', (tester) async {
      final service = PlaybackService();
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.fileMissing,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.fileMissing),
      );
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(
        find.text(PlaybackErrorMessages.forKind(PlaybackErrorKind.fileMissing)),
        findsOneWidget,
      );
    });

    testWidgets('30 tls network http timeout messages are distinct', (tester) async {
      final kinds = [
        PlaybackErrorKind.network,
        PlaybackErrorKind.tls,
        PlaybackErrorKind.httpNotFound,
        PlaybackErrorKind.timeout,
      ];
      for (final kind in kinds) {
        final service = PlaybackService();
        service.setPlaybackErrorForTest(
          kind,
          PlaybackErrorMessages.forKind(kind),
        );
        await tester.pumpWidget(_playerHarness(service));
        await tester.pump();

        expect(find.text(PlaybackErrorMessages.forKind(kind)), findsOneWidget);
      }
    });

    testWidgets('31 unsupported format copy is correct', (tester) async {
      final service = PlaybackService();
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.unsupportedFormat,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.unsupportedFormat),
      );
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(
        find.text(
          PlaybackErrorMessages.forKind(PlaybackErrorKind.unsupportedFormat),
        ),
        findsOneWidget,
      );
    });

    test('32 retry invokes existing service retry', () async {
      final mediaPath = await _tempMediaFile();
      final item = MediaItem(
        id: 'item-1',
        title: 'Test Movie',
        filePath: mediaPath,
      );
      var initCount = 0;
      final service = PlaybackService(
        mediaLocationResolver: _StubResolver(),
        mediaKitInitOverride: (s, uri, generation) async {
          initCount++;
          final fake = FakePlaybackSessionControls(snapshot: _richSnapshot());
          s.attachSessionControlsForTest(fake);
          s.simulateReadyForTest(item);
        },
      );

      await service.play(item);
      expect(initCount, 1);

      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );
      await service.retry();
      expect(initCount, 2);
      expect(service.errorMessage, isNull);
    });

    testWidgets('32b error view exposes Try Again action', (tester) async {
      final service = PlaybackService();
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('33 go back pops the route', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_stackedPlayerHarness(service));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Go Back'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
    });
  });

  group('completion and resume regression', () {
    testWidgets('34 completed state offers Watch Again', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 90),
        position: const Duration(minutes: 90),
        completed: true,
      );
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('Watch Again'), findsOneWidget);
    });

    testWidgets('35 watch again seeks to zero and plays', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 90),
        position: const Duration(minutes: 90),
        completed: true,
      );
      service.simulatePlayingForTest(playing: false);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('Watch Again'));
      await tester.pump();

      expect(service.position, Duration.zero);
      expect(service.isPlaying, isTrue);
    });

    test('36 item detail resume label unchanged', () async {
      final playback = PlaybackService();
      await playback.persistResumeStateForTest(
        _testItem.id,
        const Duration(minutes: 2),
        duration: const Duration(hours: 1),
      );
      final info = await playback.resumeInfoFor(_testItem.id);
      expect(info!.shouldOffer, isTrue);
      expect('Resume from ${info.formattedPosition}', 'Resume from 02:00');

      final source =
          File('lib/screens/item_detail_screen.dart').readAsStringSync();
      expect(source, contains('Resume from \${resume.formattedPosition}'));
    });

    test('37 item detail start from beginning unchanged', () {
      final source =
          File('lib/screens/item_detail_screen.dart').readAsStringSync();
      expect(source, contains("'Start from beginning'"));
    });
  });

  group('transport and platform safety', () {
    testWidgets('38 seek slider and buttons remain functional', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();
      expect(service.position, const Duration(minutes: 9, seconds: 50));

      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.pump();
      expect(service.position, const Duration(minutes: 10, seconds: 20));
    });

    testWidgets('39 auto-hide timer does not hide open menus', (tester) async {
      final service = PlaybackService();
      _readyPlayer(service);
      service.simulatePlayingForTest(playing: true);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      await tester.tap(find.text('1.25×'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('2×'), findsWidgets);
    });

    testWidgets('41 non-Windows backend hides unsupported controls', (tester) async {
      final service = PlaybackService(
        initialSessionControls: UnsupportedSessionControls(),
      );
      _readyPlayer(service);
      await tester.pumpWidget(_playerHarness(service));
      await tester.pump();

      expect(find.text('Audio'), findsNothing);
      expect(find.text('Subtitles'), findsNothing);
      expect(find.text('1×'), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  test('40 player screen does not import media_kit Player API', () {
    final source = File('lib/screens/player_screen.dart').readAsStringSync();
    expect(source.contains("package:media_kit/media_kit.dart"), isFalse);
    expect(source.contains('package:media_kit_video/media_kit_video.dart'), isTrue);
  });
}
