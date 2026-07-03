import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/catalog.dart';
import '../../models/catalogue_source_kind.dart';
import '../../models/catalogue_validation_result.dart';
import '../../services/catalog_service.dart';
import '../../services/scanner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/catalogue_source_chip.dart';
import '../../widgets/loading_card.dart';
import '../../widgets/scan_progress_dialog.dart';
import '../../widgets/tts_app_bar.dart';

class LibraryManagerScreen extends StatefulWidget {
  const LibraryManagerScreen({super.key});

  @override
  State<LibraryManagerScreen> createState() => _LibraryManagerScreenState();
}

class _LibraryManagerScreenState extends State<LibraryManagerScreen> {
  ScannerConfigSummary? _config;
  CatalogueValidationResult? _validation;
  bool _validating = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await context.read<CatalogService>().readScannerConfig();
    if (mounted) setState(() => _config = config);
  }

  Future<void> _refreshCatalogue() async {
    setState(() => _refreshing = true);
    await context.read<CatalogService>().rescan();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _validateCatalogue() async {
    setState(() => _validating = true);
    final result = await context.read<CatalogService>().validateCatalogue();
    if (mounted) {
      setState(() {
        _validation = result;
        _validating = false;
      });
    }
  }

  void _runFullScan() {
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

    scannerService.runScan(catalogService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Library Manager'),
      body: Consumer<CatalogService>(
        builder: (context, catalogService, _) {
          final catalog = catalogService.catalog;
          if (catalogService.isLoading && catalog == null) {
            return const LoadingCard(message: 'Loading…');
          }
          if (catalog == null) {
            return const Center(
              child: Text('No catalogue loaded.', style: AppTypography.body),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourcePanel(
                  kind: catalogService.catalogueSourceKind,
                  catalogPath: catalogService.catalogPath,
                  config: _config,
                ),
                const SizedBox(height: AppSpacing.section),
                _StatsPanel(catalog: catalog),
                const SizedBox(height: AppSpacing.section),
                _RefreshPanel(
                  lastRefreshedAt: catalogService.lastRefreshedAt,
                  generatedAt: catalog.generatedAt,
                  refreshing: _refreshing,
                  onRefresh: _refreshCatalogue,
                  onRescan: _runFullScan,
                ),
                const SizedBox(height: AppSpacing.section),
                _ValidationPanel(
                  validating: _validating,
                  result: _validation,
                  onValidate: _validateCatalogue,
                ),
                const SizedBox(height: AppSpacing.section),
                _DiagnosticsPanel(catalog: catalog),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SourcePanel extends StatelessWidget {
  final CatalogueSourceKind kind;
  final String? catalogPath;
  final ScannerConfigSummary? config;

  const _SourcePanel({
    required this.kind,
    this.catalogPath,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Active source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CatalogueSourceChip(kind: kind),
              const Spacer(),
              Text(
                kind.label,
                style: AppTypography.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoLine(
            label: 'Media root',
            value: config?.mediaRoot.isNotEmpty == true
                ? config!.mediaRoot
                : '—',
          ),
          _InfoLine(
            label: 'Fallback (UNC)',
            value: config?.uncPath.isNotEmpty == true ? config!.uncPath : '—',
          ),
          _InfoLine(
            label: 'Catalogue location',
            value: catalogPath ?? config?.cataloguePath ?? '—',
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final Catalog catalog;

  const _StatsPanel({required this.catalog});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Library overview',
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.md,
        children: [
          _Stat(label: 'Libraries', value: '${catalog.libraryFolders.length}'),
          _Stat(label: 'Total items', value: '${catalog.allItems.length}'),
          _Stat(
            label: 'Catalogue ID',
            value: catalog.catalogueIdentity,
          ),
        ],
      ),
    );
  }
}

class _RefreshPanel extends StatelessWidget {
  final DateTime? lastRefreshedAt;
  final String generatedAt;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onRescan;

  const _RefreshPanel({
    this.lastRefreshedAt,
    required this.generatedAt,
    required this.refreshing,
    required this.onRefresh,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final refreshed = lastRefreshedAt != null
        ? _formatDateTime(lastRefreshedAt!)
        : (generatedAt.isNotEmpty ? generatedAt : '—');

    return _Panel(
      title: 'Catalogue refresh',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: 'Last catalogue refresh', value: refreshed),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh Catalogue'),
              ),
              OutlinedButton.icon(
                onPressed: onRescan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Run Full Scan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_p(local.month)}-${_p(local.day)}'
        '  ${_p(local.hour)}:${_p(local.minute)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}

class _ValidationPanel extends StatelessWidget {
  final bool validating;
  final CatalogueValidationResult? result;
  final VoidCallback onValidate;

  const _ValidationPanel({
    required this.validating,
    this.result,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Validate catalogue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: validating ? null : onValidate,
            icon: validating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: const Text('Validate Catalogue'),
          ),
          if (result != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result!.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: result!.success ? AppColors.success : AppColors.caution,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result!.message, style: AppTypography.body),
                      if (result!.itemCount != null)
                        Text(
                          '${result!.itemCount} items'
                          '  ·  ${result!.libraryCount} libraries',
                          style: AppTypography.cardSubtitle,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  final Catalog catalog;

  const _DiagnosticsPanel({required this.catalog});

  @override
  Widget build(BuildContext context) {
    final scan = catalog.scan;
    return _Panel(
      title: 'Diagnostics summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(
            label: 'Supported extensions',
            value: catalog.supportedExtensionsLabel,
          ),
          if (scan != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoLine(
              label: 'Last scan',
              value: scan.completed.isNotEmpty ? scan.completed : scan.started,
            ),
            _InfoLine(
              label: 'Scan stats',
              value: '${scan.items} items  ·  ${scan.folders} folders'
                  '  ·  ${scan.warnings} warnings',
            ),
          ],
          if (catalog.hasScanWarnings) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${catalog.scanWarnings.length} scan warning(s) in the loaded catalogue.',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: AppTypography.size12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      padding: AppSpacing.cardPremium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMuted.copyWith(
              fontSize: AppTypography.size11,
            ),
          ),
          Text(value, style: AppTypography.mono),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.cardTitle),
        Text(label, style: AppTypography.cardSubtitle),
      ],
    );
  }
}
