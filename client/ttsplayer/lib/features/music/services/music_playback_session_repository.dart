import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
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

/// Outcome of [MusicPlaybackSessionRepository.validateAgainstCatalog].
class MusicPlaybackSessionValidationResult {
  const MusicPlaybackSessionValidationResult({
    required this.changed,
    required this.originalCount,
    required this.retainedCount,
    required this.removedCount,
    this.activeTrackRetained = false,
    this.sessionCleared = false,
    this.persisted = false,
    this.persistenceFailed = false,
    this.warnings = const [],
  });

  final bool changed;
  final int originalCount;
  final int retainedCount;
  final int removedCount;
  final bool activeTrackRetained;
  final bool sessionCleared;
  final bool persisted;
  final bool persistenceFailed;
  final List<String> warnings;
}

/// Loads and persists music playback session state (M5.5).
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

  /// Prunes queue IDs absent from playable audio items in [catalog].
  ///
  /// Identity is [MediaItem.id] only. Persists and notifies only when the
  /// reconciled session differs from the current in-memory session.
  Future<MusicPlaybackSessionValidationResult> validateAgainstCatalog(
    Catalog catalog,
  ) async {
    try {
      if (_session.isEmpty) {
        return const MusicPlaybackSessionValidationResult(
          changed: false,
          originalCount: 0,
          retainedCount: 0,
          removedCount: 0,
        );
      }

      final originalCount = _session.queueTrackIds.length;
      final reconciled = reconcileSession(_session, catalog);
      final removedCount = originalCount - reconciled.queueTrackIds.length;
      final activeSurvived = _session.activeTrackId != null &&
          reconciled.activeTrackId == _session.activeTrackId;

      if (reconciled == _session) {
        return MusicPlaybackSessionValidationResult(
          changed: false,
          originalCount: originalCount,
          retainedCount: reconciled.queueTrackIds.length,
          removedCount: 0,
          activeTrackRetained: activeSurvived,
          sessionCleared: reconciled.isEmpty,
        );
      }

      final saveResult = reconciled.isEmpty
          ? await _persistEmptyAfterReconcile()
          : await _persist(reconciled);

      if (!saveResult.success) {
        return MusicPlaybackSessionValidationResult(
          changed: false,
          originalCount: originalCount,
          retainedCount: _session.queueTrackIds.length,
          removedCount: 0,
          activeTrackRetained: _session.activeTrackId != null &&
              reconciled.activeTrackId == _session.activeTrackId,
          sessionCleared: _session.isEmpty,
          persistenceFailed: true,
          warnings: [
            saveResult.errorMessage ??
                'Could not persist reconciled music playback session.',
          ],
        );
      }

      if (kDebugMode && removedCount > 0) {
        debugPrint(
          '[MusicPlaybackSessionRepository] pruned $removedCount playback '
          'session track(s) after catalogue replacement.',
        );
      }

      return MusicPlaybackSessionValidationResult(
        changed: true,
        originalCount: originalCount,
        retainedCount: reconciled.queueTrackIds.length,
        removedCount: removedCount,
        activeTrackRetained: activeSurvived,
        sessionCleared: reconciled.isEmpty,
        persisted: true,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[MusicPlaybackSessionRepository] validateAgainstCatalog failed: '
        '$e\n$stackTrace',
      );
      return MusicPlaybackSessionValidationResult(
        changed: false,
        originalCount: _session.queueTrackIds.length,
        retainedCount: _session.queueTrackIds.length,
        removedCount: 0,
        persistenceFailed: true,
        warnings: const [
          'Catalogue playback-session validation failed unexpectedly.',
        ],
      );
    }
  }

  /// Reconciles [source] against playable audio items in [catalog].
  @visibleForTesting
  static MusicPlaybackSession reconcileSession(
    MusicPlaybackSession source,
    Catalog catalog,
  ) {
    final playableById = _playableAudioByTrackId(catalog);
    if (source.isEmpty) {
      return source.normalized(updatedAtOverride: source.updatedAt);
    }

    final retained = <String>[];
    for (final trackId in source.queueTrackIds) {
      if (playableById.containsKey(trackId)) {
        retained.add(trackId);
      }
    }

    if (retained.isEmpty) {
      return MusicPlaybackSession(
        queueTrackIds: const [],
        activeTrackId: null,
        playbackPosition: Duration.zero,
        updatedAt: source.updatedAt,
      ).normalized(updatedAtOverride: source.updatedAt);
    }

    final activeSurvived =
        source.activeTrackId != null && retained.contains(source.activeTrackId);

    if (activeSurvived) {
      return source
          .copyWith(queueTrackIds: retained)
          .normalized(updatedAtOverride: source.updatedAt);
    }

    return MusicPlaybackSession(
      queueTrackIds: retained,
      activeTrackId: retained.first,
      playbackPosition: Duration.zero,
      updatedAt: source.updatedAt,
    ).normalized(updatedAtOverride: source.updatedAt);
  }

  Future<MusicPlaybackSessionSaveResult> _persistEmptyAfterReconcile() async {
    return _persist(_emptySession().normalized());
  }

  static Map<String, MediaItem> _playableAudioByTrackId(Catalog catalog) {
    final byId = <String, MediaItem>{};
    for (final item in catalog.allItems) {
      if (!item.isAudio || !item.status.isPlayable) continue;
      byId.putIfAbsent(item.id, () => item);
    }
    return byId;
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
