/// Discrete playback rates supported in Phase 4.4 (ADR-011).
class PlaybackRatePresets {
  PlaybackRatePresets._();

  static const List<double> supported = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  static const double defaultRate = 1.0;

  static bool isSupported(double rate) {
    return supported.any((preset) => (preset - rate).abs() < 0.001);
  }

  static double normalize(double rate) {
    for (final preset in supported) {
      if ((preset - rate).abs() < 0.001) return preset;
    }
    return defaultRate;
  }

  static String displayLabel(double rate) {
    final normalized = normalize(rate);
    if ((normalized - 1.0).abs() < 0.001) {
      return 'Normal (1×)';
    }
    if (normalized == normalized.roundToDouble()) {
      return '${normalized.toInt()}×';
    }
    return '${normalized}×';
  }

  /// Compact label for in-player chrome (e.g. `1×`, `1.25×`).
  static String compactLabel(double rate) {
    final normalized = normalize(rate);
    if ((normalized - 1.0).abs() < 0.001) return '1×';
    if (normalized == normalized.roundToDouble()) {
      return '${normalized.toInt()}×';
    }
    return '${normalized}×';
  }

  static int indexOf(double rate) {
    final normalized = normalize(rate);
    for (var i = 0; i < supported.length; i++) {
      if ((supported[i] - normalized).abs() < 0.001) return i;
    }
    return supported.indexOf(defaultRate);
  }

  static double? stepRate(double current, int delta) {
    final index = indexOf(current);
    final next = index + delta;
    if (next < 0 || next >= supported.length) return null;
    return supported[next];
  }
}
