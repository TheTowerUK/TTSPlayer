import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/settings/settings_navigation.dart';
import '../../../models/catalogue_provider_snapshot.dart';
import '../../../services/catalog_service.dart';
import '../../../services/media_access/media_access_config.dart';
import '../../../services/media_access/media_catalogue_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/section_header.dart';

/// Dashboard provider operational status (ADR-003). Not the Phase 4.6
/// diagnostics screen.
class ProviderStatusSection extends StatelessWidget {
  const ProviderStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CatalogService>(
      builder: (context, catalogService, _) {
        final catalog = catalogService.catalog;
        final snapshot = catalogService.providerSnapshot;
        final itemCount = catalog?.allItems.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Provider Status'),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
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
                    _ActiveProviderHeader(
                      catalogService: catalogService,
                      snapshot: snapshot,
                      itemCount: itemCount,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      label: 'Access mode',
                      value: _accessModeLabel(snapshot.accessMode),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Catalogue source',
                      value: _catalogueSourceLabel(catalogService, snapshot),
                    ),
                    if (itemCount != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        label: 'Items indexed',
                        value: '$itemCount',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Last successful load',
                      value: _formatWhen(
                        catalogService.lastCatalogueLoadAt ??
                            catalogService.lastRefreshedAt,
                      ),
                    ),
                    if (snapshot.isDegradedLoad && !snapshot.isDemoFallback) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const _StatusHint(
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        text:
                            'Loaded from fallback — preferred source unavailable.',
                      ),
                    ],
                    if (snapshot.isDemoFallback) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const _StatusHint(
                        icon: Icons.info_outline,
                        color: AppColors.primary,
                        text: 'Demo catalogue active — configured sources unavailable.',
                      ),
                    ],
                    if (catalogService.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _StatusHint(
                        icon: Icons.error_outline,
                        color: AppColors.caution,
                        text: catalogService.errorMessage!,
                      ),
                    ],
                    if (snapshot.providers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Configured providers',
                        style: AppTypography.bodyMuted.copyWith(
                          fontSize: AppTypography.size11,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final record in snapshot.providers)
                        _ProviderRow(record: record),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Refresh catalogue reloads catalog.json from your configured '
                      'sources. Run Full Scan (Library Manager) to rescan files on disk.',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: catalogService.isLoading
                              ? null
                              : () => catalogService.refreshCatalogue(),
                          icon: catalogService.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('Refresh catalogue'),
                        ),
                        if (catalogService.errorMessage != null)
                          OutlinedButton.icon(
                            onPressed: catalogService.isLoading
                                ? null
                                : () => catalogService.refreshCatalogue(),
                            icon: const Icon(Icons.replay),
                            label: const Text('Retry'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              openMediaProviderSettingsScreen(context),
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _accessModeLabel(MediaAccessMode mode) {
    switch (mode) {
      case MediaAccessMode.localPreferred:
        return 'Local preferred';
      case MediaAccessMode.httpRequired:
        return 'HTTPS required';
    }
  }

  static String _catalogueSourceLabel(
    CatalogService catalogService,
    CatalogueProviderSnapshot snapshot,
  ) {
    if (catalogService.isDemoCatalogue) {
      return 'Demo catalogue (bundled)';
    }
    final path = snapshot.catalogPath ?? catalogService.catalogPath;
    if (path == null || path.isEmpty) return '—';
    return path;
  }

  static String _formatWhen(DateTime? when) {
    if (when == null) return '—';
    final local = when.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _ActiveProviderHeader extends StatelessWidget {
  final CatalogService catalogService;
  final CatalogueProviderSnapshot snapshot;
  final int? itemCount;

  const _ActiveProviderHeader({
    required this.catalogService,
    required this.snapshot,
    this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final active = catalogService.activeCatalogueProvider ??
        snapshot.activeProvider;
    final health = snapshot.activeRecord?.health ??
        (catalogService.isDemoCatalogue
            ? CatalogueProviderHealth.failed
            : CatalogueProviderHealth.idle);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _providerIcon(active),
          color: AppColors.textLow,
          size: AppIcons.lg,
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active provider', style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                active != null ? active.location : 'None',
                style: AppTypography.mono,
              ),
              const SizedBox(height: AppSpacing.sm),
              _HealthBadge(health: health, loading: catalogService.isLoading),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _providerIcon(MediaCatalogueProviderDefinition? provider) {
    if (provider == null) return Icons.cloud_off_outlined;
    switch (provider.kind) {
      case MediaCatalogueProviderKind.localFile:
        return Icons.folder_outlined;
      case MediaCatalogueProviderKind.http:
        return Icons.cloud_outlined;
    }
  }
}

class _ProviderRow extends StatelessWidget {
  final CatalogueProviderAttemptRecord record;

  const _ProviderRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            record.isActive
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            size: AppIcons.sm,
            color: record.isActive ? AppColors.primary : AppColors.textLow,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.definition.location,
                  style: AppTypography.mono,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _HealthBadge(health: record.health, loading: false, compact: true),
                if (record.health == CatalogueProviderHealth.skipped)
                  Text(
                    'Not used in this access mode',
                    style: AppTypography.caption,
                  ),
                if (record.lastError != null &&
                    record.health == CatalogueProviderHealth.failed)
                  Text(
                    record.lastError!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.caution,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final CatalogueProviderHealth health;
  final bool loading;
  final bool compact;

  const _HealthBadge({
    required this.health,
    required this.loading,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = loading && health == CatalogueProviderHealth.loading
        ? CatalogueProviderHealth.loading
        : health;
    final (label, color) = switch (display) {
      CatalogueProviderHealth.idle => ('Idle', AppColors.textLow),
      CatalogueProviderHealth.loading => ('Loading', AppColors.primary),
      CatalogueProviderHealth.success => ('Success', AppColors.primary),
      CatalogueProviderHealth.degraded => ('Degraded', AppColors.warning),
      CatalogueProviderHealth.failed => ('Failed', AppColors.caution),
      CatalogueProviderHealth.skipped => ('Skipped', AppColors.textLow),
    };
    return Text(
      label,
      style: (compact ? AppTypography.caption : AppTypography.cardSubtitle)
          .copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: AppTypography.bodyMuted),
        ),
        Expanded(child: Text(value, style: AppTypography.cardSubtitle)),
      ],
    );
  }
}

class _StatusHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusHint({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIcons.sm, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
