import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/settings/media_provider_settings_screen.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_catalogue_provider.dart';
import 'package:ttsplayer/services/media_access/media_provider_config.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';

Widget _settingsHarness(MediaProviderConfigService service) {
  return ChangeNotifierProvider<MediaProviderConfigService>.value(
    value: service,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const MediaProviderSettingsScreen(),
    ),
  );
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester,
  MediaProviderConfigService service,
) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await service.load();
  await tester.pumpWidget(_settingsHarness(service));
  await tester.pump();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byKey(const Key('save_settings')), findsOneWidget);
}

TextEditingController? _fieldController(WidgetTester tester, Key key) {
  final field = tester.widget<TextField>(find.byKey(key));
  return field.controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaProviderConfig.fromDraft', () {
    test('builds mixed local and HTTPS catalogue providers', () {
      final config = MediaProviderConfig.fromDraft(
        localCataloguePaths: const [r'Y:\Media\catalog.json'],
        httpCatalogueUrl: 'https://192.168.0.10:8443/catalog.json',
        mediaRoots: const [r'Y:\Media'],
        httpMediaBaseUrl: 'https://192.168.0.10:8443/media/',
        mode: MediaAccessMode.httpRequired,
      );

      expect(config.localCataloguePaths, [r'Y:\Media\catalog.json']);
      expect(
        config.httpCatalogueUrl,
        'https://192.168.0.10:8443/catalog.json',
      );
      expect(config.mediaAccess.mode, MediaAccessMode.httpRequired);
      expect(config.validate(), isEmpty);
    });
  });

  group('MediaProviderSettingsScreen', () {
    testWidgets('loads persisted config into the form', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();
      final custom = MediaProviderConfig(
        catalogueProviders: const [
          MediaCatalogueProviderDefinition.http(
            'https://192.168.0.10:8443/catalog.json',
          ),
        ],
        mediaAccess: MediaAccessConfig.defaults(
          httpMediaBaseUrl: 'https://192.168.0.10:8443/media/',
          mode: MediaAccessMode.httpRequired,
        ),
      );
      await service.save(custom);

      await _pumpSettingsScreen(tester, service);

      expect(
        _fieldController(tester, const Key('http_catalogue_url'))?.text,
        'https://192.168.0.10:8443/catalog.json',
      );
      expect(
        _fieldController(tester, const Key('http_media_base_url'))?.text,
        'https://192.168.0.10:8443/media/',
      );
    });

    testWidgets('save persists valid settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();
      await _pumpSettingsScreen(tester, service);

      await tester.enterText(
        find.byKey(const Key('http_catalogue_url')),
        'http://192.168.0.10:8443/catalog.json',
      );
      await tester.enterText(
        find.byKey(const Key('http_media_base_url')),
        'http://192.168.0.10:8443/media/',
      );
      await tester.ensureVisible(find.byKey(const Key('save_settings')));
      await tester.tap(find.byKey(const Key('save_settings')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Settings saved.'), findsOneWidget);
      expect(find.byKey(const Key('validation_warnings')), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(MediaProviderConfigService.prefKey);
      expect(raw, isNotNull);

      final decoded =
          MediaProviderConfig.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
      expect(
        decoded.httpCatalogueUrl,
        'http://192.168.0.10:8443/catalog.json',
      );
      expect(
        decoded.mediaAccess.httpMediaBaseUrl,
        'http://192.168.0.10:8443/media/',
      );
    });

    testWidgets('rejects plain HTTP when HTTP required mode is selected',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();
      await _pumpSettingsScreen(tester, service);

      await tester.tap(find.byKey(const Key('media_access_mode_http')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('http_catalogue_url')),
        'http://192.168.0.10:8443/catalog.json',
      );
      await tester.enterText(
        find.byKey(const Key('http_media_base_url')),
        'http://192.168.0.10:8443/media/',
      );
      await tester.ensureVisible(find.byKey(const Key('save_settings')));
      await tester.tap(find.byKey(const Key('save_settings')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validation_errors')), findsOneWidget);
      expect(find.textContaining('https://'), findsWidgets);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);
    });

    testWidgets('shows validation errors when save would be invalid',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();
      await _pumpSettingsScreen(tester, service);

      for (final key in ['local_catalogue_0', 'local_catalogue_1']) {
        await tester.enterText(find.byKey(Key(key)), '');
      }
      await tester.enterText(find.byKey(const Key('http_catalogue_url')), '');

      await tester.ensureVisible(find.byKey(const Key('save_settings')));
      await tester.tap(find.byKey(const Key('save_settings')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validation_errors')), findsOneWidget);
      expect(
        find.textContaining('At least one catalogue provider'),
        findsOneWidget,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);
    });

    testWidgets('reset restores defaults and clears persisted config',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();
      await service.save(
        MediaProviderConfig(
          catalogueProviders: const [
            MediaCatalogueProviderDefinition.http(
              'http://192.168.0.10:8443/catalog.json',
            ),
          ],
          mediaAccess: MediaAccessConfig.defaults(
            httpMediaBaseUrl: 'http://192.168.0.10:8443/media/',
          ),
        ),
      );

      await _pumpSettingsScreen(tester, service);

      await tester.ensureVisible(find.byKey(const Key('reset_settings')));
      await tester.tap(find.byKey(const Key('reset_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_reset_settings')));
      await tester.pumpAndSettle();

      expect(find.text('Settings reset to defaults.'), findsOneWidget);
      expect(
        _fieldController(tester, const Key('http_catalogue_url'))?.text,
        isEmpty,
      );
      expect(
        find.textContaining(r'Y:\Media\catalog.json'),
        findsWidgets,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MediaProviderConfigService.prefKey), isNull);
    });

    testWidgets('reload after save shows persisted values in a new session',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MediaProviderConfigService();
      await _pumpSettingsScreen(tester, service);

      await tester.enterText(
        find.byKey(const Key('http_catalogue_url')),
        'http://192.168.0.10:8443/catalog.json',
      );
      await tester.ensureVisible(find.byKey(const Key('save_settings')));
      await tester.tap(find.byKey(const Key('save_settings')));
      await tester.pumpAndSettle();

      final reloadedService = MediaProviderConfigService();
      await _pumpSettingsScreen(tester, reloadedService);

      expect(
        _fieldController(tester, const Key('http_catalogue_url'))?.text,
        'http://192.168.0.10:8443/catalog.json',
      );
    });
  });
}
