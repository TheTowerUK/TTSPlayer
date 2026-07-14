import '../services/media_access/media_provider_config.dart';
import 'library_sort_mode.dart';
import 'playback/playback_rate_presets.dart';

/// Versioned user settings envelope stored at `ttsplayer_settings_v1`.
///
/// Runtime catalogue state, playback progress, and UI dismissal keys remain
/// outside this model per ADR-004.
class ApplicationSettings {
  const ApplicationSettings({
    required this.settingsVersion,
    required this.general,
    required this.libraryProviders,
    required this.network,
    required this.playback,
    required this.diagnostics,
  });

  static const currentSettingsVersion = 1;

  final int settingsVersion;
  final GeneralSettings general;
  final LibraryProvidersSettings libraryProviders;
  final NetworkSettings network;
  final PlaybackSettings playback;
  final DiagnosticsSettings diagnostics;

  factory ApplicationSettings.defaults() {
    return ApplicationSettings(
      settingsVersion: currentSettingsVersion,
      general: GeneralSettings.defaults(),
      libraryProviders: LibraryProvidersSettings.defaults(),
      network: NetworkSettings.defaults(),
      playback: PlaybackSettings.defaults(),
      diagnostics: DiagnosticsSettings.defaults(),
    );
  }

  factory ApplicationSettings.fromProviderConfig(MediaProviderConfig config) {
    return ApplicationSettings(
      settingsVersion: currentSettingsVersion,
      general: GeneralSettings.defaults(),
      libraryProviders: LibraryProvidersSettings(providerConfig: config),
      network: NetworkSettings.defaults(),
      playback: PlaybackSettings.defaults(),
      diagnostics: DiagnosticsSettings.defaults(),
    );
  }

  factory ApplicationSettings.fromJson(Map<String, dynamic> json) {
    return ApplicationSettings.fromJsonWithRecovery(json);
  }

  /// Parses JSON, substituting defaults for invalid groups (ADR-004 partial recovery).
  factory ApplicationSettings.fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final version = json['settingsVersion'];
    if (version is! int) {
      warnings?.add('Missing settingsVersion; using defaults for unknown groups.');
    } else if (version != currentSettingsVersion) {
      warnings?.add(
        'Unsupported settingsVersion $version; using known fields only.',
      );
    }

    return ApplicationSettings(
      settingsVersion: version is int ? version : currentSettingsVersion,
      general: _parseGeneral(json['general'], warnings),
      libraryProviders: _parseLibraryProviders(
        json['libraryProviders'],
        warnings,
      ),
      network: _parseNetwork(json['network'], warnings),
      playback: _parsePlayback(json['playback'], warnings),
      diagnostics: _parseDiagnostics(json['diagnostics'], warnings),
    );
  }

  Map<String, dynamic> toJson() => {
        'settingsVersion': settingsVersion,
        'general': general.toJson(),
        'libraryProviders': libraryProviders.toJson(),
        'network': network.toJson(),
        'playback': playback.toJson(),
        'diagnostics': diagnostics.toJson(),
      };

  /// Blocking validation errors for the full envelope.
  List<String> validate() {
    final errors = <String>[];
    errors.addAll(general.validate());
    errors.addAll(libraryProviders.validate());
    errors.addAll(network.validate());
    errors.addAll(playback.validate());
    errors.addAll(diagnostics.validate());
    return errors;
  }

  ApplicationSettings copyWith({
    int? settingsVersion,
    GeneralSettings? general,
    LibraryProvidersSettings? libraryProviders,
    NetworkSettings? network,
    PlaybackSettings? playback,
    DiagnosticsSettings? diagnostics,
  }) {
    return ApplicationSettings(
      settingsVersion: settingsVersion ?? this.settingsVersion,
      general: general ?? this.general,
      libraryProviders: libraryProviders ?? this.libraryProviders,
      network: network ?? this.network,
      playback: playback ?? this.playback,
      diagnostics: diagnostics ?? this.diagnostics,
    );
  }

  static GeneralSettings _parseGeneral(
    Object? raw,
    List<String>? warnings,
  ) {
    if (raw is! Map<String, dynamic>) {
      warnings?.add('Invalid general settings; using defaults.');
      return GeneralSettings.defaults();
    }
    try {
      final parsed = GeneralSettings.fromJsonWithRecovery(raw, warnings: warnings);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        warnings?.add('Invalid general settings; using defaults.');
        return GeneralSettings.defaults();
      }
      return parsed;
    } catch (_) {
      warnings?.add('Invalid general settings; using defaults.');
      return GeneralSettings.defaults();
    }
  }

  static LibraryProvidersSettings _parseLibraryProviders(
    Object? raw,
    List<String>? warnings,
  ) {
    if (raw is! Map<String, dynamic>) {
      warnings?.add('Missing libraryProviders; using defaults.');
      return LibraryProvidersSettings.defaults();
    }
    try {
      final parsed = LibraryProvidersSettings.fromJson(raw);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        warnings?.add('Invalid provider configuration; using defaults.');
        return LibraryProvidersSettings.defaults();
      }
      return parsed;
    } catch (_) {
      warnings?.add('Invalid provider configuration; using defaults.');
      return LibraryProvidersSettings.defaults();
    }
  }

  static NetworkSettings _parseNetwork(
    Object? raw,
    List<String>? warnings,
  ) {
    if (raw is! Map<String, dynamic>) {
      return NetworkSettings.defaults();
    }
    try {
      final parsed = NetworkSettings.fromJson(raw);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        warnings?.add('Invalid network settings; using defaults.');
        return NetworkSettings.defaults();
      }
      return parsed;
    } catch (_) {
      warnings?.add('Invalid network settings; using defaults.');
      return NetworkSettings.defaults();
    }
  }

  static PlaybackSettings _parsePlayback(
    Object? raw,
    List<String>? warnings,
  ) {
    if (raw is! Map<String, dynamic>) {
      return PlaybackSettings.defaults();
    }
    try {
      final parsed = PlaybackSettings.fromJsonWithRecovery(raw, warnings: warnings);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        warnings?.add('Invalid playback settings; using defaults.');
        return PlaybackSettings.defaults();
      }
      return parsed;
    } catch (_) {
      warnings?.add('Invalid playback settings; using defaults.');
      return PlaybackSettings.defaults();
    }
  }

  static DiagnosticsSettings _parseDiagnostics(
    Object? raw,
    List<String>? warnings,
  ) {
    if (raw is! Map<String, dynamic>) {
      return DiagnosticsSettings.defaults();
    }
    try {
      final parsed = DiagnosticsSettings.fromJson(raw);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        warnings?.add('Invalid diagnostics settings; using defaults.');
        return DiagnosticsSettings.defaults();
      }
      return parsed;
    } catch (_) {
      warnings?.add('Invalid diagnostics settings; using defaults.');
      return DiagnosticsSettings.defaults();
    }
  }
}

/// General app preferences.
class GeneralSettings {
  const GeneralSettings({required this.libraryBrowse});

  final LibraryBrowseSettings libraryBrowse;

  factory GeneralSettings.defaults() {
    return GeneralSettings(libraryBrowse: LibraryBrowseSettings.defaults());
  }

  factory GeneralSettings.fromJson(Map<String, dynamic> json) {
    return GeneralSettings.fromJsonWithRecovery(json);
  }

  factory GeneralSettings.fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final browseRaw = json['libraryBrowse'];
    if (browseRaw is Map<String, dynamic>) {
      return GeneralSettings(
        libraryBrowse: LibraryBrowseSettings.fromJsonWithRecovery(
          browseRaw,
          warnings: warnings,
        ),
      );
    }
    return GeneralSettings(libraryBrowse: LibraryBrowseSettings.defaults());
  }

  Map<String, dynamic> toJson() => {
        'libraryBrowse': libraryBrowse.toJson(),
      };

  List<String> validate() => libraryBrowse.validate();

  GeneralSettings copyWith({LibraryBrowseSettings? libraryBrowse}) {
    return GeneralSettings(
      libraryBrowse: libraryBrowse ?? this.libraryBrowse,
    );
  }
}

/// Library browsing preferences persisted in the settings envelope (ADR-008).
class LibraryBrowseSettings {
  const LibraryBrowseSettings({required this.defaultSortMode});

  final LibrarySortMode defaultSortMode;

  factory LibraryBrowseSettings.defaults() {
    return const LibraryBrowseSettings(
      defaultSortMode: LibrarySortMode.defaultMode,
    );
  }

  factory LibraryBrowseSettings.fromJson(Map<String, dynamic> json) {
    return LibraryBrowseSettings.fromJsonWithRecovery(json);
  }

  factory LibraryBrowseSettings.fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    return LibraryBrowseSettings(
      defaultSortMode: LibrarySortMode.fromStorageKey(
        json['defaultSortMode'] as String?,
        warnings: warnings,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultSortMode': defaultSortMode.storageKey,
      };

  List<String> validate() => const [];

  LibraryBrowseSettings copyWith({LibrarySortMode? defaultSortMode}) {
    return LibraryBrowseSettings(
      defaultSortMode: defaultSortMode ?? this.defaultSortMode,
    );
  }
}

/// Library and provider configuration group.
class LibraryProvidersSettings {
  const LibraryProvidersSettings({required this.providerConfig});

  final MediaProviderConfig providerConfig;

  factory LibraryProvidersSettings.defaults() {
    return LibraryProvidersSettings(
      providerConfig: MediaProviderConfig.defaults(),
    );
  }

  factory LibraryProvidersSettings.fromJson(Map<String, dynamic> json) {
    final providerJson =
        json['providerConfig'] as Map<String, dynamic>? ?? const {};
    return LibraryProvidersSettings(
      providerConfig: MediaProviderConfig.fromJson(providerJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'providerConfig': providerConfig.toJson(),
      };

  List<String> validate() => providerConfig.validate();

  LibraryProvidersSettings copyWith({MediaProviderConfig? providerConfig}) {
    return LibraryProvidersSettings(
      providerConfig: providerConfig ?? this.providerConfig,
    );
  }
}

/// Network behaviour preferences.
class NetworkSettings {
  const NetworkSettings({required this.catalogueFetchTimeoutSeconds});

  static const defaultCatalogueFetchTimeoutSeconds = 15;
  static const minCatalogueFetchTimeoutSeconds = 5;
  static const maxCatalogueFetchTimeoutSeconds = 120;

  final int catalogueFetchTimeoutSeconds;

  factory NetworkSettings.defaults() {
    return const NetworkSettings(
      catalogueFetchTimeoutSeconds: defaultCatalogueFetchTimeoutSeconds,
    );
  }

  factory NetworkSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['catalogueFetchTimeoutSeconds'];
    return NetworkSettings(
      catalogueFetchTimeoutSeconds: raw is int
          ? raw
          : defaultCatalogueFetchTimeoutSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'catalogueFetchTimeoutSeconds': catalogueFetchTimeoutSeconds,
      };

  List<String> validate() {
    final errors = <String>[];
    if (catalogueFetchTimeoutSeconds < minCatalogueFetchTimeoutSeconds ||
        catalogueFetchTimeoutSeconds > maxCatalogueFetchTimeoutSeconds) {
      errors.add(
        'catalogueFetchTimeoutSeconds must be between '
        '$minCatalogueFetchTimeoutSeconds and '
        '$maxCatalogueFetchTimeoutSeconds.',
      );
    }
    return errors;
  }

  NetworkSettings copyWith({int? catalogueFetchTimeoutSeconds}) {
    return NetworkSettings(
      catalogueFetchTimeoutSeconds:
          catalogueFetchTimeoutSeconds ?? this.catalogueFetchTimeoutSeconds,
    );
  }
}

/// Playback preferences (M4.4: default speed per ADR-011).
class PlaybackSettings {
  const PlaybackSettings({required this.defaultPlaybackSpeed});

  final double defaultPlaybackSpeed;

  factory PlaybackSettings.defaults() {
    return const PlaybackSettings(
      defaultPlaybackSpeed: PlaybackRatePresets.defaultRate,
    );
  }

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) {
    return PlaybackSettings.fromJsonWithRecovery(json);
  }

  factory PlaybackSettings.fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final raw = json['defaultPlaybackSpeed'];
    if (raw is num && raw.isFinite) {
      final rate = raw.toDouble();
      if (PlaybackRatePresets.isSupported(rate)) {
        return PlaybackSettings(defaultPlaybackSpeed: rate);
      }
      warnings?.add('Invalid defaultPlaybackSpeed; using default.');
      return PlaybackSettings.defaults();
    }
    if (raw != null) {
      warnings?.add('Invalid defaultPlaybackSpeed; using default.');
    }
    return PlaybackSettings.defaults();
  }

  Map<String, dynamic> toJson() => {
        'defaultPlaybackSpeed': defaultPlaybackSpeed,
      };

  List<String> validate() {
    if (!PlaybackRatePresets.isSupported(defaultPlaybackSpeed)) {
      return ['defaultPlaybackSpeed must be a supported preset.'];
    }
    return const [];
  }

  PlaybackSettings copyWith({double? defaultPlaybackSpeed}) {
    return PlaybackSettings(
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
    );
  }
}

/// Diagnostics and advanced preferences (M4.2: version display deferred to UI).
class DiagnosticsSettings {
  const DiagnosticsSettings();

  factory DiagnosticsSettings.defaults() => const DiagnosticsSettings();

  factory DiagnosticsSettings.fromJson(Map<String, dynamic> json) =>
      const DiagnosticsSettings();

  Map<String, dynamic> toJson() => const {};

  List<String> validate() => const [];
}
