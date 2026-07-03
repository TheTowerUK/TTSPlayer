import 'package:flutter/material.dart';

import '../../../models/catalog.dart';
import '../../../models/catalogue_source_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/catalogue_source_chip.dart';

class DashboardWelcomeHeader extends StatelessWidget {
  final Catalog catalog;
  final CatalogueSourceKind sourceKind;
  final String? catalogPath;

  const DashboardWelcomeHeader({
    super.key,
    required this.catalog,
    required this.sourceKind,
    this.catalogPath,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = catalog.allItems.length;
    final libraryCount = catalog.libraryFolders.length;
    final sourceName = catalog.sources.isNotEmpty
        ? catalog.sources.first.name
        : 'Local Library';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Welcome back',
                  style: AppTypography.dashboardHeader,
                ),
              ),
              CatalogueSourceChip(kind: sourceKind),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$libraryCount librar${libraryCount == 1 ? 'y' : 'ies'}'
            '  ·  $totalItems item${totalItems == 1 ? '' : 's'}'
            '  ·  $sourceName',
            style: AppTypography.dashboardSub,
          ),
          if (catalogPath != null && catalogPath != 'bundled')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                catalogPath!,
                style: AppTypography.bodyMuted.copyWith(
                  fontSize: AppTypography.size11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
