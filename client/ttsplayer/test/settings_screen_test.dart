import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/features/settings/settings_screen.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/models/playback/playback_rate_presets.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/playback_platform.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'support/diagnostics_test_harness.dart';

class _RejectPlaybackSaveRepository extends SettingsRepository {
  @override
  Future<SettingsSaveResult> saveDefaultPlaybackRate(double rate) async {
    return const SettingsSaveResult(
      success: false,
      validationErrors: ['Unsupported playback rate.'],
    );
  }
}

Widget _settingsHarness(
  SettingsRepository repository, {
  LibraryMetadataRepository? metadataRepository,
  DiagnosticsService? diagnosticsService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsRepository>.value(value: repository),
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      if (metadataRepository != null)
        ChangeNotifierProvider<LibraryMetadataRepository>.value(
          value: metadataRepository,
        ),
      if (diagnosticsService != null)
        Provider<DiagnosticsService>.value(value: diagnosticsService),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const SettingsScreen(),
    ),
  );
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester,
  SettingsRepository repository, {
  LibraryMetadataRepository? metadataRepository,
  DiagnosticsService? diagnosticsService,
}) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await repository.initialize();
  await tester.pumpWidget(
    _settingsHarness(
      repository,
      metadataRepository: metadataRepository,
      diagnosticsService: diagnosticsService,
    ),
  );
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('save_network_settings')).evaluate().isNotEmpty &&
        (find.byKey(const Key('default_playback_speed')).evaluate().isNotEmpty ||
            find
                .byKey(const Key('playback_speed_readonly'))
                .evaluate()
                .isNotEmpty)) {
      break;
    }
  }
  expect(tester.takeException(), isNull);
}

Future<void> _selectPlaybackRate(WidgetTester tester, double rate) async {
  await tester.ensureVisible(find.byKey(const Key('default_playback_speed')));
  await tester.tap(find.byKey(const Key('default_playback_speed')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(PlaybackRatePresets.displayLabel(rate)).last);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    playbackSpeedSettingsSupportedOverride = () => true;
    PackageInfo.setMockInitialValues(
      appName: 'TTSPlayer',
      packageName: 'ttsplayer',
      version: '0.4.0-dev.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    playbackSpeedSettingsSupportedOverride = null;
  });

  group('SettingsScreen', () {
    testWidgets('renders grouped sections', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Library & Providers'), findsOneWidget);
      expect(find.text('Playback'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Diagnostics & Advanced'), findsOneWidget);
      expect(find.byKey(const Key('catalogue_fetch_timeout')), findsOneWidget);
      expect(find.byKey(const Key('default_playback_speed')), findsOneWidget);
      expect(find.byKey(const Key('app_version')), findsOneWidget);
      expect(find.byKey(const Key('save_settings')), findsOneWidget);
      expect(find.byKey(const Key('save_network_settings')), findsOneWidget);
      expect(find.byKey(const Key('open_provider_settings')), findsNothing);
      expect(find.byKey(const Key('http_catalogue_url')), findsOneWidget);
    });

    testWidgets('loads network timeout from repository', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveNetworkSettings(
        const NetworkSettings(catalogueFetchTimeoutSeconds: 45),
      );

      await _pumpSettingsScreen(tester, repository);

      final field = tester.widget<TextField>(
        find.byKey(const Key('catalogue_fetch_timeout')),
      );
      expect(field.controller?.text, '45');
    });

    testWidgets('save persists network timeout', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      await tester.enterText(
        find.byKey(const Key('catalogue_fetch_timeout')),
        '30',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save_network_settings')));
      await tester.tap(find.byKey(const Key('save_network_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Network settings saved.'), findsOneWidget);

      final reloaded = SettingsRepository();
      await reloaded.initialize();
      expect(reloaded.catalogueFetchTimeoutSeconds, 30);
    });

    testWidgets('blocks invalid timeout with validation errors', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      await tester.enterText(
        find.byKey(const Key('catalogue_fetch_timeout')),
        '999',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save_network_settings')));
      await tester.tap(find.byKey(const Key('save_network_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('network_validation_errors')), findsOneWidget);
    });

    testWidgets('scrolls at constrained height', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();

      tester.view.physicalSize = const Size(900, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_settingsHarness(repository));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(Scrollable).evaluate().isNotEmpty) break;
      }

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('reset_all_settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsScreen — playback (M4.4 Step 3)', () {
    testWidgets('15 playback section shows current saved speed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(1.5);

      await _pumpSettingsScreen(tester, repository);

      expect(
        find.textContaining(PlaybackRatePresets.displayLabel(1.5)),
        findsWidgets,
      );
    });

    testWidgets('16 user can select a different preset', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      await _selectPlaybackRate(tester, 1.25);

      final saveButton = find.byKey(const Key('save_playback_settings'));
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('17 save persists the selected value', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      await _selectPlaybackRate(tester, 2.0);
      await tester.ensureVisible(find.byKey(const Key('save_playback_settings')));
      await tester.tap(find.byKey(const Key('save_playback_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Playback settings saved.'), findsOneWidget);

      final reloaded = SettingsRepository();
      await reloaded.initialize();
      expect(reloaded.defaultPlaybackRate, 2.0);
    });

    testWidgets('18 validation failure shows feedback and preserves prior value',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsRepository.storageKey: jsonEncode(
          ApplicationSettings.defaults().copyWith(
            playback: const PlaybackSettings(defaultPlaybackSpeed: 1.25),
          ).toJson(),
        ),
      });
      final repository = _RejectPlaybackSaveRepository();
      await _pumpSettingsScreen(tester, repository);

      await _selectPlaybackRate(tester, 1.5);
      await tester.ensureVisible(find.byKey(const Key('save_playback_settings')));
      await tester.tap(find.byKey(const Key('save_playback_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('playback_validation_errors')), findsOneWidget);
      expect(repository.defaultPlaybackRate, 1.25);
    });

    testWidgets('19 reset playback restores 1.0', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(2.0);
      await _pumpSettingsScreen(tester, repository);

      await tester.ensureVisible(find.byKey(const Key('reset_playback_settings')));
      await tester.tap(find.byKey(const Key('reset_playback_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_reset_playback')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.defaultPlaybackRate, PlaybackRatePresets.defaultRate);
      expect(
        find.textContaining(PlaybackRatePresets.displayLabel(1.0)),
        findsWidgets,
      );
    });

    testWidgets('20 unsaved playback change triggers navigation warning',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      await _selectPlaybackRate(tester, 1.5);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets('21 reset all restores playback default', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(2.0);
      await _pumpSettingsScreen(tester, repository);

      await tester.ensureVisible(find.byKey(const Key('reset_all_settings')));
      await tester.tap(find.byKey(const Key('reset_all_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_reset_all_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.defaultPlaybackRate, PlaybackRatePresets.defaultRate);
    });

    testWidgets('22 reset all preserves favourites', (tester) async {
      SharedPreferences.setMockInitialValues({
        LibraryMetadataRepository.storageKey: jsonEncode({
          'metadataVersion': 1,
          'favourites': {
            'items': [
              {
                'id': 'item-1',
                'favouritedAt': '2026-07-13T12:00:00.000Z',
              },
            ],
            'folders': [],
          },
        }),
      });
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();

      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(1.5);
      await _pumpSettingsScreen(
        tester,
        repository,
        metadataRepository: metadata,
      );

      await tester.ensureVisible(find.byKey(const Key('reset_all_settings')));
      await tester.tap(find.byKey(const Key('reset_all_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_reset_all_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(metadata.favouriteItems.map((item) => item.id), contains('item-1'));
      expect(repository.defaultPlaybackRate, PlaybackRatePresets.defaultRate);
    });

    testWidgets('23 reset all preserves resume progress', (tester) async {
      SharedPreferences.setMockInitialValues({
        'position_item-1': 120,
        'duration_item-1': 3600,
      });
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(1.5);
      await _pumpSettingsScreen(tester, repository);

      await tester.ensureVisible(find.byKey(const Key('reset_all_settings')));
      await tester.tap(find.byKey(const Key('reset_all_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_reset_all_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('position_item-1'), 120);
      expect(prefs.getInt('duration_item-1'), 3600);
    });

    testWidgets('24 layout and scrolling work at 900×420', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();

      tester.view.physicalSize = const Size(900, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_settingsHarness(repository));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(Scrollable).evaluate().isNotEmpty) break;
      }

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('save_playback_settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('25 keyboard interaction works for the speed control',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await _pumpSettingsScreen(tester, repository);

      final dropdown = find.byKey(const Key('default_playback_speed'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      final saveButton = find.byKey(const Key('save_playback_settings'));
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });

    testWidgets('26 unsupported platform hides editable speed dropdown',
        (tester) async {
      playbackSpeedSettingsSupportedOverride = () => false;
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(1.5);
      await _pumpSettingsScreen(tester, repository);

      expect(find.byKey(const Key('default_playback_speed')), findsNothing);
      expect(find.byKey(const Key('playback_speed_readonly')), findsOneWidget);
      expect(find.textContaining('Normal (1×)'), findsNothing);
      expect(find.textContaining('1.5×'), findsOneWidget);

      final saveButton = find.byKey(const Key('save_playback_settings'));
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    });

    testWidgets('27 unsupported platform preserves stored speed on reload',
        (tester) async {
      playbackSpeedSettingsSupportedOverride = () => false;
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.initialize();
      await repository.saveDefaultPlaybackRate(1.25);
      await _pumpSettingsScreen(tester, repository);

      expect(find.textContaining('1.25×'), findsOneWidget);
      expect(repository.defaultPlaybackRate, 1.25);
    });
  });

  group('SettingsScreen — diagnostics (M4.4.6 Step 4)', () {
    testWidgets('shows View diagnostics entry', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'TTSPlayer',
        packageName: 'ttsplayer',
        version: '0.5.0-dev',
        buildNumber: '42',
        buildSignature: 'sig',
        installerStore: null,
      );
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      final diagnostics = await buildDiagnosticsHarness();
      await _pumpSettingsScreen(
        tester,
        repository,
        diagnosticsService: diagnostics,
      );

      expect(find.byKey(const Key('view_diagnostics')), findsOneWidget);
      expect(find.text('View diagnostics'), findsOneWidget);
    });

    testWidgets('opens DiagnosticsScreen without capturing before navigation',
        (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'TTSPlayer',
        packageName: 'ttsplayer',
        version: '0.5.0-dev',
        buildNumber: '42',
        buildSignature: 'sig',
        installerStore: null,
      );
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      final config = MediaProviderConfigService();
      await config.load();
      final wrapped = FakeDiagnosticsService(
        catalogService: StubCatalogService(
          stubCatalog: diagnosticsCatalog(identity: 'REV-SET', itemCount: 1),
        ),
        artworkService: ArtworkService(fileExists: (_) => true),
        searchService: SearchService(),
        playbackService: PlaybackService(),
        mediaProviderConfigService: config,
        libraryMetadataRepository: metadata,
        applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
      );

      await _pumpSettingsScreen(
        tester,
        repository,
        diagnosticsService: wrapped,
      );

      expect(wrapped.captureCount, 0);

      await tester.ensureVisible(find.byKey(const Key('view_diagnostics')));
      await tester.tap(find.byKey(const Key('view_diagnostics')));
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsScreen), findsOneWidget);
      expect(wrapped.captureCount, greaterThanOrEqualTo(1));
    });

    testWidgets('unsaved network changes remain after returning from diagnostics',
        (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'TTSPlayer',
        packageName: 'ttsplayer',
        version: '0.5.0-dev',
        buildNumber: '42',
        buildSignature: 'sig',
        installerStore: null,
      );
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      final diagnostics = await buildDiagnosticsHarness();
      await _pumpSettingsScreen(
        tester,
        repository,
        diagnosticsService: diagnostics,
      );

      await tester.enterText(
        find.byKey(const Key('catalogue_fetch_timeout')),
        '45',
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('view_diagnostics')));
      await tester.tap(find.byKey(const Key('view_diagnostics')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('45'), findsOneWidget);
      final saveButton = find.byKey(const Key('save_network_settings'));
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    });
  });
}
