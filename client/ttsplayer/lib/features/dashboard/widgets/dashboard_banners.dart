import 'package:flutter/material.dart';

import '../../../models/catalog.dart';
import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';

class DashboardBanners extends StatelessWidget {
  final CatalogService catalogService;
  final String? scannerError;
  final VoidCallback onDismissScannerError;
  final VoidCallback onRetryScanner;
  final VoidCallback onRetryCatalogue;

  const DashboardBanners({
    super.key,
    required this.catalogService,
    this.scannerError,
    required this.onDismissScannerError,
    required this.onRetryScanner,
    required this.onRetryCatalogue,
  });

  @override
  Widget build(BuildContext context) {
    final catalog = catalogService.catalog;
    return Column(
      children: [
        if (catalogService.isDegradedLoad && !catalogService.isUsingFallback)
          _DegradedBanner(onRetry: onRetryCatalogue),
        if (catalogService.isUsingFallback)
          _FallbackBanner(
            message: catalogService.fallbackBannerMessage,
            onRetry: onRetryCatalogue,
          ),
        if (catalogService.errorMessage != null)
          _MessageBanner(
            message: catalogService.errorMessage!,
            onDismiss: catalogService.clearError,
            onRetry: onRetryCatalogue,
            isError: true,
          ),
        if (scannerError != null)
          _MessageBanner(
            message: scannerError!,
            onDismiss: onDismissScannerError,
            onRetry: onRetryScanner,
            isError: true,
          ),
        if (catalog != null && catalogService.shouldShowScanWarnings)
          _ScanWarningsBanner(
            warnings: catalog.scanWarnings,
            onDismiss: catalogService.dismissScanWarnings,
          ),
      ],
    );
  }
}

class _DegradedBanner extends StatefulWidget {
  final VoidCallback onRetry;

  const _DegradedBanner({required this.onRetry});

  @override
  State<_DegradedBanner> createState() => _DegradedBannerState();
}

class _DegradedBannerState extends State<_DegradedBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Material(
      color: AppColors.warningBannerBg,
      child: Padding(
        padding: AppSpacing.banner,
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: AppIcons.md),
            const SizedBox(width: AppSpacing.iconGap),
            const Expanded(
              child: Text(
                'Loaded from fallback source — preferred catalogue provider unavailable.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: AppTypography.size12,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                padding: AppSpacing.buttonSm,
              ),
              child: const Text('Retry',
                  style: TextStyle(fontSize: AppTypography.size12)),
            ),
            IconButton(
              icon: const Icon(Icons.close,
                  size: AppIcons.sm, color: AppColors.textLow),
              onPressed: () => setState(() => _dismissed = true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackBanner extends StatefulWidget {
  final String message;
  final VoidCallback onRetry;

  const _FallbackBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  State<_FallbackBanner> createState() => _FallbackBannerState();
}

class _FallbackBannerState extends State<_FallbackBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Material(
      color: AppColors.infoBannerBg,
      child: Padding(
        padding: AppSpacing.banner,
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.primary, size: AppIcons.md),
            const SizedBox(width: AppSpacing.iconGap),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: AppTypography.size12,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _dismissed = true);
                widget.onRetry();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: AppSpacing.buttonSm,
              ),
              child: const Text('Retry',
                  style: TextStyle(fontSize: AppTypography.size12)),
            ),
            IconButton(
              icon: const Icon(Icons.close,
                  size: AppIcons.sm, color: AppColors.textLow),
              onPressed: () => setState(() => _dismissed = true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;
  final bool isError;

  const _MessageBanner({
    required this.message,
    required this.onDismiss,
    required this.onRetry,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isError ? AppColors.errorBannerBg : AppColors.infoBannerBg,
      child: Padding(
        padding: AppSpacing.banner,
        child: Row(
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.info_outline,
              color: isError ? AppColors.caution : AppColors.primary,
              size: AppIcons.md,
            ),
            const SizedBox(width: AppSpacing.iconGap),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? AppColors.textHigh : AppColors.primaryLight,
                  fontSize: AppTypography.size12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: isError ? AppColors.caution : AppColors.primary,
                padding: AppSpacing.buttonSm,
              ),
              child: const Text('Retry',
                  style: TextStyle(fontSize: AppTypography.size12)),
            ),
            IconButton(
              icon: const Icon(Icons.close,
                  size: AppIcons.sm, color: AppColors.textLow),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanWarningsBanner extends StatelessWidget {
  final List<ScanWarning> warnings;
  final Future<void> Function() onDismiss;

  const _ScanWarningsBanner({
    required this.warnings,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningBannerBg,
      child: Padding(
        padding: AppSpacing.banner,
        child: Row(
          children: [
            const Icon(Icons.folder_off_outlined,
                color: AppColors.warning, size: AppIcons.md),
            const SizedBox(width: AppSpacing.iconGap),
            Expanded(
              child: Text(
                '${warnings.length} scan '
                'notice${warnings.length == 1 ? '' : 's'} from the last catalogue.',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: AppTypography.size12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onDismiss(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                padding: AppSpacing.buttonSm,
              ),
              child: const Text('Clear Warning',
                  style: TextStyle(fontSize: AppTypography.size12)),
            ),
          ],
        ),
      ),
    );
  }
}
