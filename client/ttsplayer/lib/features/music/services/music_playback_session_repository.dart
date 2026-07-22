import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_playback_session.dart';

/// Where persisted playback session state was loaded from.
enum MusicPlaybackSessionLoadSource {
  envelope,
  defaults,
}

/// Outcome of [MusicPlaybackSessionRepository.load] / [initialize].
class MusicPlaybackSessionLoadResult {
  const MusicPlaybackSessionLoadResult({
    required this.session,
    required this.source,
    this.recoveryWarnings = const [],
  });

  final MusicPlaybackSession session;
  final MusicPlaybackSessionLoadSource source;
  final List<String> recoveryWarnings;
}

/// Outcome of [MusicPlaybackSessionRepository.save].
class MusicPlaybackSessionSaveResult {
  const MusicPlaybackSessionSaveResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

/// Outcome category for [MusicPlaybackSessionRepository.clear].
enum MusicPlaybackSessionClearOutcome {
  cleared,
  alreadyEmpty,
  persistenceFailed,
}

/// Outcome of [MusicPlaybackSessionRepository.clear].
class MusicPlaybackSessionClearResult {
  const MusicPlaybackSessionClearResult({
    required this.outcome,
    this.errorMessage,
  });

  final MusicPlaybackSessionClearOutcome outcome;
  final String? errorMessage;

  bool get success =>
      outcome == MusicPlaybackSessionClearOutcome.cleared ||
      outcome == MusicPlaybackSessionClearOutcome.alreadyEmpty;

  bool get changed => outcome == MusicPlaybackSessionClearOutcome.cleared;
}

/// Loads and persists music playback session state (M5.5 Step 1).
///
/// Persistence-only — playback, catalogue reconciliation, and diagnostics
/// wiring arrive in later steps.
class MusicPlaybackSessionRepository extends ChangeNotifier {
  MusicPlaybackSessionRepository({MusicPlaybackSession? initialSession})
      : _session = (initialSession ?? _emptySession()).normalized();

  static const storageKey = 'ttsplayer_music_queue_v1';
  static const currentStateVersion = 1;

  MusicPlaybackSession _session;
  bool _isLoaded = false;
  MusicPlaybackSessionLoadSource? _lastLoadSource;
  List<String> _lastRecoveryWarnings = const [];

  /// When true, [save] / persistence writes fail (tests only).
  @visibleForTesting
  bool simulatePersistFailure = false;

  bool get isLoaded => _isLoaded;

  MusicPlaybackSession get session => _session;

  List<String> get lastRecoveryWarnings => _lastRecoveryWarnings;

  int get persistedTrackCount => _session.queueTrackIds.length;

  bool get hasPersistedSession => !_session.isEmpty;

  bool get recoveryWarningPresent => _lastRecoveryWarnings.isNotEmpty;

  /// Loads persisted session once at startup. Safe to call multiple times.
  Future<MusicPlaybackSessionLoadResult> initialize() async {
    if (_isLoaded) {
      return MusicPlaybackSessionLoadResult(
        session: session,
        source: _lastLoadSource ?? MusicPlaybackSessionLoadSource.defaults,
        recoveryWarnings: _lastRecoveryWarnings,
      );
    }
    return load();
  }

  /// Re-reads session state from storage on every call.
  Future<MusicPlaybackSessionLoadResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];

    final raw = prefs.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = _parseEnvelopeString(raw, warnings);
      if (parsed != null) {
        _session = parsed.session;
        return _completeLoad(
          MusicPlaybackSessionLoadResult(
            session: session,
            source: parsed.validEnvelope
                ? MusicPlaybackSessionLoadSource.envelope
                : MusicPlaybackSessionLoadSource.defaults,
            recoveryWarnings: warnings,
          ),
        );
      }
    }

    _session = _emptySession().normalized();
    return _completeLoad(
      MusicPlaybackSessionLoadResult(
        session: session,
        source: MusicPlaybackSessionLoadSource.defaults,
        recoveryWarnings: warnings,
      ),
    );
  }

  /// Persists [nextSession] after normalization.
  Future<MusicPlaybackSessionSaveResult> save(
    MusicPlaybackSession nextSession,
  ) async {
    final normalized = nextSession.normalized(
      updatedAtOverride: DateTime.now().toUtc(),
    );
    return _persist(normalized);
  }

  /// Removes persisted session after successful write.
  Future<MusicPlaybackSessionClearResult> clear() async {
    if (_session.isEmpty) {
      return const MusicPlaybackSessionClearResult(
        outcome: MusicPlaybackSessionClearOutcome.alreadyEmpty,
      );
    }

    final saveResult = await _persist(_emptySession().normalized());
    if (!saveResult.success) {
      return MusicPlaybackSessionClearResult(
        outcome: MusicPlaybackSessionClearOutcome.persistenceFailed,
        errorMessage: saveResult.errorMessage,
      );
    }

    return const MusicPlaybackSessionClearResult(
      outcome: MusicPlaybackSessionClearOutcome.cleared,
    );
  }

  MusicPlaybackSessionLoadResult _completeLoad(
    MusicPlaybackSessionLoadResult result,
  ) {
    _isLoaded = true;
    _lastLoadSource = result.source;
    _lastRecoveryWarnings = result.recoveryWarnings;
    notifyListeners();
    return result;
  }

  Future<MusicPlaybackSessionSaveResult> _persist(
    MusicPlaybackSession nextSession,
  ) async {
    if (simulatePersistFailure) {
      return const MusicPlaybackSessionSaveResult(
        success: false,
        errorMessage: 'Could not save music playback session.',
      );
    }

    final normalized = nextSession.normalized();
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await prefs.setString(
        storageKey,
        jsonEncode(_envelopeToJson(normalized)),
      );
      if (!persisted) {
        return const MusicPlaybackSessionSaveResult(
          success: false,
          errorMessage: 'Could not save music playback session.',
        );
      }

      _session = normalized;
      _isLoaded = true;
      notifyListeners();
      return const MusicPlaybackSessionSaveResult(success: true);
    } catch (e, stackTrace) {
      debugPrint(
        '[MusicPlaybackSessionRepository] persist failed: $e\n$stackTrace',
      );
      return const MusicPlaybackSessionSaveResult(
        success: false,
        errorMessage: 'Could not save music playback session.',
      );
    }
  }

  _EnvelopeParseResult? _parseEnvelopeString(
    String raw,
    List<String> warnings,
  ) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        warnings.add('Stored music playback session could not be read.');
        return null;
      }

      final version = json['stateVersion'];
      if (version is! int || version != currentStateVersion) {
        if (version is! int) {
          warnings.add(
            'Missing stateVersion; stored music playback session was not loaded.',
          );
        } else {
          warnings.add(
            'Unsupported stateVersion $version; stored music playback session was not loaded.',
          );
        }
        return _EnvelopeParseResult(
          session: _emptySession().normalized(),
          validEnvelope: false,
        );
      }

      final sessionRaw = json['session'];
      if (sessionRaw is! Map<String, dynamic>) {
        warnings.add('Stored music playback session could not be read.');
        return null;
      }

      final parsedSession = MusicPlaybackSession.fromSessionJsonWithRecovery(
        sessionRaw,
        warnings: warnings,
      );
      if (parsedSession == null) {
        warnings.add('Stored music playback session could not be read.');
        return null;
      }

      return _EnvelopeParseResult(
        session: parsedSession,
        validEnvelope: true,
      );
    } catch (e) {
      debugPrint('[MusicPlaybackSessionRepository] corrupt envelope JSON: $e');
      warnings.add('Stored music playback session could not be read.');
      return null;
    }
  }

  static Map<String, dynamic> _envelopeToJson(MusicPlaybackSession session) {
    return {
      'stateVersion': currentStateVersion,
      'session': session.toSessionJson(),
    };
  }

  static MusicPlaybackSession _emptySession() {
    return MusicPlaybackSession(
      queueTrackIds: const [],
      activeTrackId: null,
      playbackPosition: Duration.zero,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

class _EnvelopeParseResult {
  const _EnvelopeParseResult({
    required this.session,
    required this.validEnvelope,
  });

  final MusicPlaybackSession session;
  final bool validEnvelope;
}
