import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'horizontal_carousel_scroll.dart';

/// Left/right page buttons for a horizontal [ScrollController] carousel.
class HorizontalCarouselNavButtons extends StatefulWidget {
  const HorizontalCarouselNavButtons({
    super.key,
    required this.controller,
    required this.sectionLabel,
    required this.semanticsId,
  });

  final ScrollController controller;
  final String sectionLabel;
  final String semanticsId;

  @override
  State<HorizontalCarouselNavButtons> createState() =>
      _HorizontalCarouselNavButtonsState();
}

class _HorizontalCarouselNavButtonsState
    extends State<HorizontalCarouselNavButtons> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(HorizontalCarouselNavButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    _refresh();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _page(int direction) async {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = HorizontalCarouselScroll.targetOffset(
      current: position.pixels,
      viewport: position.viewportDimension,
      maxExtent: position.maxScrollExtent,
      direction: direction,
    );
    await controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
      return const SizedBox.shrink();
    }

    final position = controller.position;
    final maxExtent = position.maxScrollExtent;
    if (HorizontalCarouselScroll.fitsInViewport(maxExtent)) {
      return const SizedBox.shrink();
    }

    final atStart = HorizontalCarouselScroll.atStart(position.pixels);
    final atEnd = HorizontalCarouselScroll.atEnd(position.pixels, maxExtent);
    final label = widget.sectionLabel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavIconButton(
          key: Key('carousel_nav_prev_${widget.semanticsId}'),
          icon: Icons.chevron_left,
          tooltip: 'Scroll $label left',
          semanticLabel: 'Scroll $label left',
          onPressed: atStart ? null : () => _page(-1),
        ),
        _NavIconButton(
          key: Key('carousel_nav_next_${widget.semanticsId}'),
          icon: Icons.chevron_right,
          tooltip: 'Scroll $label right',
          semanticLabel: 'Scroll $label right',
          onPressed: atEnd ? null : () => _page(1),
        ),
      ],
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      focusable: true,
      label: semanticLabel,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(icon, size: AppIcons.standard),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textLow,
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}
