@Tags(['phase44-runtime'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/settings/settings_screen.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/models/playback/playback_rate_presets.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback/playback_error_messages.dart';
import 'package:ttsplayer/services/playback_platform.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';

/// Windows runtime validation harness for M4 Phase 4.4 playback improvements.
///
/// Exercises [PlaybackService] and player UI — not direct `media_kit` (Gate 0).
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows   # once — provides libmpv-2.dll
/// $env:PHASE_44_RUNTIME='1'
/// flutter test test/phase_44_windows_runtime_test.dart --tags phase44-runtime
/// ```
///
/// Optional fixture environment variables (no committed media paths):
/// - `GATE0_LOCAL_URI` or `PHASE_44_LOCAL_URI` — local MP4/MKV (`file://` or path)
/// - `GATE0_HTTPS_URI` — HTTPS MP4 stream
/// - `GATE0_MULTI_AUDIO_URI` — MKV with ≥ 2 audio tracks
/// - `GATE0_SUBTITLED_URI` — MKV with embedded subtitles
///
/// ### P1–P24 matrix (Step 6)
///
/// | ID | Scenario | Automation |
/// |----|----------|------------|
/// | P1 | Default speed on play | Service + local fixture |
/// | P2 | In-player speed change | Service; settings unchanged |
/// | P3 | Speed survives pause/seek; Watch Again retains rate | Service |
/// | P4 | HTTPS speed (optional) | Service when `GATE0_HTTPS_URI` set |
/// | P5 | Audio track enumeration in UI | Widget + multi-audio fixture |
/// | P6 | Audio track switch | Service + multi-audio fixture |
/// | P7 | Subtitle enumeration | Service + subtitled fixture |
/// | P8 | Subtitle select | Service + subtitled fixture |
/// | P9 | Subtitle off | Service + subtitled fixture |
/// | P10 | Resume offer + playback from saved position | Prefs + service + detail UI |
/// | P11 | Start from beginning | Service with `startPosition: zero` |
/// | P12 | Continue Watching eligibility | Service + catalog (no dashboard UI) |
/// | P13 | Keyboard play/pause | Widget + local fixture |
/// | P14 | Keyboard seek | Widget + local fixture |
/// | P15 | Esc closes menu then exits player | Widget + local/multi fixture |
/// | P16 | Missing file error + retry re-prepare | Service + player error UI |
/// | P17 | Resolver failure copy | Service + player error UI |
/// | P18 | Settings speed Save | Settings widget |
/// | P19 | Settings Discard | Settings widget |
/// | P20 | Reset all / reset playback | Settings widget + prefs |
/// | P21 | Non-Windows omission | Manual checkpoint (+ unsupported settings UI) |
/// | P22 | Stop clears session; next play uses saved default | Service |
/// | P23 | New item clears prior track ids | Service (two items) |
/// | P24 | HTTPS open, seek, play | Service when `GATE0_HTTPS_URI` set |
///
/// Manual checkpoints (not weak automated substitutes):
/// - P1–P4, P5–P9, P10 playback seek, P11, P13–P15, P22–P24 when
///   [PlaybackService] media init is unavailable in `flutter test` (no
///   `media_kit_video` platform channel). Gate 0 direct `Player()` audit still
///   passes; validate these via Windows desktop app (`flutter run -d windows`).
/// - P21 player speed/track chrome on non-Windows devices
/// - P12 dashboard Continue Watching section opens player
/// - Completion clears persisted progress (long playback)
/// - Track enumeration failure remains non-fatal
/// - Audio/subtitle SnackBar-only failures vs fatal error state
/// - Auto-hide resumes after popup menu closes
/// - Successful retry restores playback after transient engine failure
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TlsHttpOverrides();

  PackageInfo.setMockInitialValues(
    appName: 'TTSPlayer',
    packageName: 'ttsplayer',
    version: '0.5.0-dev.1',
    buildNumber: '1',
    buildSignature: '',
  );

  if (Platform.environment['PHASE_44_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_44_RUNTIME=1 to run Phase 4.4 runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test('skipped — Phase 4.4 runtime validation is Windows-only', () {},
        skip: true);
    return;
  }

  final localUri = _optionalUri(
    Platform.environment['PHASE_44_LOCAL_URI'] ??
        Platform.environment['GATE0_LOCAL_URI'],
  );
  final httpsUri = _optionalUri(Platform.environment['GATE0_HTTPS_URI']);
  final multiAudioUri = _optionalUri(Platform.environment['GATE0_MULTI_AUDIO_URI']);
  final subtitledUri = _optionalUri(Platform.environment['GATE0_SUBTITLED_URI']);

  group('Phase 4.4 Windows runtime validation', () {
    late bool localAvailable;
    late bool httpsAvailable;
    late bool multiAudioAvailable;
    late bool subtitledAvailable;
    late String? localSkipReason;
    late String? httpsSkipReason;
    late String? multiAudioSkipReason;
    late String? subtitledSkipReason;

    bool playbackServiceMediaAvailable = false;
    String? playbackServiceMediaSkipReason;

    setUpAll(() async {
      final libmpv = _resolveLibMpvPath();
      MediaKit.ensureInitialized(libmpv: libmpv);
      playbackServiceMediaAvailable = await _probePlaybackServiceMediaInit();
      if (!playbackServiceMediaAvailable) {
        playbackServiceMediaSkipReason =
            'PlaybackService media init unavailable in flutter test '
            '(media_kit_video platform channel missing). Gate 0 direct Player '
            'audit passes; validate playback scenarios manually on Windows '
            'desktop (`flutter run -d windows`).';
      }

      if (localUri == null) {
        localAvailable = false;
        localSkipReason =
            'Local fixture not configured — set GATE0_LOCAL_URI or PHASE_44_LOCAL_URI';
      } else {
        localAvailable = await _uriExists(localUri);
        localSkipReason =
            localAvailable ? null : 'Local fixture missing: $localUri';
      }

      if (httpsUri == null) {
        httpsAvailable = false;
        httpsSkipReason = 'HTTPS fixture not configured — set GATE0_HTTPS_URI';
      } else {
        httpsAvailable = await _httpsReachable(httpsUri);
        httpsSkipReason =
            httpsAvailable ? null : 'HTTPS fixture unreachable: $httpsUri';
      }

      if (multiAudioUri == null) {
        multiAudioAvailable = false;
        multiAudioSkipReason =
            'Multi-audio fixture not configured — set GATE0_MULTI_AUDIO_URI';
      } else if (!_looksLikeMkv(multiAudioUri)) {
        multiAudioAvailable = false;
        multiAudioSkipReason =
            'GATE0_MULTI_AUDIO_URI should be an MKV with multiple audio tracks';
      } else {
        multiAudioAvailable = await _fixtureAvailable(multiAudioUri);
        multiAudioSkipReason = multiAudioAvailable
            ? null
            : _fixtureSkipReason(multiAudioUri, 'GATE0_MULTI_AUDIO_URI');
      }

      if (subtitledUri == null) {
        subtitledAvailable = false;
        subtitledSkipReason =
            'Subtitled fixture not configured — set GATE0_SUBTITLED_URI';
      } else if (!_looksLikeMkv(subtitledUri)) {
        subtitledAvailable = false;
        subtitledSkipReason =
            'GATE0_SUBTITLED_URI should be a subtitled MKV, not ${Uri.parse(subtitledUri).path.split('/').last}';
      } else {
        subtitledAvailable = await _fixtureAvailable(subtitledUri);
        subtitledSkipReason = subtitledAvailable
            ? null
            : _fixtureSkipReason(subtitledUri, 'GATE0_SUBTITLED_URI');
      }
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      playbackSpeedSettingsSupportedOverride = null;
    });

    tearDown(() {
      playbackSpeedSettingsSupportedOverride = null;
    });

    test('P00 fixture availability report', () {
      // Printed for Step 6 closure records; always passes when harness runs.
      // ignore: avoid_print
      print('Phase 4.4 fixtures: '
          'local=${localAvailable ? localUri : localSkipReason}, '
          'https=${httpsAvailable ? httpsUri : httpsSkipReason}, '
          'multiAudio=${multiAudioAvailable ? multiAudioUri : multiAudioSkipReason}, '
          'subtitled=${subtitledAvailable ? subtitledUri : subtitledSkipReason}, '
          'playbackServiceMedia=$playbackServiceMediaAvailable');
      expect(true, isTrue);
    });

    group('P1–P4 playback speed', () {
      test('P1 default speed on play matches settings default', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        final settings = SettingsRepository();
        await settings.initialize();
        await settings.saveDefaultPlaybackRate(1.5);

        final service = await _createRuntimeService(settings);
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: 'p1-default-speed');
        await service.play(item);
        await _waitForPlaybackReady(service);

        expect(service.playbackRate, closeTo(1.5, 0.01));
        expect(service.hasSessionRateOverride, isFalse);
        expect(settings.defaultPlaybackRate, 1.5);
      }, timeout: const Timeout(Duration(minutes: 3)));

      test('P2 in-player speed change updates session; settings unchanged',
          () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        final settings = SettingsRepository();
        await settings.initialize();
        await settings.saveDefaultPlaybackRate(1.0);

        final service = await _createRuntimeService(settings);
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: 'p2-session-speed');
        await service.play(item);
        await _waitForPlaybackReady(service);

        final result = await service.setPlaybackRate(1.25);
        expect(result.isSuccess, isTrue);
        expect(service.playbackRate, closeTo(1.25, 0.01));
        expect(service.hasSessionRateOverride, isTrue);
        expect(settings.defaultPlaybackRate, 1.0);
      }, timeout: const Timeout(Duration(minutes: 3)));

      test('P3 speed survives pause/seek; Watch Again retains session rate',
          () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: 'p3-pause-seek-watch-again');
        await service.play(item);
        await _waitForPlaybackReady(service);

        await service.setPlaybackRate(1.5);
        expect(service.playbackRate, closeTo(1.5, 0.01));

        await service.togglePlayPause();
        await _waitFor(() => !service.isPlaying);
        await service.seekTo(const Duration(seconds: 45));
        expect(service.playbackRate, closeTo(1.5, 0.01));

        await service.seekTo(Duration.zero);
        await service.togglePlayPause();
        await _waitFor(() => service.isPlaying);
        expect(service.playbackRate, closeTo(1.5, 0.01));
      }, timeout: const Timeout(Duration(minutes: 3)));

      test('P4 HTTPS setRate when fixture available', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!httpsAvailable) {
          _skipUnlessFixture(httpsAvailable, httpsSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(httpsUri!, id: 'p4-https-speed');
        await service.play(item);
        await _waitForPlaybackReady(service);

        final result = await service.setPlaybackRate(1.25);
        expect(result.isSuccess, isTrue);
        expect(service.playbackRate, closeTo(1.25, 0.01));
      }, timeout: const Timeout(Duration(minutes: 4)));
    });

    group('P5–P9 audio and subtitle tracks', () {
      testWidgets('P5 audio tracks enumerated in player UI', (tester) async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!multiAudioAvailable) {
          _skipUnlessFixture(multiAudioAvailable, multiAudioSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(multiAudioUri!, id: 'p5-audio-ui');
        await tester.pumpWidget(_playerWidget(service, item, autoPlay: true));
        await _waitForPlaybackReady(service);
        await tester.pump();

        expect(service.availableAudioTracks.length, greaterThanOrEqualTo(2));
        expect(find.text('Audio'), findsOneWidget);

        await tester.tap(find.text('Audio'));
        await tester.pumpAndSettle();
        expect(find.text('Audio 1'), findsOneWidget);
        expect(find.text('Audio 2'), findsOneWidget);
      }, timeout: const Timeout(Duration(minutes: 4)));

      test('P6 audio track switch updates service selection', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!multiAudioAvailable) {
          _skipUnlessFixture(multiAudioAvailable, multiAudioSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(multiAudioUri!, id: 'p6-audio-switch');
        await service.play(item);
        await _waitForPlaybackReady(service);
        await _waitFor(
          () => service.availableAudioTracks.length >= 2,
          timeout: const Duration(seconds: 45),
        );

        final second = service.availableAudioTracks[1];
        final result = await service.selectAudioTrack(second.id);
        expect(result.isSuccess, isTrue);
        expect(service.selectedAudioTrackId, second.id);
      }, timeout: const Timeout(Duration(minutes: 4)));

      test('P7 subtitle tracks enumerated', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!subtitledAvailable) {
          _skipUnlessFixture(subtitledAvailable, subtitledSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(subtitledUri!, id: 'p7-sub-enumeration');
        await service.play(item);
        if (service.errorMessage != null) {
          markTestSkipped('Subtitled fixture could not be opened: '
              '${service.playbackErrorKind?.name ?? service.errorMessage}');
          return;
        }
        await _waitForPlaybackReady(service);
        await _waitFor(
          () => service.availableSubtitleTracks.isNotEmpty,
          timeout: const Duration(seconds: 45),
        );

        expect(service.availableSubtitleTracks, isNotEmpty);
        expect(service.canSelectSubtitleTracks, isTrue);
      }, timeout: const Timeout(Duration(minutes: 4)));

      test('P8 subtitle select updates playback state', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!subtitledAvailable) {
          _skipUnlessFixture(subtitledAvailable, subtitledSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(subtitledUri!, id: 'p8-sub-select');
        await service.play(item);
        await _waitForPlaybackReady(service);
        await _waitFor(
          () => service.availableSubtitleTracks.isNotEmpty,
          timeout: const Duration(seconds: 45),
        );

        final track = service.availableSubtitleTracks.first;
        final result = await service.selectSubtitleTrack(track.id);
        expect(result.isSuccess, isTrue);
        expect(service.selectedSubtitleTrackId, track.id);
      }, timeout: const Timeout(Duration(minutes: 4)));

      test('P9 subtitle off clears selection', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!subtitledAvailable) {
          _skipUnlessFixture(subtitledAvailable, subtitledSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(subtitledUri!, id: 'p9-sub-off');
        await service.play(item);
        await _waitForPlaybackReady(service);
        await _waitFor(
          () => service.availableSubtitleTracks.isNotEmpty,
          timeout: const Duration(seconds: 45),
        );

        await service.selectSubtitleTrack(service.availableSubtitleTracks.first.id);
        expect(service.selectedSubtitleTrackId, isNotNull);

        final result = await service.disableSubtitles();
        expect(result.isSuccess, isTrue);
        expect(service.selectedSubtitleTrackId, isNull);
      }, timeout: const Timeout(Duration(minutes: 4)));
    });

    group('P10–P12 resume and progress', () {
      test('P10 resume thresholds, detail offer, and playback from saved position',
          () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        const itemId = 'p10-resume-item';
        SharedPreferences.setMockInitialValues({
          'position_$itemId': 120,
          'duration_$itemId': 3600,
        });

        final resume = await PlaybackService().resumeInfoFor(itemId);
        expect(resume, isNotNull);
        expect(resume!.shouldOffer, isTrue);
        expect(resume.savedPosition, const Duration(minutes: 2));

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: itemId);
        await service.play(item);
        await _waitForPlaybackReady(service);

        expect(
          service.position.inSeconds,
          greaterThanOrEqualTo(110),
          reason: 'Resume should seek near saved position',
        );
      }, timeout: const Timeout(Duration(minutes: 3)));

      testWidgets('P10 detail screen shows resume offer', (tester) async {
        const itemId = 'p10-detail-resume';
        SharedPreferences.setMockInitialValues({
          'position_$itemId': 120,
          'duration_$itemId': 3600,
        });

        final item = MediaItem(
          id: itemId,
          title: 'Resume Movie',
          filePath: r'C:\media\resume.mp4',
        );
        final playback = PlaybackService();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PlaybackService>.value(value: playback),
              Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
              Provider(
                create: (_) => MediaLocationResolver(
                  config: MediaProviderConfig.defaults().mediaAccess,
                  isWindowsDesktop: true,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => LibraryMetadataRepository()..initialize(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: ItemDetailScreen(item: item),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Resume from'), findsOneWidget);
        expect(find.text('Start from beginning'), findsOneWidget);
      });

      test('P11 start from beginning ignores saved resume for that action',
          () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        const itemId = 'p11-start-over';
        SharedPreferences.setMockInitialValues({
          'position_$itemId': 120,
          'duration_$itemId': 3600,
        });

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: itemId);
        await service.play(item, startPosition: Duration.zero);
        await _waitForPlaybackReady(service);

        expect(service.position.inSeconds, lessThan(15));
      }, timeout: const Timeout(Duration(minutes: 3)));

      test('P12 Continue Watching eligibility unchanged', () async {
        SharedPreferences.setMockInitialValues({
          'position_eligible': 120,
          'duration_eligible': 3600,
          'position_too-short': 10,
          'duration_too-short': 3600,
        });

        final catalog = Catalog.fromJson({
          'generated_at': '2026-07-01T10:00:00+00:00',
          'total_items': 2,
          'folders': [
            const MediaFolder(
              id: 'f1',
              name: 'Videos',
              path: r'C:\Media\Videos',
              itemCount: 2,
              items: [
                MediaItem(
                  id: 'eligible',
                  title: 'Eligible',
                  filePath: r'C:\Media\Videos\one.mp4',
                ),
                MediaItem(
                  id: 'too-short',
                  title: 'Too Short',
                  filePath: r'C:\Media\Videos\two.mp4',
                ),
              ],
              subfolders: [],
            ).toJson(),
          ],
        });

        final service = PlaybackService();
        final entries = await service.getContinueWatching(catalog);
        expect(entries.length, 1);
        expect(entries.first.item.id, 'eligible');
      });
    });

    group('P13–P15 keyboard and popup behaviour', () {
      testWidgets('P13 space toggles playback when player has focus',
          (tester) async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: 'p13-space');
        await tester.pumpWidget(_playerWidget(service, item, autoPlay: true));
        await _waitForPlaybackReady(service);
        await _waitFor(() => service.isPlaying);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        await _waitFor(() => !service.isPlaying);

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        await _waitFor(() => service.isPlaying);
      }, timeout: const Timeout(Duration(minutes: 4)));

      testWidgets('P14 arrow keys seek when no menu owns focus', (tester) async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: 'p14-seek');
        await service.play(item);
        await _waitForPlaybackReady(service);
        await service.seekTo(const Duration(minutes: 2));
        await service.togglePlayPause();

        await tester.pumpWidget(_playerWidget(service, item, autoPlay: false));
        await tester.pumpAndSettle();

        final before = service.position;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(service.position, before + const Duration(seconds: 30));
      }, timeout: const Timeout(Duration(minutes: 4)));

      testWidgets('P14b seek shortcuts ignored while audio menu is open',
          (tester) async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!multiAudioAvailable) {
          _skipUnlessFixture(multiAudioAvailable, multiAudioSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(multiAudioUri!, id: 'p14-menu-focus');
        await service.play(item);
        await _waitForPlaybackReady(service);
        await _waitFor(() => service.availableAudioTracks.length >= 2);
        await service.togglePlayPause();

        await tester.pumpWidget(_playerWidget(service, item, autoPlay: false));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Audio'));
        await tester.pumpAndSettle();

        final before = service.position;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(service.position, before);
      }, timeout: const Timeout(Duration(minutes: 4)));

      testWidgets('P15 first Esc closes popup; second Esc exits player',
          (tester) async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!multiAudioAvailable) {
          _skipUnlessFixture(multiAudioAvailable, multiAudioSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(multiAudioUri!, id: 'p15-esc');
        await tester.pumpWidget(_stackedPlayerHarness(service, item));
        await tester.tap(find.text('open'));
        await tester.pump();
        await _waitForPlaybackReady(service);
        await _waitFor(() => service.availableAudioTracks.length >= 2);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Audio'));
        await tester.pumpAndSettle();
        expect(find.text('Audio 2'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('open'), findsNothing);
        expect(find.byType(PlayerScreen), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
        expect(find.byType(PlayerScreen), findsNothing);
      }, timeout: const Timeout(Duration(minutes: 4)));
    });

    group('P16–P17 errors and retry', () {
      testWidgets('P16 missing file shows playback-layer error copy', (tester) async {
        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        const item = MediaItem(
          id: 'p16-missing',
          title: 'Missing',
          filePath: r'Z:\phase44-missing\not-found.mp4',
        );

        await service.play(item);
        await _waitFor(() => service.errorMessage != null);

        await tester.pumpWidget(_playerWidget(service, item, autoPlay: false));
        await tester.pumpAndSettle();

        expect(service.playbackErrorKind, PlaybackErrorKind.fileMissing);
        expect(
          find.text(PlaybackErrorMessages.forKind(PlaybackErrorKind.fileMissing)),
          findsOneWidget,
        );
        expect(find.text('Try Again'), findsOneWidget);
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('P16b retry re-prepares after missing file error', () async {
        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        const item = MediaItem(
          id: 'p16-retry',
          title: 'Missing',
          filePath: r'Z:\phase44-missing\not-found.mp4',
        );

        await service.play(item);
        await _waitFor(() => service.errorMessage != null);
        expect(service.playbackErrorKind, PlaybackErrorKind.fileMissing);

        await service.retry();
        await _waitFor(() => service.errorMessage != null);
        expect(service.playbackErrorKind, PlaybackErrorKind.fileMissing);
        expect(service.isInitializing, isFalse);
      });

      testWidgets('P17 resolver failure shows playback message with settings hint',
          (tester) async {
        final resolver = MediaLocationResolver(
          config: MediaAccessConfig.defaults(
            mode: MediaAccessMode.httpRequired,
            httpMediaBaseUrl: '',
          ),
          isWindowsDesktop: true,
        );
        final service = PlaybackService(
          mediaLocationResolver: resolver,
          defaultPlaybackRateProvider: () => PlaybackRatePresets.defaultRate,
        );
        addTearDown(() => _safeStop(service));

        const item = MediaItem(
          id: 'p17-resolver',
          title: 'Unresolved',
          filePath: '/volume1/media/unresolved.mp4',
        );

        await service.play(item);
        await _waitFor(() => service.errorMessage != null);

        await tester.pumpWidget(_playerWidget(service, item, autoPlay: false));
        await tester.pumpAndSettle();

        expect(service.playbackErrorKind, PlaybackErrorKind.resolverFailed);
        expect(
          find.text(
            PlaybackErrorMessages.forKind(PlaybackErrorKind.resolverFailed),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Open Provider Status in Settings'),
          findsOneWidget,
        );
      });
    });

    group('P18–P20 settings', () {
      testWidgets('P18 settings Save persists playback speed', (tester) async {
        final repository = SettingsRepository();
        await _pumpSettingsScreen(tester, repository);

        await _selectPlaybackRate(tester, 1.5);
        await tester.ensureVisible(find.byKey(const Key('save_playback_settings')));
        await tester.tap(find.byKey(const Key('save_playback_settings')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        tester.takeException();

        expect(repository.defaultPlaybackRate, 1.5);
        expect(find.text('Playback settings saved.'), findsOneWidget);
      });

      testWidgets('P19 settings Discard reverts unsaved draft', (tester) async {
        final repository = SettingsRepository();
        await _pumpSettingsScreen(tester, repository);

        await _selectPlaybackRate(tester, 1.5);
        expect(
          tester.widget<FilledButton>(
            find.byKey(const Key('save_playback_settings')),
          ).onPressed,
          isNotNull,
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(repository.defaultPlaybackRate, PlaybackRatePresets.defaultRate);
      });

      testWidgets('P20 reset playback and reset all retain resume keys',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'position_resume-key': 90,
          'duration_resume-key': 1800,
        });

        final repository = SettingsRepository();
        await repository.initialize();
        await repository.saveDefaultPlaybackRate(1.5);
        await _pumpSettingsScreen(tester, repository);

        await tester.ensureVisible(
          find.byKey(const Key('reset_playback_settings')),
        );
        await tester.tap(find.byKey(const Key('reset_playback_settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm_reset_playback')));
        await tester.pumpAndSettle();

        expect(repository.defaultPlaybackRate, PlaybackRatePresets.defaultRate);

        await _selectPlaybackRate(tester, 1.25);
        await tester.tap(find.byKey(const Key('save_playback_settings')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('reset_all_settings')));
        await tester.tap(find.byKey(const Key('reset_all_settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm_reset_all_settings')));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('position_resume-key'), 90);
        expect(repository.defaultPlaybackRate, PlaybackRatePresets.defaultRate);
      });
    });

    test('P21 manual checkpoint — non-Windows player chrome omission', () {
      // Automated on Windows: unsupported settings UI preserves stored preference.
      // Player speed/track chrome on Android/iOS/macOS/Linux requires device QA.
      expect(Platform.isWindows, isTrue);
    });

    testWidgets('P21 unsupported settings UI is read-only on Windows override',
        (tester) async {
      playbackSpeedSettingsSupportedOverride = () => false;
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(1.5);
      await _pumpSettingsScreen(tester, repository);

      expect(find.byKey(const Key('default_playback_speed')), findsNothing);
      expect(find.byKey(const Key('playback_speed_readonly')), findsOneWidget);
      expect(find.textContaining('1.5×'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save_playback_settings')))
            .onPressed,
        isNull,
      );
    });

    group('P22–P24 session lifecycle and HTTPS regression', () {
      test('P22 stop clears session; next play loads saved default', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable) {
          _skipUnlessFixture(localAvailable, localSkipReason!);
          return;
        }

        final settings = SettingsRepository();
        await settings.initialize();
        await settings.saveDefaultPlaybackRate(1.25);

        final service = await _createRuntimeService(settings);
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(localUri!, id: 'p22-stop-session');
        await service.play(item);
        await _waitForPlaybackReady(service);
        await service.setPlaybackRate(1.5);
        expect(service.hasSessionRateOverride, isTrue);

        await service.stop();
        expect(service.hasSessionRateOverride, isFalse);
        expect(service.availableAudioTracks, isEmpty);
        expect(service.availableSubtitleTracks, isEmpty);
        expect(service.currentItem, isNull);

        await service.play(item);
        await _waitForPlaybackReady(service);
        expect(service.playbackRate, closeTo(1.25, 0.01));
        expect(service.hasSessionRateOverride, isFalse);
      }, timeout: const Timeout(Duration(minutes: 4)));

      test('P23 new item clears stale track ids', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!localAvailable || !multiAudioAvailable) {
          _skipUnlessFixture(
            localAvailable && multiAudioAvailable,
            !localAvailable ? localSkipReason! : multiAudioSkipReason!,
          );
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final multiItem = _itemFromUri(multiAudioUri!, id: 'p23-multi');
        await service.play(multiItem);
        await _waitForPlaybackReady(service);
        await _waitFor(() => service.availableAudioTracks.length >= 2);
        await service.selectAudioTrack(service.availableAudioTracks[1].id);
        expect(service.selectedAudioTrackId, isNotNull);

        final localItem = _itemFromUri(localUri!, id: 'p23-local');
        await service.play(localItem);
        await _waitForPlaybackReady(service);

        if (service.availableAudioTracks.isEmpty) {
          expect(service.selectedAudioTrackId, isNull);
        } else {
          expect(
            service.availableAudioTracks
                .any((t) => t.id == service.selectedAudioTrackId),
            isTrue,
          );
        }
        expect(service.selectedSubtitleTrackId, isNull);
      }, timeout: const Timeout(Duration(minutes: 5)));

      test('P24 HTTPS open seek and play', () async {
        if (_skipUnlessPlaybackServiceMediaAvailable(
          playbackServiceMediaAvailable,
          playbackServiceMediaSkipReason,
        )) {
          return;
        }
        if (!httpsAvailable) {
          _skipUnlessFixture(httpsAvailable, httpsSkipReason!);
          return;
        }

        final service = await _createRuntimeService();
        addTearDown(() => _safeStop(service));

        final item = _itemFromUri(httpsUri!, id: 'p24-https-regression');
        await service.play(item);
        await _waitForPlaybackReady(service);

        await service.seekTo(const Duration(seconds: 30));
        expect(service.position.inSeconds, greaterThanOrEqualTo(25));

        await service.togglePlayPause();
        await _waitFor(() => service.isPlaying);
      }, timeout: const Timeout(Duration(minutes: 4)));
    });
  });
}

// ---------------------------------------------------------------------------
// Harness helpers
// ---------------------------------------------------------------------------

class _TlsHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, __, ___) => true;
    return client;
  }
}

bool _skipUnlessPlaybackServiceMediaAvailable(
  bool available,
  String? reason,
) {
  if (Platform.environment.containsKey('FLUTTER_TEST') || !available) {
    markTestSkipped(
      reason ??
          'PlaybackService media init unavailable in flutter test '
          '(media_kit_video platform channel missing)',
    );
    return true;
  }
  return false;
}

void _skipUnlessFixture(bool available, String reason) {
  if (!available) {
    markTestSkipped(reason);
  }
}

Future<void> _safeStop(PlaybackService service) async {
  try {
    await service.stop().timeout(const Duration(seconds: 5));
  } catch (_) {}
}

Future<bool> _probePlaybackServiceMediaInit() async {
  // Gate 0 uses bare media_kit Player() and passes under `flutter test`.
  // PlaybackService also creates media_kit_video VideoController, which needs
  // native platform channels absent in the test embedding.
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return false;
  }

  Player? player;
  final errors = <Object>[];

  await runZonedGuarded(() async {
    player = Player();
    VideoController(player!);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }, (error, stack) {
    errors.add(error);
  });

  try {
    await player?.dispose().timeout(const Duration(seconds: 3));
  } catch (_) {}

  if (errors.any((e) => e is MissingPluginException)) {
    return false;
  }
  return errors.isEmpty;
}

Future<PlaybackService> _createRuntimeService([SettingsRepository? settings]) async {
  settings ??= SettingsRepository();
  if (!settings.isLoaded) {
    await settings.initialize();
  }
  return PlaybackService(
    mediaLocationResolver: MediaLocationResolver(
      config: MediaProviderConfig.defaults().mediaAccess,
      isWindowsDesktop: true,
    ),
    defaultPlaybackRateProvider: () => settings!.defaultPlaybackRate,
  );
}

MediaItem _itemFromUri(String uri, {required String id}) {
  final cataloguePath = uri.startsWith('file://')
      ? Uri.parse(uri).toFilePath(windows: true)
      : uri;
  return MediaItem(
    id: id,
    title: 'Phase 4.4 runtime fixture',
    filePath: cataloguePath,
  );
}

Widget _playerWidget(
  PlaybackService service,
  MediaItem item, {
  required bool autoPlay,
}) {
  return ChangeNotifierProvider<PlaybackService>.value(
    value: service,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: PlayerScreen(item: item, autoPlay: autoPlay),
    ),
  );
}

Widget _stackedPlayerHarness(PlaybackService service, MediaItem item) {
  return ChangeNotifierProvider<PlaybackService>.value(
    value: service,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider<PlaybackService>.value(
                  value: service,
                  child: PlayerScreen(item: item, autoPlay: true),
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

Widget _settingsHarness(SettingsRepository repository) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsRepository>.value(value: repository),
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const SettingsScreen(),
    ),
  );
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester,
  SettingsRepository repository,
) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await repository.initialize();
  await tester.pumpWidget(_settingsHarness(repository));
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('save_playback_settings')).evaluate().isNotEmpty) {
      break;
    }
  }
  tester.takeException();
}

Future<void> _selectPlaybackRate(WidgetTester tester, double rate) async {
  await tester.ensureVisible(find.byKey(const Key('default_playback_speed')));
  await tester.tap(find.byKey(const Key('default_playback_speed')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(PlaybackRatePresets.displayLabel(rate)).last);
  await tester.pumpAndSettle();
}

Future<void> _waitForPlaybackReady(
  PlaybackService service, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  await _waitFor(
    () => service.isReady || service.errorMessage != null,
    timeout: timeout,
  );
  if (service.errorMessage != null) {
    fail(
      'Playback failed (${service.playbackErrorKind}): ${service.errorMessage}',
    );
  }
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

Future<bool> _fixtureAvailable(String uri) async {
  if (uri.startsWith('http://') || uri.startsWith('https://')) {
    return _httpsReachable(uri);
  }
  return _uriExists(uri);
}

String _fixtureSkipReason(String uri, String envName) {
  if (uri.startsWith('http://') || uri.startsWith('https://')) {
    return '$envName unreachable or unsuitable for runtime playback: $uri';
  }
  return '$envName fixture missing: $uri';
}

bool _looksLikeMkv(String uri) {
  final path = uri.startsWith('file://')
      ? Uri.parse(uri).path
      : Uri.parse(uri).path;
  return path.toLowerCase().endsWith('.mkv');
}

Future<bool> _uriExists(String uri) async {
  if (uri.startsWith('http://') || uri.startsWith('https://')) {
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
