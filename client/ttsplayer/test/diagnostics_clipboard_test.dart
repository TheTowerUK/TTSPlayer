import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_export_coordinator.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'support/diagnostics_test_harness.dart';

Future<(FakeDiagnosticsService, FakeClipboardWriter)> _harness() async {
  SharedPreferences.setMockInitialValues({});
  final metadata = LibraryMetadataRepository();
  await metadata.initialize();
  final config = MediaProviderConfigService();
  await config.load();
  final service = FakeDiagnosticsService(
    catalogService: StubCatalogService(
      stubCatalog: diagnosticsCatalog(identity: 'REV-COPY', itemCount: 3),
    ),
    artworkService: ArtworkService(fileExists: (_) => true),
    searchService: SearchService(),
    playbackService: PlaybackService(),
    mediaProviderConfigService: config,
    libraryMetadataRepository: metadata,
    applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
  );
  return (service, FakeClipboardWriter());
}

Future<void> _pump(
  WidgetTester tester,
  DiagnosticsService service,
  FakeClipboardWriter clipboard,
) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    diagnosticsScreenHarness(service, clipboardWriter: clipboard),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('coordinator', () {
    test('writes formatted export on success', () async {
      final (service, clipboard) = await _harness();
      final coordinator = DiagnosticsExportCoordinator(
        diagnosticsService: service,
        clipboardWriter: clipboard,
      );

      final result = await coordinator.copyDiagnostics();

      expect(result, isA<DiagnosticsExportSuccess>());
      expect(clipboard.writeCount, 1);
      expect(clipboard.lastWrittenText, contains('TTSPlayer Diagnostics'));
      expect(clipboard.lastWrittenText, contains('=== Cache ==='));
    });

    test('returns capture failure without writing clipboard', () async {
      final (service, clipboard) = await _harness();
      service.throwOnCapture = StateError('fail');
      final coordinator = DiagnosticsExportCoordinator(
        diagnosticsService: service,
        clipboardWriter: clipboard,
      );

      final result = await coordinator.copyDiagnostics();

      expect(result, isA<DiagnosticsExportCaptureFailure>());
      expect(clipboard.writeCount, 0);
    });

    test('returns format failure without writing clipboard', () async {
      final (service, clipboard) = await _harness();
      service.throwOnFormat = StateError('format');
      final coordinator = DiagnosticsExportCoordinator(
        diagnosticsService: service,
        clipboardWriter: clipboard,
      );

      final result = await coordinator.copyDiagnostics();

      expect(result, isA<DiagnosticsExportFormatFailure>());
      expect(clipboard.writeCount, 0);
    });

    test('returns clipboard failure after capture', () async {
      final (service, clipboard) = await _harness();
      clipboard.throwOnWrite = Exception('denied');
      final coordinator = DiagnosticsExportCoordinator(
        diagnosticsService: service,
        clipboardWriter: clipboard,
      );

      final result = await coordinator.copyDiagnostics();

      expect(result, isA<DiagnosticsExportClipboardFailure>());
      expect(service.captureCount, 1);
    });
  });

  group('action visibility', () {
    testWidgets('Copy diagnostics appears after snapshot loads', (tester) async {
      final (service, clipboard) = await _harness();
      await _pump(tester, service, clipboard);

      expect(find.byKey(const Key('copy_diagnostics')), findsOneWidget);
      expect(find.text('Copy diagnostics'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Export'), findsNothing);
    });

    testWidgets('Copy is not shown during initial loading', (tester) async {
      final (service, clipboard) = await _harness();
      service.captureDelay = const Duration(milliseconds: 200);
      await tester.pumpWidget(
        diagnosticsScreenHarness(service, clipboardWriter: clipboard),
      );
      await tester.pump();

      expect(find.byKey(const Key('copy_diagnostics')), findsNothing);
      expect(find.byKey(const Key('diagnostics_loading')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });
  });

  group('successful copy', () {
    testWidgets('captures fresh snapshot and writes formatted text', (tester) async {
      final (service, clipboard) = await _harness();
      service.snapshotFactory = (count) => minimalSnapshot(
            capturedAt: DateTime.utc(2026, 7, 16, 14, 0, count),
          );

      await _pump(tester, service, clipboard);
      expect(service.captureCount, 1);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(service.captureCount, 2);
      expect(clipboard.writeCount, 1);
      expect(clipboard.lastWrittenText, isNotNull);
      expect(clipboard.lastWrittenText, contains('=== Application ==='));
      expect(clipboard.lastWrittenText, contains('=== Library ==='));
      expect(find.text('Diagnostics copied to clipboard.'), findsOneWidget);
    });

    testWidgets('updates displayed snapshot on success (Option A)', (tester) async {
      final (service, clipboard) = await _harness();
      service.snapshotFactory = (count) => minimalSnapshot(
            capturedAt: DateTime.utc(2026, 7, 16, 15, 0, count),
          );

      await _pump(tester, service, clipboard);

      final before = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      );
      expect(before.data, contains('2026-07-16T15:00:01'));

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      final after = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      );
      expect(after.data, contains('2026-07-16T15:00:02'));
      expect(clipboard.lastWrittenText, contains('2026-07-16T15:00:02.000Z'));
    });
  });

  group('duplicate taps', () {
    testWidgets('repeated taps produce one capture and one write', (tester) async {
      final (service, clipboard) = await _harness();
      service.captureDelay = const Duration(milliseconds: 200);

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(service.captureCount, 2);
      expect(clipboard.writeCount, 1);
    });
  });

  group('capture failure', () {
    testWidgets('preserves snapshot and shows safe feedback', (tester) async {
      final (service, clipboard) = await _harness();
      service.snapshotFactory = (count) {
        if (count >= 2) {
          throw StateError('capture failed');
        }
        return minimalSnapshot(capturedAt: DateTime.utc(2026, 7, 16, 16));
      };

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(clipboard.writeCount, 0);
      expect(find.text('Diagnostics could not be collected. Try again.'), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.byKey(const Key('diagnostics_app_version')), findsOneWidget);
    });
  });

  group('format failure', () {
    testWidgets('does not write clipboard on format failure', (tester) async {
      final (service, clipboard) = await _harness();
      service.throwOnFormat = StateError('format failed');

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(clipboard.writeCount, 0);
      expect(find.text('Diagnostics could not be copied.'), findsOneWidget);
    });
  });

  group('clipboard failure', () {
    testWidgets('shows safe feedback and re-enables copy', (tester) async {
      final (service, clipboard) = await _harness();
      clipboard.throwOnWrite = Exception('clipboard denied');

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics could not be copied.'), findsOneWidget);
      expect(find.textContaining('clipboard denied'), findsNothing);

      clipboard.throwOnWrite = null;
      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(clipboard.writeCount, 2);
      expect(clipboard.lastWrittenText, contains('TTSPlayer Diagnostics'));
    });
  });

  group('redaction', () {
    testWidgets('clipboard text excludes sensitive patterns', (tester) async {
      final (service, clipboard) = await _harness();
      service.snapshotFactory = (_) => minimalSnapshot(
            provider: const ProviderDiagnostics(
              status: DiagnosticSectionStatus.complete,
              lastCycleErrorSummary: 'Load failed at [redacted-path]',
            ),
          );

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      final text = clipboard.lastWrittenText!;
      const forbidden = [
        r'Y:\Media',
        r'C:\Users',
        r'\\SERVER',
        '/volume1/Media',
        'file://',
        'http://',
        'https://',
        'token=',
        'api_key',
        'password',
        'user:password@',
        'stack trace',
      ];
      for (final fragment in forbidden) {
        expect(text.contains(fragment), isFalse, reason: fragment);
      }
      expect(exportContainsSensitiveData(text), isFalse);
    });
  });

  group('refresh interaction', () {
    testWidgets('refresh disabled while copy in flight', (tester) async {
      final (service, clipboard) = await _harness();
      service.captureDelay = const Duration(milliseconds: 200);

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump();

      final refreshButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('refresh_diagnostics_button')),
      );
      expect(refreshButton.onPressed, isNull);
      expect(find.byKey(const Key('diagnostics_copy_progress')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    });

    testWidgets('copy disabled while refresh in flight', (tester) async {
      final (service, clipboard) = await _harness();
      service.captureDelay = const Duration(milliseconds: 200);

      await _pump(tester, service, clipboard);

      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump();

      final copyButton = tester.widget<FilledButton>(
        find.byKey(const Key('copy_diagnostics')),
      );
      expect(copyButton.onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    });
  });

  group('async safety', () {
    testWidgets('disposing during copy does not throw', (tester) async {
      final (service, clipboard) = await _harness();
      service.captureDelay = const Duration(milliseconds: 200);

      await tester.pumpWidget(
        diagnosticsScreenHarness(service, clipboardWriter: clipboard),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });
  });

  group('integration non-mutation', () {
    testWidgets('copy does not build search index', (tester) async {
      final search = SearchService();
      final metadata = LibraryMetadataRepository();
      await metadata.initialize();
      final service = FakeDiagnosticsService(
        catalogService: StubCatalogService(
          stubCatalog: diagnosticsCatalog(identity: 'REV-NOCOPY-IDX', itemCount: 2),
        ),
        artworkService: ArtworkService(fileExists: (_) => true),
        searchService: search,
        playbackService: PlaybackService(),
        mediaProviderConfigService: MediaProviderConfigService(),
        libraryMetadataRepository: metadata,
        applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
      );
      final clipboard = FakeClipboardWriter();

      await _pump(tester, service, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 0);
      expect(clipboard.writeCount, 1);
    });

    testWidgets('end-to-end with real DiagnosticsService', (tester) async {
      final realService = await buildDiagnosticsHarness(
        catalog: diagnosticsCatalog(identity: 'REV-E2E', itemCount: 4),
      );
      final clipboard = FakeClipboardWriter();

      await _pump(tester, realService, clipboard);

      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      expect(clipboard.writeCount, 1);
      expect(clipboard.lastWrittenText, contains('=== Provider ==='));
      expect(clipboard.lastWrittenText, contains('Items: 4'));
      expect(exportContainsSensitiveData(clipboard.lastWrittenText!), isFalse);
    });
  });
}
