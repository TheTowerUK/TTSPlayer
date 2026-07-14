import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/application_settings.dart';
import '../../models/library_sort_mode.dart';
import '../../models/playback/playback_rate_presets.dart';
import '../media_access/media_provider_config.dart';
import '../media_access/media_provider_config_service.dart';

/// Where persisted settings were loaded from.
enum SettingsLoadSource {
  envelope,
  legacyMigration,
  defaults,
}

/// Outcome of [SettingsRepository.load].
class SettingsLoadResult {
  const SettingsLoadResult({
    required this.settings,
    required this.source,
    this.recoveryWarnings = const [],
  });

  final ApplicationSettings settings;
  final SettingsLoadSource source;
  final List<String> recoveryWarnings;
}

/// Outcome of [SettingsRepository.save].
class SettingsSaveResult {
  const SettingsSaveResult({
    required this.success,
    this.validationErrors = const [],
  });

  final bool success;
  final List<String> validationErrors;
}

/// Loads, migrates, validates, and persists the versioned settings envelope.
///
/// Persistence-only layer — runtime services consume [settings] snapshots; they
/// do not own preference I/O (ADR-004).
class SettingsRepository extends ChangeNotifier {
  SettingsRepository({ApplicationSettings? initialSettings})
      : _settings = initialSettings ?? ApplicationSettings.defaults();

  static const storageKey = 'ttsplayer_settings_v1';

  ApplicationSettings _settings;
  bool _isLoaded = false;
  SettingsLoadSource? _lastLoadSource;

  /// Whether [initialize] or [load] has completed at least once.
  ///
  /// Before the first load, [settings] holds in-memory defaults that may not
  /// reflect persisted preferences yet.
  bool get isLoaded => _isLoaded;

  ApplicationSettings get settings => _settings;

  NetworkSettings get networkSettings => _settings.network;

  MediaProviderConfig get providerConfig =>
      _settings.libraryProviders.providerConfig;

  LibraryBrowseSettings get libraryBrowseSettings =>
      _settings.general.libraryBrowse;

  LibrarySortMode get defaultLibrarySortMode =>
      libraryBrowseSettings.defaultSortMode;

  int get catalogueFetchTimeoutSeconds =>
      networkSettings.catalogueFetchTimeoutSeconds;

  PlaybackSettings get playbackSettings => _settings.playback;

  /// Persisted default playback rate (ADR-011).
  double get defaultPlaybackRate => playbackSettings.defaultPlaybackSpeed;

  /// Loads persisted settings once at startup. Safe to call multiple times.
  Future<SettingsLoadResult> initialize() async {
    if (_isLoaded) {
      return SettingsLoadResult(
        settings: _settings,
        source: _lastLoadSource ?? SettingsLoadSource.defaults,
      );
    }
    return load();
  }

  /// Loads settings per ADR-004: envelope → legacy migration → defaults.
  ///
  /// Re-reads from disk on every call. Prefer [initialize] for app startup.
  Future<SettingsLoadResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];

    final envelopeRaw = prefs.getString(storageKey);
    if (envelopeRaw != null && envelopeRaw.trim().isNotEmpty) {
      final parsed = _parseEnvelopeString(envelopeRaw, warnings);
      if (parsed != null) {
        _settings = parsed;
        return _completeLoad(
          SettingsLoadResult(
            settings: parsed,
            source: SettingsLoadSource.envelope,
            recoveryWarnings: warnings,
          ),
        );
      }
    }

    final legacyConfig = _tryParseLegacyProviderConfig(prefs, warnings);
    if (legacyConfig != null) {
      _settings = ApplicationSettings.fromProviderConfig(legacyConfig);
      await _writeEnvelope(_settings);
      return _completeLoad(
        SettingsLoadResult(
          settings: _settings,
          source: SettingsLoadSource.legacyMigration,
          recoveryWarnings: warnings,
        ),
      );
    }

    _settings = ApplicationSettings.defaults();
    return _completeLoad(
      SettingsLoadResult(
        settings: _settings,
        source: SettingsLoadSource.defaults,
        recoveryWarnings: warnings,
      ),
    );
  }

  SettingsLoadResult _completeLoad(SettingsLoadResult result) {
    _isLoaded = true;
    _lastLoadSource = result.source;
    notifyListeners();
    return result;
  }

  /// Validates and atomically persists [settings]. Does not write the legacy key.
  Future<SettingsSaveResult> save(ApplicationSettings settings) async {
    final errors = settings.validate();
    if (errors.isNotEmpty) {
      return SettingsSaveResult(success: false, validationErrors: errors);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
    _settings = settings.copyWith(
      settingsVersion: ApplicationSettings.currentSettingsVersion,
    );
    _isLoaded = true;
    notifyListeners();
    return const SettingsSaveResult(success: true);
  }

  /// Updates only the provider slice and saves the full envelope.
  Future<SettingsSaveResult> saveProviderConfig(
    MediaProviderConfig config,
  ) async {
    return save(
      _settings.copyWith(
        libraryProviders: LibraryProvidersSettings(providerConfig: config),
      ),
    );
  }

  /// Updates only the network slice and saves the full envelope.
  Future<SettingsSaveResult> saveNetworkSettings(NetworkSettings network) async {
    return save(_settings.copyWith(network: network));
  }

  /// Updates library browse preferences (global default sort only).
  Future<SettingsSaveResult> saveLibraryBrowseSettings(
    LibraryBrowseSettings libraryBrowse,
  ) async {
    return save(
      _settings.copyWith(
        general: _settings.general.copyWith(libraryBrowse: libraryBrowse),
      ),
    );
  }

  /// Updates the persisted global default sort mode (ADR-008).
  Future<SettingsSaveResult> saveDefaultLibrarySortMode(
    LibrarySortMode sortMode,
  ) async {
    return saveLibraryBrowseSettings(
      _settings.general.libraryBrowse.copyWith(defaultSortMode: sortMode),
    );
  }

  /// Updates only the playback slice and saves the full envelope.
  Future<SettingsSaveResult> savePlaybackSettings(
    PlaybackSettings playback,
  ) async {
    return save(_settings.copyWith(playback: playback));
  }

  /// Updates the persisted default playback rate.
  Future<SettingsSaveResult> saveDefaultPlaybackRate(double rate) async {
    if (!PlaybackRatePresets.isSupported(rate)) {
      return const SettingsSaveResult(
        success: false,
        validationErrors: ['Unsupported playback rate.'],
      );
    }
    return savePlaybackSettings(
      _settings.playback.copyWith(defaultPlaybackSpeed: rate),
    );
  }

  /// Resets playback preferences to defaults.
  Future<void> resetPlaybackToDefaults() async {
    _settings = _settings.copyWith(playback: PlaybackSettings.defaults());
    await _writeEnvelope(_settings);
    _isLoaded = true;
    notifyListeners();
  }

  /// Resets provider configuration to defaults and clears the legacy key.
  Future<void> resetProviderToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(MediaProviderConfigService.prefKey);
    _settings = _settings.copyWith(
      libraryProviders: LibraryProvidersSettings.defaults(),
    );
    await _writeEnvelope(_settings);
    _isLoaded = true;
    notifyListeners();
  }

  /// Resets all settings groups to defaults and clears the legacy key.
  ///
  /// Does not touch playback progress, catalogue runtime keys, or scanner config.
  Future<void> resetAllToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(MediaProviderConfigService.prefKey);
    _settings = ApplicationSettings.defaults();
    await _writeEnvelope(_settings);
    _isLoaded = true;
    notifyListeners();
  }

  ApplicationSettings? _parseEnvelopeString(
    String raw,
    List<String> warnings,
  ) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        debugPrint('[SettingsRepository] envelope is not a JSON object.');
        warnings.add('Stored settings could not be read.');
        return null;
      }
      return ApplicationSettings.fromJsonWithRecovery(json, warnings: warnings);
    } catch (e) {
      debugPrint('[SettingsRepository] corrupt envelope JSON: $e');
      warnings.add('Stored settings could not be read.');
      return null;
    }
  }

  MediaProviderConfig? _tryParseLegacyProviderConfig(
    SharedPreferences prefs,
    List<String> warnings,
  ) {
    final raw = prefs.getString(MediaProviderConfigService.prefKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = MediaProviderConfig.fromJson(json);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        debugPrint(
          '[SettingsRepository] invalid legacy provider config: '
          '${errors.join(' ')}',
        );
        warnings.add('Legacy provider configuration was invalid.');
        return null;
      }
      return parsed;
    } catch (e) {
      debugPrint('[SettingsRepository] could not load legacy provider config: $e');
      warnings.add('Legacy provider configuration could not be read.');
      return null;
    }
  }

  Future<void> _writeEnvelope(ApplicationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }
}
