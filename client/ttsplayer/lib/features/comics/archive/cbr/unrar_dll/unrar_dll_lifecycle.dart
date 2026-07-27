/// Deterministic native lifecycle counters for Gate 1 tests and redacted diagnostics.
///
/// Not user-visible; no paths or archive identifiers.
class UnrarDllLifecycle {
  UnrarDllLifecycle._();

  static final UnrarDllLifecycle instance = UnrarDllLifecycle._();

  int _activeArchiveHandles = 0;
  int _peakArchiveHandles = 0;
  int _totalOpens = 0;
  int _totalCloses = 0;
  int _loadAttempts = 0;
  int _loadSuccesses = 0;
  int _loadFailures = 0;
  int _extractionTempDirsCreated = 0;
  int _extractionTempDirsRemoved = 0;

  int get activeArchiveHandles => _activeArchiveHandles;
  int get peakArchiveHandles => _peakArchiveHandles;
  int get totalOpens => _totalOpens;
  int get totalCloses => _totalCloses;
  int get loadAttempts => _loadAttempts;
  int get loadSuccesses => _loadSuccesses;
  int get loadFailures => _loadFailures;
  int get extractionTempResidue =>
      _extractionTempDirsCreated - _extractionTempDirsRemoved;

  void recordLoadAttempt({required bool success}) {
    _loadAttempts++;
    if (success) {
      _loadSuccesses++;
    } else {
      _loadFailures++;
    }
  }

  void recordArchiveOpened() {
    _totalOpens++;
    _activeArchiveHandles++;
    if (_activeArchiveHandles > _peakArchiveHandles) {
      _peakArchiveHandles = _activeArchiveHandles;
    }
  }

  void recordArchiveClosed() {
    _totalCloses++;
    if (_activeArchiveHandles > 0) _activeArchiveHandles--;
  }

  void recordTempDirCreated() => _extractionTempDirsCreated++;

  void recordTempDirRemoved() => _extractionTempDirsRemoved++;

  void resetForTest() {
    _activeArchiveHandles = 0;
    _peakArchiveHandles = 0;
    _totalOpens = 0;
    _totalCloses = 0;
    _loadAttempts = 0;
    _loadSuccesses = 0;
    _loadFailures = 0;
    _extractionTempDirsCreated = 0;
    _extractionTempDirsRemoved = 0;
  }
}
