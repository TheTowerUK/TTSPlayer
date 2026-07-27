import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/catalog.dart';
import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../models/reading_location_payload.dart';
import '../models/reading_progress_policy.dart';
import '../models/reading_progress_record.dart';

enum ReadingProgressLoadSource { envelope, defaults }

class ReadingProgressLoadResult {
  const ReadingProgressLoadResult({
    required this.records,
    required this.source,
    this.recoveryWarnings = const [],
  });

  final List<ReadingProgressRecord> records;
  final ReadingProgressLoadSource source;
  final List<String> recoveryWarnings;
}

class ReadingProgressSaveResult {
  const ReadingProgressSaveResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

class ReadingProgressValidationResult {
  const ReadingProgressValidationResult({
    required this.changed,
    required this.retainedCount,
    required this.removedCount,
    this.removedMissingCount = 0,
    this.removedFormatMismatchCount = 0,
    this.metadataRefreshedCount = 0,
    this.staleCount = 0,
    this.persisted = false,
    this.persistenceFailed = false,
    this.warnings = const [],
  });

  final bool changed;
  final int retainedCount;
  final int removedCount;
  final int removedMissingCount;
  final int removedFormatMismatchCount;
  final int metadataRefreshedCount;
  final int staleCount;
  final bool persisted;
  final bool persistenceFailed;
  final List<String> warnings;
}

/// Loads, validates, and persists reading progress (M6.5).
class ReadingProgressRepository extends ChangeNotifier {
  ReadingProgressRepository({List<ReadingProgressRecord>? initialRecords})
      : _records = _sortRecords(initialRecords ?? const []);

  static const storageKey = 'ttsplayer_reading_progress_v1';
  static const currentStateVersion = 1;

  List<ReadingProgressRecord> _records;
  bool _isLoaded = false;
  ReadingProgressLoadSource? _lastLoadSource;
  List<String> _lastRecoveryWarnings = const [];
  int _lastLoadSkippedRecordCount = 0;
  ReadingProgressValidationResult? _lastValidationResult;
  DateTime? _lastSuccessfulWriteAt;
  String? _lastRepositoryError;

  @visibleForTesting
  bool simulatePersistFailure = false;

  bool get isLoaded => _isLoaded;
  List<String> get lastRecoveryWarnings => _lastRecoveryWarnings;
  int get lastLoadSkippedRecordCount => _lastLoadSkippedRecordCount;
  ReadingProgressValidationResult? get lastValidationResult =>
      _lastValidationResult;
  DateTime? get lastSuccessfulWriteAt => _lastSuccessfulWriteAt;
  String? get lastRepositoryError => _lastRepositoryError;

  int get storedRecordCount => _records.length;
  int get completedRecordCount =>
      _records.where((record) => record.completed).length;
  int get incompleteRecordCount =>
      _records.where((record) => !record.completed).length;
  int get continueReadingCount => continueReading().length;
  bool get recoveryWarningPresent => _lastRecoveryWarnings.isNotEmpty;

  List<ReadingProgressRecord> get allRecords =>
      List<ReadingProgressRecord>.unmodifiable(_records);

  Future<ReadingProgressLoadResult> initialize() async {
    if (_isLoaded) {
      return ReadingProgressLoadResult(
        records: allRecords,
        source: _lastLoadSource ?? ReadingProgressLoadSource.defaults,
        recoveryWarnings: _lastRecoveryWarnings,
      );
    }
    return load();
  }

  Future<ReadingProgressLoadResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];

    final raw = prefs.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = _parseEnvelopeString(raw, warnings);
      if (parsed != null) {
        _records = parsed.records;
        return _completeLoad(
          ReadingProgressLoadResult(
            records: allRecords,
            source: parsed.validEnvelope
                ? ReadingProgressLoadSource.envelope
                : ReadingProgressLoadSource.defaults,
            recoveryWarnings: warnings,
          ),
        );
      }
    }

    _records = const [];
    return _completeLoad(
      ReadingProgressLoadResult(
        records: allRecords,
        source: ReadingProgressLoadSource.defaults,
        recoveryWarnings: warnings,
      ),
    );
  }

  ReadingProgressRecord? getByMediaId(String mediaId) {
    for (final record in _records) {
      if (record.mediaId == mediaId) return record;
    }
    return null;
  }

  Future<ReadingProgressSaveResult> upsert(ReadingProgressRecord record) async {
    if (record.mediaId.trim().isEmpty) {
      return const ReadingProgressSaveResult(
        success: false,
        errorMessage: 'mediaId is required.',
      );
    }

    final normalized = record.normalized();
    final existing = getByMediaId(normalized.mediaId);
    final withFirstRead = existing?.firstReadAt != null
        ? normalized.copyWith(firstReadAt: existing!.firstReadAt)
        : normalized.copyWith(firstReadAt: normalized.lastReadAt);

    final byId = <String, ReadingProgressRecord>{
      for (final item in _records) item.mediaId: item,
    };
    byId[withFirstRead.mediaId] = withFirstRead;

    return _persist(byId.values.toList());
  }

  Future<ReadingProgressSaveResult> remove(String mediaId) async {
    if (mediaId.trim().isEmpty) {
      return const ReadingProgressSaveResult(success: true);
    }
    final next =
        _records.where((record) => record.mediaId != mediaId).toList();
    if (next.length == _records.length) {
      return const ReadingProgressSaveResult(success: true);
    }
    return _persist(next);
  }

  Future<ReadingProgressValidationResult> validateAgainstCatalog(
    Catalog catalog,
  ) async {
    try {
      final itemsById = _readingItemsByMediaId(catalog);
      final next = <ReadingProgressRecord>[];
      var removedCount = 0;
      var removedMissingCount = 0;
      var removedFormatMismatchCount = 0;
      var metadataRefreshedCount = 0;

      for (final record in _records) {
        final item = itemsById[record.mediaId];
        if (item == null) {
          removedCount++;
          removedMissingCount++;
          continue;
        }
        if (!_formatMatchesItem(record, item)) {
          removedCount++;
          removedFormatMismatchCount++;
          continue;
        }
        final refreshed = _refreshSnapshot(record, item);
        if (refreshed != record) {
          metadataRefreshedCount++;
        }
        next.add(refreshed);
      }

      final changed = removedCount > 0 || metadataRefreshedCount > 0;
      if (!changed) {
        final result = ReadingProgressValidationResult(
          changed: false,
          retainedCount: _records.length,
          removedCount: 0,
        );
        _lastValidationResult = result;
        return result;
      }

      final saveResult = await _persist(next);
      if (!saveResult.success) {
        final result = ReadingProgressValidationResult(
          changed: false,
          retainedCount: _records.length,
          removedCount: 0,
          persistenceFailed: true,
          warnings: [
            saveResult.errorMessage ??
                'Could not persist pruned reading progress.',
          ],
        );
        _lastValidationResult = result;
        return result;
      }

      if (kDebugMode && removedCount > 0) {
        debugPrint(
          '[ReadingProgressRepository] pruned $removedCount reading '
          'record(s) after catalogue replacement.',
        );
      }

      final result = ReadingProgressValidationResult(
        changed: true,
        retainedCount: next.length,
        removedCount: removedCount,
        removedMissingCount: removedMissingCount,
        removedFormatMismatchCount: removedFormatMismatchCount,
        metadataRefreshedCount: metadataRefreshedCount,
        persisted: true,
      );
      _lastValidationResult = result;
      return result;
    } catch (e, stackTrace) {
      debugPrint(
        '[ReadingProgressRepository] validateAgainstCatalog failed: $e\n'
        '$stackTrace',
      );
      final result = ReadingProgressValidationResult(
        changed: false,
        retainedCount: _records.length,
        removedCount: 0,
        persistenceFailed: true,
        warnings: const [
          'Catalogue reading-progress validation failed unexpectedly.',
        ],
      );
      _lastValidationResult = result;
      return result;
    }
  }

  List<ReadingProgressRecord> continueReading({int? limit}) {
    final eligible = _records
        .where(
          (record) =>
              !record.completed &&
              ReadingProgressRecord.hasMeaningfulProgress(record),
        )
        .toList(growable: false);
    final cap = limit ?? ReadingProgressPolicy.defaultContinueReadingQueryCap;
    if (cap >= 0 && eligible.length > cap) {
      return eligible.sublist(0, cap);
    }
    return eligible;
  }

  ReadingProgressLoadResult _completeLoad(ReadingProgressLoadResult result) {
    _isLoaded = true;
    _lastLoadSource = result.source;
    _lastRecoveryWarnings = result.recoveryWarnings;
    _lastLoadSkippedRecordCount = result.recoveryWarnings
        .where((warning) => warning.startsWith('Skipped '))
        .length;
    notifyListeners();
    return result;
  }

  Future<ReadingProgressSaveResult> _persist(
    List<ReadingProgressRecord> records,
  ) async {
    if (simulatePersistFailure) {
      _lastRepositoryError = 'Could not save reading progress.';
      return const ReadingProgressSaveResult(
        success: false,
        errorMessage: 'Could not save reading progress.',
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
        _lastRepositoryError = 'Could not save reading progress.';
        return const ReadingProgressSaveResult(
          success: false,
          errorMessage: 'Could not save reading progress.',
        );
      }

      _records = normalized;
      _isLoaded = true;
      _lastSuccessfulWriteAt = DateTime.now().toUtc();
      _lastRepositoryError = null;
      notifyListeners();
      return const ReadingProgressSaveResult(success: true);
    } catch (e, stackTrace) {
      debugPrint('[ReadingProgressRepository] persist failed: $e\n$stackTrace');
      _lastRepositoryError = 'Could not save reading progress.';
      return const ReadingProgressSaveResult(
        success: false,
        errorMessage: 'Could not save reading progress.',
      );
    }
  }

  Map<String, Object?> _envelopeToJson(List<ReadingProgressRecord> records) => {
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
        warnings.add('Stored reading progress could not be read.');
        return null;
      }

      final version = json['stateVersion'];
      if (version is! int || version != currentStateVersion) {
        if (version is! int) {
          warnings.add(
            'Missing stateVersion; stored reading progress was not loaded.',
          );
        } else {
          warnings.add(
            'Unsupported stateVersion $version; stored reading progress was not loaded.',
          );
        }
        return const _EnvelopeParseResult(records: [], validEnvelope: false);
      }

      return _EnvelopeParseResult(
        records: _parseRecordList(json['records'], warnings),
        validEnvelope: true,
      );
    } catch (e) {
      debugPrint('[ReadingProgressRepository] corrupt envelope JSON: $e');
      warnings.add('Stored reading progress could not be read.');
      return null;
    }
  }

  static List<ReadingProgressRecord> _parseRecordList(
    dynamic raw,
    List<String> warnings,
  ) {
    if (raw == null) return const [];
    if (raw is! List<dynamic>) {
      warnings.add('Reading record list was invalid.');
      return const [];
    }

    final parsed = <ReadingProgressRecord>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        warnings.add('Skipped malformed reading record.');
        continue;
      }
      final record = ReadingProgressRecord.fromJsonWithRecovery(
        entry,
        warnings: warnings,
      );
      if (record != null) {
        parsed.add(record);
      }
    }
    return _dedupeAndSort(parsed);
  }

  static List<ReadingProgressRecord> _dedupeAndSort(
    List<ReadingProgressRecord> records,
  ) {
    final byId = <String, ReadingProgressRecord>{};
    for (final record in records) {
      final existing = byId[record.mediaId];
      if (existing == null ||
          record.lastReadAt.isAfter(existing.lastReadAt)) {
        byId[record.mediaId] = record;
      }
    }
    return _sortRecords(byId.values.toList());
  }

  static List<ReadingProgressRecord> _applyRetention(
    List<ReadingProgressRecord> records,
  ) {
    final sorted = _sortRecords(records);
    if (sorted.length <= ReadingProgressPolicy.maxStoredRecords) {
      return sorted;
    }
    return sorted.sublist(0, ReadingProgressPolicy.maxStoredRecords);
  }

  static List<ReadingProgressRecord> _sortRecords(
    List<ReadingProgressRecord> records,
  ) {
    final sorted = List<ReadingProgressRecord>.from(records);
    sorted.sort((a, b) {
      final byTime = b.lastReadAt.compareTo(a.lastReadAt);
      if (byTime != 0) return byTime;
      return a.mediaId.compareTo(b.mediaId);
    });
    return sorted;
  }

  static Map<String, MediaItem> _readingItemsByMediaId(Catalog catalog) {
    return {
      for (final item in catalog.allItems)
        if (item.isBook || item.isComic) item.id: item,
    };
  }

  static bool _formatMatchesItem(ReadingProgressRecord record, MediaItem item) {
    if (item.isBook && record.mediaKind != MediaKind.book) return false;
    if (item.isComic && record.mediaKind != MediaKind.comic) return false;
    return _readerFormatForItem(item) == record.readerFormat;
  }

  static ReadingReaderFormat? _readerFormatForItem(MediaItem item) {
    final ext = _extensionFromPath(item.filePath);
    if (item.isBook) {
      return switch (ext) {
        'pdf' => ReadingReaderFormat.pdf,
        'epub' => ReadingReaderFormat.epub,
        _ => null,
      };
    }
    if (item.isComic) {
      return readerFormatForComicExtension(ext);
    }
    return null;
  }

  static ReadingProgressRecord _refreshSnapshot(
    ReadingProgressRecord record,
    MediaItem item,
  ) {
    final basename = _basenameFromPath(item.filePath);
    if (record.title == item.title && record.sourceBasename == basename) {
      return record;
    }
    return record.copyWith(
      title: item.title,
      sourceBasename: basename,
    );
  }

  static String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static String? _basenameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    return name.isEmpty ? null : name;
  }
}

class _EnvelopeParseResult {
  const _EnvelopeParseResult({
    required this.records,
    required this.validEnvelope,
  });

  final List<ReadingProgressRecord> records;
  final bool validEnvelope;
}
