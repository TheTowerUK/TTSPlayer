import 'dart:async';

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
import 'package:ttsplayer/features/metadata_enrichment/services/book_metadata_matching_coordinator.dart';
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
    this.config = MetadataEnrichmentFeatureConfig.developmentEnabled,
  });

  final MetadataEnrichmentRepository repository;
  final FakeBookMetadataProvider provider;
  final BookMetadataMatchingCoordinator coordinator;
  final MetadataEnrichmentFeatureConfig config;

  static Future<EnrichmentTestHarness> create({
    MetadataEnrichmentFeatureConfig config =
        MetadataEnrichmentFeatureConfig.developmentEnabled,
    FakeBookMetadataProvider? provider,
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
    return EnrichmentTestHarness(
      repository: repository,
      provider: resolvedProvider,
      coordinator: coordinator,
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

Widget enrichmentSectionHarness({
  required MediaItem item,
  required MetadataEnrichmentRepository repository,
  BookMetadataMatchingCoordinator? coordinator,
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
