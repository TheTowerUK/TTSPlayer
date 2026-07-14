import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_action_result.dart';
import 'package:ttsplayer/models/playback/playback_audio_track.dart';
import 'package:ttsplayer/models/playback/playback_error_kind.dart';
import 'package:ttsplayer/models/playback/playback_rate_presets.dart';
import 'package:ttsplayer/models/playback/playback_subtitle_track.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_access_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/resolved_media_location.dart';
import 'package:ttsplayer/services/playback/playback_error_mapper.dart';
import 'package:ttsplayer/services/playback/playback_session_controls.dart';
import 'package:ttsplayer/services/playback/unsupported_session_controls.dart';
import 'package:ttsplayer/services/playback_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakePlaybackSessionControls implements PlaybackSessionControls {
  FakePlaybackSessionControls({
    this.supportsPlaybackRate = true,
    this.supportsTrackSelection = true,
    PlaybackSessionSnapshot? snapshot,
    this.rateApplyFails = false,
    this.enumerationFails = false,
    this.audioSelectFails = false,
    this.subtitleSelectFails = false,
  }) : _snapshot = snapshot ?? PlaybackSessionSnapshot.empty;

  @override
  final bool supportsPlaybackRate;

  @override
  final bool supportsTrackSelection;

  bool rateApplyFails;
  bool enumerationFails;
  bool audioSelectFails;
  bool subtitleSelectFails;

  PlaybackSessionSnapshot _snapshot;

  double? lastRequestedRate;
  String? lastAudioTrackId;
  String? lastSubtitleTrackId;
  bool disableSubtitlesCalled = false;
  int setRateCallCount = 0;

  void setSnapshot(PlaybackSessionSnapshot snapshot) {
    _snapshot = snapshot;
  }

  void resetSelectionForNewMedia() {
    _snapshot = PlaybackSessionSnapshot(
      playbackRate: _snapshot.playbackRate,
      audioTracks: _snapshot.audioTracks,
      subtitleTracks: _snapshot.subtitleTracks,
    );
  }

  @override
  PlaybackSessionSnapshot readSnapshot() {
    if (enumerationFails) {
      throw StateError('enumeration failed');
    }
    return _snapshot;
  }

  @override
  Future<PlaybackActionResult> setPlaybackRate(double rate) async {
    setRateCallCount++;
    lastRequestedRate = rate;
    if (rateApplyFails) {
      return const PlaybackActionResult.backendFailed('rate rejected');
    }
    _snapshot = PlaybackSessionSnapshot(
      playbackRate: rate,
      audioTracks: _snapshot.audioTracks,
      subtitleTracks: _snapshot.subtitleTracks,
      selectedAudioTrackId: _snapshot.selectedAudioTrackId,
      selectedSubtitleTrackId: _snapshot.selectedSubtitleTrackId,
    );
    return const PlaybackActionResult.success();
  }

  @override
  Future<PlaybackActionResult> selectAudioTrack(String trackId) async {
    if (audioSelectFails) {
      return const PlaybackActionResult.backendFailed('audio rejected');
    }
    lastAudioTrackId = trackId;
    if (!_snapshot.audioTracks.any((track) => track.id == trackId)) {
      return PlaybackActionResult.invalidArgument('Unknown audio track: $trackId');
    }
    _snapshot = PlaybackSessionSnapshot(
      playbackRate: _snapshot.playbackRate,
      audioTracks: _snapshot.audioTracks,
      subtitleTracks: _snapshot.subtitleTracks,
      selectedAudioTrackId: trackId,
      selectedSubtitleTrackId: _snapshot.selectedSubtitleTrackId,
    );
    return const PlaybackActionResult.success();
  }

  @override
  Future<PlaybackActionResult> selectSubtitleTrack(String? trackId) async {
    if (subtitleSelectFails) {
      return const PlaybackActionResult.backendFailed('subtitle rejected');
    }
    if (trackId == null) {
      return disableSubtitles();
    }
    lastSubtitleTrackId = trackId;
    if (!_snapshot.subtitleTracks.any((track) => track.id == trackId)) {
      return PlaybackActionResult.invalidArgument(
        'Unknown subtitle track: $trackId',
      );
    }
    _snapshot = PlaybackSessionSnapshot(
      playbackRate: _snapshot.playbackRate,
      audioTracks: _snapshot.audioTracks,
      subtitleTracks: _snapshot.subtitleTracks,
      selectedAudioTrackId: _snapshot.selectedAudioTrackId,
      selectedSubtitleTrackId: trackId,
    );
    return const PlaybackActionResult.success();
  }

  @override
  Future<PlaybackActionResult> disableSubtitles() async {
    disableSubtitlesCalled = true;
    _snapshot = PlaybackSessionSnapshot(
      playbackRate: _snapshot.playbackRate,
      audioTracks: _snapshot.audioTracks,
      subtitleTracks: _snapshot.subtitleTracks,
      selectedAudioTrackId: _snapshot.selectedAudioTrackId,
      selectedSubtitleTrackId: null,
    );
    return const PlaybackActionResult.success();
  }

  @override
  Future<void> dispose() async {}
}

class _StubResolver extends MediaLocationResolver {
  _StubResolver(this._resolveFn)
      : super(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        );

  final ResolvedMediaLocation Function(String path) _resolveFn;

  @override
  ResolvedMediaLocation resolve(String cataloguePath) => _resolveFn(cataloguePath);
}

MediaItem _item({
  required String id,
  required String filePath,
  String title = 'Test Item',
}) {
  return MediaItem(id: id, title: title, filePath: filePath);
}

PlaybackService _serviceWithFakeControls({
  required FakePlaybackSessionControls controls,
  double defaultRate = PlaybackRatePresets.defaultRate,
  MediaLocationResolver? resolver,
  MediaKitInitOverride? openOverride,
}) {
  return PlaybackService(
    mediaLocationResolver: resolver,
    defaultPlaybackRateProvider: () => defaultRate,
    mediaKitInitOverride: openOverride ??
        (service, uri, generation) async {
          controls.resetSelectionForNewMedia();
          service.attachSessionControlsForTest(controls);
          service.simulatePlaybackMetricsForTest(
            duration: const Duration(hours: 1),
          );
          final item = service.currentItem;
          if (item != null) {
            service.simulateReadyForTest(item);
          }
        },
  );
}

Future<String> _createTempMediaFile() async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_playback_ext_');
  final file = File('${dir.path}/sample.mp4');
  await file.writeAsBytes([0, 1, 2, 3]);
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('playback rate', () {
    test('1 initial playback rate state', () {
      final service = PlaybackService();
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
      expect(service.supportedPlaybackRates, PlaybackRatePresets.supported);
      expect(service.canChangePlaybackRate, isFalse);
      expect(service.hasSessionRateOverride, isFalse);
    });

    test('2 valid rate change succeeds', () async {
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(controls: controls);
      final item = _item(id: 'a', filePath: r'Y:\Media\a.mp4');

      service.simulateReadyForTest(item);
      service.attachSessionControlsForTest(controls);

      final result = await service.setPlaybackRate(1.5);
      expect(result.isSuccess, isTrue);
      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isTrue);
      expect(controls.lastRequestedRate, 1.5);
    });

    test('3 invalid rate rejected', () async {
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(controls: controls);
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.setPlaybackRate(1.1);
      expect(result.status, PlaybackActionStatus.invalidArgument);
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
      expect(controls.setRateCallCount, 0);
    });

    test('4 backend rate failure preserves prior state', () async {
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(controls: controls);
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      await service.setPlaybackRate(1.25);
      controls.rateApplyFails = true;

      final result = await service.setPlaybackRate(2.0);
      expect(result.status, PlaybackActionStatus.backendFailed);
      expect(service.playbackRate, 1.25);
    });

    test('5 rate persists through pause', () async {
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(controls: controls);
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      await service.setPlaybackRate(1.5);
      await service.togglePlayPause();

      expect(service.playbackRate, 1.5);
    });

    test('6 rate persists through seek', () async {
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(controls: controls);
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      await service.setPlaybackRate(1.5);
      await service.seekTo(const Duration(minutes: 5));

      expect(service.playbackRate, 1.5);
    });

    test('7 new-media rate lifecycle follows ADR', () async {
      final controls = FakePlaybackSessionControls();
      final path = await _createTempMediaFile();
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(path).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final service = _serviceWithFakeControls(
        controls: controls,
        defaultRate: 1.5,
        resolver: resolver,
      );

      final first = _item(id: 'first', filePath: path);
      await service.play(first);
      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isFalse);

      await service.setPlaybackRate(2.0);
      expect(service.hasSessionRateOverride, isTrue);

      final second = _item(id: 'second', filePath: path, title: 'Second');
      await service.play(second);
      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isFalse);
    });

    test('8 unsupported backend rate result', () async {
      const controls = UnsupportedSessionControls();
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.setPlaybackRate(1.5);
      expect(result.status, PlaybackActionStatus.unsupported);
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
    });
  });

  group('track enumeration and selection', () {
    const audioTracks = [
      PlaybackAudioTrack(id: 'a1', title: 'English', language: 'eng'),
      PlaybackAudioTrack(id: 'a2', title: 'French', language: 'fra'),
    ];
    const subtitleTracks = [
      PlaybackSubtitleTrack(id: 's1', title: 'English CC', language: 'eng'),
    ];

    PlaybackSessionSnapshot snapshotWithTracks() {
      return const PlaybackSessionSnapshot(
        playbackRate: 1.0,
        audioTracks: audioTracks,
        subtitleTracks: subtitleTracks,
        selectedAudioTrackId: 'a1',
        selectedSubtitleTrackId: null,
      );
    }

    test('9 audio tracks mapped from backend', () {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      expect(service.availableAudioTracks, audioTracks);
      expect(service.selectedAudioTrackId, 'a1');
      expect(service.canSelectAudioTracks, isTrue);
    });

    test('10 subtitle tracks mapped from backend', () {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      expect(service.availableSubtitleTracks, subtitleTracks);
      expect(service.canSelectSubtitleTracks, isTrue);
    });

    test('11 empty track sets handled', () {
      final controls = FakePlaybackSessionControls();
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      expect(service.availableAudioTracks, isEmpty);
      expect(service.availableSubtitleTracks, isEmpty);
      expect(service.canSelectAudioTracks, isFalse);
      expect(service.canSelectSubtitleTracks, isFalse);
    });

    test('12 enumeration failure does not fail playback', () async {
      final controls = FakePlaybackSessionControls(enumerationFails: true);
      final path = await _createTempMediaFile();
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(path).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final service = _serviceWithFakeControls(
        controls: controls,
        resolver: resolver,
      );

      await service.play(_item(id: 'a', filePath: path));
      expect(service.isReady, isTrue);
      expect(service.errorMessage, isNull);
      expect(service.availableAudioTracks, isEmpty);
    });

    test('13 select valid audio track', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.selectAudioTrack('a2');
      expect(result.isSuccess, isTrue);
      expect(service.selectedAudioTrackId, 'a2');
      expect(controls.lastAudioTrackId, 'a2');
    });

    test('14 reject unknown audio track', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.selectAudioTrack('missing');
      expect(result.status, PlaybackActionStatus.invalidArgument);
      expect(service.selectedAudioTrackId, 'a1');
    });

    test('15 reselect current audio track', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.selectAudioTrack('a1');
      expect(result.isSuccess, isTrue);
      expect(controls.lastAudioTrackId, isNull);
    });

    test('16 select valid subtitle track', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.selectSubtitleTrack('s1');
      expect(result.isSuccess, isTrue);
      expect(service.selectedSubtitleTrackId, 's1');
    });

    test('17 disable subtitles', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: audioTracks,
          subtitleTracks: subtitleTracks,
          selectedSubtitleTrackId: 's1',
        ),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.disableSubtitles();
      expect(result.isSuccess, isTrue);
      expect(service.selectedSubtitleTrackId, isNull);
      expect(controls.disableSubtitlesCalled, isTrue);
    });

    test('18 reject unknown subtitle track', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      final result = await service.selectSubtitleTrack('missing');
      expect(result.status, PlaybackActionStatus.invalidArgument);
      expect(service.selectedSubtitleTrackId, isNull);
    });

    test('19 track state resets on new media', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: snapshotWithTracks(),
      );
      final path = await _createTempMediaFile();
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(path).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final service = _serviceWithFakeControls(
        controls: controls,
        resolver: resolver,
      );

      await service.play(_item(id: 'first', filePath: path));
      await service.selectAudioTrack('a2');
      await service.selectSubtitleTrack('s1');
      expect(service.selectedAudioTrackId, 'a2');
      expect(service.selectedSubtitleTrackId, 's1');

      controls.setSnapshot(PlaybackSessionSnapshot.empty);
      await service.play(_item(id: 'second', filePath: path, title: 'Second'));
      expect(service.availableAudioTracks, isEmpty);
      expect(service.availableSubtitleTracks, isEmpty);
      expect(service.selectedAudioTrackId, isNull);
      expect(service.selectedSubtitleTrackId, isNull);
    });

    test('20 unsupported backend track selection', () async {
      const controls = UnsupportedSessionControls();
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      expect(
        (await service.selectAudioTrack('a1')).status,
        PlaybackActionStatus.unsupported,
      );
      expect(
        (await service.selectSubtitleTrack('s1')).status,
        PlaybackActionStatus.unsupported,
      );
      expect(
        (await service.disableSubtitles()).status,
        PlaybackActionStatus.unsupported,
      );
    });
  });

  group('error taxonomy', () {
    test('21 resolver error maps to resolver category', () async {
      final resolver = _StubResolver(
        (_) => const ResolvedMediaLocation.unresolved(
          providerType: MediaAccessProviderType.localFile,
          errorReason: 'SMB unavailable',
        ),
      );
      final service = PlaybackService(mediaLocationResolver: resolver);

      await service.play(_item(id: 'a', filePath: r'Y:\Media\missing.mp4'));
      expect(service.playbackErrorKind, PlaybackErrorKind.resolverFailed);
      expect(service.errorMessage, isNotEmpty);
    });

    test('22 local missing file maps correctly', () async {
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(p).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final service = PlaybackService(mediaLocationResolver: resolver);

      await service.play(
        _item(id: 'a', filePath: r'Z:\definitely-missing\video.mp4'),
      );
      expect(service.playbackErrorKind, PlaybackErrorKind.fileMissing);
    });

    test('23 timeout maps correctly', () async {
      final path = await _createTempMediaFile();
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(path).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final service = PlaybackService(
        mediaLocationResolver: resolver,
        mediaKitInitOverride: (_, __, ___) async {
          throw TimeoutException('open timed out');
        },
      );

      await service.play(_item(id: 'a', filePath: path));
      expect(service.playbackErrorKind, PlaybackErrorKind.timeout);
    });

    test('24 TLS network HTTP failure mapping where distinguishable', () {
      final tls = PlaybackErrorMapper.fromException(
        Exception('HandshakeException: TLS failure'),
      );
      expect(tls.kind, PlaybackErrorKind.tls);

      final http = PlaybackErrorMapper.fromException(Exception('HTTP 404 Not Found'));
      expect(http.kind, PlaybackErrorKind.httpNotFound);

      final network = PlaybackErrorMapper.fromException(
        Exception('SocketException: Failed host lookup'),
      );
      expect(network.kind, PlaybackErrorKind.network);
    });

    test('25 codec/format error mapping', () {
      final mapping = PlaybackErrorMapper.fromException(
        Exception('PlatformException: unsupported codec'),
      );
      expect(mapping.kind, PlaybackErrorKind.unsupportedFormat);
    });

    test('26 action-level failure does not replace viable playback state', () async {
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(controls: controls);
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);
      service.setPlaybackErrorForTest(
        PlaybackErrorKind.network,
        'Network issue',
      );

      controls.rateApplyFails = true;
      await service.setPlaybackRate(1.5);

      expect(service.playbackErrorKind, PlaybackErrorKind.network);
      expect(service.errorMessage, 'Network issue');
      expect(service.isReady, isTrue);
    });
  });

  group('lifecycle preservation', () {
    test('27 existing resume and explicit start position remain unchanged', () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });

      final path = await _createTempMediaFile();
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(path).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final controls = FakePlaybackSessionControls();
      final service = _serviceWithFakeControls(
        controls: controls,
        resolver: resolver,
        openOverride: (svc, uri, gen) async {
          controls.resetSelectionForNewMedia();
          svc.attachSessionControlsForTest(controls);
          svc.simulatePlaybackMetricsForTest(
            duration: const Duration(seconds: 3600),
          );
          final item = svc.currentItem;
          if (item != null) {
            svc.simulateReadyForTest(item);
          }
        },
      );

      await service.play(_item(id: 'item-1', filePath: path));
      expect(service.position, const Duration(seconds: 120));

      await service.play(
        _item(id: 'item-1', filePath: path),
        startPosition: const Duration(seconds: 45),
      );
      expect(service.position, const Duration(seconds: 45));
    });

    test('28 completion still clears eligible resume progress', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PlaybackService();
      final item = _item(id: 'item-1', filePath: r'Y:\Media\a.mp4');

      await service.persistResumeStateForTest(
        item.id,
        const Duration(minutes: 10),
        duration: const Duration(hours: 1),
      );

      service.simulateReadyForTest(item);
      service.simulatePlaybackMetricsForTest(
        duration: const Duration(hours: 1),
        completed: true,
      );
      service.runPlaybackTickForTest();

      final resume = await service.resumeInfoFor(item.id);
      expect(resume, isNull);
    });

    test('29 retry preserves expected start position and resets transient capability state',
        () async {
      final path = await _createTempMediaFile();
      final resolver = _StubResolver(
        (p) => ResolvedMediaLocation.resolved(
          uri: Uri.file(path).toString(),
          providerType: MediaAccessProviderType.localFile,
        ),
      );
      final controls = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [
            PlaybackAudioTrack(id: 'a1', title: 'English'),
            PlaybackAudioTrack(id: 'a2', title: 'French'),
          ],
          subtitleTracks: [
            PlaybackSubtitleTrack(id: 's1', title: 'English CC'),
          ],
          selectedAudioTrackId: 'a1',
        ),
      );
      final service = _serviceWithFakeControls(
        controls: controls,
        resolver: resolver,
      );
      final item = _item(id: 'retry-item', filePath: path);

      await service.play(item, startPosition: const Duration(seconds: 90));
      await service.setPlaybackRate(2.0);
      await service.selectAudioTrack('a2');

      await service.retry(startPosition: const Duration(seconds: 90));

      expect(service.position, const Duration(seconds: 90));
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
      expect(service.hasSessionRateOverride, isFalse);
      expect(service.selectedAudioTrackId, isNull);
    });

    test('30 PlaybackService remains the only owner of backend control calls', () async {
      final controls = FakePlaybackSessionControls(
        snapshot: const PlaybackSessionSnapshot(
          playbackRate: 1.0,
          audioTracks: [
            PlaybackAudioTrack(id: 'a1', title: 'English'),
            PlaybackAudioTrack(id: 'a2', title: 'French'),
          ],
          subtitleTracks: [
            PlaybackSubtitleTrack(id: 's1', title: 'English CC'),
          ],
          selectedAudioTrackId: 'a1',
        ),
      );
      final service = PlaybackService();
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(controls);

      await service.setPlaybackRate(1.5);
      await service.selectAudioTrack('a2');
      await service.selectSubtitleTrack('s1');
      await service.disableSubtitles();

      expect(controls.setRateCallCount, 1);
      expect(controls.lastRequestedRate, 1.5);
      expect(controls.lastAudioTrackId, 'a2');
      expect(controls.lastSubtitleTrackId, 's1');
      expect(controls.disableSubtitlesCalled, isTrue);
      expect(identical(service.sessionControls, controls), isTrue);
    });
  });
}
