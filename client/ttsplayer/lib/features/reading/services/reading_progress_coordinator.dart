import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../models/reading_location_payload.dart';
import '../models/reading_progress_policy.dart';
import '../models/reading_progress_record.dart';
import 'reading_location_reconciliation.dart';
import 'reading_progress_repository.dart';

enum ReadingProgressFlushReason {
  locationChange,
  readerClose,
  lifecycle,
  completion,
  restart,
  forced,
}

/// Observes reader sessions and persists reading progress (M6.5).
class ReadingProgressCoordinator extends ChangeNotifier {
  ReadingProgressCoordinator({
    required ReadingProgressRepository repository,
    DateTime Function()? now,
  })  : _repository = repository,
        _now = now ?? DateTime.now;

  final ReadingProgressRepository _repository;
  final DateTime Function() _now;

  _ActiveReadingSession? _session;
  Timer? _debounceTimer;
  bool _disposed = false;
  String? _lastPersistenceWarning;
  Future<void>? _inFlightWrite;
  DateTime? _lastPersistAt;
  ReadingProgressRecord? _pendingRecord;

  String? get lastPersistenceWarning => _lastPersistenceWarning;
  bool get sessionActive => _session != null;
  bool get pendingWrite => pendingDebounceWrite || writeInFlight;
  bool get pendingDebounceWrite => _debounceTimer?.isActive == true;
  bool get writeInFlight => _inFlightWrite != null;
  DateTime? get lastSuccessfulFlushAt => _lastPersistAt;
  ReadingProgressRecord? get pendingRecord => _pendingRecord;

  Future<void> drainPendingWrites() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pendingRecord != null) {
      await _flushPending(force: true, reason: ReadingProgressFlushReason.forced);
    }
    final pending = _inFlightWrite;
    if (pending != null) await pending;
  }

  @visibleForTesting
  Future<void> waitForIdleForTest() => drainPendingWrites();

  Future<void> onAppLifecyclePaused() async {
    if (_disposed) return;
    await drainPendingWrites();
  }

  void beginSession({
    required MediaItem item,
    required ReadingReaderFormat readerFormat,
    required ReadingLocationPayload initialLocation,
    required double progressFraction,
    bool completed = false,
  }) {
    if (_disposed) return;
    _session = _ActiveReadingSession(
      mediaId: item.id,
      mediaKind: item.mediaKind,
      readerFormat: readerFormat,
      title: item.title,
      sourceBasename: _basenameFromPath(item.filePath),
      location: initialLocation,
      progressFraction: progressFraction,
      completed: completed,
      layoutReady: false,
    );
  }

  void markLayoutReady() {
    _session?.layoutReady = true;
  }

  void onLocationChanged({
    required ReadingLocationPayload location,
    required double progressFraction,
    bool force = false,
  }) {
    if (_disposed || _session == null) return;
    final session = _session!;
    if (!session.layoutReady && !force) return;

    final normalizedFraction = progressFraction.clamp(0.0, 1.0);
    final completed =
        ReadingLocationReconciliation.isCompletedFraction(normalizedFraction);

    if (_locationsEquivalent(session.location, location) &&
        (session.progressFraction - normalizedFraction).abs() < 0.001 &&
        session.completed == completed &&
        !force) {
      return;
    }

    session.location = location;
    session.progressFraction = normalizedFraction;
    session.completed = completed;

    if (completed) {
      unawaited(_scheduleWrite(_flushNow(reason: ReadingProgressFlushReason.completion)));
      return;
    }

    if (force) {
      unawaited(
        _scheduleWrite(_flushNow(reason: ReadingProgressFlushReason.forced)),
      );
      return;
    }

    _queueDebouncedWrite();
  }

  Future<void> onReaderClosed() async {
    if (_disposed) return;
    await drainPendingWrites();
    if (_session != null && !_session!.completed) {
      await _flushNow(reason: ReadingProgressFlushReason.readerClose);
    }
    _session = null;
  }

  Future<void> onReaderRestarted() async {
    if (_disposed || _session == null) return;
    final session = _session!;
    session.completed = false;
    session.progressFraction = 0;
    session.location = _startLocation(session.readerFormat, session.location);
    await _flushNow(reason: ReadingProgressFlushReason.restart);
  }

  Future<void> onReaderCompleted() async {
    if (_disposed || _session == null) return;
    _session!.completed = true;
    _session!.progressFraction = 1.0;
    await _flushNow(reason: ReadingProgressFlushReason.completion);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _queueDebouncedWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(ReadingProgressPolicy.persistDebounce, () {
      unawaited(_scheduleWrite(_flushNow(reason: ReadingProgressFlushReason.locationChange)));
    });
  }

  Future<void> _flushNow({required ReadingProgressFlushReason reason}) async {
    if (_disposed || _session == null) return;
    final session = _session!;

    if (!session.completed &&
        !ReadingProgressRecord.hasMeaningfulProgress(
          ReadingProgressRecord(
            mediaId: session.mediaId,
            mediaKind: session.mediaKind,
            readerFormat: session.readerFormat,
            title: session.title,
            location: session.location,
            progressFraction: session.progressFraction,
            completed: false,
            lastReadAt: _now(),
            sourceBasename: session.sourceBasename,
          ),
        ) &&
        reason != ReadingProgressFlushReason.restart) {
      return;
    }

    final existing = _repository.getByMediaId(session.mediaId);
    final record = ReadingProgressRecord(
      mediaId: session.mediaId,
      mediaKind: session.mediaKind,
      readerFormat: session.readerFormat,
      title: session.title,
      location: session.location,
      progressFraction: session.completed ? 1.0 : session.progressFraction,
      completed: session.completed,
      lastReadAt: _now(),
      firstReadAt: existing?.firstReadAt,
      completedAt: session.completed ? _now() : null,
      sourceBasename: session.sourceBasename,
    ).normalized();

    _pendingRecord = record;
    final result = await _repository.upsert(record);
    if (!result.success) {
      _lastPersistenceWarning =
          result.errorMessage ?? 'Could not save reading progress.';
    } else {
      _lastPersistenceWarning = null;
      _lastPersistAt = _now();
      if (reason == ReadingProgressFlushReason.restart && record.completed) {
        // restart clears completion via normalized incomplete record above
      }
    }
    _pendingRecord = null;
  }

  Future<void> _flushPending({
    required bool force,
    required ReadingProgressFlushReason reason,
  }) async {
    await _flushNow(reason: reason);
  }

  Future<void> _scheduleWrite(Future<void> write) {
    _inFlightWrite = write;
    return write.whenComplete(() {
      if (identical(_inFlightWrite, write)) {
        _inFlightWrite = null;
      }
    });
  }

  static bool _locationsEquivalent(
    ReadingLocationPayload a,
    ReadingLocationPayload b,
  ) {
    if (a.format != b.format) return false;
    return switch (a) {
      PdfReadingLocationPayload(:final pageIndex) when b is PdfReadingLocationPayload =>
        pageIndex == b.pageIndex,
      EpubReadingLocationPayload(
        :final spineIndex,
        :final sectionRelativeOffset,
      )
          when b is EpubReadingLocationPayload =>
        spineIndex == b.spineIndex &&
            (sectionRelativeOffset - b.sectionRelativeOffset).abs() < 8,
      ComicReadingLocationPayload(:final pageIndex)
          when b is ComicReadingLocationPayload =>
        pageIndex == b.pageIndex,
      _ => false,
    };
  }

  static ReadingLocationPayload _startLocation(
    ReadingReaderFormat format,
    ReadingLocationPayload current,
  ) {
    return switch (format) {
      ReadingReaderFormat.pdf => PdfReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave: (current as PdfReadingLocationPayload).pageCountAtSave,
        ),
      ReadingReaderFormat.epub => EpubReadingLocationPayload(
          spineIndex: 0,
          spineHref: (current as EpubReadingLocationPayload).spineHref,
          spineCountAtSave: current.spineCountAtSave,
        ),
      ReadingReaderFormat.cbz ||
      ReadingReaderFormat.cbr =>
        ComicReadingLocationPayload(
          pageIndex: 0,
          pageCountAtSave:
              (current as ComicReadingLocationPayload).pageCountAtSave,
          archiveFormat: current.archiveFormat,
        ),
    };
  }

  static String? _basenameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    return name.isEmpty ? null : name;
  }
}

class _ActiveReadingSession {
  _ActiveReadingSession({
    required this.mediaId,
    required this.mediaKind,
    required this.readerFormat,
    required this.title,
    required this.sourceBasename,
    required this.location,
    required this.progressFraction,
    required this.completed,
    required this.layoutReady,
  });

  final String mediaId;
  final MediaKind mediaKind;
  final ReadingReaderFormat readerFormat;
  final String title;
  final String? sourceBasename;
  ReadingLocationPayload location;
  double progressFraction;
  bool completed;
  bool layoutReady;
}
