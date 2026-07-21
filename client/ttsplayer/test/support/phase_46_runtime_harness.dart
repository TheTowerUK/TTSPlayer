import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/features/settings/diagnostics_screen.dart';
import 'package:ttsplayer/features/settings/settings_screen.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_service.dart';
import 'package:ttsplayer/services/diagnostics/runtime_diagnostics_models.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';

import 'diagnostics_test_harness.dart';
import 'phase_46_runtime_baseline.dart';

/// Production [DiagnosticsService] with observability hooks for runtime validation.
class ObservedDiagnosticsService extends DiagnosticsService {
  ObservedDiagnosticsService({
    required super.catalogService,
    required super.artworkService,
    required super.searchService,
    required super.playbackService,
    required super.mediaProviderConfigService,
    required super.libraryMetadataRepository,
    required super.applicationStartedAt,
    super.packageInfoLoader,
    super.platformNameProvider,
    super.imageCacheAvailableProvider,
  });

  int captureCount = 0;
  Duration captureDelay = Duration.zero;
  Object? throwOnCapture;

  @override
  Future<RuntimeDiagnosticsSnapshot> captureSnapshot() async {
    captureCount++;
    if (captureDelay > Duration.zero) {
      await Future<void>.delayed(captureDelay);
    }
    if (throwOnCapture != null) {
      throw throwOnCapture!;
    }
    return super.captureSnapshot();
  }
}

class CountingArtworkService extends ArtworkService {
  CountingArtworkService({super.fileExists});

  int clearInvocations = 0;

  @override
  void clearCache() {
    clearInvocations++;
    super.clearCache();
  }
}

/// Non-mutation probe of diagnostics source services.
class Phase46SourceState {
  Phase46SourceState({
    required this.indexBuildCount,
    required this.hasIndex,
    required this.indexedIdentity,
    required this.artworkCount,
    required this.evictionCount,
    required this.artworkCapacity,
    required this.catalogueIdentity,
    required this.hasPlaybackSession,
    required this.playbackRate,
    required this.playbackErrorKind,
    required this.artworkClearInvocations,
  });

  final int indexBuildCount;
  final bool hasIndex;
  final String? indexedIdentity;
  final int artworkCount;
  final int evictionCount;
  final int artworkCapacity;
  final String? catalogueIdentity;
  final bool hasPlaybackSession;
  final double? playbackRate;
  final Object? playbackErrorKind;
  final int artworkClearInvocations;

  factory Phase46SourceState.from(Phase46RuntimeContext ctx) {
    return Phase46SourceState(
      indexBuildCount: ctx.search.indexBuildCount,
      hasIndex: ctx.search.hasIndex,
      indexedIdentity: ctx.search.catalogueIdentity,
      artworkCount: ctx.artwork.cacheEntryCount,
      evictionCount: ctx.artwork.cacheEvictionCount,
      artworkCapacity: ctx.artwork.cacheCapacity,
      catalogueIdentity: ctx.catalog.catalogueIdentity,
      hasPlaybackSession: ctx.playback.currentItem != null,
      playbackRate: ctx.playback.playbackRate,
      playbackErrorKind: ctx.playback.playbackErrorKind,
      artworkClearInvocations: ctx.artwork.clearInvocations,
    );
  }

  void expectUnchangedExceptTimestamps(Phase46SourceState after) {
    expect(after.indexBuildCount, indexBuildCount);
    expect(after.hasIndex, hasIndex);
    expect(after.indexedIdentity, indexedIdentity);
    expect(after.artworkCount, artworkCount);
    expect(after.evictionCount, evictionCount);
    expect(after.artworkCapacity, artworkCapacity);
    expect(after.catalogueIdentity, catalogueIdentity);
    expect(after.hasPlaybackSession, hasPlaybackSession);
    expect(after.playbackRate, playbackRate);
    expect(after.playbackErrorKind, playbackErrorKind);
    expect(after.artworkClearInvocations, artworkClearInvocations);
  }
}

class Phase46RuntimeContext {
  Phase46RuntimeContext._({
    required this.catalog,
    required this.catalogService,
    required this.artwork,
    required this.search,
    required this.playback,
    required this.metadata,
    required this.config,
    required this.settings,
    required this.diagnostics,
    required this.clipboard,
    required this.applicationStartedAt,
    required this.baseline,
  });

  final Catalog catalog;
  final StubCatalogService catalogService;
  final CountingArtworkService artwork;
  final SearchService search;
  final PlaybackService playback;
  final LibraryMetadataRepository metadata;
  final MediaProviderConfigService config;
  final SettingsRepository settings;
  final ObservedDiagnosticsService diagnostics;
  final FakeClipboardWriter clipboard;
  final DateTime applicationStartedAt;
  final Phase46RuntimeBaseline baseline;

  static Future<Phase46RuntimeContext> create({
    Phase46RuntimeBaseline? baseline,
    Catalog? catalog,
  }) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'TTSPlayer',
      packageName: 'ttsplayer',
      version: '0.5.0-dev',
      buildNumber: '42',
      buildSignature: 'sig',
      installerStore: null,
    );
    configureArtworkFlutterImageCache();

    final resolvedBaseline = baseline ?? Phase46RuntimeBaseline();
    final resolvedCatalog = catalog ??
        diagnosticsCatalog(
          identity: 'PHASE46-RUNTIME-REV',
          itemCount: 5,
          libraryCount: 2,
        );

    final metadata = LibraryMetadataRepository();
    await metadata.initialize();
    final config = MediaProviderConfigService();
    await config.load();
    final catalogService = StubCatalogService(
      stubCatalog: resolvedCatalog,
      catalogPathValue: 'runtime-fixture',
    );
    final artwork = CountingArtworkService(fileExists: (_) => true);
    for (final item in resolvedCatalog.allItems.take(3)) {
      artwork.forMediaItem(item);
    }
    final search = SearchService();
    final playback = PlaybackService();
    final applicationStartedAt = DateTime.now().toUtc().subtract(
          const Duration(minutes: 2),
        );
    final diagnostics = ObservedDiagnosticsService(
      catalogService: catalogService,
      artworkService: artwork,
      searchService: search,
      playbackService: playback,
      mediaProviderConfigService: config,
      libraryMetadataRepository: metadata,
      applicationStartedAt: applicationStartedAt,
      platformNameProvider: () => 'windows',
      imageCacheAvailableProvider: () => true,
    );
    final settings = SettingsRepository();
    await settings.initialize();
    final clipboard = FakeClipboardWriter();

    return Phase46RuntimeContext._(
      catalog: resolvedCatalog,
      catalogService: catalogService,
      artwork: artwork,
      search: search,
      playback: playback,
      metadata: metadata,
      config: config,
      settings: settings,
      diagnostics: diagnostics,
      clipboard: clipboard,
      applicationStartedAt: applicationStartedAt,
      baseline: resolvedBaseline,
    );
  }

  List<SingleChildWidget> coreProviders() {
    return [
      Provider<DiagnosticsService>.value(value: diagnostics),
      ChangeNotifierProvider<SettingsRepository>.value(value: settings),
      ChangeNotifierProvider<MediaProviderConfigService>.value(value: config),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(value: metadata),
      Provider<ArtworkService>.value(value: artwork),
      Provider<SearchService>.value(value: search),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
    ];
  }

  Widget settingsApp() {
    return MultiProvider(
      providers: coreProviders(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const SettingsScreen(),
      ),
    );
  }

  Widget diagnosticsApp() {
    return MultiProvider(
      providers: coreProviders(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: DiagnosticsScreen(clipboardWriter: clipboard),
      ),
    );
  }
}

Future<void> phase46ConfigureViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> phase46OpenDiagnosticsFromSettings(
  WidgetTester tester,
  Phase46RuntimeContext ctx,
) async {
  await tester.pumpWidget(ctx.settingsApp());
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('view_diagnostics')).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.ensureVisible(find.byKey(const Key('view_diagnostics')));
  await tester.tap(find.byKey(const Key('view_diagnostics')));
  await tester.pumpAndSettle();
  tester.takeException();
}

Future<void> phase46PumpDiagnostics(
  WidgetTester tester,
  Phase46RuntimeContext ctx,
) async {
  await tester.pumpWidget(ctx.diagnosticsApp());
  await tester.pump();
  await tester.pumpAndSettle();
}

void phase46AssertAllSectionHeadings(WidgetTester tester) {
  for (final heading in const [
    'Application',
    'Provider',
    'Catalogue',
    'Cache',
    'Search',
    'Playback',
    'Library',
  ]) {
    expect(find.text(heading), findsOneWidget);
  }
}

const phase46ForbiddenFragments = <String>[
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
  'Item 0',
  'Library 0',
  'sample.mp4',
  '.mp4',
];

void phase46AssertNoForbiddenContent(String text) {
  for (final fragment in phase46ForbiddenFragments) {
    expect(
      text.contains(fragment),
      isFalse,
      reason: 'forbidden fragment: $fragment',
    );
  }
  expect(exportContainsSensitiveData(text), isFalse);
}

void phase46AssertNoForbiddenWidgets(WidgetTester tester) {
  for (final fragment in phase46ForbiddenFragments) {
    expect(find.textContaining(fragment), findsNothing);
  }
  expect(find.textContaining('Instance of'), findsNothing);
}

Future<RuntimeDiagnosticsSnapshot> phase46TimedCapture(
  Phase46RuntimeContext ctx,
  Phase46RuntimeBaseline baseline,
  String label,
) async {
  final stopwatch = Stopwatch()..start();
  final snapshot = await ctx.diagnostics.captureSnapshot();
  baseline.observe('${label}_ms', stopwatch.elapsedMilliseconds);
  return snapshot;
}

String phase46ExportText(RuntimeDiagnosticsSnapshot snapshot) {
  return formatDiagnosticsExport(snapshot);
}

void phase46AssertExportHeadings(String export) {
  for (final heading in const [
    '=== Application ===',
    '=== Provider ===',
    '=== Catalogue ===',
    '=== Cache ===',
    '=== Search ===',
    '=== Playback ===',
    '=== Music Listening ===',
    '=== Library ===',
  ]) {
    expect(export, contains(heading));
  }
}
