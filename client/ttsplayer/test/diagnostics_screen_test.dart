import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';

import 'support/diagnostics_test_harness.dart';

Future<FakeDiagnosticsService> _fakeService() async {
  SharedPreferences.setMockInitialValues({});
  final metadata = LibraryMetadataRepository();
  await metadata.initialize();
  final config = MediaProviderConfigService();
  await config.load();
  return FakeDiagnosticsService(
    catalogService: StubCatalogService(
      stubCatalog: diagnosticsCatalog(identity: 'REV-UI', itemCount: 3),
    ),
    artworkService: ArtworkService(fileExists: (_) => true),
    searchService: SearchService(),
    playbackService: PlaybackService(),
    mediaProviderConfigService: config,
    libraryMetadataRepository: metadata,
    applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
  );
}

Future<void> _pumpDiagnostics(
  WidgetTester tester,
  FakeDiagnosticsService service,
) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(diagnosticsScreenHarness(service));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('initial loading', () {
    testWidgets('shows loading then all section headings', (tester) async {
      final service = await _fakeService()
        ..captureDelay = const Duration(milliseconds: 100);

      await _pumpDiagnostics(tester, service);
      expect(find.byKey(const Key('diagnostics_loading')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Catalogue'), findsOneWidget);
      expect(find.text('Cache'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Playback'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.textContaining('Instance of'), findsNothing);
    });
  });

  group('section rendering', () {
    testWidgets('renders application and catalogue values', (tester) async {
      final service = await _fakeService();
      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_app_version')), findsOneWidget);
      expect(find.textContaining('0.5.0-dev'), findsWidgets);
      expect(find.byKey(const Key('diagnostics_catalogue_libraries')), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('search no-index state shows No', (tester) async {
      final service = await _fakeService();
      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_search_has_index')), findsOneWidget);
      expect(find.text('No'), findsWidgets);
    });

    testWidgets('search built-index state', (tester) async {
      final service = await _fakeService()
        ..snapshotFactory = (_) => minimalSnapshot(
              search: const SearchDiagnostics(
                status: DiagnosticSectionStatus.complete,
                hasIndex: true,
                indexBuildCount: 1,
                indexedItemCount: 5,
                indexMatchesActiveCatalogue: true,
              ),
            );

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.text('Yes'), findsWidgets);
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('playback inactive uses not applicable session fields', (tester) async {
      final service = await _fakeService();
      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_playback_active')), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Not applicable'), findsWidgets);
    });

    testWidgets('library zero favourites render as 0', (tester) async {
      final service = await _fakeService();
      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_library_favourites')), findsOneWidget);
      final favourites = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_library_favourites')),
      );
      expect(favourites.data, '0');
    });
  });

  group('status handling', () {
    testWidgets('partial cache section shows partial banner', (tester) async {
      final service = await _fakeService()
        ..snapshotFactory = (_) => minimalSnapshot(
              cache: const CacheDiagnostics(
                status: DiagnosticSectionStatus.partial,
                artworkCandidateCount: 1,
              ),
            );

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.textContaining('Partial'), findsWidgets);
    });

    testWidgets('unavailable library section still renders others', (tester) async {
      final service = await _fakeService()
        ..snapshotFactory = (_) => minimalSnapshot(omitLibrary: true);

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_section_library')), findsOneWidget);
      expect(find.byKey(const Key('diagnostics_section_application')), findsOneWidget);
    });
  });

  group('refresh', () {
    testWidgets('refresh captures new snapshot and updates captured time', (tester) async {
      final service = await _fakeService()
        ..snapshotFactory = (count) => minimalSnapshot(
              capturedAt: DateTime.utc(2026, 7, 16, 10, 0, count),
            );

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      final firstCaptured = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      );
      expect(firstCaptured.data, contains('2026-07-16T10:00:01'));

      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pumpAndSettle();

      final secondCaptured = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      );
      expect(secondCaptured.data, contains('2026-07-16T10:00:02'));
      expect(service.captureCount, 2);
    });

    testWidgets('refresh failure preserves previous snapshot', (tester) async {
      final service = await _fakeService()
        ..snapshotFactory = (count) {
          if (count == 2) {
            throw StateError('refresh failed');
          }
          return minimalSnapshot(capturedAt: DateTime.utc(2026, 7, 16, 12));
        };

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_refresh_error')), findsOneWidget);
      expect(find.byKey(const Key('diagnostics_app_version')), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('duplicate refresh taps do not overlap captures', (tester) async {
      final service = await _fakeService()
        ..captureDelay = const Duration(milliseconds: 200);

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(service.captureCount, 2);
    });
  });

  group('redaction regression', () {
    testWidgets('does not show sensitive path or URL fragments', (tester) async {
      final service = await _fakeService()
        ..snapshotFactory = (_) => minimalSnapshot(
              provider: const ProviderDiagnostics(
                status: DiagnosticSectionStatus.complete,
                lastCycleErrorSummary: 'Load failed at [redacted-path]',
              ),
            );

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.textContaining(r'Y:\Media'), findsNothing);
      expect(find.textContaining(r'\\SERVER'), findsNothing);
      expect(find.textContaining('file://'), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
      expect(find.textContaining('token='), findsNothing);
      expect(find.textContaining('password'), findsNothing);
    });
  });

  group('async safety', () {
    testWidgets('disposing during capture does not throw', (tester) async {
      final service = await _fakeService()
        ..captureDelay = const Duration(milliseconds: 200);

      await _pumpDiagnostics(tester, service);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });

    testWidgets('initial capture failure shows retry', (tester) async {
      final service = await _fakeService()..throwOnCapture = StateError('fail');

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('diagnostics_screen_error')), findsOneWidget);
      expect(find.byKey(const Key('diagnostics_retry')), findsOneWidget);
    });
  });

  group('integration non-mutation', () {
    testWidgets('opening screen does not build search index', (tester) async {
      final search = SearchService();
      final service = FakeDiagnosticsService(
        catalogService: StubCatalogService(
          stubCatalog: diagnosticsCatalog(identity: 'REV-NOINDEX', itemCount: 2),
        ),
        artworkService: ArtworkService(fileExists: (_) => true),
        searchService: search,
        playbackService: PlaybackService(),
        mediaProviderConfigService: MediaProviderConfigService(),
        libraryMetadataRepository: LibraryMetadataRepository(),
        applicationStartedAt: DateTime.utc(2026, 7, 16, 9),
      );

      await _pumpDiagnostics(tester, service);
      await tester.pumpAndSettle();

      expect(search.hasIndex, isFalse);
      expect(search.indexBuildCount, 0);
    });
  });
}
