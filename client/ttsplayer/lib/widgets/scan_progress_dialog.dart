import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/scanner_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog that shows live scan progress while the Python indexer runs.
///
/// Opened by the caller before [ScannerService.runScan] is called.
/// Watches [ScannerService] via Consumer and self-dismisses 3 seconds after
/// the scan completes.  During the 3-second summary window the user can also
/// tap "Done" to dismiss immediately.
class ScanProgressDialog extends StatefulWidget {
  const ScanProgressDialog({super.key});

  @override
  State<ScanProgressDialog> createState() => _ScanProgressDialogState();
}

class _ScanProgressDialogState extends State<ScanProgressDialog> {
  // Local stopwatch for smooth elapsed-time display independent of
  // the cadence of PROGRESS: messages from the indexer.
  final _stopwatch = Stopwatch()..start();
  Timer? _clockTimer;
  Timer? _dismissTimer;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    // Redraw every second so the elapsed counter ticks smoothly.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss() {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScannerService>(
      builder: (context, scanner, _) {
        final progress = scanner.progress;
        final complete = !scanner.isScanning && progress != null;

        if (complete) _scheduleDismiss();

        return PopScope(
          canPop: complete, // prevent back-gesture during active scan
          child: Dialog(
            backgroundColor: AppColors.card,
            shape: AppRadius.dialogShape,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: AppSpacing.dialog,
              child: complete
                  ? _SummaryView(
                      progress: progress,
                      formatElapsed: _formatElapsed,
                      onDone: () => Navigator.of(context).pop(),
                    )
                  : _ProgressView(
                      progress: progress,
                      elapsed: _stopwatch.elapsed.inSeconds,
                      formatElapsed: _formatElapsed,
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Progress view — shown while scan is running
// ---------------------------------------------------------------------------

class _ProgressView extends StatelessWidget {
  final ScanProgress? progress;
  final int elapsed;
  final String Function(int) formatElapsed;

  const _ProgressView({
    required this.progress,
    required this.elapsed,
    required this.formatElapsed,
  });

  @override
  Widget build(BuildContext context) {
    final library = progress?.library ?? '';
    final folder  = progress?.folder  ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sync, color: AppColors.primary, size: AppIcons.lg),
            const SizedBox(width: AppSpacing.iconGap),
            Text(
              'Scanning…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        _LabelRow('Library', library.isNotEmpty ? library : '—'),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Folder',  folder.isNotEmpty  ? folder  : '—'),

        const SizedBox(height: AppSpacing.base),
        const Divider(color: AppColors.textFaint, height: 1),
        const SizedBox(height: AppSpacing.base),

        _LabelRow('Folders',  _fmt(progress?.folders)),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Items',    _fmt(progress?.items)),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Warnings', _fmt(progress?.warnings)),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Elapsed',  formatElapsed(elapsed)),

        const SizedBox(height: AppSpacing.lg),

        const ClipRRect(
          borderRadius: AppRadius.chipRadius,
          child: LinearProgressIndicator(
            backgroundColor: AppColors.progressTrack,
            color: AppColors.primary,
            minHeight: 4,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: 'Cancellation not yet supported',
            child: TextButton(
              onPressed: null,
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textPrimary.withAlpha(60)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(int? n) {
    if (n == null) return '—';
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }
}

// ---------------------------------------------------------------------------
// Summary view — shown for 3 s after completion before auto-dismiss
// ---------------------------------------------------------------------------

class _SummaryView extends StatelessWidget {
  final ScanProgress progress;
  final String Function(int) formatElapsed;
  final VoidCallback onDone;

  const _SummaryView({
    required this.progress,
    required this.formatElapsed,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final hasWarnings = progress.warnings > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium success / warning header
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: hasWarnings
                      ? AppColors.warningBannerBg
                      : AppColors.success.withAlpha(30),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Icon(
                  hasWarnings
                      ? Icons.warning_amber_outlined
                      : Icons.check_circle_outline,
                  size: AppIcons.hero,
                  color: hasWarnings ? AppColors.warning : AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Scan Complete',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.lg),

        _LabelRow('Folders',  _fmt(progress.folders)),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Items',    _fmt(progress.items)),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Warnings', _fmt(progress.warnings)),
        const SizedBox(height: AppSpacing.labelGap),
        _LabelRow('Duration', formatElapsed(progress.elapsedSeconds)),

        const SizedBox(height: AppSpacing.xl),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
}

// ---------------------------------------------------------------------------
// Shared label row
// ---------------------------------------------------------------------------

class _LabelRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabelRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: AppTypography.labelRowLabel),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.labelRowValue,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
