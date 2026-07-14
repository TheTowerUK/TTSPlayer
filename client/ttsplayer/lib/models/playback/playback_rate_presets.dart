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

  /// User-facing label for settings and player UI (storage uses [supported] values).
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
}
