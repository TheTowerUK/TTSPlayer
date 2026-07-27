import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/music/services/music_playback_session_restorer.dart';
import '../../features/search/search_navigation.dart';
import '../../features/library_manager/library_manager_screen.dart';
import '../../navigation/app_navigator.dart';
import '../../services/catalog_service.dart';
import '../../services/media_access/media_provider_config_service.dart';
import '../../services/playback_service.dart';
import '../../services/scan_history_service.dart';
import '../../services/scanner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_card.dart';
import '../../widgets/scan_progress_dialog.dart';
import '../../widgets/tts_app_bar.dart';
import 'dashboard_service.dart';
import 'widgets/continue_watching_section.dart';
import '../reading/services/continue_reading_projection.dart';
import '../reading/services/reading_progress_repository.dart';
import '../reading/widgets/continue_reading_section.dart';
import 'widgets/dashboard_banners.dart';
import 'widgets/dashboard_quick_search_bar.dart';
import 'widgets/dashboard_welcome_header.dart';
import 'widgets/libraries_section.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/dashboard_overview_panel.dart';
import 'widgets/featured_folders_section.dart';
import 'widgets/favourites_section.dart';
import 'widgets/music_section.dart';
import 'widgets/recently_added_section.dart';
import 'widgets/provider_status_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  final _dashboardService = DashboardService();
  final _scrollController = ScrollController();
  Future<DashboardSnapshot>? _snapshotFuture;
  ScannerConfigSummary? _config;
  int _buildGeneration = 0;
  PlaybackService? _playback;
  int _lastResumeDataVersion = 0;
  ModalRoute<void>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final configService = context.read<MediaProviderConfigService>();
      final catalogService = context.read<CatalogService>();
      await catalogService.loadOnStartup(
        providerConfig: configService.config,
      );
      if (!mounted) return;
      final catalog = catalogService.catalog;
      if (catalog != null) {
        await context.read<MusicPlaybackSessionRestorer>().restoreOnColdStart(
              catalog,
            );
      }
      if (!mounted) return;
      await _reloadDashboardData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playback = context.read<PlaybackService>();
    if (!identical(_playback, playback)) {
      _playback?.removeListener(_onPlaybackResumeChanged);
      _playback = playback;
      _lastResumeDataVersion = playback.resumeDataVersion;
      _playback!.addListener(_onPlaybackResumeChanged);
    }
    final route = ModalRoute.of(context);
    if (route != null && !identical(_subscribedRoute, route)) {
      if (_subscribedRoute != null) {
        routeObserver.unsubscribe(this);
      }
      routeObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _playback?.removeListener(_onPlaybackResumeChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _reloadDashboardData();
  }

  void _onPlaybackResumeChanged() {
    final playback = _playback;
    if (playback == null || !mounted) return;
    if (playback.resumeDataVersion == _lastResumeDataVersion) return;
    _lastResumeDataVersion = playback.resumeDataVersion;
    _reloadDashboardData();
  }

  Future<void> _reloadDashboardData() async {
    final catalogService = context.read<CatalogService>();
    final historyService = context.read<ScanHistoryService>();
    final catalog = catalogService.catalog;
    if (catalog == null) return;

    final path = catalogService.catalogPath;
    if (path != null) {
      await historyService.loadAdjacentTo(path);
    }

    final config = await catalogService.readScannerConfig();
    if (!mounted) return;

    setState(() {
      _config = config;
      _buildGeneration++;
      _lastResumeDataVersion =
          context.read<PlaybackService>().resumeDataVersion;
      _snapshotFuture = _dashboardService.build(
        catalog: catalog,
        sourceKind: catalogService.catalogueSourceKind,
        catalogPath: path,
        lastRefreshedAt: catalogService.lastRefreshedAt,
        playback: context.read<PlaybackService>(),
        historyEntries: historyService.history?.entries ?? const [],
      );
    });
  }

  void _startScan() {
    final catalogService = context.read<CatalogService>();
    final scannerService = context.read<ScannerService>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: scannerService,
        child: const ScanProgressDialog(),
      ),
    );

    scannerService.runScan(catalogService).then((_) {
      if (mounted) _reloadDashboardData();
    });
  }

  void _showSourceDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Load Catalog'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Path or URL to catalog.json',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final input = controller.text.trim();
              Navigator.pop(context);
              if (input.startsWith('http')) {
                await context.read<CatalogService>().loadFromUrl(input);
              } else if (input.isNotEmpty) {
                await context.read<CatalogService>().loadFromFile(input);
              }
              if (mounted) _reloadDashboardData();
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            openSearchScreen(context, autofocus: true),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: TtsAppBar(
            title: 'TTSPlayer',
            showHome: false,
            extraActions: [
              IconButton(
                icon: const Icon(Icons.manage_search_outlined),
                tooltip: 'Library Manager',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LibraryManagerScreen(),
                  ),
                ),
              ),
              Consumer<ScannerService>(
                builder: (context, scanner, _) {
                  if (scanner.isScanning) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMedium,
                        ),
                      ),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_outlined),
                        tooltip: 'Rescan',
                        onPressed: _startScan,
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: 'Open catalog file',
                        onPressed: _showSourceDialog,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Consumer2<CatalogService, ScannerService>(
            builder: (context, catalogService, scannerService, _) {
              if (catalogService.isLoading && catalogService.catalog == null) {
                return const LoadingCard(message: 'Loading Library…');
              }

              final catalog = catalogService.catalog;
              if (catalog == null) {
                if (catalogService.errorMessage != null) {
                  return _BlockingError(
                    message: catalogService.errorMessage!,
                    onRetry: () async {
                      await catalogService.refreshCatalogue();
                      if (mounted) _reloadDashboardData();
                    },
                  );
                }
                return const EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'No catalogue loaded.',
                  subtitle:
                      'Tap the folder icon in the AppBar to choose a source.',
                );
              }

              return FutureBuilder<DashboardSnapshot>(
                key: ValueKey(_buildGeneration),
                future: _snapshotFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingCard(message: 'Preparing dashboard…');
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return const EmptyState(
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard unavailable.',
                      subtitle: 'Could not assemble dashboard data.',
                    );
                  }

                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: DashboardBanners(
                            catalogService: catalogService,
                            scannerError: scannerService.errorMessage,
                            onDismissScannerError: scannerService.clearError,
                            onRetryScanner: () {
                              scannerService.runScan(catalogService).then((_) {
                                if (mounted) _reloadDashboardData();
                              });
                            },
                            onRetryCatalogue: () async {
                              await catalogService.refreshCatalogue();
                              if (mounted) _reloadDashboardData();
                            },
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.base,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              DashboardWelcomeHeader(
                                catalog: data.catalog,
                                sourceKind: data.sourceKind,
                                catalogPath: data.catalogPath,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              DashboardOverviewPanel(catalog: data.catalog),
                              const SizedBox(height: AppSpacing.section),
                              DashboardQuickSearchBar(
                                onTap: () =>
                                    openSearchScreen(context, autofocus: true),
                              ),
                              const SizedBox(height: AppSpacing.section),
                              ContinueWatchingSection(
                                entries: data.continueWatching,
                              ),
                              const SizedBox(height: AppSpacing.section),
                              Consumer<ReadingProgressRepository>(
                                builder: (context, repository, _) {
                                  final entries = ContinueReadingProjection().build(
                                    catalog: data.catalog,
                                    repository: repository,
                                  );
                                  return Column(
                                    children: [
                                      ContinueReadingSection(entries: entries),
                                      if (entries.isNotEmpty)
                                        const SizedBox(
                                          height: AppSpacing.section,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              FavouritesSection(catalog: data.catalog),
                              const SizedBox(height: AppSpacing.section),
                              RecentlyAddedSection(entries: data.recentlyAdded),
                              const SizedBox(height: AppSpacing.section),
                              const MusicSection(),
                              const SizedBox(height: AppSpacing.section),
                              FeaturedFoldersSection(
                                  folders: data.featuredFolders),
                              const SizedBox(height: AppSpacing.section),
                              LibrariesSection(libraries: data.libraries),
                              const SizedBox(height: AppSpacing.section),
                              RecentActivitySection(
                                entries: data.recentActivity,
                              ),
                              const SizedBox(height: AppSpacing.section),
                              const ProviderStatusSection(),
                              const SizedBox(height: AppSpacing.section),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlockingError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BlockingError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: AppIcons.folderLarge, color: AppColors.error),
            const SizedBox(height: AppSpacing.base),
            Text(message,
                textAlign: TextAlign.center, style: AppTypography.body),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
