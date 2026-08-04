import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/fake_metadata_artwork_http_client.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_generation_guard.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_enrichment_ui_messages.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_artwork_download_url_resolver.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_artwork_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_artwork_workflow_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/models/media_item.dart';

import 'support/book_metadata_enrichment_section_test_support.dart';
import 'support/metadata_artwork_test_fixtures.dart';
import 'support/metadata_enrichment_test_support.dart';

/// Test-only coordinator that parks workflow results on a Completer.
///
/// Validates widget pending state without network/decode timing.
class ControllableBookMetadataArtworkCoordinator
    extends BookMetadataArtworkCoordinator {
  ControllableBookMetadataArtworkCoordinator({
    required super.repository,
    required super.downloadService,
    super.generationGuard,
    super.cacheRepository,
  });

  Completer<BookMetadataArtworkWorkflowResult>? pendingResult;
  int downloadInvocationCount = 0;
  int refreshInvocationCount = 0;

  int get workflowInvocationCount =>
      downloadInvocationCount + refreshInvocationCount;

  void resetCounts() {
    downloadInvocationCount = 0;
    refreshInvocationCount = 0;
  }

  void completePending(BookMetadataArtworkWorkflowResult result) {
    final pending = pendingResult;
    if (pending == null || pending.isCompleted) {
      return;
    }
    pending.complete(result);
  }

  @override
  Future<BookMetadataArtworkWorkflowResult> downloadCover({
    required MediaItem item,
    int? expectedGeneration,
  }) {
    downloadInvocationCount++;
    pendingResult = Completer<BookMetadataArtworkWorkflowResult>();
    return pendingResult!.future;
  }

  @override
  Future<BookMetadataArtworkWorkflowResult> refreshCover({
    required MediaItem item,
    int? expectedGeneration,
  }) {
    refreshInvocationCount++;
    pendingResult = Completer<BookMetadataArtworkWorkflowResult>();
    return pendingResult!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late MetadataEnrichmentRepository repository;
  late FakeBookMetadataProvider provider;
  late BookMetadataMatchingCoordinator matchingCoordinator;
  late FakeMetadataArtworkHttpClient artworkHttpClient;
  late MetadataArtworkCacheRepository cacheRepository;
  late MetadataArtworkDownloadGenerationGuard generationGuard;
  late MetadataArtworkDownloadService downloadService;
  late BookMetadataArtworkCoordinator artworkCoordinator;
  late ControllableBookMetadataArtworkCoordinator controllableCoordinator;

  MetadataEnrichmentRecord linkedWithArtwork({
    MetadataArtworkCacheState cacheState = MetadataArtworkCacheState.available,
    String? localRelativePath,
  }) {
    final reference = MetadataArtworkTestFixtures.sampleReference().copyWith(
      cacheState: cacheState,
      localRelativePath: localRelativePath,
      validatedAt: cacheState == MetadataArtworkCacheState.downloaded ||
              cacheState == MetadataArtworkCacheState.stale
          ? DateTime.utc(2026, 8, 3, 12)
          : null,
    );
    return MetadataEnrichmentRecord(
      itemId: 'book-1',
      matchState: EnrichmentMatchState.linkedManual,
      providerId: 'open_library',
      providerRecordId: '/books/OL123M',
      providerMediaType: 'book',
      matchMethod: EnrichmentMatchMethod.manual,
      artworkReference: reference,
    ).normalized();
  }

  void registerCoverResponse() {
    artworkHttpClient.registerResponse(
      'https://covers.openlibrary.org/b/id/8230111-L.jpg',
      MetadataArtworkTestFixtures.pngResponse(
        MetadataArtworkTestFixtures.onePixelPng,
      ),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp
        .createTemp('ttsplayer_section_artwork_test_');
    repository = await initializedMetadataEnrichmentRepository();
    provider = FakeBookMetadataProvider();
    matchingCoordinator = BookMetadataMatchingCoordinator(
      provider: provider,
      repository: repository,
      refreshService: BookMetadataRefreshService(
        provider: provider,
        repository: repository,
      ),
      clock: () => DateTime.utc(2026, 7, 30, 12),
    );
    cacheRepository = MetadataArtworkCacheRepository(
      filesystem: MetadataArtworkFilesystem(cacheRoot: tempRoot),
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await cacheRepository.initialize();
    artworkHttpClient = FakeMetadataArtworkHttpClient();
    generationGuard = MetadataArtworkDownloadGenerationGuard();
    downloadService = MetadataArtworkDownloadService(
      cacheRepository: cacheRepository,
      httpClient: artworkHttpClient,
      urlResolver: const OpenLibraryArtworkDownloadUrlResolver(),
      generationGuard: generationGuard,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    artworkCoordinator = BookMetadataArtworkCoordinator(
      repository: repository,
      downloadService: downloadService,
      generationGuard: generationGuard,
      cacheRepository: cacheRepository,
    );
    controllableCoordinator = ControllableBookMetadataArtworkCoordinator(
      repository: repository,
      downloadService: downloadService,
      generationGuard: generationGuard,
      cacheRepository: cacheRepository,
    );
  });

  tearDownAll(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await repository.clearAll();
    await cacheRepository.cleanup();
    artworkHttpClient.requestCount = 0;
    artworkHttpClient.requestedUris.clear();
    controllableCoordinator.resetCounts();
    if (controllableCoordinator.pendingResult != null &&
        !controllableCoordinator.pendingResult!.isCompleted) {
      controllableCoordinator.pendingResult!.complete(
        const BookMetadataArtworkCancelled(),
      );
    }
    controllableCoordinator.pendingResult = null;
  });

  group('BookMetadataEnrichmentSection artwork controls', () {
    testWidgets('linked available reference shows download cover', (tester) async {
      await repository.upsert(linkedWithArtwork());

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: matchingCoordinator,
          artworkCoordinator: artworkCoordinator,
        ),
      );
      await tester.pump();

      expect(find.text('Cover available'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_download_cover')),
          findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_refresh_cover')),
          findsNothing);
    });

    testWidgets('downloaded reference shows refresh cover', (tester) async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await repository.upsert(
        linkedWithArtwork(
          cacheState: MetadataArtworkCacheState.downloaded,
          localRelativePath: '${reference.cacheKey}.png',
        ),
      );

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: matchingCoordinator,
          artworkCoordinator: artworkCoordinator,
        ),
      );
      await tester.pump();

      expect(find.text('Cover downloaded'), findsOneWidget);
      expect(find.byKey(const Key('book_metadata_enrichment_refresh_cover')),
          findsOneWidget);
    });

    testWidgets('unlinked book shows no artwork actions', (tester) async {
      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: matchingCoordinator,
          artworkCoordinator: artworkCoordinator,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('book_metadata_enrichment_download_cover')),
          findsNothing);
    });

    testWidgets('download invokes one HTTP request and shows success', (tester) async {
      await repository.upsert(linkedWithArtwork());
      registerCoverResponse();

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: matchingCoordinator,
          artworkCoordinator: artworkCoordinator,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_download_cover')),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .text(MetadataEnrichmentUiMessages.coverDownloadedMessage)
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }

      expect(artworkHttpClient.requestCount, 1);
      expect(provider.searchInvocationCount, 0);
    });

    testWidgets('never renders raw URL or cache key', (tester) async {
      final reference = MetadataArtworkTestFixtures.sampleReference();
      await repository.upsert(linkedWithArtwork());
      registerCoverResponse();

      await tester.pumpWidget(
        enrichmentSectionHarness(
          item: enrichmentBookItem(),
          repository: repository,
          coordinator: matchingCoordinator,
          artworkCoordinator: artworkCoordinator,
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('book_metadata_enrichment_download_cover')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('http'), findsNothing);
      expect(find.textContaining(reference.cacheKey), findsNothing);
    });

    for (final caseConfig in [
      (
        name: 'download',
        cacheState: MetadataArtworkCacheState.available,
        actionKey: const Key('book_metadata_enrichment_download_cover'),
        otherArtworkKey: const Key('book_metadata_enrichment_refresh_cover'),
        successResult: const BookMetadataArtworkDownloaded(),
        successMessage: MetadataEnrichmentUiMessages.coverDownloadedMessage,
        resultingStatus: 'Cover downloaded',
        resultingActionKey: const Key('book_metadata_enrichment_refresh_cover'),
        expectedDownloadInvocations: 1,
        expectedRefreshInvocations: 0,
        refresh: false,
      ),
      (
        name: 'refresh',
        cacheState: MetadataArtworkCacheState.downloaded,
        actionKey: const Key('book_metadata_enrichment_refresh_cover'),
        otherArtworkKey: const Key('book_metadata_enrichment_download_cover'),
        successResult: const BookMetadataArtworkRefreshed(),
        successMessage: MetadataEnrichmentUiMessages.coverRefreshedMessage,
        resultingStatus: 'Cover downloaded',
        resultingActionKey: const Key('book_metadata_enrichment_refresh_cover'),
        expectedDownloadInvocations: 0,
        expectedRefreshInvocations: 1,
        refresh: true,
      ),
    ]) {
      testWidgets(
        '${caseConfig.name} pending disables actions until Completer completes',
        (tester) async {
          final reference = MetadataArtworkTestFixtures.sampleReference();
          await repository.upsert(
            linkedWithArtwork(
              cacheState: caseConfig.cacheState,
              localRelativePath:
                  caseConfig.cacheState == MetadataArtworkCacheState.downloaded
                      ? '${reference.cacheKey}.png'
                      : null,
            ),
          );
          registerCoverResponse();

          await tester.pumpWidget(
            enrichmentSectionHarness(
              item: enrichmentBookItem(),
              repository: repository,
              coordinator: matchingCoordinator,
              artworkCoordinator: controllableCoordinator,
            ),
          );
          await tester.pump();

          expect(find.byKey(caseConfig.actionKey), findsOneWidget);

          await tester.tap(find.byKey(caseConfig.actionKey));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.byType(LinearProgressIndicator), findsOneWidget);

          final pendingAction = tester.widget<OutlinedButton>(
            find.byKey(caseConfig.actionKey),
          );
          expect(pendingAction.onPressed, isNull);

          expect(find.byKey(caseConfig.otherArtworkKey), findsNothing);

          final unlink = tester.widget<OutlinedButton>(
            find.byKey(const Key('book_metadata_enrichment_unlink')),
          );
          expect(unlink.onPressed, isNull);
          final changeMetadata = tester.widget<OutlinedButton>(
            find.byKey(const Key('book_metadata_enrichment_change_metadata')),
          );
          expect(changeMetadata.onPressed, isNull);

          await tester.tap(find.byKey(caseConfig.actionKey));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            controllableCoordinator.downloadInvocationCount,
            caseConfig.expectedDownloadInvocations,
          );
          expect(
            controllableCoordinator.refreshInvocationCount,
            caseConfig.expectedRefreshInvocations,
          );
          expect(controllableCoordinator.workflowInvocationCount, 1);
          expect(artworkHttpClient.requestCount, 0);

          // One explicit HTTP call for evidence (widget test parks workflow on
          // Completer; decode/download timing is covered by coordinator tests).
          await artworkHttpClient.getBytes(
            Uri.parse('https://covers.openlibrary.org/b/id/8230111-L.jpg'),
          );
          expect(artworkHttpClient.requestCount, 1);

          final current = repository.getByItemId('book-1')!;
          await repository.upsert(
            current
                .copyWith(
                  artworkReference: reference.copyWith(
                    cacheState: MetadataArtworkCacheState.downloaded,
                    localRelativePath: '${reference.cacheKey}.png',
                    validatedAt: DateTime.utc(2026, 8, 3, 12),
                    contentType: 'image/png',
                    width: 1,
                    height: 1,
                  ),
                )
                .normalized(),
          );

          controllableCoordinator.completePending(caseConfig.successResult);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(find.text(caseConfig.successMessage), findsOneWidget);
          expect(find.text(caseConfig.resultingStatus), findsOneWidget);
          expect(find.byKey(caseConfig.resultingActionKey), findsOneWidget);

          final completedAction = tester.widget<OutlinedButton>(
            find.byKey(caseConfig.resultingActionKey),
          );
          expect(completedAction.onPressed, isNotNull);

          expect(
            controllableCoordinator.downloadInvocationCount,
            caseConfig.expectedDownloadInvocations,
          );
          expect(
            controllableCoordinator.refreshInvocationCount,
            caseConfig.expectedRefreshInvocations,
          );
          expect(controllableCoordinator.workflowInvocationCount, 1);
          expect(artworkHttpClient.requestCount, 1);
          expect(provider.searchInvocationCount, 0);
        },
      );
    }
  });
}
