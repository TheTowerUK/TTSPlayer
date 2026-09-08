import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/settings/widgets/metadata_provider_settings.dart';
import 'package:ttsplayer/models/application_settings.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy settings without metadataProviders recover safe defaults', () {
    final settings = ApplicationSettings.fromJsonWithRecovery({
      'settingsVersion': ApplicationSettings.currentSettingsVersion,
      'general': <String, Object?>{},
      'libraryProviders': <String, Object?>{},
      'network': <String, Object?>{},
      'playback': <String, Object?>{},
      'diagnostics': <String, Object?>{},
    });

    expect(settings.metadataProviders.externalMetadataEnabled, false);
    expect(settings.metadataProviders.enabledProviderIds, isEmpty);
    expect(
      settings.metadataProviders.metadataRetentionOnDisable,
      ProviderDataRetentionPolicy.retain,
    );
    expect(
      settings.metadataProviders.artworkRetentionOnDisable,
      ProviderDataRetentionPolicy.retain,
    );
  });

  test('metadata provider settings round-trip in the envelope', () {
    final settings = ApplicationSettings.defaults().copyWith(
      metadataProviders: const MetadataProvidersSettings(
        externalMetadataEnabled: true,
        enabledProviderIds: {'open_library'},
      ),
    );

    final restored = ApplicationSettings.fromJson(settings.toJson());

    expect(restored.metadataProviders.toJson(),
        settings.metadataProviders.toJson());
  });

  testWidgets('opt-in disclosure states transmitted and prohibited data',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository();
    await repository.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: Scaffold(body: MetadataProviderSettings()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('external_metadata_enabled')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('metadata_privacy_disclosure')), findsOneWidget);
    expect(find.textContaining('normalized ISBN'), findsOneWidget);
    expect(find.textContaining('normalized title'), findsOneWidget);
    expect(find.textContaining('author'), findsOneWidget);
    expect(find.textContaining('optional year'), findsOneWidget);
    expect(find.textContaining('full paths'), findsOneWidget);
    expect(find.textContaining('directory names'), findsOneWidget);
    expect(find.textContaining('filenames'), findsOneWidget);
    expect(find.textContaining('basenames'), findsOneWidget);
    expect(find.textContaining('file stems'), findsOneWidget);
    expect(find.textContaining('catalogue tree structure'), findsOneWidget);
  });

  testWidgets('enabling requires confirmation and does not enable provider',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository();
    await repository.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: Scaffold(body: MetadataProviderSettings()),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('external_metadata_enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_enable_external_metadata')));
    await tester.pumpAndSettle();

    expect(repository.metadataProviders.externalMetadataEnabled, true);
    expect(repository.metadataProviders.enabledProviderIds, isEmpty);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('open_library_enabled')),
          )
          .value,
      false,
    );
    expect(
        find.byKey(const Key('metadata_retention_disclosure')), findsOneWidget);
  });
}
