import '../services/media_access/media_access_config.dart';
import '../services/media_access/media_catalogue_provider.dart';
import '../services/media_access/media_provider_config.dart';

/// Per-provider attempt lifecycle and final outcome for the most recent load
/// cycle. See ADR-001.
enum CatalogueProviderHealth {
  idle,
  loading,
  success,
  degraded,
  failed,
  skipped,
}

/// One configured catalogue provider's attempt state within a session.
class CatalogueProviderAttemptRecord {
  final MediaCatalogueProviderDefinition definition;
  final CatalogueProviderHealth health;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;

  const CatalogueProviderAttemptRecord({
    required this.definition,
    required this.health,
    this.lastError,
    this.lastAttemptAt,
    this.lastSuccessAt,
  });

  bool get isActive =>
      health == CatalogueProviderHealth.success ||
      health == CatalogueProviderHealth.degraded;

  CatalogueProviderAttemptRecord copyWith({
    MediaCatalogueProviderDefinition? definition,
    CatalogueProviderHealth? health,
    String? lastError,
    bool clearError = false,
    DateTime? lastAttemptAt,
    DateTime? lastSuccessAt,
  }) {
    return CatalogueProviderAttemptRecord(
      definition: definition ?? this.definition,
      health: health ?? this.health,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    );
  }
}

/// Session-scoped read-only view of catalogue provider load state (ADR-001).
class CatalogueProviderSnapshot {
  final List<CatalogueProviderAttemptRecord> providers;
  final MediaCatalogueProviderDefinition? activeProvider;
  final String? loadedCatalogueIdentity;
  final String? catalogPath;
  final MediaAccessMode accessMode;
  final DateTime? lastLoadStartedAt;
  final DateTime? lastCatalogueLoadAt;
  final DateTime? sessionStartedAt;
  final String? lastCycleError;
  final bool isDemoFallback;
  final bool isDegradedLoad;
  final bool demoActiveWithoutProvider;

  const CatalogueProviderSnapshot({
    required this.providers,
    this.activeProvider,
    this.loadedCatalogueIdentity,
    this.catalogPath,
    required this.accessMode,
    this.lastLoadStartedAt,
    this.lastCatalogueLoadAt,
    this.sessionStartedAt,
    this.lastCycleError,
    this.isDemoFallback = false,
    this.isDegradedLoad = false,
    this.demoActiveWithoutProvider = false,
  });

  factory CatalogueProviderSnapshot.initial({
    required MediaProviderConfig config,
    List<CatalogueProviderAttemptRecord> providers = const [],
  }) {
    return CatalogueProviderSnapshot(
      providers: providers,
      accessMode: config.mediaAccess.mode,
    );
  }

  CatalogueProviderAttemptRecord? get activeRecord {
    for (final record in providers) {
      if (record.isActive) return record;
    }
    return null;
  }
}

/// Builds [CatalogueProviderSnapshot] during provider-chain load attempts.
class CatalogueProviderLoadTracker {
  CatalogueProviderLoadTracker({
    required MediaProviderConfig config,
    required List<MediaCatalogueProviderDefinition> attemptChain,
    required List<MediaCatalogueProviderDefinition> skippedProviders,
  })  : _config = config,
        _attemptChainLength = attemptChain.length,
        _records = [
          for (final definition in attemptChain)
            CatalogueProviderAttemptRecord(
              definition: definition,
              health: CatalogueProviderHealth.idle,
            ),
          for (final definition in skippedProviders)
            CatalogueProviderAttemptRecord(
              definition: definition,
              health: CatalogueProviderHealth.skipped,
            ),
        ];

  final MediaProviderConfig _config;
  final int _attemptChainLength;
  final List<CatalogueProviderAttemptRecord> _records;

  DateTime? _lastLoadStartedAt;
  MediaCatalogueProviderDefinition? _activeProvider;
  String? _lastCycleError;

  List<CatalogueProviderAttemptRecord> get records =>
      List.unmodifiable(_records);

  void beginCycle(DateTime startedAt) {
    _lastLoadStartedAt = startedAt;
    _lastCycleError = null;
    _activeProvider = null;
    for (var i = 0; i < _attemptChainLength; i++) {
      _records[i] = _records[i].copyWith(
        health: CatalogueProviderHealth.idle,
        clearError: true,
      );
    }
  }

  void markLoading(int attemptIndex, DateTime at) {
    _ensureAttemptIndex(attemptIndex);
    _records[attemptIndex] = _records[attemptIndex].copyWith(
      health: CatalogueProviderHealth.loading,
      lastAttemptAt: at,
      clearError: true,
    );
  }

  void markFailed(int attemptIndex, String? error, DateTime at) {
    _ensureAttemptIndex(attemptIndex);
    _records[attemptIndex] = _records[attemptIndex].copyWith(
      health: CatalogueProviderHealth.failed,
      lastError: error,
      lastAttemptAt: at,
    );
    _lastCycleError = error;
  }

  void markSuccess(
    int attemptIndex,
    DateTime at, {
    required bool hadEarlierFailure,
  }) {
    _ensureAttemptIndex(attemptIndex);
    final degraded = _config.mediaAccess.mode == MediaAccessMode.localPreferred &&
        hadEarlierFailure;
    final health = degraded
        ? CatalogueProviderHealth.degraded
        : CatalogueProviderHealth.success;

    _records[attemptIndex] = _records[attemptIndex].copyWith(
      health: health,
      lastAttemptAt: at,
      lastSuccessAt: at,
      clearError: true,
    );
    _activeProvider = _records[attemptIndex].definition;
    _lastCycleError = null;

    for (var i = attemptIndex + 1; i < _attemptChainLength; i++) {
      if (_records[i].health == CatalogueProviderHealth.loading) {
        _records[i] = _records[i].copyWith(
          health: CatalogueProviderHealth.idle,
          clearError: true,
        );
      }
    }
  }

  void markAllAttemptedFailed(String? error) {
    _lastCycleError = error;
    for (var i = 0; i < _attemptChainLength; i++) {
      final record = _records[i];
      if (record.health == CatalogueProviderHealth.loading ||
          record.health == CatalogueProviderHealth.failed) {
        _records[i] = record.copyWith(
          health: CatalogueProviderHealth.failed,
          lastError: record.lastError ?? error,
        );
      }
    }
  }

  CatalogueProviderSnapshot build({
    required String? loadedCatalogueIdentity,
    required String? catalogPath,
    required DateTime? lastCatalogueLoadAt,
    required DateTime? sessionStartedAt,
    required bool isDemoFallback,
    required bool demoActiveWithoutProvider,
  }) {
    final activeRecord = _records.where((r) => r.isActive).firstOrNull;
    return CatalogueProviderSnapshot(
      providers: List.unmodifiable(_records),
      activeProvider: _activeProvider,
      loadedCatalogueIdentity: loadedCatalogueIdentity,
      catalogPath: catalogPath,
      accessMode: _config.mediaAccess.mode,
      lastLoadStartedAt: _lastLoadStartedAt,
      lastCatalogueLoadAt: lastCatalogueLoadAt,
      sessionStartedAt: sessionStartedAt,
      lastCycleError: _lastCycleError,
      isDemoFallback: isDemoFallback,
      isDegradedLoad: activeRecord?.health == CatalogueProviderHealth.degraded,
      demoActiveWithoutProvider: demoActiveWithoutProvider,
    );
  }

  void _ensureAttemptIndex(int attemptIndex) {
    if (attemptIndex < 0 || attemptIndex >= _attemptChainLength) {
      throw RangeError.index(
        attemptIndex,
        _records,
        'attemptIndex',
        null,
        _attemptChainLength,
      );
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
