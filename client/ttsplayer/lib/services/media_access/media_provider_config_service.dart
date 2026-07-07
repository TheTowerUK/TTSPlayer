import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_access_config.dart';
import 'media_provider_config.dart';

/// Loads and persists [MediaProviderConfig].
///
/// [load] runs at app startup in [main] before the widget tree is built.
/// Settings also calls [load] when opened so the form reflects persisted values.
class MediaProviderConfigService extends ChangeNotifier {
  MediaProviderConfigService({MediaProviderConfig? initialConfig})
      : _config = initialConfig ?? MediaProviderConfig.defaults();

  static const prefKey = 'media_provider_config_v1';

  MediaProviderConfig _config;

  MediaProviderConfig get config => _config;

  /// Active media access slice for [MediaLocationResolver].
  MediaAccessConfig get mediaAccess => _config.mediaAccess;

  /// Loads persisted config or keeps defaults when missing/invalid.
  Future<MediaProviderConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.trim().isEmpty) {
      return _applyDefaultsWithoutNotify();
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = MediaProviderConfig.fromJson(json);
      final errors = parsed.validate();
      if (errors.isNotEmpty) {
        debugPrint(
          '[MediaProviderConfigService] invalid stored config: ${errors.join(' ')}',
        );
        return _applyDefaultsWithoutNotify();
      }
      _config = parsed;
      notifyListeners();
      return _config;
    } catch (e) {
      debugPrint('[MediaProviderConfigService] could not load config: $e');
      return _applyDefaultsWithoutNotify();
    }
  }

  /// Persists [config] when valid. Returns false without writing when invalid.
  Future<bool> save(MediaProviderConfig config) async {
    final errors = config.validate();
    if (errors.isNotEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, jsonEncode(config.toJson()));
    _config = config;
    notifyListeners();
    return true;
  }

  /// Removes persisted config and restores [MediaProviderConfig.defaults].
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKey);
    _config = MediaProviderConfig.defaults();
    notifyListeners();
  }

  MediaProviderConfig _applyDefaultsWithoutNotify() {
    _config = MediaProviderConfig.defaults();
    notifyListeners();
    return _config;
  }
}
