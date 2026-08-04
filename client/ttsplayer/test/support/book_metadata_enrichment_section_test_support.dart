import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/book_search_request.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/book_metadata_provider_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/fake_book_metadata_provider.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_candidate_selection_context.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/fake_metadata_artwork_http_client.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_generation_guard.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_download_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';
import 'package:ttsplayer/features/metadata_enrichment/providers/open_library/open_library_artwork_download_url_resolver.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_artwork_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_result.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_refresh_service.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/widgets/book_metadata_enrichment_section.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_item.dart' show MediaItemStatus;
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/screens/item_detail_screen.dart';
import 'package:ttsplayer/theme/app_theme.dart';

import 'metadata_enrichment_test_support.dart';

MediaItem enrichmentBookItem({
  String id = 'book-1',
  String title = 'Local Title',
  String? author,
  int? year,
}) {
  return MediaItem(
    id: id,
    title: title,
    author: author,
    year: year,
    filePath: '/media/Books/sample.epub',
    status: MediaItemStatus.available,
    mediaKindRaw: MediaKind.book.catalogueValue,
  );
}

MediaItem enrichmentVideoItem() {
  return MediaItem(
    id: 'video-1',
    title: 'Sample Video',
    filePath: '/media/Movies/sample.mp4',
    status: MediaItemStatus.available,
    mediaKindRaw: MediaKind.video.catalogueValue,
  );
}

class EnrichmentTestHarness {
  EnrichmentTestHarness({
    required this.repository,
    required this.provider,
    required this.coordinator,
    this.artworkCoordinator,
    this.artworkHttpClient,
    this.config = MetadataEnrichmentFeatureConfig.developmentEnabled,
  });

  final MetadataEnrichmentRepository repository;
  final FakeBookMetadataProvider provider;
  final BookMetadataMatchingCoordinator coordinator;
  final BookMetadataArtworkCoordinator? artworkCoordinator;
  final FakeMetadataArtworkHttpClient? artworkHttpClient;
  final MetadataEnrichmentFeatureConfig config;

  static Future<EnrichmentTestHarness> create({
    MetadataEnrichmentFeatureConfig config =
        MetadataEnrichmentFeatureConfig.developmentEnabled,
    FakeBookMetadataProvider? provider,
    bool withArtworkCoordinator = false,
    Directory? artworkCacheRoot,
    Duration? artworkHttpDelay,
    Object? artworkHttpThrow,
  }) async {
    final repository = await initializedMetadataEnrichmentRepository();
    final resolvedProvider = provider ?? FakeBookMetadataProvider();
    final refreshService = BookMetadataRefreshService(
      provider: resolvedProvider,
      repository: repository,
    );
    final coordinator = BookMetadataMatchingCoordinator(
      provider: resolvedProvider,
      repository: repository,
      refreshService: refreshService,
      clock: () => DateTime.utc(2026, 7, 30, 12),
    );

    BookMetadataArtworkCoordinator? artworkCoordinator;
    FakeMetadataArtworkHttpClient? artworkHttpClient;
    if (withArtworkCoordinator) {
      final root = artworkCacheRoot ??
          await Directory.systemTemp
              .createTemp('ttsplayer_enrichment_artwork_test_');
      final cacheRepository = MetadataArtworkCacheRepository(
        filesystem: MetadataArtworkFilesystem(cacheRoot: root),
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );
      await cacheRepository.initialize();
      artworkHttpClient = FakeMetadataArtworkHttpClient(
        delay: artworkHttpDelay,
        throwOnRequest: artworkHttpThrow,
      );
      final generationGuard = MetadataArtworkDownloadGenerationGuard();
      final downloadService = MetadataArtworkDownloadService(
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
    }

    return EnrichmentTestHarness(
      repository: repository,
      provider: resolvedProvider,
      coordinator: coordinator,
      artworkCoordinator: artworkCoordinator,
      artworkHttpClient: artworkHttpClient,
      config: config,
    );
  }
}

/// Fake provider whose [search] awaits an external completer (widget concurrency tests).
class HangingSearchFakeBookMetadataProvider extends FakeBookMetadataProvider {
  Completer<BookMetadataSearchResult>? pendingSearch;

  @override
  Future<BookMetadataSearchResult> search(
    BookSearchRequest request, {
    BookMetadataRequestOptions options = const BookMetadataRequestOptions(),
  }) async {
    searchInvocationCount++;
    lastSearchRequest = request;
    pendingSearch = Completer<BookMetadataSearchResult>();
    return pendingSearch!.future;
  }

  void completeSearch(BookMetadataSearchResult result) {
    pendingSearch?.complete(result);
  }
}

class CountingTransitionCoordinator extends BookMetadataMatchingCoordinator {
  CountingTransitionCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  int unlinkInvocationCount = 0;
  int ignoreInvocationCount = 0;
  int resumeInvocationCount = 0;
  int relinkInvocationCount = 0;
  int selectInvocationCount = 0;

  @override
  Future<BookLinkTransitionResult> unlink({required MediaItem item}) async {
    unlinkInvocationCount++;
    return super.unlink(item: item);
  }

  @override
  Future<BookLinkTransitionResult> ignore({required MediaItem item}) async {
    ignoreInvocationCount++;
    return super.ignore(item: item);
  }

  @override
  Future<BookLinkTransitionResult> resumeMatching({required MediaItem item}) async {
    resumeInvocationCount++;
    return super.resumeMatching(item: item);
  }

  @override
  Future<BookCandidateSelectionResult> relinkCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    relinkInvocationCount++;
    return super.relinkCandidate(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
    );
  }

  @override
  Future<BookCandidateSelectionResult> selectCandidate({
    required MediaItem item,
    required BookCandidateSelectionContext context,
    required String providerRecordId,
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    selectInvocationCount++;
    return super.selectCandidate(
      item: item,
      context: context,
      providerRecordId: providerRecordId,
      confirmation: confirmation,
    );
  }
}

class DelayedUnlinkCoordinator extends BookMetadataMatchingCoordinator {
  DelayedUnlinkCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  @override
  Future<BookLinkTransitionResult> unlink({required MediaItem item}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return super.unlink(item: item);
  }
}

class DelayedIgnoreCoordinator extends BookMetadataMatchingCoordinator {
  DelayedIgnoreCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  @override
  Future<BookLinkTransitionResult> ignore({required MediaItem item}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return super.ignore(item: item);
  }
}

class DelayedResumeCoordinator extends BookMetadataMatchingCoordinator {
  DelayedResumeCoordinator({
    required super.provider,
    required super.repository,
    super.refreshService,
    super.clock,
  });

  @override
  Future<BookLinkTransitionResult> resumeMatching({required MediaItem item}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return super.resumeMatching(item: item);
  }
}

Widget enrichmentSectionHarness({
  required MediaItem item,
  required MetadataEnrichmentRepository repository,
  BookMetadataMatchingCoordinator? coordinator,
  BookMetadataArtworkCoordinator? artworkCoordinator,
  MetadataEnrichmentFeatureConfig config =
      MetadataEnrichmentFeatureConfig.developmentEnabled,
  Size viewport = const Size(1280, 800),
}) {
  return MediaQuery(
    data: MediaQueryData(size: viewport),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<MetadataEnrichmentRepository>.value(
          value: repository,
        ),
        Provider<MetadataEnrichmentFeatureConfig>.value(value: config),
        Provider<BookMetadataMatchingCoordinator?>.value(value: coordinator),
        Provider<BookMetadataArtworkCoordinator?>.value(
          value: artworkCoordinator,
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

Widget itemDetailEnrichmentHarness({
  required MediaItem item,
  required MetadataEnrichmentRepository repository,
  BookMetadataMatchingCoordinator? coordinator,
  MetadataEnrichmentFeatureConfig config =
      MetadataEnrichmentFeatureConfig.defaults,
  Size viewport = const Size(1280, 800),
}) {
  final metadata = LibraryMetadataRepository();
  final readingRepository = ReadingProgressRepository();
  return MediaQuery(
    data: MediaQueryData(size: viewport),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
        ChangeNotifierProvider<LibraryMetadataRepository>.value(
          value: metadata,
        ),
        Provider(
          create: (context) => MediaLocationResolver(
            config: context.read<MediaProviderConfigService>().mediaAccess,
            isWindowsDesktop: false,
          ),
        ),
        Provider(create: (_) => ArtworkService(fileExists: (_) => false)),
        ChangeNotifierProvider(
          create: (context) => PlaybackService(
            mediaLocationResolver: context.read<MediaLocationResolver>(),
          ),
        ),
        ChangeNotifierProvider<ReadingProgressRepository>.value(
          value: readingRepository,
        ),
        ChangeNotifierProvider(
          create: (context) => ReadingProgressCoordinator(
            repository: context.read<ReadingProgressRepository>(),
          ),
        ),
        ChangeNotifierProvider<MetadataEnrichmentRepository>.value(
          value: repository,
        ),
        Provider<MetadataEnrichmentFeatureConfig>.value(value: config),
        Provider<BookMetadataMatchingCoordinator?>.value(value: coordinator),
        Provider<BookMetadataArtworkCoordinator?>.value(value: null),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ItemDetailScreen(item: item),
      ),
    ),
  );
}

Future<void> openIsbnDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_enrichment_lookup_isbn')));
  await tester.pumpAndSettle();
}

Future<void> submitIsbnDialog(
  WidgetTester tester, {
  required String isbn,
}) async {
  await tester.enterText(
    find.byKey(const Key('book_metadata_enrichment_isbn_field')),
    isbn,
  );
  await tester.tap(find.byKey(const Key('book_metadata_enrichment_isbn_submit')));
  await tester.pumpAndSettle();
}

Future<void> cancelIsbnDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_enrichment_isbn_cancel')));
  await tester.pumpAndSettle();
}

Future<void> confirmDialog(WidgetTester tester, String confirmLabel) async {
  await tester.tap(find.widgetWithText(FilledButton, confirmLabel));
  await tester.pumpAndSettle();
}

Future<void> confirmTransitionByKey(WidgetTester tester, Key confirmKey) async {
  await tester.tap(find.byKey(confirmKey));
  await tester.pumpAndSettle();
}

Future<void> cancelConfirmDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
  await tester.pumpAndSettle();
}

Future<void> tapSearchMetadata(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_enrichment_search')));
  await tester.pumpAndSettle();
}

Future<void> tapReviewCandidates(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_enrichment_review_candidates')));
  await tester.pumpAndSettle();
}

Future<void> tapCandidateCard(WidgetTester tester, String recordId) async {
  final suffix = recordId.replaceAll('/', '_');
  await tester.tap(find.byKey(Key('book_metadata_candidate_card_$suffix')));
  await tester.pumpAndSettle();
}

Future<void> tapUseSelectedCandidate(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_candidate_use')));
  await tester.pumpAndSettle();
}

Future<void> confirmCandidateSelection(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_candidate_confirm')));
  await tester.pumpAndSettle();
}

Future<void> confirmCriticalOverride(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_metadata_candidate_critical_confirm')));
  await tester.pumpAndSettle();
}
