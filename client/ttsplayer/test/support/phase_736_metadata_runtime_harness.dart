import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_candidate_selection_context.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/widgets/book_metadata_enrichment_section.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'book_metadata_enrichment_section_test_support.dart';
import 'metadata_enrichment_test_support.dart';
import 'phase_736_metadata_fixtures.dart';
import 'phase_736_metadata_runtime_baseline.dart';
import 'phase_736_scripted_book_metadata_provider.dart';

/// Production stack for Phase 7.3.6 metadata matching runtime validation.
class Phase736RuntimeContext {
  Phase736RuntimeContext._({
    required this.baseline,
    required this.repository,
    required this.provider,
    required this.coordinator,
    required this.config,
    required this.activeCoordinator,
  });

  final Phase736MetadataRuntimeBaseline baseline;
  final MetadataEnrichmentRepository repository;
  final Phase736ScriptedBookMetadataProvider provider;
  final CountingTransitionCoordinator coordinator;
  final BookMetadataMatchingCoordinator activeCoordinator;
  final MetadataEnrichmentFeatureConfig config;

  static Future<Phase736RuntimeContext> create({
    Phase736MetadataRuntimeBaseline? baseline,
    Map<String, Object>? initialPreferences,
    bool seedBaselineRecords = true,
    BookMetadataMatchingCoordinator? coordinatorOverride,
    Phase736ScriptedBookMetadataProvider? providerOverride,
  }) async {
    final resolvedBaseline = baseline ?? Phase736MetadataRuntimeBaseline();
    resolvedBaseline.captureEnvironment();

    final repository = await initializedMetadataEnrichmentRepository(
      initialPreferences: initialPreferences,
    );
    final provider = providerOverride ?? Phase736ScriptedBookMetadataProvider();
    final refreshService = BookMetadataRefreshService(
      provider: provider,
      repository: repository,
    );
    final coordinator = coordinatorOverride ??
        CountingTransitionCoordinator(
          provider: provider,
          repository: repository,
          refreshService: refreshService,
          clock: () => Phase736Fixtures.fetchedAt,
        );

    if (seedBaselineRecords) {
      await repository.upsert(Phase736Fixtures.seedManualLinkC());
      await repository.upsert(Phase736Fixtures.seedIgnoredD());
      await repository.upsert(Phase736Fixtures.seedRematchE());
    }

    return Phase736RuntimeContext._(
      baseline: resolvedBaseline,
      repository: repository,
      provider: provider,
      coordinator: coordinator is CountingTransitionCoordinator
          ? coordinator
          : CountingTransitionCoordinator(
              provider: provider,
              repository: repository,
              refreshService: refreshService,
              clock: () => Phase736Fixtures.fetchedAt,
            ),
      config: MetadataEnrichmentFeatureConfig.developmentEnabled,
      activeCoordinator: coordinator,
    );
  }

  Future<Phase736RuntimeContext> reloadFromPersistedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MetadataEnrichmentRepository.storageKey);
    final initial = raw == null
        ? <String, Object>{}
        : {MetadataEnrichmentRepository.storageKey: raw};
    return Phase736RuntimeContext.create(
      baseline: baseline,
      initialPreferences: initial,
      seedBaselineRecords: false,
    );
  }

  void syncBaselineCounts() {
    baseline.totalProviderSearches = provider.searchInvocationCount;
    baseline.totalCoordinatorSelects = coordinator.selectInvocationCount;
    baseline.totalCoordinatorRelinks = coordinator.relinkInvocationCount;
    baseline.totalCoordinatorUnlinks = coordinator.unlinkInvocationCount;
    baseline.totalCoordinatorIgnores = coordinator.ignoreInvocationCount;
    baseline.totalCoordinatorResumes = coordinator.resumeInvocationCount;
  }

  MetadataEnrichmentRecord? recordFor(String itemId) =>
      repository.getByItemId(itemId);

  Future<void> pumpSection(
    WidgetTester tester,
    MediaItem item, {
    Size viewport = const Size(1280, 900),
  }) async {
    await tester.pumpWidget(
      enrichmentSectionHarness(
        item: item,
        repository: repository,
        coordinator: activeCoordinator,
        config: config,
        viewport: viewport,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpItemDetail(
    WidgetTester tester,
    MediaItem item, {
    Size viewport = const Size(1280, 900),
  }) async {
    await tester.pumpWidget(
      itemDetailEnrichmentHarness(
        item: item,
        repository: repository,
        coordinator: activeCoordinator,
        config: config,
        viewport: viewport,
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Coordinator backstop for M9 conflict-confirmation-required path.
class Phase736ConflictBackstopCoordinator extends BookMetadataMatchingCoordinator {
  Phase736ConflictBackstopCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  var _firstSelect = true;
  int selectInvocationCount = 0;

  @override
  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    selectInvocationCount++;
    if (_firstSelect && confirmation == BookCandidateSelectionConfirmation.normal) {
      _firstSelect = false;
      return const BookCandidateSelectionConflictConfirmationRequired();
    }
    return super.selectCandidate(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
    );
  }
}

class Phase736DelayedSelectCoordinator extends BookMetadataMatchingCoordinator {
  Phase736DelayedSelectCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  var selectInvocationCount = 0;

  @override
  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    selectInvocationCount++;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return super.selectCandidate(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
    );
  }
}

class Phase736DelayedUnlinkCoordinator extends BookMetadataMatchingCoordinator {
  Phase736DelayedUnlinkCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  @override
  Future<BookLinkTransitionResult> unlink({required MediaItem item}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return super.unlink(item: item);
  }
}

/// Host widget for item-scoped lifecycle scenarios (M22–M25).
class Phase736ItemHost extends StatefulWidget {
  const Phase736ItemHost({
    super.key,
    required this.ctx,
    required this.initialItem,
  });

  final Phase736RuntimeContext ctx;
  final MediaItem initialItem;

  @override
  State<Phase736ItemHost> createState() => Phase736ItemHostState();
}

class Phase736ItemHostState extends State<Phase736ItemHost> {
  late MediaItem item;

  @override
  void initState() {
    super.initState();
    item = widget.initialItem;
  }

  void showItem(MediaItem next) {
    setState(() {
      item = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1280, 900)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<MetadataEnrichmentRepository>.value(
            value: widget.ctx.repository,
          ),
          Provider<MetadataEnrichmentFeatureConfig>.value(
            value: widget.ctx.config,
          ),
          Provider<BookMetadataMatchingCoordinator?>.value(
            value: widget.ctx.activeCoordinator,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookMetadataEnrichmentSection(item: item),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> phase736PumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> phase736CompleteSearchAndReview(
  WidgetTester tester,
  Phase736RuntimeContext ctx,
  MediaItem item, {
  required String candidateRecordId,
}) async {
  await ctx.pumpSection(tester, item);
  await tapSearchMetadata(tester);
  await tapReviewCandidates(tester);
  await tapCandidateCard(tester, candidateRecordId);
}
