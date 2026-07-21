import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_listening_policy.dart';
import '../models/music_listening_record.dart';

/// Where persisted listening history was loaded from.
enum MusicListeningLoadSource {
  envelope,
  defaults,
}

/// Outcome of [MusicListeningRepository.load] / [initialize].
class MusicListeningLoadResult {
  const MusicListeningLoadResult({
    required this.records,
    required this.source,
    this.recoveryWarnings = const [],
  });

  final List<MusicListeningRecord> records;
  final MusicListeningLoadSource source;
  final List<String> recoveryWarnings;
}

/// Outcome of a mutating repository operation.
class MusicListeningSaveResult {
  const MusicListeningSaveResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

/// Loads, validates, and persists music listening history (M5.4).
///
/// Persistence-only — does not observe playback or mutate catalogue data.
class MusicListeningRepository extends ChangeNotifier {
  MusicListeningRepository({List<MusicListeningRecord>? initialRecords})
      : _records = _sortRecords(initialRecords ?? const []);

  static const storageKey = 'ttsplayer_music_listening_v1';
  static const currentStateVersion = 1;

  List<MusicListeningRecord> _records;
  bool _isLoaded = false;
  MusicListeningLoadSource? _lastLoadSource;
  List<String> _lastRecoveryWarnings = const [];

  /// When true, [save] / persistence writes fail (tests only).
  @visibleForTesting
  bool simulatePersistFailure = false;

  bool get isLoaded => _isLoaded;

  List<String> get lastRecoveryWarnings => _lastRecoveryWarnings;

  int get storedRecordCount => _records.length;

  /// All records ordered by [MusicListeningRecord.lastPlayedAt] descending.
  List<MusicListeningRecord> get allRecords =>
      List<MusicListeningRecord>.unmodifiable(_records);

  /// Loads persisted history once at startup. Safe to call multiple times.
  Future<MusicListeningLoadResult> initialize() async {
    if (_isLoaded) {
      return MusicListeningLoadResult(
        records: allRecords,
        source: _lastLoadSource ?? MusicListeningLoadSource.defaults,
        recoveryWarnings: _lastRecoveryWarnings,
      );
    }
    return load();
  }

  /// Re-reads history from storage on every call.
  Future<MusicListeningLoadResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];

    final raw = prefs.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = _parseEnvelopeString(raw, warnings);
      if (parsed != null) {
        _records = parsed.records;
        return _completeLoad(
          MusicListeningLoadResult(
            records: allRecords,
            source: parsed.validEnvelope
                ? MusicListeningLoadSource.envelope
                : MusicListeningLoadSource.defaults,
            recoveryWarnings: warnings,
          ),
        );
      }
    }

    _records = const [];
    return _completeLoad(
      MusicListeningLoadResult(
        records: allRecords,
        source: MusicListeningLoadSource.defaults,
        recoveryWarnings: warnings,
      ),
    );
  }

  MusicListeningRecord? getByTrackId(String trackId) {
    for (final record in _records) {
      if (record.trackId == trackId) {
        return record;
      }
    }
    return null;
  }

  /// Inserts or replaces the record for [record.trackId], applies retention,
  /// and persists.
  Future<MusicListeningSaveResult> upsert(MusicListeningRecord record) async {
    if (record.trackId.trim().isEmpty) {
      return const MusicListeningSaveResult(
        success: false,
        errorMessage: 'trackId is required.',
      );
    }

    final normalized = record.normalized();
    final byId = <String, MusicListeningRecord>{
      for (final existing in _records) existing.trackId: existing,
    };
    byId[normalized.trackId] = normalized;

    final next = _applyRetention(byId.values.toList());
    return _persist(next);
  }

  Future<MusicListeningSaveResult> remove(String trackId) async {
    if (trackId.trim().isEmpty) {
      return const MusicListeningSaveResult(success: true);
    }

    final next = _records
        .where((record) => record.trackId != trackId)
        .toList(growable: false);
    if (next.length == _records.length) {
      return const MusicListeningSaveResult(success: true);
    }
    return _persist(next);
  }

  Future<MusicListeningSaveResult> clearAll() async {
    return _persist(const []);
  }

  /// Incomplete, resume-eligible records — most recently played first.
  List<MusicListeningRecord> continueListening({int? limit}) {
    final eligible =
        _records.where(_isContinueListeningEligible).toList(growable: false);
    if (limit != null && limit >= 0 && eligible.length > limit) {
      return eligible.sublist(0, limit);
    }
    return eligible;
  }

  /// All stored records — most recently played first.
  List<MusicListeningRecord> recentlyPlayed({
    int limit = MusicListeningPolicy.defaultRecentlyPlayedQueryCap,
  }) {
    if (limit < 0) {
      return allRecords;
    }
    if (_records.length <= limit) {
      return allRecords;
    }
    return _records.sublist(0, limit);
  }

  MusicListeningLoadResult _completeLoad(MusicListeningLoadResult result) {
    _isLoaded = true;
    _lastLoadSource = result.source;
    _lastRecoveryWarnings = result.recoveryWarnings;
    notifyListeners();
    return result;
  }

  Future<MusicListeningSaveResult> _persist(
      List<MusicListeningRecord> records) async {
    if (simulatePersistFailure) {
      return const MusicListeningSaveResult(
        success: false,
        errorMessage: 'Could not save music listening history.',
      );
    }

    final normalized = _applyRetention(records);
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await prefs.setString(
        storageKey,
        jsonEncode(_envelopeToJson(normalized)),
      );
      if (!persisted) {
        return const MusicListeningSaveResult(
          success: false,
          errorMessage: 'Could not save music listening history.',
        );
      }

      _records = normalized;
      _isLoaded = true;
      notifyListeners();
      return const MusicListeningSaveResult(success: true);
    } catch (e, stackTrace) {
      debugPrint(
        '[MusicListeningRepository] persist failed: $e\n$stackTrace',
      );
      return const MusicListeningSaveResult(
        success: false,
        errorMessage: 'Could not save music listening history.',
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
        warnings.add('Stored music listening history could not be read.');
        return null;
      }

      final version = json['stateVersion'];
      if (version is! int || version != currentStateVersion) {
        if (version is! int) {
          warnings.add(
            'Missing stateVersion; stored music listening history was not loaded.',
          );
        } else {
          warnings.add(
            'Unsupported stateVersion $version; stored music listening history was not loaded.',
          );
        }
        return const _EnvelopeParseResult(
          records: [],
          validEnvelope: false,
        );
      }

      return _EnvelopeParseResult(
        records: _parseRecordList(json['records'], warnings),
        validEnvelope: true,
      );
    } catch (e) {
      debugPrint('[MusicListeningRepository] corrupt envelope JSON: $e');
      warnings.add('Stored music listening history could not be read.');
      return null;
    }
  }

  static List<MusicListeningRecord> _parseRecordList(
    dynamic raw,
    List<String> warnings,
  ) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List<dynamic>) {
      warnings.add('Listening record list was invalid.');
      return const [];
    }

    final parsed = <MusicListeningRecord>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        warnings.add('Skipped malformed listening record.');
        continue;
      }
      final record = MusicListeningRecord.fromJsonWithRecovery(
        entry,
        warnings: warnings,
      );
      if (record != null) {
        parsed.add(record);
      }
    }
    return _dedupeAndSort(parsed);
  }

  static List<MusicListeningRecord> _dedupeAndSort(
    List<MusicListeningRecord> records,
  ) {
    final byId = <String, MusicListeningRecord>{};
    for (final record in records) {
      final existing = byId[record.trackId];
      if (existing == null ||
          record.lastPlayedAt.isAfter(existing.lastPlayedAt)) {
        byId[record.trackId] = record;
      }
    }
    return _sortRecords(byId.values.toList());
  }

  static List<MusicListeningRecord> _applyRetention(
    List<MusicListeningRecord> records,
  ) {
    final sorted = _sortRecords(records);
    if (sorted.length <= MusicListeningPolicy.maxStoredRecords) {
      return sorted;
    }
    return sorted.sublist(0, MusicListeningPolicy.maxStoredRecords);
  }

  static List<MusicListeningRecord> _sortRecords(
    List<MusicListeningRecord> records,
  ) {
    final sorted = List<MusicListeningRecord>.from(records);
    sorted.sort(compareRecords);
    return sorted;
  }

  static int compareRecords(MusicListeningRecord a, MusicListeningRecord b) {
    final byTime = b.lastPlayedAt.compareTo(a.lastPlayedAt);
    if (byTime != 0) return byTime;
    return a.trackId.compareTo(b.trackId);
  }

  static bool _isContinueListeningEligible(MusicListeningRecord record) {
    if (record.completed) return false;
    if (record.lastPosition < MusicListeningPolicy.minResumePosition) {
      return false;
    }

    final duration = record.duration;
    if (duration != null && duration > Duration.zero) {
      final remaining = duration - record.lastPosition;
      if (remaining < MusicListeningPolicy.nearEndWindow) {
        return false;
      }
    }
    return true;
  }

  static Map<String, dynamic> _envelopeToJson(
    List<MusicListeningRecord> records,
  ) {
    return {
      'stateVersion': currentStateVersion,
      'records': records.map((record) => record.toJson()).toList(),
    };
  }
}

class _EnvelopeParseResult {
  const _EnvelopeParseResult({
    required this.records,
    required this.validEnvelope,
  });

  final List<MusicListeningRecord> records;
  final bool validEnvelope;
}
