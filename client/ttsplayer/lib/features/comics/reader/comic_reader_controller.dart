import 'package:flutter/foundation.dart';

import '../../reading/models/reading_location_payload.dart';
import '../../reading/services/reader_session_telemetry.dart';
import '../archive/comic_archive_errors.dart';
import '../archive/comic_archive_source.dart';
import '../archive/comic_page_ref.dart';
import 'comic_page_cache.dart';
import 'comic_page_failure.dart';

enum ComicReaderLoadState {
  loadingPages,
  ready,
  loadingPage,
  error,
}

/// Session state for a single open comic (page navigation and cache).
class ComicReaderController extends ChangeNotifier {
  ComicReaderController({
    required ComicArchiveSource source,
    ComicPageCache? cache,
    this.prefetchAdjacent = true,
  })  : _source = source,
        _cache = cache ?? ComicPageCache();

  final ComicArchiveSource _source;
  final ComicPageCache _cache;
  final bool prefetchAdjacent;

  ComicPageCache get pageCache => _cache;

  List<ComicPageRef> _pages = const [];
  int _index = 0;
  ComicReaderLoadState _state = ComicReaderLoadState.loadingPages;
  ComicArchiveException? _error;
  List<int>? _currentBytes;
  final Map<String, ComicPageFailure> _pageFailures = {};
  String? _loadingEntry;
  bool _disposed = false;

  List<ComicPageRef> get pages => _pages;
  int get pageIndex => _index;
  int get pageCount => _pages.length;
  ComicReaderLoadState get state => _state;
  ComicArchiveException? get error => _error;
  List<int>? get currentPageBytes => _currentBytes;
  ComicPageRef? get currentPage =>
      _pages.isEmpty ? null : _pages[_index.clamp(0, _pages.length - 1)];

  ComicPageFailure? get currentPageFailure {
    final page = currentPage;
    if (page == null) return null;
    return _pageFailures[page.entryName];
  }

  ComicPageLoadStatus get currentPageLoadStatus {
    final page = currentPage;
    if (page == null) return ComicPageLoadStatus.notRequested;
    if (_loadingEntry == page.entryName) return ComicPageLoadStatus.loading;
    if (_currentBytes != null) return ComicPageLoadStatus.loaded;
    if (_pageFailures.containsKey(page.entryName)) {
      return ComicPageLoadStatus.failed;
    }
    if (_state == ComicReaderLoadState.loadingPage) {
      return ComicPageLoadStatus.loading;
    }
    return ComicPageLoadStatus.notRequested;
  }

  @visibleForTesting
  Map<String, ComicPageFailure> get pageFailures =>
      Map.unmodifiable(_pageFailures);

  @visibleForTesting
  ComicPageFailure? failureForEntry(String entryName) =>
      _pageFailures[entryName];

  bool get canGoPrevious => _index > 0;
  bool get canGoNext => _index < _pages.length - 1;
  String get pageIndicatorLabel {
    if (_pages.isEmpty) return 'No pages';
    return 'Page ${_index + 1} of ${_pages.length}';
  }

  void _publishCacheTelemetry() {
    ReaderSessionTelemetry.instance.updateComicPageCache(
      maxEntries: _cache.maxEntries,
      maxBytes: _cache.maxBytes,
      entryCount: _cache.length,
      estimatedBytes: _cache.estimatedBytes,
    );
  }

  Future<void> open({int initialPageIndex = 0}) async {
    final openStarted = DateTime.now();
    _state = ComicReaderLoadState.loadingPages;
    _error = null;
    _pageFailures.clear();
    _currentBytes = null;
    _loadingEntry = null;
    _notify();
    try {
      _pages = await _source.listPages();
      _index = initialPageIndex.clamp(0, _pages.length - 1);
      await _loadCurrent(prefetch: true);
      _publishCacheTelemetry();
      ReaderSessionTelemetry.instance.recordReaderOpen(
        format: ReadingReaderFormat.cbz,
        openDuration: DateTime.now().difference(openStarted),
      );
    } on ComicArchiveException catch (e) {
      _error = e;
      _state = ComicReaderLoadState.error;
      _notify();
    } catch (_) {
      _error = ComicArchiveException(
        kind: ComicArchiveErrorKind.unknown,
        userMessage: 'This comic archive could not be opened.',
      );
      _state = ComicReaderLoadState.error;
      _notify();
    }
  }

  Future<void> goToIndex(int index) async {
    if (_pages.isEmpty) return;
    final next = index.clamp(0, _pages.length - 1);
    final entryName = _pages[next].entryName;
    if (next == _index &&
        _currentBytes != null &&
        _loadingEntry != entryName) {
      return;
    }
    if (next == _index &&
        _pageFailures.containsKey(entryName) &&
        _loadingEntry == null) {
      return;
    }
    _index = next;
    await _loadCurrent(prefetch: true);
  }

  Future<void> nextPage() => goToIndex(_index + 1);
  Future<void> previousPage() => goToIndex(_index - 1);
  Future<void> firstPage() => goToIndex(0);
  Future<void> lastPage() => goToIndex(_pages.length - 1);

  Future<void> retryCurrentPage() async {
    final page = currentPage;
    if (page == null || _disposed) return;
    if (_loadingEntry == page.entryName) return;
    _pageFailures.remove(page.entryName);
    _cache.remove(page.entryName);
    _currentBytes = null;
    _error = null;
    await _loadCurrent(prefetch: false, forceRetry: true);
  }

  /// Called when [Image.memory] fails to decode loaded bytes.
  void reportCurrentPageDecodeFailed() {
    final page = currentPage;
    if (page == null || _disposed) return;
    _cache.remove(page.entryName);
    _currentBytes = null;
    _error = null;
    _pageFailures[page.entryName] =
        ComicPageFailure.decodeFailure(page.entryName);
    ReaderSessionTelemetry.instance.recordComicReaderSafeError(
      ComicPageFailureCategory.decodeFailure.diagnosticLabel,
    );
    _state = ComicReaderLoadState.ready;
    _loadingEntry = null;
    _notify();
    if (prefetchAdjacent) {
      // ignore: unawaited_futures
      _prefetchNeighbors();
    }
  }

  Future<void> _loadCurrent({
    required bool prefetch,
    bool forceRetry = false,
  }) async {
    if (_pages.isEmpty) return;
    final ref = _pages[_index];
    final entryName = ref.entryName;

    if (!forceRetry && _pageFailures.containsKey(entryName)) {
      _currentBytes = null;
      _error = null;
      _state = ComicReaderLoadState.ready;
      _notify();
      if (prefetch) {
        // ignore: unawaited_futures
        _prefetchNeighbors();
      }
      return;
    }

    final cached = _cache.get(entryName);
    if (cached != null) {
      _pageFailures.remove(entryName);
      _currentBytes = cached;
      _error = null;
      _state = ComicReaderLoadState.ready;
      _loadingEntry = null;
      _notify();
      if (prefetch) {
        // ignore: unawaited_futures
        _prefetchNeighbors();
      }
      _publishCacheTelemetry();
      return;
    }

    if (_loadingEntry == entryName) return;

    _loadingEntry = entryName;
    _state = ComicReaderLoadState.loadingPage;
    _error = null;
    _currentBytes = null;
    _notify();

    try {
      final bytes = await _source.loadPageBytes(entryName);
      if (_disposed || _pages[_index].entryName != entryName) return;
      _cache.put(entryName, bytes);
      _pageFailures.remove(entryName);
      _currentBytes = bytes;
      _state = ComicReaderLoadState.ready;
      _loadingEntry = null;
      _notify();
      if (prefetch) {
        // ignore: unawaited_futures
        _prefetchNeighbors();
      }
      _publishCacheTelemetry();
    } on ComicArchiveException catch (e) {
      if (_disposed || _pages[_index].entryName != entryName) return;
      _applyPageFailure(entryName, e);
    } catch (_) {
      if (_disposed || _pages[_index].entryName != entryName) return;
      _applyPageFailure(
        entryName,
        ComicArchiveException(
          kind: ComicArchiveErrorKind.pageExtractFailed,
          userMessage: 'This page could not be displayed.',
        ),
      );
    } finally {
      if (_loadingEntry == entryName) {
        _loadingEntry = null;
      }
    }
  }

  void _applyPageFailure(String entryName, ComicArchiveException exception) {
    _cache.remove(entryName);
    _currentBytes = null;
    _error = null;
    final failure =
        ComicPageFailure.fromArchiveException(entryName, exception);
    _pageFailures[entryName] = failure;
    ReaderSessionTelemetry.instance.recordComicReaderSafeError(
      failure.category.diagnosticLabel,
    );
    _state = ComicReaderLoadState.ready;
    _notify();
    if (prefetchAdjacent &&
        _pages.isNotEmpty &&
        _pages[_index].entryName == entryName) {
      // ignore: unawaited_futures
      _prefetchNeighbors();
    }
  }

  Future<void> _prefetchNeighbors() async {
    if (!prefetchAdjacent || _pages.isEmpty) return;
    for (final i in [_index - 1, _index + 1]) {
      if (i < 0 || i >= _pages.length) continue;
      final name = _pages[i].entryName;
      if (_cache.get(name) != null || _pageFailures.containsKey(name)) {
        continue;
      }
      if (_loadingEntry == name) continue;
      try {
        final bytes = await _source.loadPageBytes(name);
        if (_disposed) return;
        _cache.put(name, bytes);
        _pageFailures.remove(name);
      } on ComicArchiveException catch (e) {
        if (_disposed) return;
        _pageFailures[name] =
            ComicPageFailure.fromArchiveException(name, e);
        ReaderSessionTelemetry.instance.recordComicReaderSafeError(
          _pageFailures[name]!.category.diagnosticLabel,
        );
      } catch (_) {
        if (_disposed) return;
        _pageFailures[name] = ComicPageFailure.unknown(name);
        ReaderSessionTelemetry.instance.recordComicReaderSafeError(
          ComicPageFailureCategory.unknownPageError.diagnosticLabel,
        );
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _publishCacheTelemetry();
    _cache.clear();
    _pageFailures.clear();
    ReaderSessionTelemetry.instance.recordCleanupResult('comic_reader_disposed');
    // ignore: discarded_futures
    _source.dispose();
    super.dispose();
  }
}
