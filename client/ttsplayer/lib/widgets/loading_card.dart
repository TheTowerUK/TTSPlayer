import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Branded loading indicator used in place of a generic [CircularProgressIndicator].
///
/// Shows a small spinner above a contextual [message] such as
/// "Loading Library…", "Preparing Media…", or "Scanning…".
/// The widget fades in smoothly using an [AnimatedOpacity].
class LoadingCard extends StatefulWidget {
  /// Short descriptive message shown below the spinner.
  final String message;

  const LoadingCard({super.key, this.message = 'Loading…'});

  @override
  State<LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<LoadingCard> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // Defer the fade-in one frame so it fires after the first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: AppAnimations.slow,
        curve: AppAnimations.enter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(widget.message, style: AppTypography.bodyMuted),
          ],
        ),
      ),
    );
  }
}
