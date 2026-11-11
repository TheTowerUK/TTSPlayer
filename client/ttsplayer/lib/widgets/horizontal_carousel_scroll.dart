import 'dart:math' as math;

/// Step size and clamping for dashboard horizontal carousels.
abstract final class HorizontalCarouselScroll {
  /// Overlap retained after each button step so the previous card stays in view.
  static const double overlap = 64;

  /// Distance to travel for one "page" of [viewport].
  static double stepForViewport(double viewport) {
    if (viewport <= 0) return 0;
    return math.max(viewport - overlap, viewport * 0.5);
  }

  /// Next offset in [direction] (`-1` left, `+1` right), clamped to [maxExtent].
  static double targetOffset({
    required double current,
    required double viewport,
    required double maxExtent,
    required int direction,
  }) {
    final extent = math.max(0.0, maxExtent);
    final step = stepForViewport(viewport);
    return (current + direction * step).clamp(0.0, extent);
  }

  static bool fitsInViewport(double maxExtent) => maxExtent <= 0.5;

  static bool atStart(double pixels) => pixels <= 0.5;

  static bool atEnd(double pixels, double maxExtent) =>
      pixels >= math.max(0.0, maxExtent) - 0.5;
}
