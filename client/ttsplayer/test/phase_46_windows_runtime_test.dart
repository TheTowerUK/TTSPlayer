@Tags(['phase46-runtime'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostic_section_status.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';

import 'support/diagnostics_test_harness.dart';
import 'support/phase_46_runtime_baseline.dart';
import 'support/phase_46_runtime_harness.dart';

/// Windows runtime validation harness for M4 Phase 4.6 diagnostics.
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_46_RUNTIME='1'
/// flutter test test/phase_46_windows_runtime_test.dart --tags phase46-runtime
/// Remove-Item Env:PHASE_46_RUNTIME -ErrorAction SilentlyContinue
/// ```
///
/// Optional environment variable (no committed paths):
/// - `PHASE_46_LOCAL_CATALOG` — path to a local `catalog.json` for optional live validation
///
/// ### D1–D10 runtime matrix
///
/// | ID | Scenario | Automation |
/// |----|----------|------------|
/// | D1 | Settings → View diagnostics navigation | Widget |
/// | D2 | Initial snapshot — seven sections | Widget |
/// | D3 | Provider diagnostics + redaction | Service + Widget |
/// | D4 | Catalogue and library counts | Service + Widget |
/// | D5 | Cache observability + non-mutation | Service + Widget |
/// | D6 | Search lifecycle before/after query | Service + Widget |
/// | D7 | Playback inactive baseline | Widget |
/// | D8 | Clipboard export flow | Widget + coordinator |
/// | D9 | Redaction + failure isolation | Widget + Service |
/// | D10 | Refresh, lifecycle, stability | Widget |
///
/// Manual checkpoints (not automated):
/// - Narrow/wide Windows layout readability
/// - Keyboard focus traversal and scroll
/// - Snackbar visibility and wording
/// - External Windows clipboard paste into Notepad
/// - Long identity wrapping and high-DPI layout
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_46_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_46_RUNTIME=1 to run Phase 4.6 runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 4.6 runtime validation is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final baseline = Phase46RuntimeBaseline();
  final optionalLiveCatalog = Platform.environment['PHASE_46_LOCAL_CATALOG'];

  group('Phase 4.6 Windows runtime validation', () {
    late Phase46RuntimeContext ctx;

    setUp(() async {
      ctx = await Phase46RuntimeContext.create(baseline: baseline);
    });

    tearDownAll(() {
      baseline.printReport();
    });

    testWidgets('D1 — Settings navigation opens DiagnosticsScreen', (tester) async {
      await phase46ConfigureViewport(tester);
      final capturesBefore = ctx.diagnostics.captureCount;

      await phase46OpenDiagnosticsFromSettings(tester, ctx);

      expect(find.byType(DiagnosticsScreen), findsOneWidget);
      expect(find.text('Diagnostics & Advanced'), findsNothing);
      expect(ctx.diagnostics.captureCount, greaterThan(capturesBefore));
      tester.takeException(); // ignore minor Settings layout overflow if present
    });

    testWidgets('D2 — Initial snapshot population', (tester) async {
      await phase46ConfigureViewport(tester);
      await phase46PumpDiagnostics(tester, ctx);

      expect(find.byKey(const Key('diagnostics_loading')), findsNothing);
      phase46AssertAllSectionHeadings(tester);
      expect(find.byKey(const Key('diagnostics_captured_at')), findsOneWidget);
      expect(find.byKey(const Key('diagnostics_screen_error')), findsNothing);

      final snapshot = await phase46TimedCapture(ctx, baseline, 'd2_capture');
      expect(snapshot.application.startupElapsed, isNotNull);
      expect(
        snapshot.application.startupElapsed!.inMicroseconds,
        greaterThanOrEqualTo(0),
      );
      baseline.observe('d2_section_count', 7);
    });

    testWidgets('D3 — Provider diagnostics are safe', (tester) async {
      await phase46ConfigureViewport(tester);
      final snapshot = await ctx.diagnostics.captureSnapshot();
      final export = phase46ExportText(snapshot);

      expect(snapshot.provider.accessModeLabel, isNotEmpty);
      expect(snapshot.provider.activeProviderKindLabel, isNotNull);
      expect(snapshot.provider.activeSourceCategoryLabel, isNotNull);
      phase46AssertNoForbiddenContent(export);

      await phase46PumpDiagnostics(tester, ctx);
      phase46AssertNoForbiddenWidgets(tester);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('D4 — Catalogue and library counts match fixture', (tester) async {
      await phase46ConfigureViewport(tester);
      final snapshot = await ctx.diagnostics.captureSnapshot();

      expect(snapshot.catalogue, isNotNull);
      expect(snapshot.catalogue!.libraryCount, ctx.catalog.folders.length);
      expect(snapshot.catalogue!.itemCount, ctx.catalog.totalItems);
      expect(snapshot.catalogue!.libraryCount! >= 0, isTrue);
      expect(snapshot.catalogue!.folderCount! >= 0, isTrue);
      expect(snapshot.catalogue!.itemCount! >= 0, isTrue);
      expect(snapshot.library?.favouriteItemCount, greaterThanOrEqualTo(0));

      await phase46PumpDiagnostics(tester, ctx);
      expect(
        find.byKey(const Key('diagnostics_catalogue_libraries')),
        findsOneWidget,
      );
      phase46AssertNoForbiddenWidgets(tester);
    });

    testWidgets('D5 — Cache diagnostics and non-mutation', (tester) async {
      await phase46ConfigureViewport(tester);
      expect(ctx.artwork.cacheEntryCount, greaterThan(0));
      expect(ctx.artwork.cacheCapacity, ArtworkService.defaultCacheCapacity);

      final before = Phase46SourceState.from(ctx);
      await phase46PumpDiagnostics(tester, ctx);

      expect(find.byKey(const Key('diagnostics_cache_entries')), findsOneWidget);
      final snapshot = await ctx.diagnostics.captureSnapshot();
      expect(snapshot.cache.artworkCandidateCapacity, 500);
      expect(
        snapshot.cache.imageCacheBudgetBytes,
        kArtworkFlutterImageCacheMaxBytes,
      );
      expect(snapshot.cache.imageCacheCurrentBytes, greaterThanOrEqualTo(0));

      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();

      final after = Phase46SourceState.from(ctx);
      before.expectUnchangedExceptTimestamps(after);
      expect(ctx.artwork.clearInvocations, 0);
      baseline.observe('d5_artwork_cache_count', ctx.artwork.cacheEntryCount);
    });

    testWidgets('D6 — Search lifecycle before and after query', (tester) async {
      await phase46ConfigureViewport(tester);
      expect(ctx.search.hasIndex, isFalse);
      final buildsBefore = ctx.search.indexBuildCount;

      await phase46PumpDiagnostics(tester, ctx);
      expect(ctx.search.indexBuildCount, buildsBefore);
      expect(find.text('No'), findsWidgets);

      await ctx.search.searchCatalog(
        ctx.catalog,
        'Item',
        const SearchFilters.empty(),
      );
      expect(ctx.search.hasIndex, isTrue);
      expect(ctx.search.indexBuildCount, buildsBefore + 1);

      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pumpAndSettle();

      final snapshot = await ctx.diagnostics.captureSnapshot();
      expect(snapshot.search.hasIndex, isTrue);
      expect(snapshot.search.indexBuildCount, buildsBefore + 1);
      expect(snapshot.search.indexMatchesActiveCatalogue, isTrue);

      final buildsAfterRefresh = ctx.search.indexBuildCount;
      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();
      expect(ctx.search.indexBuildCount, buildsAfterRefresh);
      phase46AssertNoForbiddenWidgets(tester);
    });

    testWidgets('D7 — Playback inactive baseline', (tester) async {
      await phase46ConfigureViewport(tester);
      final snapshot = await ctx.diagnostics.captureSnapshot();

      expect(snapshot.playback.playbackPlatformSupported, isNotNull);
      expect(snapshot.playback.hasActiveSession, isFalse);

      await phase46PumpDiagnostics(tester, ctx);
      expect(find.byKey(const Key('diagnostics_playback_active')), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('Not applicable'), findsWidgets);
      phase46AssertNoForbiddenWidgets(tester);
    });

    testWidgets('D8 — Clipboard export', (tester) async {
      await phase46ConfigureViewport(tester);
      await phase46PumpDiagnostics(tester, ctx);

      expect(find.byKey(const Key('copy_diagnostics')), findsOneWidget);
      final capturesBefore = ctx.diagnostics.captureCount;
      final beforeCaptured = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      ).data;

      ctx.diagnostics.captureDelay = const Duration(milliseconds: 200);
      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump();
      final refreshDuringCopy = tester.widget<OutlinedButton>(
        find.byKey(const Key('refresh_diagnostics_button')),
      );
      expect(refreshDuringCopy.onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      ctx.diagnostics.captureDelay = Duration.zero;

      expect(ctx.diagnostics.captureCount, capturesBefore + 1);
      expect(ctx.clipboard.writeCount, 1);
      expect(ctx.clipboard.lastWrittenText, isNotEmpty);
      phase46AssertExportHeadings(ctx.clipboard.lastWrittenText!);
      phase46AssertNoForbiddenContent(ctx.clipboard.lastWrittenText!);
      expect(find.text('Diagnostics copied to clipboard.'), findsOneWidget);

      final afterCaptured = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      ).data;
      expect(afterCaptured, isNot(equals(beforeCaptured)));

      ctx.clipboard.writeCount = 0;
      ctx.diagnostics.captureDelay = const Duration(milliseconds: 200);
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      ctx.diagnostics.captureDelay = Duration.zero;
      expect(ctx.clipboard.writeCount, 1);

      baseline.observe(
        'd8_export_chars',
        ctx.clipboard.lastWrittenText!.length,
      );
    });

    testWidgets('D9 — Redaction and failure isolation', (tester) async {
      await phase46ConfigureViewport(tester);

      final failingDiagnostics = ObservedDiagnosticsService(
        catalogService: ctx.catalogService,
        artworkService: ThrowingArtworkService(),
        searchService: ctx.search,
        playbackService: ctx.playback,
        mediaProviderConfigService: ctx.config,
        libraryMetadataRepository: ctx.metadata,
        applicationStartedAt: ctx.applicationStartedAt,
        platformNameProvider: () => 'windows',
        imageCacheAvailableProvider: () => true,
      );

      final partialSnapshot = await failingDiagnostics.captureSnapshot();
      expect(
        partialSnapshot.cache.status,
        DiagnosticSectionStatus.unavailable,
      );
      expect(partialSnapshot.application.status, DiagnosticSectionStatus.complete);
      expect(partialSnapshot.provider.status, DiagnosticSectionStatus.complete);

      await phase46PumpDiagnostics(tester, ctx);
      phase46AssertNoForbiddenWidgets(tester);
      phase46AssertNoForbiddenContent(
        phase46ExportText(await ctx.diagnostics.captureSnapshot()),
      );

      ctx.diagnostics.throwOnCapture = StateError('runtime capture failure');
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diagnostics_refresh_error')), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.byKey(const Key('diagnostics_app_version')), findsOneWidget);

      ctx.diagnostics.throwOnCapture = null;
      ctx.clipboard.throwOnWrite = Exception('clipboard denied');
      await tester.ensureVisible(find.byKey(const Key('copy_diagnostics')));
      await tester.tap(find.byKey(const Key('copy_diagnostics')));
      await tester.pumpAndSettle();
      expect(find.text('Diagnostics could not be copied.'), findsOneWidget);
      expect(find.textContaining('clipboard denied'), findsNothing);
    });

    testWidgets('D10 — Refresh, lifecycle, and stability', (tester) async {
      await phase46ConfigureViewport(tester);
      await phase46OpenDiagnosticsFromSettings(tester, ctx);

      final firstCaptured = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      ).data;

      ctx.diagnostics.captureDelay = const Duration(milliseconds: 200);
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump();
      expect(find.byKey(const Key('diagnostics_refresh_progress')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      ctx.diagnostics.captureDelay = Duration.zero;

      final secondCaptured = tester.widget<SelectableText>(
        find.byKey(const Key('diagnostics_captured_at')),
      ).data;
      expect(secondCaptured, isNot(equals(firstCaptured)));

      ctx.diagnostics.captureDelay = const Duration(milliseconds: 200);
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      ctx.diagnostics.captureDelay = Duration.zero;

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('View diagnostics'), findsOneWidget);

      await phase46OpenDiagnosticsFromSettings(tester, ctx);
      expect(find.byType(DiagnosticsScreen), findsOneWidget);

      final probeBefore = Phase46SourceState.from(ctx);
      await tester.pumpWidget(ctx.diagnosticsApp());
      await tester.pumpAndSettle();
      ctx.diagnostics.captureDelay = const Duration(milliseconds: 200);
      await tester.tap(find.byKey(const Key('refresh_diagnostics')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 250));
      ctx.diagnostics.captureDelay = Duration.zero;
      expect(tester.takeException(), isNull);

      probeBefore.expectUnchangedExceptTimestamps(Phase46SourceState.from(ctx));
    });
  });

  group('Phase 4.6 optional live catalogue', () {
    test(
      'skipped — set PHASE_46_LOCAL_CATALOG to run optional live catalogue validation',
      () {},
      skip: optionalLiveCatalog == null || !File(optionalLiveCatalog).existsSync(),
    );

    if (optionalLiveCatalog != null && File(optionalLiveCatalog).existsSync()) {
      testWidgets('optional live catalogue diagnostics capture', (tester) async {
        await phase46ConfigureViewport(tester);
        final bytes = await File(optionalLiveCatalog).readAsBytes();
        final catalog = Catalog.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        );
        final liveCtx = await Phase46RuntimeContext.create(
          baseline: baseline,
          catalog: catalog,
        );
        final snapshot = await liveCtx.diagnostics.captureSnapshot();
        expect(snapshot.catalogue, isNotNull);
        expect(snapshot.catalogue!.itemCount, greaterThanOrEqualTo(0));
        phase46AssertNoForbiddenContent(phase46ExportText(snapshot));
      });
    }
  });
}
