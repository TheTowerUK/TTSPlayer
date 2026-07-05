import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Pulsing skeleton block for artwork loading states.
class ArtworkSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ArtworkSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<ArtworkSkeleton> createState() => _ArtworkSkeletonState();
}

class _ArtworkSkeletonState extends State<ArtworkSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.skeleton,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadius.cardRadius,
            color: Color.lerp(
              AppColors.chip,
              AppColors.cardHover,
              _controller.value,
            ),
          ),
        );
      },
    );
  }
}
