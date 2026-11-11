import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists Continue-row dismissals by media item ID without clearing progress.
///
/// A dismissal stores the progress token at hide time. Matching tokens stay
/// hidden; a different token (new playback or reading progress) reveals the
/// item again. Undo deletes the ID from this map only.
class ContinueRowDismissalStore {
  ContinueRowDismissalStore(this.storageKey);

  static const watchingStorageKey = 'continue_watching_hidden_v1';
  static const readingStorageKey = 'continue_reading_hidden_v1';

  final String storageKey;
  final Map<String, String> _tokens = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    _tokens
      ..clear()
      ..addAll(_decode(raw));
    _loaded = true;
  }

  /// Whether [mediaId] is hidden for this exact [progressToken].
  bool hides(String mediaId, String progressToken) {
    final stored = _tokens[mediaId];
    if (stored == null) return false;
    return stored == progressToken;
  }

  Future<void> hide(String mediaId, String progressToken) async {
    await ensureLoaded();
    _tokens[mediaId] = progressToken;
    await _persist();
  }

  Future<void> restore(String mediaId) async {
    await ensureLoaded();
    if (!_tokens.containsKey(mediaId)) return;
    _tokens.remove(mediaId);
    await _persist();
  }

  /// Clears a stale hide when progress no longer matches the dismissed token.
  Future<bool> revealIfProgressChanged(
    String mediaId,
    String progressToken,
  ) async {
    await ensureLoaded();
    final stored = _tokens[mediaId];
    if (stored == null || stored == progressToken) return false;
    _tokens.remove(mediaId);
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(_tokens));
  }

  static Map<String, String> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final tokens = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String && key.isNotEmpty) {
          tokens[key] = value;
        }
      }
      return tokens;
    } catch (_) {
      return {};
    }
  }
}
