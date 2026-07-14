import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/playback/playback_rate_presets.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_access_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/resolved_media_location.dart';
import 'package:ttsplayer/services/playback/unsupported_session_controls.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'playback_service_extensions_test.dart';

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
  String title = 'Test',
}) {
  return MediaItem(id: id, title: title, filePath: filePath);
}

PlaybackService _wiredService({
  required SettingsRepository settings,
  required FakePlaybackSessionControls controls,
  required String mediaPath,
}) {
  final resolver = _StubResolver(
    (p) => ResolvedMediaLocation.resolved(
      uri: Uri.file(p).toString(),
      providerType: MediaAccessProviderType.localFile,
    ),
  );

  return PlaybackService(
    mediaLocationResolver: resolver,
    defaultPlaybackRateProvider: () => settings.defaultPlaybackRate,
    mediaKitInitOverride: (service, uri, generation) async {
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

Future<String> _tempMediaFile() async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_playback_settings_');
  final file = File('${dir.path}/sample.mp4');
  await file.writeAsBytes([0, 1, 2, 3]);
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaybackService default-rate wiring', () {
    test('26 receives 1.0 when settings are absent', () async {
      final settings = SettingsRepository();
      await settings.initialize();

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'a', filePath: path));
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
      expect(service.hasSessionRateOverride, isFalse);
    });

    test('27 persisted default is applied when new media opens', () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.5);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'a', filePath: path));
      expect(service.playbackRate, 1.5);
      expect(controls.lastRequestedRate, 1.5);
    });

    test('28 changing saved default affects the next new media', () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.25);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'first', filePath: path));
      expect(service.playbackRate, 1.25);

      await settings.saveDefaultPlaybackRate(2.0);
      await service.play(_item(id: 'second', filePath: path, title: 'Second'));
      expect(service.playbackRate, 2.0);
      expect(controls.lastRequestedRate, 2.0);
    });

    test('29 changing saved default does not alter the current active session',
        () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.25);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'a', filePath: path));
      await service.setPlaybackRate(1.5);
      expect(service.playbackRate, 1.5);

      await settings.saveDefaultPlaybackRate(2.0);
      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isTrue);
    });

    test('30 retry reapplies the latest saved default according to ADR', () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.25);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(
        _item(id: 'a', filePath: path),
        startPosition: const Duration(seconds: 30),
      );
      await service.setPlaybackRate(2.0);

      await settings.saveDefaultPlaybackRate(1.5);
      await service.retry(startPosition: const Duration(seconds: 30));

      expect(service.playbackRate, 1.5);
      expect(service.hasSessionRateOverride, isFalse);
      expect(service.position, const Duration(seconds: 30));
    });

    test('31 session override still wins for the current media', () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.25);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'a', filePath: path));
      await service.setPlaybackRate(2.0);

      expect(service.playbackRate, 2.0);
      expect(service.hasSessionRateOverride, isTrue);
    });

    test('32 stop/dispose resets to the saved-default lifecycle', () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.5);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'a', filePath: path));
      await service.setPlaybackRate(2.0);
      await service.stop();

      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
      expect(service.hasSessionRateOverride, isFalse);

      await service.play(_item(id: 'b', filePath: path, title: 'Second'));
      expect(service.playbackRate, 1.5);
    });

    test('33 invalid stored value never reaches the backend', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: jsonEncode({
          'settingsVersion': 1,
          'general': {},
          'libraryProviders': {
            'providerConfig':
                ApplicationSettings.defaults().libraryProviders.providerConfig.toJson(),
          },
          'network': {'catalogueFetchTimeoutSeconds': 15},
          'playback': {'defaultPlaybackSpeed': 9.9},
          'diagnostics': {},
        }),
      });

      final settings = SettingsRepository();
      await settings.load();
      expect(settings.defaultPlaybackRate, PlaybackRatePresets.defaultRate);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'a', filePath: path));
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
      expect(controls.lastRequestedRate, PlaybackRatePresets.defaultRate);
    });

    test('34 unsupported backend remains at 1.0 regardless of persisted preference',
        () async {
      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(2.0);

      final service = PlaybackService(
        defaultPlaybackRateProvider: () => settings.defaultPlaybackRate,
      );
      service.simulateReadyForTest(_item(id: 'a', filePath: r'Y:\Media\a.mp4'));
      service.attachSessionControlsForTest(const UnsupportedSessionControls());

      final result = await service.setPlaybackRate(2.0);
      expect(result.isSuccess, isFalse);
      expect(service.playbackRate, PlaybackRatePresets.defaultRate);
    });

    test('35 existing resume behaviour remains unchanged with settings wiring',
        () async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });

      final settings = SettingsRepository();
      await settings.initialize();
      await settings.saveDefaultPlaybackRate(1.5);

      final controls = FakePlaybackSessionControls();
      final path = await _tempMediaFile();
      final service = _wiredService(
        settings: settings,
        controls: controls,
        mediaPath: path,
      );

      await service.play(_item(id: 'item-1', filePath: path));
      expect(service.position, const Duration(seconds: 120));
      expect(service.playbackRate, 1.5);
    });
  });
}
