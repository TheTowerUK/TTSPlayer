import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/catalog.dart';
import '../models/enrichment_match_state.dart';
import '../models/metadata_enrichment_record.dart';

enum MetadataEnrichmentLoadSource { envelope, defaults }

class MetadataEnrichmentLoadResult {
  const MetadataEnrichmentLoadResult({
    required this.records,
    required this.source,
    this.recoveryWarnings = const [],
  });

  final List<MetadataEnrichmentRecord> records;
  final MetadataEnrichmentLoadSource source;
  final List<String> recoveryWarnings;
}

class MetadataEnrichmentSaveResult {
  const MetadataEnrichmentSaveResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

class MetadataEnrichmentValidationResult {
  const MetadataEnrichmentValidationResult({
    required this.changed,
    required this.retainedCount,
    required this.removedCount,
    this.persisted = false,
    this.persistenceFailed = false,
    this.warnings = const [],
  });

  final bool changed;
  final int retainedCount;
  final int removedCount;
  final bool persisted;
  final bool persistenceFailed;
  final List<String> warnings;
}

/// Counts by match state for later diagnostics (M7.1).
class MetadataEnrichmentCounts {
  const MetadataEnrichmentCounts({
    required this.total,
    required this.byMatchState,
  });

  final int total;
  final Map<EnrichmentMatchState, int> byMatchState;
}

/// Loads, validates, and persists optional metadata enrichment overlays (M7.1).
class MetadataEnrichmentRepository extends ChangeNotifier {
  MetadataEnrichmentRepository({List<MetadataEnrichmentRecord>? initialRecords})
      : _records = _sortRecords(initialRecords ?? const []);

  static const storageKey = 'ttsplayer_metadata_enrichment_v1';
  static const currentStateVersion = 1;

  List<MetadataEnrichmentRecord> _records;
  bool _isLoaded = false;
  MetadataEnrichmentLoadSource? _lastLoadSource;
  List<String> _lastRecoveryWarnings = const [];
  int _lastLoadSkippedRecordCount = 0;
  MetadataEnrichmentValidationResult? _lastValidationResult;
  DateTime? _lastSuccessfulWriteAt;
  String? _lastRepositoryError;

  @visibleForTesting
  bool simulatePersistFailure = false;

  bool get isLoaded => _isLoaded;
  List<String> get lastRecoveryWarnings => _lastRecoveryWarnings;
  int get lastLoadSkippedRecordCount => _lastLoadSkippedRecordCount;
  MetadataEnrichmentValidationResult? get lastValidationResult =>
      _lastValidationResult;
  DateTime? get lastSuccessfulWriteAt => _lastSuccessfulWriteAt;
  String? get lastRepositoryError => _lastRepositoryError;

  int get storedRecordCount => _records.length;

  List<MetadataEnrichmentRecord> get allRecords =>
      List<MetadataEnrichmentRecord>.unmodifiable(_records);

  MetadataEnrichmentCounts get counts {
    final byState = <EnrichmentMatchState, int>{};
    for (final state in EnrichmentMatchState.values) {
      byState[state] = 0;
    }
    for (final record in _records) {
      byState[record.matchState] = (byState[record.matchState] ?? 0) + 1;
    }
    return MetadataEnrichmentCounts(
      total: _records.length,
      byMatchState: byState,
    );
  }

  Future<MetadataEnrichmentLoadResult> initialize() async {
    if (_isLoaded) {
      return MetadataEnrichmentLoadResult(
        records: allRecords,
        source: _lastLoadSource ?? MetadataEnrichmentLoadSource.defaults,
        recoveryWarnings: _lastRecoveryWarnings,
      );
    }
    return load();
  }

  Future<MetadataEnrichmentLoadResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];

    final raw = prefs.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = _parseEnvelopeString(raw, warnings);
      if (parsed != null) {
        _records = parsed.records;
        return _completeLoad(
          MetadataEnrichmentLoadResult(
            records: allRecords,
            source: parsed.validEnvelope
                ? MetadataEnrichmentLoadSource.envelope
                : MetadataEnrichmentLoadSource.defaults,
            recoveryWarnings: warnings,
          ),
        );
      }
    }

    _records = const [];
    return _completeLoad(
      MetadataEnrichmentLoadResult(
        records: allRecords,
        source: MetadataEnrichmentLoadSource.defaults,
        recoveryWarnings: warnings,
      ),
    );
  }

  MetadataEnrichmentRecord? getByItemId(String itemId) {
    for (final record in _records) {
      if (record.itemId == itemId) return record;
    }
    return null;
  }

  Future<MetadataEnrichmentSaveResult> upsert(
    MetadataEnrichmentRecord record,
  ) async {
    if (record.itemId.trim().isEmpty) {
      return const MetadataEnrichmentSaveResult(
        success: false,
        errorMessage: 'itemId is required.',
      );
    }

    final byId = <String, MetadataEnrichmentRecord>{
      for (final item in _records) item.itemId: item,
    };
    byId[record.normalized().itemId] = record.normalized();
    return _persist(byId.values.toList());
  }

  Future<MetadataEnrichmentSaveResult> remove(String itemId) async {
    if (itemId.trim().isEmpty) {
      return const MetadataEnrichmentSaveResult(success: true);
    }
    final next =
        _records.where((record) => record.itemId != itemId).toList();
    if (next.length == _records.length) {
      return const MetadataEnrichmentSaveResult(success: true);
    }
    return _persist(next);
  }

  Future<MetadataEnrichmentSaveResult> clearAll() async {
    if (_records.isEmpty) {
      return const MetadataEnrichmentSaveResult(success: true);
    }
    return _persist(const []);
  }

  /// Removes enrichment records whose [MetadataEnrichmentRecord.itemId] is
  /// absent from [catalog]. Rename/move creates a new item id — old records
  /// are pruned; automatic transfer to the new id is out of scope (M7.1).
  Future<MetadataEnrichmentValidationResult> validateAgainstCatalog(
    Catalog catalog,
  ) async {
    try {
      final validIds = {for (final item in catalog.allItems) item.id};
      final next = <MetadataEnrichmentRecord>[];
      var removedCount = 0;

      for (final record in _records) {
        if (validIds.contains(record.itemId)) {
          next.add(record);
        } else {
          removedCount++;
        }
      }

      if (removedCount == 0) {
        final result = MetadataEnrichmentValidationResult(
          changed: false,
          retainedCount: _records.length,
          removedCount: 0,
        );
        _lastValidationResult = result;
        return result;
      }

      final saveResult = await _persist(next);
      if (!saveResult.success) {
        final result = MetadataEnrichmentValidationResult(
          changed: false,
          retainedCount: _records.length,
          removedCount: 0,
          persistenceFailed: true,
          warnings: [
            saveResult.errorMessage ??
                'Could not persist pruned metadata enrichment.',
          ],
        );
        _lastValidationResult = result;
        return result;
      }

      if (kDebugMode) {
        debugPrint(
          '[MetadataEnrichmentRepository] pruned $removedCount enrichment '
          'record(s) after catalogue replacement.',
        );
      }

      final result = MetadataEnrichmentValidationResult(
        changed: true,
        retainedCount: next.length,
        removedCount: removedCount,
        persisted: true,
      );
      _lastValidationResult = result;
      return result;
    } catch (e, stackTrace) {
      debugPrint(
        '[MetadataEnrichmentRepository] validateAgainstCatalog failed: $e\n'
        '$stackTrace',
      );
      final result = MetadataEnrichmentValidationResult(
        changed: false,
        retainedCount: _records.length,
        removedCount: 0,
        persistenceFailed: true,
        warnings: const [
          'Catalogue metadata-enrichment validation failed unexpectedly.',
        ],
      );
      _lastValidationResult = result;
      return result;
    }
  }

  MetadataEnrichmentLoadResult _completeLoad(
    MetadataEnrichmentLoadResult result,
  ) {
    _isLoaded = true;
    _lastLoadSource = result.source;
    _lastRecoveryWarnings = result.recoveryWarnings;
    _lastLoadSkippedRecordCount = result.recoveryWarnings
        .where((warning) => warning.startsWith('Skipped '))
        .length;
    notifyListeners();
    return result;
  }

  Future<MetadataEnrichmentSaveResult> _persist(
    List<MetadataEnrichmentRecord> records,
  ) async {
    if (simulatePersistFailure) {
      _lastRepositoryError = 'Could not save metadata enrichment.';
      return const MetadataEnrichmentSaveResult(
        success: false,
        errorMessage: 'Could not save metadata enrichment.',
      );
    }

    final normalized = _sortRecords(
      records.map((record) => record.normalized()).toList(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await prefs.setString(
        storageKey,
        jsonEncode(_envelopeToJson(normalized)),
      );
      if (!persisted) {
        _lastRepositoryError = 'Could not save metadata enrichment.';
        return const MetadataEnrichmentSaveResult(
          success: false,
          errorMessage: 'Could not save metadata enrichment.',
        );
      }

      _records = normalized;
      _isLoaded = true;
      _lastSuccessfulWriteAt = DateTime.now().toUtc();
      _lastRepositoryError = null;
      notifyListeners();
      return const MetadataEnrichmentSaveResult(success: true);
    } catch (e, stackTrace) {
      debugPrint(
        '[MetadataEnrichmentRepository] persist failed: $e\n$stackTrace',
      );
      _lastRepositoryError = 'Could not save metadata enrichment.';
      return const MetadataEnrichmentSaveResult(
        success: false,
        errorMessage: 'Could not save metadata enrichment.',
      );
    }
  }

  Map<String, Object?> _envelopeToJson(
    List<MetadataEnrichmentRecord> records,
  ) =>
      {
        'stateVersion': currentStateVersion,
        'records': records.map((record) => record.toJson()).toList(),
      };

  _EnvelopeParseResult? _parseEnvelopeString(
    String raw,
    List<String> warnings,
  ) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        warnings.add('Stored metadata enrichment could not be read.');
        return null;
      }

      final version = json['stateVersion'];
      if (version is! int) {
        warnings.add(
          'Missing stateVersion; stored metadata enrichment was not loaded.',
        );
        return const _EnvelopeParseResult(records: [], validEnvelope: false);
      }
      if (version > currentStateVersion) {
        warnings.add(
          'Unsupported stateVersion $version; stored metadata enrichment '
          'was not loaded.',
        );
        return const _EnvelopeParseResult(records: [], validEnvelope: false);
      }
      if (version < currentStateVersion) {
        warnings.add(
          'Unsupported stateVersion $version; stored metadata enrichment '
          'was not loaded.',
        );
        return const _EnvelopeParseResult(records: [], validEnvelope: false);
      }

      return _EnvelopeParseResult(
        records: _parseRecordList(json['records'], warnings),
        validEnvelope: true,
      );
    } catch (e) {
      debugPrint('[MetadataEnrichmentRepository] corrupt envelope JSON: $e');
      warnings.add('Stored metadata enrichment could not be read.');
      return null;
    }
  }

  static List<MetadataEnrichmentRecord> _parseRecordList(
    dynamic raw,
    List<String> warnings,
  ) {
    if (raw == null) return const [];
    if (raw is! List<dynamic>) {
      warnings.add('Metadata enrichment record list was invalid.');
      return const [];
    }

    final parsed = <MetadataEnrichmentRecord>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        warnings.add('Skipped malformed metadata enrichment record.');
        continue;
      }
      final record = MetadataEnrichmentRecord.fromJsonWithRecovery(
        entry,
        warnings: warnings,
      );
      if (record != null) {
        parsed.add(record);
      }
    }
    return _dedupeAndSort(parsed);
  }

  static List<MetadataEnrichmentRecord> _dedupeAndSort(
    List<MetadataEnrichmentRecord> records,
  ) {
    final byId = <String, MetadataEnrichmentRecord>{};
    for (final record in records) {
      final existing = byId[record.itemId];
      if (existing == null) {
        byId[record.itemId] = record;
        continue;
      }
      if (_compareRecordPreference(record, existing) > 0) {
        byId[record.itemId] = record;
      }
    }
    return _sortRecords(byId.values.toList());
  }

  /// Duplicate [itemId] recovery preference (deterministic):
  /// 1. Latest [MetadataEnrichmentRecord.fetchedAt] (missing → epoch UTC)
  /// 2. Higher [confidence] (missing → 0)
  /// 3. Lexicographically greater [providerRecordId] (missing → empty)
  /// 4. More enriched [fields]
  /// 5. Retain the incumbent record
  static int _compareRecordPreference(
    MetadataEnrichmentRecord candidate,
    MetadataEnrichmentRecord incumbent,
  ) {
    final candidateFetched = candidate.fetchedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final incumbentFetched = incumbent.fetchedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final fetchedCompare = candidateFetched.compareTo(incumbentFetched);
    if (fetchedCompare != 0) return fetchedCompare;

    final candidateConfidence = candidate.confidence ?? 0;
    final incumbentConfidence = incumbent.confidence ?? 0;
    final confidenceCompare =
        candidateConfidence.compareTo(incumbentConfidence);
    if (confidenceCompare != 0) return confidenceCompare;

    final candidateProvider = candidate.providerRecordId ?? '';
    final incumbentProvider = incumbent.providerRecordId ?? '';
    final providerCompare = candidateProvider.compareTo(incumbentProvider);
    if (providerCompare != 0) return providerCompare;

    final fieldCountCompare =
        candidate.fields.length.compareTo(incumbent.fields.length);
    if (fieldCountCompare != 0) return fieldCountCompare;

    return 0;
  }

  static List<MetadataEnrichmentRecord> _sortRecords(
    List<MetadataEnrichmentRecord> records,
  ) {
    final sorted = List<MetadataEnrichmentRecord>.from(records);
    sorted.sort((a, b) {
      final byFetched = _compareNullableDateTime(b.fetchedAt, a.fetchedAt);
      if (byFetched != 0) return byFetched;
      return a.itemId.compareTo(b.itemId);
    });
    return sorted;
  }

  static int _compareNullableDateTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}

class _EnvelopeParseResult {
  const _EnvelopeParseResult({
    required this.records,
    required this.validEnvelope,
  });

  final List<MetadataEnrichmentRecord> records;
  final bool validEnvelope;
}
