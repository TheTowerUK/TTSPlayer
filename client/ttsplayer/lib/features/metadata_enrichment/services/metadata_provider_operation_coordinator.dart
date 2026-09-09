import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../providers/book_metadata_provider_failure.dart';
import 'metadata_provider_lifecycle.dart';

typedef MetadataOperationDelay = Future<void> Function(Duration duration);
typedef MetadataOperationClock = DateTime Function();

class MetadataProviderOperationRejected implements Exception {
  const MetadataProviderOperationRejected(this.category);
  final BookMetadataProviderFailureCategory category;
}

/// Bounded, in-memory execution policy for explicit provider operations.
class MetadataProviderOperationCoordinator extends ChangeNotifier {
  MetadataProviderOperationCoordinator({
    required MetadataProviderLifecycle lifecycle,
    MetadataOperationDelay delay = _defaultDelay,
    MetadataOperationClock clock = _defaultClock,
    this.maxPendingOperations = 32,
    this.maxGlobalConcurrency = 2,
    this.minimumProviderSpacing = const Duration(seconds: 1),
  })  : _lifecycle = lifecycle,
        _delay = delay,
        _clock = clock {
    _lifecycle.addListener(_onLifecycleChanged);
  }

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);
  static DateTime _defaultClock() => DateTime.now().toUtc();

  final MetadataProviderLifecycle _lifecycle;
  final MetadataOperationDelay _delay;
  final MetadataOperationClock _clock;
  final int maxPendingOperations;
  final int maxGlobalConcurrency;
  final Duration minimumProviderSpacing;
  final Queue<dynamic> _pending = Queue<dynamic>();
  final Set<String> _activeProviders = {};
  final Map<String, DateTime> _lastRequestStartedAt = {};
  Completer<void> _stateChanged = Completer<void>();
  int _inFlight = 0;
  DateTime? _lastSuccessfulRefreshAt;
  BookMetadataProviderFailureCategory? _lastSafeErrorCategory;

  int get pendingOperationCount => _pending.length;
  int get inFlightOperationCount => _inFlight;
  DateTime? get lastSuccessfulRefreshAt => _lastSuccessfulRefreshAt;
  BookMetadataProviderFailureCategory? get lastSafeErrorCategory =>
      _lastSafeErrorCategory;

  Future<T> execute<T>({
    required String providerId,
    required Future<T> Function() operation,
    required BookMetadataProviderFailure? Function(T result) failureOf,
    bool Function()? isCancelled,
    Future<void>? cancellationSignal,
  }) {
    final token = _lifecycle.beginOperation(providerId);
    if (token == null) {
      return Future.error(const MetadataProviderOperationRejected(
        BookMetadataProviderFailureCategory.cancelled,
      ));
    }
    if (_pending.length >= maxPendingOperations) {
      return Future.error(const MetadataProviderOperationRejected(
        BookMetadataProviderFailureCategory.providerUnavailable,
      ));
    }
    final queued = _QueuedOperation<T>(
      providerId: providerId,
      token: token,
      operation: operation,
      failureOf: failureOf,
      isCancelled: isCancelled ?? () => false,
    );
    _pending.add(queued);
    cancellationSignal?.then((_) => _onOperationCancelled(queued));
    notifyListeners();
    _drain();
    return queued.completer.future;
  }

  void recordSuccessfulRefresh() {
    _lastSuccessfulRefreshAt = _clock();
    notifyListeners();
  }

  void _drain() {
    while (_inFlight < maxGlobalConcurrency) {
      dynamic next;
      for (final candidate in _pending) {
        if (!_activeProviders.contains(candidate.providerId)) {
          next = candidate;
          break;
        }
      }
      if (next == null) return;
      _pending.remove(next);
      if (!_isCurrent(next)) {
        next.reject(BookMetadataProviderFailureCategory.cancelled);
        notifyListeners();
        continue;
      }
      _inFlight++;
      _activeProviders.add(next.providerId);
      notifyListeners();
      _run(next);
    }
  }

  Future<void> _run(dynamic queued) async {
    try {
      dynamic result;
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!_isCurrent(queued)) {
          queued.reject(BookMetadataProviderFailureCategory.cancelled);
          return;
        }
        await _waitForSpacing(queued.providerId);
        if (!_isCurrent(queued)) {
          queued.reject(BookMetadataProviderFailureCategory.cancelled);
          return;
        }
        _lastRequestStartedAt[queued.providerId] = _clock();
        result = await queued.operation();
        if (!_isCurrent(queued)) {
          queued.reject(BookMetadataProviderFailureCategory.cancelled);
          return;
        }
        final failure = queued.failureOf(result);
        if (failure == null) {
          queued.complete(result);
          return;
        }
        _lastSafeErrorCategory = failure.category;
        notifyListeners();
        final wait = _retryDelay(failure, attempt);
        if (wait == null || !_isCurrent(queued)) {
          queued.complete(result);
          return;
        }
        await _cancellableDelay(wait);
      }
      queued.complete(result);
    } catch (_) {
      _lastSafeErrorCategory = BookMetadataProviderFailureCategory.unknown;
      queued.reject(BookMetadataProviderFailureCategory.unknown);
    } finally {
      _inFlight--;
      _activeProviders.remove(queued.providerId);
      notifyListeners();
      _drain();
    }
  }

  Duration? _retryDelay(BookMetadataProviderFailure failure, int attempt) {
    if (attempt >= 2) return null;
    switch (failure.category) {
      case BookMetadataProviderFailureCategory.timeout:
      case BookMetadataProviderFailureCategory.networkUnavailable:
      case BookMetadataProviderFailureCategory.providerUnavailable:
        return Duration(seconds: attempt == 0 ? 2 : 4);
      case BookMetadataProviderFailureCategory.rateLimited:
        final retryAfter = failure.retryAfter;
        if (retryAfter != null) {
          if (retryAfter <= Duration.zero ||
              retryAfter > const Duration(minutes: 5)) {
            return null;
          }
          return retryAfter;
        }
        return Duration(seconds: attempt == 0 ? 2 : 4);
      default:
        return null;
    }
  }

  Future<void> _waitForSpacing(String providerId) async {
    final last = _lastRequestStartedAt[providerId];
    if (last == null) return;
    final remaining = minimumProviderSpacing - _clock().difference(last);
    if (remaining > Duration.zero) await _cancellableDelay(remaining);
  }

  Future<void> _cancellableDelay(Duration duration) async {
    final signal = _stateChanged.future;
    await Future.any<void>([_delay(duration), signal]);
  }

  bool _isCurrent(dynamic operation) =>
      !operation.isCancelled() && _lifecycle.isCurrent(operation.token);

  void _onLifecycleChanged() {
    if (!_stateChanged.isCompleted) _stateChanged.complete();
    _stateChanged = Completer<void>();
    final cancelled = _pending.where((item) => !_isCurrent(item)).toList();
    for (final item in cancelled) {
      _pending.remove(item);
      item.reject(BookMetadataProviderFailureCategory.cancelled);
    }
    notifyListeners();
    _drain();
  }

  void _onOperationCancelled(dynamic operation) {
    if (_disposed) return;
    if (_pending.remove(operation)) {
      operation.reject(BookMetadataProviderFailureCategory.cancelled);
    }
    if (!_stateChanged.isCompleted) _stateChanged.complete();
    _stateChanged = Completer<void>();
    notifyListeners();
    _drain();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _lifecycle.removeListener(_onLifecycleChanged);
    for (final operation in _pending) {
      operation.reject(BookMetadataProviderFailureCategory.cancelled);
    }
    _pending.clear();
    if (!_stateChanged.isCompleted) _stateChanged.complete();
    super.dispose();
  }
}

class _QueuedOperation<T> {
  _QueuedOperation({
    required this.providerId,
    required this.token,
    required this.operation,
    required this.failureOf,
    required this.isCancelled,
  });
  final String providerId;
  final MetadataProviderOperationToken token;
  final Future<T> Function() operation;
  final BookMetadataProviderFailure? Function(T result) failureOf;
  final bool Function() isCancelled;
  final Completer<T> completer = Completer<T>();

  void complete(T value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  void reject(BookMetadataProviderFailureCategory category) {
    if (!completer.isCompleted) {
      completer.completeError(MetadataProviderOperationRejected(category));
    }
  }
}
