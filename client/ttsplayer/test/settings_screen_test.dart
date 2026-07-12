import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/settings/settings_screen.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';

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
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await repository.initialize();
  await tester.pumpWidget(_settingsHarness(repository));
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('save_settings')).evaluate().isNotEmpty) break;
  }
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'TTSPlayer',
      packageName: 'ttsplayer',
      version: '0.4.0-dev.1',
      buildNumber: '1',
      buildSignature: '',
    );
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
      expect(find.byKey(const Key('app_version')), findsOneWidget);
      expect(find.byKey(const Key('save_settings')), findsOneWidget);
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
      await tester.ensureVisible(find.byKey(const Key('save_settings')));
      await tester.tap(find.byKey(const Key('save_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Settings saved.'), findsOneWidget);

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
      await tester.ensureVisible(find.byKey(const Key('save_settings')));
      await tester.tap(find.byKey(const Key('save_settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('validation_errors')), findsOneWidget);
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
}
