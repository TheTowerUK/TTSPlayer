import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/search/search_navigation.dart';
import '../../features/library_manager/library_manager_screen.dart';
import '../../services/catalog_service.dart';
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
import 'widgets/dashboard_banners.dart';
import 'widgets/dashboard_quick_search_bar.dart';
import 'widgets/dashboard_welcome_header.dart';
import 'widgets/libraries_section.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/recently_added_section.dart';
import 'widgets/storage_status_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dashboardService = DashboardService();
  Future<DashboardSnapshot>? _snapshotFuture;
  ScannerConfigSummary? _config;
  int _buildGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final catalogService = context.read<CatalogService>();
      await catalogService.loadOnStartup();
      if (!mounted) return;
      await _reloadDashboardData();
    });
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
    return Scaffold(
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
                  await catalogService.rescan();
                  if (mounted) _reloadDashboardData();
                },
              );
            }
            return const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No catalogue loaded.',
              subtitle: 'Tap the folder icon in the AppBar to choose a source.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardBanners(
                catalogService: catalogService,
                scannerError: scannerService.errorMessage,
                onDismissScannerError: scannerService.clearError,
                onRetryScanner: () {
                  scannerService.runScan(catalogService).then((_) {
                    if (mounted) _reloadDashboardData();
                  });
                },
                onRetryCatalogue: () async {
                  await catalogService.rescan();
                  if (mounted) _reloadDashboardData();
                },
              ),
              Expanded(
                child: FutureBuilder<DashboardSnapshot>(
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

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.base,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          DashboardWelcomeHeader(
                            catalog: data.catalog,
                            sourceKind: data.sourceKind,
                            catalogPath: data.catalogPath,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          DashboardQuickSearchBar(
                            onTap: () => openSearchScreen(context, autofocus: true),
                          ),
                          const SizedBox(height: AppSpacing.section),
                            ContinueWatchingSection(
                              entries: data.continueWatching,
                            ),
                            const SizedBox(height: AppSpacing.section),
                            LibrariesSection(libraries: data.libraries),
                            const SizedBox(height: AppSpacing.section),
                            const RecentlyAddedSection(),
                            const SizedBox(height: AppSpacing.section),
                            RecentActivitySection(
                              entries: data.recentActivity,
                            ),
                            const SizedBox(height: AppSpacing.section),
                            StorageStatusSection(
                              sourceKind: data.sourceKind,
                              catalogPath: data.catalogPath,
                              mediaRoot: _config?.mediaRoot,
                              uncPath: _config?.uncPath,
                            ),
                            const SizedBox(height: AppSpacing.section),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
            Text(message, textAlign: TextAlign.center, style: AppTypography.body),
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
