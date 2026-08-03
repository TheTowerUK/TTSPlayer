@Tags(['phase736-runtime'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';

import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_enrichment_test_support.dart';
import 'support/phase_736_metadata_fixtures.dart';
import 'support/phase_736_metadata_runtime_baseline.dart';
import 'support/phase_736_metadata_runtime_harness.dart';
import 'support/phase_736_scripted_book_metadata_provider.dart';

/// Opt-in Windows metadata matching runtime harness (Phase 7.3.6).
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_736_RUNTIME='1'
/// flutter test test/phase_736_metadata_matching_windows_runtime_test.dart --tags phase736-runtime
/// Remove-Item Env:PHASE_736_RUNTIME
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_736_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_736_RUNTIME=1 to run Phase 7.3.6 metadata runtime validation',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 7.3.6 metadata runtime validation is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  late Phase736MetadataRuntimeBaseline baseline;
  late Phase736RuntimeContext ctx;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    baseline = Phase736MetadataRuntimeBaseline();
    ctx = await Phase736RuntimeContext.create(baseline: baseline);
  });

  tearDownAll(() {
    baseline.printReport();
  });

  group('Phase 7.3.6 metadata runtime — harness and entry', () {
    testWidgets('M1 harness initialisation', (tester) async {
      baseline.classifyScenario('M1', 'automated');
      expect(Platform.isWindows, isTrue);
      expect(Platform.environment['PHASE_736_RUNTIME'], '1');
      expect(ctx.repository.storedRecordCount, 3);
      expect(ctx.provider.searchInvocationCount, 0);
      expect(ctx.recordFor(Phase736Fixtures.bookCId)!.matchState,
          EnrichmentMatchState.linkedManual);
      expect(ctx.recordFor(Phase736Fixtures.bookDId)!.matchState,
          EnrichmentMatchState.ignored);
      expect(ctx.recordFor(Phase736Fixtures.bookEId)!.providerRecordId,
          Phase736Fixtures.recordLinkedE);
      baseline.observe('M1_fixture_books', Phase736Fixtures.allBooks().length);
    });

    testWidgets('M2 item-detail metadata section', (tester) async {
      baseline.classifyScenario('M2', 'automated');
      await ctx.pumpItemDetail(tester, Phase736Fixtures.bookA());
      expect(find.byKey(const Key('book_metadata_enrichment_section')),
          findsOneWidget);
      expect(find.text('Not linked'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_search')),
          findsOneWidget);
      expect(ctx.provider.searchInvocationCount, 0);
    });
  });

  group('Phase 7.3.6 metadata runtime — search and candidate review', () {
    testWidgets('M3 search from unmatched book', (tester) async {
      baseline.classifyScenario('M3', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookA());
      await tapSearchMetadata(tester);
      expect(ctx.provider.searchInvocationCount, 1);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsOneWidget);
      expect(ctx.repository.getByItemId(Phase736Fixtures.bookAId), isNull);
    });

    testWidgets('M4 candidate ordering and presentation', (tester) async {
      baseline.classifyScenario('M4', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookA());
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);

      final strong = find.byKey(
        Key(
          'book_metadata_candidate_title_${Phase736Fixtures.recordStrong.replaceAll('/', '_')}',
        ),
      );
      final secondary = find.byKey(
        Key(
          'book_metadata_candidate_title_${Phase736Fixtures.recordSecondary.replaceAll('/', '_')}',
        ),
      );
      expect(strong, findsOneWidget);
      expect(secondary, findsOneWidget);
      expect(tester.getTopLeft(strong).dy < tester.getTopLeft(secondary).dy,
          isTrue);

      final useButton =
          tester.widget<FilledButton>(find.byKey(const Key('book_metadata_candidate_use')));
      expect(useButton.onPressed, isNull);
      final strongMatch = find.byKey(
        Key(
          'book_metadata_candidate_match_${Phase736Fixtures.recordStrong.replaceAll('/', '_')}',
        ),
      );
      expect(strongMatch, findsOneWidget);
      final matchLabel = tester.widget<Text>(strongMatch).data!;
      expect(matchLabel.toLowerCase(), contains('match'));
      expect(find.textContaining('0.'), findsNothing);
      expect(find.textContaining('Publisher: Alpha Press'), findsWidgets);
      expect(find.textContaining('Author Alpha'), findsWidgets);
    });

    testWidgets('M5 ordinary manual selection', (tester) async {
      baseline.classifyScenario('M5', 'automated');
      await phase736CompleteSearchAndReview(
        tester,
        ctx,
        Phase736Fixtures.bookA(),
        candidateRecordId: Phase736Fixtures.recordStrong,
      );
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);

      expect(ctx.coordinator.selectInvocationCount, 1);
      expect(ctx.recordFor(Phase736Fixtures.bookAId)!.matchState,
          EnrichmentMatchState.linkedManual);
      expect(Phase736Fixtures.bookA().title, Phase736Fixtures.bookATitle);
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsNothing);
      expect(ctx.provider.searchInvocationCount, 1);
    });

    testWidgets('M6 confirmation cancellation', (tester) async {
      baseline.classifyScenario('M6', 'automated');
      await phase736CompleteSearchAndReview(
        tester,
        ctx,
        Phase736Fixtures.bookA(),
        candidateRecordId: Phase736Fixtures.recordStrong,
      );
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm_cancel')));
      await tester.pumpAndSettle();

      expect(ctx.repository.getByItemId(Phase736Fixtures.bookAId), isNull);
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsOneWidget);
      expect(ctx.provider.searchInvocationCount, 1);
    });
  });

  group('Phase 7.3.6 metadata runtime — conflict handling', () {
    testWidgets('M7 critical conflict warning', (tester) async {
      baseline.classifyScenario('M7', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookB());
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordConflict);
      await tapUseSelectedCandidate(tester);

      expect(find.textContaining('Author differs'), findsWidgets);
      expect(find.textContaining('authorConflict'), findsNothing);
      expect(find.byKey(const Key('book_metadata_candidate_confirm')), findsNothing);
      expect(ctx.provider.searchInvocationCount, 1);
    });

    testWidgets('M8 critical override', (tester) async {
      baseline.classifyScenario('M8', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookB());
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordConflict);
      await tapUseSelectedCandidate(tester);
      await confirmCriticalOverride(tester);

      expect(ctx.coordinator.selectInvocationCount, 1);
      expect(ctx.recordFor(Phase736Fixtures.bookBId)!.matchState,
          EnrichmentMatchState.linkedManual);
      expect(ctx.provider.searchInvocationCount, 1);
    });

    testWidgets('M9 conflict backstop', (tester) async {
      baseline.classifyScenario('M9', 'automated');
      SharedPreferences.setMockInitialValues({});
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = Phase736ScriptedBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final backstop = Phase736ConflictBackstopCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => Phase736Fixtures.fetchedAt,
      );
      ctx = await Phase736RuntimeContext.create(
        baseline: baseline,
        seedBaselineRecords: false,
        coordinatorOverride: backstop,
        providerOverride: provider,
      );
      await ctx.pumpSection(tester, Phase736Fixtures.bookA());
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordStrong);
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);
      expect(find.byKey(const Key('book_metadata_candidate_critical_confirm')),
          findsOneWidget);
      await confirmCriticalOverride(tester);

      expect(backstop.selectInvocationCount, 2);
      expect(repository.getByItemId(Phase736Fixtures.bookAId)!.matchState,
          EnrichmentMatchState.linkedManual);
      expect(provider.searchInvocationCount, 1);
    });
  });

  group('Phase 7.3.6 metadata runtime — linked-item rematch', () {
    testWidgets('M10 begin rematch', (tester) async {
      baseline.classifyScenario('M10', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookE());
      expect(find.text('Manually linked'), findsOneWidget);
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_change_metadata')));
      await tester.pumpAndSettle();
      expect(find.text('Manually linked'), findsOneWidget);
      expect(ctx.provider.searchInvocationCount, 1);
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsOneWidget);
    });

    testWidgets('M11 rematch cancellation', (tester) async {
      baseline.classifyScenario('M11', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookE());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_change_metadata')));
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_cancel')));
      await tester.pumpAndSettle();
      expect(ctx.recordFor(Phase736Fixtures.bookEId)!.providerRecordId,
          Phase736Fixtures.recordLinkedE);
      expect(ctx.provider.searchInvocationCount, 1);
    });

    testWidgets('M12 successful relink', (tester) async {
      baseline.classifyScenario('M12', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookE());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_change_metadata')));
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordAltE);
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Replace link'));
      await tester.pumpAndSettle();

      expect(ctx.coordinator.relinkInvocationCount, 1);
      final record = ctx.recordFor(Phase736Fixtures.bookEId)!;
      expect(record.providerRecordId, Phase736Fixtures.recordAltE);
      expect(record.lockedFields, contains(EnrichmentBookFieldKeys.authors));
      expect(record.fields[EnrichmentBookFieldKeys.publishers]?.value,
          contains('Rematch Press'));
      expect(ctx.provider.searchInvocationCount, 1);
    });

    testWidgets('M13 same-record relink', (tester) async {
      baseline.classifyScenario('M13', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookE());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_change_metadata')));
      await tester.pumpAndSettle();
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordLinkedE);
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Replace link'));
      await tester.pumpAndSettle();

      expect(find.text('This metadata is already linked.'), findsOneWidget);
      expect(ctx.recordFor(Phase736Fixtures.bookEId)!.providerRecordId,
          Phase736Fixtures.recordLinkedE);
      expect(ctx.provider.searchInvocationCount, 1);
    });
  });

  group('Phase 7.3.6 metadata runtime — unlink ignore resume', () {
    testWidgets('M14 unlink cancellation', (tester) async {
      baseline.classifyScenario('M14', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookC());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await cancelConfirmDialog(tester);
      expect(find.text('Manually linked'), findsOneWidget);
      expect(ctx.coordinator.unlinkInvocationCount, 0);
    });

    testWidgets('M15 successful unlink', (tester) async {
      baseline.classifyScenario('M15', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookC());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_unlink_confirm'),
      );
      expect(ctx.coordinator.unlinkInvocationCount, 1);
      final record = ctx.recordFor(Phase736Fixtures.bookCId)!;
      expect(record.matchState, EnrichmentMatchState.unmatched);
      expect(find.text('Metadata link removed.'), findsOneWidget);
    });

    testWidgets('M16 ignore matching', (tester) async {
      baseline.classifyScenario('M16', 'automated');
      await ctx.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: Phase736Fixtures.bookAId,
          matchState: EnrichmentMatchState.unmatched,
        ),
      );
      await ctx.pumpSection(tester, Phase736Fixtures.bookA());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_ignore')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_ignore_confirm'),
      );
      expect(ctx.coordinator.ignoreInvocationCount, 1);
      expect(ctx.recordFor(Phase736Fixtures.bookAId)!.matchState,
          EnrichmentMatchState.ignored);
      expect(find.byKey(const Key('book_metadata_enrichment_search')), findsNothing);
      expect(ctx.provider.searchInvocationCount, 0);
    });

    testWidgets('M17 resume matching', (tester) async {
      baseline.classifyScenario('M17', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookD());
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_resume')));
      await tester.pumpAndSettle();
      expect(ctx.coordinator.resumeInvocationCount, 1);
      expect(ctx.recordFor(Phase736Fixtures.bookDId)!.matchState,
          EnrichmentMatchState.unmatched);
      expect(find.text('Metadata matching resumed.'), findsOneWidget);
      expect(ctx.provider.searchInvocationCount, 0);
    });
  });

  group('Phase 7.3.6 metadata runtime — failures and retries', () {
    testWidgets('M18 empty provider result', (tester) async {
      baseline.classifyScenario('M18', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookF());
      await tapSearchMetadata(tester);
      expect(ctx.provider.searchInvocationCount, 1);
      expect(find.text('No metadata candidates found.'), findsOneWidget);
      expect(ctx.repository.getByItemId(Phase736Fixtures.bookFId), isNull);
      expect(find.byKey(const Key('book_metadata_enrichment_search')), findsOneWidget);
    });

    testWidgets('M19 provider failure', (tester) async {
      baseline.classifyScenario('M19', 'automated');
      await ctx.pumpSection(tester, Phase736Fixtures.bookG());
      await tapSearchMetadata(tester);
      expect(ctx.provider.searchInvocationCount, 1);
      expect(find.text('Could not reach the metadata service.'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(ctx.recordFor(Phase736Fixtures.bookGId), isNull);
      await tapSearchMetadata(tester);
      expect(ctx.provider.searchInvocationCount, 2);
    });

    testWidgets('M20 repository failure', (tester) async {
      baseline.classifyScenario('M20', 'automated');
      await phase736CompleteSearchAndReview(
        tester,
        ctx,
        Phase736Fixtures.bookA(),
        candidateRecordId: Phase736Fixtures.recordStrong,
      );
      ctx.repository.simulatePersistFailure = true;
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);
      expect(find.text('Metadata could not be saved.'), findsOneWidget);
      expect(ctx.recordFor(Phase736Fixtures.bookAId), isNull);
      ctx.repository.simulatePersistFailure = false;
      await tapUseSelectedCandidate(tester);
      await confirmCandidateSelection(tester);
      expect(ctx.provider.searchInvocationCount, 1);
      expect(ctx.recordFor(Phase736Fixtures.bookAId)!.matchState,
          EnrichmentMatchState.linkedManual);
    });

    testWidgets('M21 duplicate submission', (tester) async {
      baseline.classifyScenario('M21', 'automated');
      SharedPreferences.setMockInitialValues({});
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = Phase736ScriptedBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final delayed = Phase736DelayedSelectCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => Phase736Fixtures.fetchedAt,
      );
      ctx = await Phase736RuntimeContext.create(
        baseline: baseline,
        seedBaselineRecords: false,
        coordinatorOverride: delayed,
        providerOverride: provider,
      );
      await ctx.pumpSection(tester, Phase736Fixtures.bookA());
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordStrong);
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(delayed.selectInvocationCount, 1);
      expect(repository.getByItemId(Phase736Fixtures.bookAId)!.matchState,
          EnrichmentMatchState.linkedManual);
    });
  });

  group('Phase 7.3.6 metadata runtime — item lifecycle and isolation', () {
    testWidgets('M22 item change during candidate review', (tester) async {
      baseline.classifyScenario('M22', 'automated');
      await tester.pumpWidget(
        Phase736ItemHost(ctx: ctx, initialItem: Phase736Fixtures.bookA()),
      );
      await tester.pumpAndSettle();
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      final host = tester.state<Phase736ItemHostState>(find.byType(Phase736ItemHost));
      host.showItem(Phase736Fixtures.bookB());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('book_metadata_candidate_dialog')), findsNothing);
      expect(ctx.repository.getByItemId(Phase736Fixtures.bookAId), isNull);
      expect(ctx.provider.searchInvocationCount, 1);
      await tapSearchMetadata(tester);
      expect(ctx.provider.searchInvocationCount, 2);
    });

    testWidgets('M23 delayed result after item change', (tester) async {
      baseline.classifyScenario('M23', 'automated');
      SharedPreferences.setMockInitialValues({});
      final repository = await initializedMetadataEnrichmentRepository();
      final provider = Phase736ScriptedBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final delayed = Phase736DelayedSelectCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => Phase736Fixtures.fetchedAt,
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: Phase736Fixtures.bookA(),
          repository: repository,
          coordinator: delayed,
        ),
      );
      await tester.pumpAndSettle();
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tapCandidateCard(tester, Phase736Fixtures.recordStrong);
      await tapUseSelectedCandidate(tester);
      await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
      await tester.pump();
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: Phase736Fixtures.bookB(),
          repository: repository,
          coordinator: delayed,
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Manually linked'), findsNothing);
      expect(repository.getByItemId(Phase736Fixtures.bookBId), isNull);
      expect(repository.getByItemId(Phase736Fixtures.bookAId)!.matchState,
          EnrichmentMatchState.linkedManual);
    });

    testWidgets('M24 item change during delayed unlink', (tester) async {
      baseline.classifyScenario('M24', 'automated');
      SharedPreferences.setMockInitialValues({});
      final repository = await initializedMetadataEnrichmentRepository();
      await repository.upsert(Phase736Fixtures.seedManualLinkC());
      final provider = Phase736ScriptedBookMetadataProvider();
      final refreshService = BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      );
      final delayedUnlink = Phase736DelayedUnlinkCoordinator(
        provider: provider,
        repository: repository,
        refreshService: refreshService,
        clock: () => Phase736Fixtures.fetchedAt,
      );
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: Phase736Fixtures.bookC(),
          repository: repository,
          coordinator: delayedUnlink,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('book_metadata_enrichment_unlink')));
      await tester.pumpAndSettle();
      await confirmTransitionByKey(
        tester,
        const Key('book_metadata_enrichment_unlink_confirm'),
      );
      await tester.pump();
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: Phase736Fixtures.bookB(),
          repository: repository,
          coordinator: delayedUnlink,
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Metadata link removed.'), findsNothing);
      expect(repository.getByItemId(Phase736Fixtures.bookCId)!.matchState,
          EnrichmentMatchState.unmatched);
    });

    testWidgets('M25 disposal with open dialog', (tester) async {
      baseline.classifyScenario('M25', 'automated');
      await tester.pumpWidget(
        Phase736ItemHost(ctx: ctx, initialItem: Phase736Fixtures.bookA()),
      );
      await tester.pumpAndSettle();
      await tapSearchMetadata(tester);
      await tapReviewCandidates(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('M26 cross-item repository isolation', (tester) async {
      baseline.classifyScenario('M26', 'automated');
      expect(ctx.recordFor(Phase736Fixtures.bookCId)!.matchState,
          EnrichmentMatchState.linkedManual);
      expect(ctx.recordFor(Phase736Fixtures.bookDId)!.matchState,
          EnrichmentMatchState.ignored);
      expect(ctx.recordFor(Phase736Fixtures.bookAId), isNull);
      await ctx.pumpSection(tester, Phase736Fixtures.bookC());
      expect(find.text('Manually linked'), findsOneWidget);
      await ctx.pumpSection(tester, Phase736Fixtures.bookD());
      expect(find.text('Metadata suggestions ignored'), findsOneWidget);
      await ctx.pumpSection(tester, Phase736Fixtures.bookA());
      expect(find.text('Not linked'), findsOneWidget);
    });

    testWidgets('M27 non-book isolation', (tester) async {
      baseline.classifyScenario('M27', 'automated');
      await ctx.pumpItemDetail(tester, Phase736Fixtures.videoItem());
      expect(find.byKey(const Key('book_metadata_enrichment_section')), findsNothing);
      expect(ctx.provider.searchInvocationCount, 0);
      expect(ctx.recordFor(Phase736Fixtures.videoId), isNull);
    });
  });

  group('Phase 7.3.6 metadata runtime — persistence and diagnostics', () {
    testWidgets('M28 repository reload', (tester) async {
      baseline.classifyScenario('M28', 'automated');
      await ctx.repository.upsert(
        MetadataEnrichmentRecord(
          itemId: Phase736Fixtures.bookAId,
          matchState: EnrichmentMatchState.linkedManual,
          providerId: Phase736Fixtures.providerId,
          providerRecordId: Phase736Fixtures.recordStrong,
          matchMethod: EnrichmentMatchMethod.manual,
          confidence: 0.9,
          lockedFields: [EnrichmentBookFieldKeys.title],
          fields: {
            EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
              value: 'Locked Title',
              source: EnrichmentFieldSource.userOverride,
              locked: true,
            ),
          },
        ),
      );
      final reloaded = await ctx.reloadFromPersistedPreferences();
      final record = reloaded.recordFor(Phase736Fixtures.bookAId)!;
      expect(record.matchState, EnrichmentMatchState.linkedManual);
      expect(record.matchMethod, EnrichmentMatchMethod.manual);
      expect(record.lockedFields, contains(EnrichmentBookFieldKeys.title));
      expect(record.providerRecordId, Phase736Fixtures.recordStrong);
      await reloaded.pumpSection(tester, Phase736Fixtures.bookA());
      expect(find.byKey(const Key('book_metadata_enrichment_review_candidates')),
          findsNothing);
    });

    test('M29 diagnostics safety deferred', () {
      baseline.classifyScenario('M29', 'deferred');
      baseline.observe(
        'M29_reason',
        'Metadata enrichment diagnostics export not implemented in M7.3',
      );
    });

    testWidgets('M30 invocation and transition summary', (tester) async {
      baseline.classifyScenario('M30', 'automated-informational');
      ctx.syncBaselineCounts();
      baseline.observe('final_book_c_state',
          ctx.recordFor(Phase736Fixtures.bookCId)?.matchState.serializedValue);
      baseline.observe('final_book_d_state',
          ctx.recordFor(Phase736Fixtures.bookDId)?.matchState.serializedValue);
      baseline.observe('final_book_e_state',
          ctx.recordFor(Phase736Fixtures.bookEId)?.matchState.serializedValue);
      expect(ctx.provider.searchInvocationCount, 0);
    });
  });

  final localCatalog = Platform.environment['PHASE_736_LOCAL_CATALOG'];
  if (localCatalog != null && localCatalog.trim().isNotEmpty) {
    test('O1 optional local catalogue — manual inspection only', () {
      baseline.classifyScenario('O1', 'optional-manual');
      baseline.observe('PHASE_736_LOCAL_CATALOG', localCatalog);
    }, skip: File(localCatalog).existsSync() ? false : 'catalog missing');
  } else {
    test('O1 optional local catalogue skipped — set PHASE_736_LOCAL_CATALOG', () {},
        skip: true);
  }
}
