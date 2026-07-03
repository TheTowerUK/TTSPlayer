import 'package:flutter/material.dart';

import '../../models/catalogue_source_kind.dart';
import '../../theme/app_theme.dart';

/// Chip showing Live NAS, Fallback NAS, or Demo Catalogue status.
class CatalogueSourceChip extends StatelessWidget {
  final CatalogueSourceKind kind;
  final bool compact;

  const CatalogueSourceChip({
    super.key,
    required this.kind,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(kind);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadius.chipRadius,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: compact ? AppTypography.size11 : AppTypography.size12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _ChipColors _colorsFor(CatalogueSourceKind kind) {
    switch (kind) {
      case CatalogueSourceKind.liveNas:
        return _ChipColors(
          background: AppColors.success.withAlpha(30),
          border: AppColors.success,
          foreground: AppColors.success,
        );
      case CatalogueSourceKind.fallbackNas:
        return const _ChipColors(
          background: AppColors.warningBannerBg,
          border: AppColors.warning,
          foreground: AppColors.warning,
        );
      case CatalogueSourceKind.demo:
        return const _ChipColors(
          background: AppColors.infoBannerBg,
          border: AppColors.primary,
          foreground: AppColors.primaryLight,
        );
    }
  }
}

class _ChipColors {
  final Color background;
  final Color border;
  final Color foreground;

  const _ChipColors({
    required this.background,
    required this.border,
    required this.foreground,
  });
}
