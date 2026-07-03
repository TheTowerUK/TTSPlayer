import 'package:flutter/material.dart';

import '../../../models/catalogue_source_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/catalogue_source_chip.dart';
import '../../../widgets/section_header.dart';

class StorageStatusSection extends StatelessWidget {
  final CatalogueSourceKind sourceKind;
  final String? catalogPath;
  final String? mediaRoot;
  final String? uncPath;

  const StorageStatusSection({
    super.key,
    required this.sourceKind,
    this.catalogPath,
    this.mediaRoot,
    this.uncPath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Storage Status'),
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
                Row(
                  children: [
                    const Icon(Icons.storage_outlined,
                        color: AppColors.textLow, size: AppIcons.lg),
                    const SizedBox(width: AppSpacing.base),
                    const Text('Active source', style: AppTypography.cardTitle),
                    const Spacer(),
                    CatalogueSourceChip(kind: sourceKind, compact: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _StatusRow(
                  label: 'Live NAS',
                  active: sourceKind == CatalogueSourceKind.liveNas,
                  detail: mediaRoot?.isNotEmpty == true
                      ? mediaRoot!
                      : CatalogServicePaths.primaryCatalogue,
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusRow(
                  label: 'Fallback NAS',
                  active: sourceKind == CatalogueSourceKind.fallbackNas,
                  detail: uncPath?.isNotEmpty == true
                      ? uncPath!
                      : CatalogServicePaths.fallbackCatalogue,
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusRow(
                  label: 'Demo Catalogue',
                  active: sourceKind == CatalogueSourceKind.demo,
                  detail: 'Bundled asset (offline demo)',
                ),
                if (catalogPath != null && catalogPath != 'bundled') ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Loaded from',
                    style: AppTypography.bodyMuted.copyWith(
                      fontSize: AppTypography.size11,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(catalogPath!, style: AppTypography.mono),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Path constants for display — mirrors [CatalogService.liveCataloguePaths].
class CatalogServicePaths {
  static const primaryCatalogue = r'Y:\Media\catalog.json';
  static const fallbackCatalogue = r'\\MEDIATNAS-B725\Media\catalog.json';
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool active;
  final String detail;

  const _StatusRow({
    required this.label,
    required this.active,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          active ? Icons.radio_button_checked : Icons.radio_button_off,
          size: AppIcons.sm,
          color: active ? AppColors.primary : AppColors.textLow,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.textPrimary : AppColors.textMedium,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: AppTypography.size14,
                ),
              ),
              Text(detail, style: AppTypography.cardSubtitle),
            ],
          ),
        ),
      ],
    );
  }
}
