import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
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
import 'package:ttsplayer/services/playback/playback_error_mapper.dart';
import 'package:ttsplayer/services/playback/playback_error_messages.dart';
import 'package:ttsplayer/services/playback/playback_session_controls.dart';
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

const _itemA = MediaItem(
  id: 'item-a',
  title: 'Movie A',
  filePath: r'C:\media\a.mp4',
);

const _itemB = MediaItem(
  id: 'item-b',
  title: 'Movie B',
  filePath: r'C:\media\b.mp4',
);

Future<String> _tempMediaFile(String name) async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_integration_');
  final file = File('${dir.path}/$name');
  await file.writeAsBytes([0, 1, 2, 3]);
  return file.path;
}

PlaybackService _wiredService({
  required SettingsRepository settings,
  required FakePlaybackSessionControls controls,
  required MediaItem item,
}) {
  final resolver = _StubResolver();

  return PlaybackService(
    mediaLocationResolver: resolver,
    defaultPlaybackRateProvider: () => settings.defaultPlaybackRate,
    mediaKitInitOverride: (service, uri, generation) async {
      controls.resetSelectionForNewMedia();
      service.attachSessionControlsForTest(controls);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(hours: 1),
        position: const Duration(minutes: 5),
      );
      final current = service.currentItem ?? item;
      service.simulateReadyForTest(current);
    },
  );
}

Widget _playerHarness(PlaybackService service, MediaItem item) {
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
                  child: PlayerScreen(item: item, autoPlay: false),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('playback-rate lifecycle', () {
    test('saved default applies on first media', () async {
      final path = await _tempMediaFile('first.mp4');
      final settings = SettingsRepository();
      await settings.load();
      await settings.saveDefaultPlaybackRate(1.5);

      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      final fake = FakePlaybackSessionControls();
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: item,
      );

      await service.play(item);

      expect(fake.lastRequestedRate, 1.5);
      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isFalse);
    });

    test('session override survives pause and seek', () async {
      final path = await _tempMediaFile('pause.mp4');
      final settings = SettingsRepository();
      await settings.load();
      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(playbackRate: 1.0),
      );
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: item,
      );
      await service.play(item);

      await service.setPlaybackRate(1.25);
      await service.togglePlayPause();
      await service.seekTo(const Duration(minutes: 6));

      expect(service.playbackRate, 1.25);
      expect(service.hasSessionRateOverride, isTrue);
    });

    test('new media resets to latest saved default', () async {
      final pathA = await _tempMediaFile('a.mp4');
      final pathB = await _tempMediaFile('b.mp4');
      final settings = SettingsRepository();
      await settings.load();
      await settings.saveDefaultPlaybackRate(1.5);

      final itemA = MediaItem(id: 'item-a', title: 'Movie A', filePath: pathA);
      final itemB = MediaItem(id: 'item-b', title: 'Movie B', filePath: pathB);
      final fake = FakePlaybackSessionControls();
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: itemA,
      );

      await service.play(itemA);
      await service.setPlaybackRate(2.0);
      expect(service.hasSessionRateOverride, isTrue);

      await service.play(itemB);
      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isFalse);
    });

    test('retry applies latest saved default', () async {
      final path = await _tempMediaFile('retry.mp4');
      final settings = SettingsRepository();
      await settings.load();
      await settings.saveDefaultPlaybackRate(1.25);

      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      final fake = FakePlaybackSessionControls();
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: item,
      );

      await service.play(item);
      await service.setPlaybackRate(2.0);
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );

      await service.retry();
      expect(service.errorMessage, isNull);
      expect(service.playbackRate, 1.25);
      expect(service.hasSessionRateOverride, isFalse);
    });

    test('backend rejection leaves prior session rate intact', () async {
      final path = await _tempMediaFile('reject.mp4');
      final settings = SettingsRepository();
      await settings.load();
      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(playbackRate: 1.0),
      );
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: item,
      );
      await service.play(item);

      await service.setPlaybackRate(1.25);
      fake.rateApplyFails = true;
      final result = await service.setPlaybackRate(2.0);

      expect(result.isSuccess, isFalse);
      expect(service.playbackRate, 1.25);
    });

    testWidgets('watch again retains session playback rate', (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(playbackRate: 1.5),
      );
      final service = PlaybackService(initialSessionControls: fake);
      service.attachSessionControlsForTest(fake);
      service.simulateReadyForTest(_itemA);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 90),
        position: const Duration(minutes: 90),
        completed: true,
      );
      service.simulatePlayingForTest(playing: false);
      await service.setPlaybackRate(1.5);

      await tester.pumpWidget(_playerHarness(service, _itemA));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Watch Again'));
      await tester.pump();

      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isTrue);
      expect(service.position, Duration.zero);
      expect(service.isPlaying, isTrue);
    });
  });

  group('track state coherence', () {
    test('stale selected audio id is cleared on sync', () {
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [PlaybackAudioTrack(id: 'a1', language: 'eng')],
          selectedAudioTrackId: 'stale-id',
        ),
      );
      final service = PlaybackService(initialSessionControls: fake);
      service.attachSessionControlsForTest(fake);

      expect(service.selectedAudioTrackId, isNull);
    });

    test('retry repopulates tracks without stale ids', () async {
      final path = await _tempMediaFile('tracks.mp4');
      final settings = SettingsRepository();
      await settings.load();

      final fake = FakePlaybackSessionControls(
        snapshot: PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: const [
            PlaybackAudioTrack(id: 'old-a1', language: 'eng'),
            PlaybackAudioTrack(id: 'old-a2'),
          ],
          subtitleTracks: const [
            PlaybackSubtitleTrack(id: 'old-s1', language: 'eng'),
          ],
          selectedAudioTrackId: 'old-a2',
          selectedSubtitleTrackId: 'old-s1',
        ),
      );

      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: item,
      );

      await service.play(item);
      expect(service.availableAudioTracks.length, 2);

      fake.setSnapshot(
        const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [
            PlaybackAudioTrack(id: 'new-a1', language: 'fra'),
            PlaybackAudioTrack(id: 'new-a2'),
          ],
          subtitleTracks: [PlaybackSubtitleTrack(id: 'new-s1')],
          selectedAudioTrackId: 'new-a1',
        ),
      );
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );

      await service.retry();
      service.attachSessionControlsForTest(fake);

      expect(service.availableAudioTracks.first.id, 'new-a1');
      expect(service.selectedAudioTrackId, isNull);
      expect(
        service.availableAudioTracks.any((track) => track.id == 'old-a1'),
        isFalse,
      );
    });

    testWidgets('duplicate labels still select by track id', (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [
            PlaybackAudioTrack(id: 'a1', language: 'English'),
            PlaybackAudioTrack(id: 'a2'),
          ],
          selectedAudioTrackId: 'a1',
        ),
      );
      final service = PlaybackService(initialSessionControls: fake);
      service.attachSessionControlsForTest(fake);
      service.simulateReadyForTest(_itemA);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 90),
        position: const Duration(minutes: 10),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<PlaybackService>.value(
          value: service,
          child: MaterialApp(
            home: PlayerScreen(item: _itemA, autoPlay: false),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio 2'));
      await tester.pumpAndSettle();

      expect(fake.lastAudioTrackId, 'a2');
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('keyboard and menu interaction', () {
    testWidgets('escape closes open menu before exiting player', (tester) async {
      final fake = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [
            PlaybackAudioTrack(id: 'a1', language: 'English'),
            PlaybackAudioTrack(id: 'a2'),
          ],
        ),
      );
      final service = PlaybackService(initialSessionControls: fake);
      service.attachSessionControlsForTest(fake);
      service.simulateReadyForTest(_itemA);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(minutes: 90),
        position: const Duration(minutes: 10),
      );

      await tester.pumpWidget(_playerHarness(service, _itemA));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      expect(find.text('Audio 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('open'), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('error taxonomy', () {
    test('all PlaybackErrorKind values have non-empty user copy', () {
      for (final kind in PlaybackErrorKind.values) {
        final message = PlaybackErrorMessages.forKind(kind);
        expect(message.trim(), isNotEmpty, reason: kind.name);
      }
    });

    test('mapper assigns expected kinds', () {
      expect(
        PlaybackErrorMapper.fileMissing().kind,
        PlaybackErrorKind.fileMissing,
      );
      expect(
        PlaybackErrorMapper.fromException(
          Exception('SocketException: connection refused'),
        ).kind,
        PlaybackErrorKind.network,
      );
      expect(
        PlaybackErrorMapper.fromException(
          Exception('HandshakeException: CERTIFICATE_VERIFY_FAILED'),
        ).kind,
        PlaybackErrorKind.tls,
      );
    });

    test('retry clears obsolete fatal error while preparing', () async {
      final path = await _tempMediaFile('err.mp4');
      final settings = SettingsRepository();
      await settings.load();
      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      final fake = FakePlaybackSessionControls();
      final service = _wiredService(
        settings: settings,
        controls: fake,
        item: item,
      );

      await service.play(item);
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );
      expect(service.playbackErrorKind, PlaybackErrorKind.network);

      final retryFuture = service.retry();
      expect(service.errorMessage, isNull);
      await retryFuture;
      expect(service.playbackErrorKind, isNull);
      expect(service.isReady, isTrue);
    });

    test('failed retry surfaces new mapped error', () async {
      final path = await _tempMediaFile('fail.mp4');
      final settings = SettingsRepository();
      await settings.load();

      final item = MediaItem(id: 'item-a', title: 'Movie A', filePath: path);
      var attempt = 0;
      final service = PlaybackService(
        mediaLocationResolver: _StubResolver(),
        defaultPlaybackRateProvider: () => settings.defaultPlaybackRate,
        mediaKitInitOverride: (s, uri, generation) async {
          attempt++;
          if (attempt == 1) {
            s.simulateReadyForTest(item);
            return;
          }
          throw Exception('SocketException: connection refused');
        },
      );

      await service.play(item);
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.timeout,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.timeout),
      );

      await service.retry();
      expect(service.playbackErrorKind, PlaybackErrorKind.network);
      expect(
        service.errorMessage,
        PlaybackErrorMessages.forKind(PlaybackErrorKind.network),
      );
    });
  });

  group('resume and progress regression', () {
    test('resume eligibility thresholds unchanged', () {
      expect(ResumeInfo.minResumePosition, const Duration(seconds: 30));
      expect(ResumeInfo.nearEndWindow, const Duration(minutes: 2));
    });

    test('completion clears eligible saved progress', () async {
      final service = PlaybackService();
      await service.persistResumeStateForTest(
        'item-a',
        const Duration(minutes: 10),
        duration: const Duration(hours: 1),
      );

      service.simulateReadyForTest(_itemA);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(hours: 1),
        completed: true,
      );
      service.runPlaybackTickForTest();

      final info = await service.resumeInfoFor('item-a');
      expect(info, isNull);
    });

    test('continue watching remains eligibility-based', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-a': 120,
        'duration_item-a': 3600,
        'position_item-b': 10,
        'duration_item-b': 3600,
      });

      final catalog = Catalog.fromJson({
        'generated_at': '2026-07-01T10:00:00+00:00',
        'total_items': 2,
        'folders': [
          const MediaFolder(
            id: 'f1',
            name: 'Videos',
            path: r'Y:\Media\Videos',
            itemCount: 2,
            items: [_itemA, _itemB],
            subfolders: [],
          ).toJson(),
        ],
      });

      final service = PlaybackService();
      final entries = await service.getContinueWatching(catalog);
      expect(entries.length, 1);
      expect(entries.first.item.id, 'item-a');
    });
  });
}
