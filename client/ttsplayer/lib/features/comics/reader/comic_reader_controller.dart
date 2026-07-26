import 'package:flutter/foundation.dart';

import '../archive/comic_archive_errors.dart';
import '../archive/comic_archive_source.dart';
import '../archive/comic_page_ref.dart';
import 'comic_page_cache.dart';

enum ComicReaderLoadState {
  loadingPages,
  ready,
  loadingPage,
  error,
}

/// Session state for a single open comic (no Phase 6.5 progress persistence).
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

  List<ComicPageRef> _pages = const [];
  int _index = 0;
  ComicReaderLoadState _state = ComicReaderLoadState.loadingPages;
  ComicArchiveException? _error;
  List<int>? _currentBytes;
  bool _disposed = false;

  List<ComicPageRef> get pages => _pages;
  int get pageIndex => _index;
  int get pageCount => _pages.length;
  ComicReaderLoadState get state => _state;
  ComicArchiveException? get error => _error;
  List<int>? get currentPageBytes => _currentBytes;
  ComicPageRef? get currentPage =>
      _pages.isEmpty ? null : _pages[_index.clamp(0, _pages.length - 1)];
  bool get canGoPrevious => _index > 0;
  bool get canGoNext => _index < _pages.length - 1;
  String get pageIndicatorLabel {
    if (_pages.isEmpty) return 'No pages';
    return 'Page ${_index + 1} of ${_pages.length}';
  }

  Future<void> open() async {
    _state = ComicReaderLoadState.loadingPages;
    _error = null;
    _notify();
    try {
      _pages = await _source.listPages();
      _index = 0;
      await _loadCurrent(prefetch: true);
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
    if (next == _index && _currentBytes != null) return;
    _index = next;
    await _loadCurrent(prefetch: true);
  }

  Future<void> nextPage() => goToIndex(_index + 1);
  Future<void> previousPage() => goToIndex(_index - 1);
  Future<void> firstPage() => goToIndex(0);
  Future<void> lastPage() => goToIndex(_pages.length - 1);

  Future<void> retryCurrentPage() => _loadCurrent(prefetch: false);

  Future<void> _loadCurrent({required bool prefetch}) async {
    if (_pages.isEmpty) return;
    final ref = _pages[_index];
    final cached = _cache.get(ref.entryName);
    if (cached != null) {
      _currentBytes = cached;
      _state = ComicReaderLoadState.ready;
      _error = null;
      _notify();
      if (prefetch) {
        // ignore: unawaited_futures
        _prefetchNeighbors();
      }
      return;
    }

    _state = ComicReaderLoadState.loadingPage;
    _error = null;
    _notify();
    try {
      final bytes = await _source.loadPageBytes(ref.entryName);
      if (_disposed) return;
      _cache.put(ref.entryName, bytes);
      _currentBytes = bytes;
      _state = ComicReaderLoadState.ready;
      _notify();
      if (prefetch) {
        // ignore: unawaited_futures
        _prefetchNeighbors();
      }
    } on ComicArchiveException catch (e) {
      if (_disposed) return;
      _cache.remove(ref.entryName);
      _currentBytes = null;
      _error = e;
      _state = ComicReaderLoadState.error;
      _notify();
    } catch (_) {
      if (_disposed) return;
      _cache.remove(ref.entryName);
      _currentBytes = null;
      _error = ComicArchiveException(
        kind: ComicArchiveErrorKind.pageExtractFailed,
        userMessage: 'That comic page could not be opened.',
      );
      _state = ComicReaderLoadState.error;
      _notify();
    }
  }

  Future<void> _prefetchNeighbors() async {
    if (!prefetchAdjacent || _pages.isEmpty) return;
    for (final i in [_index - 1, _index + 1]) {
      if (i < 0 || i >= _pages.length) continue;
      final name = _pages[i].entryName;
      if (_cache.get(name) != null) continue;
      try {
        final bytes = await _source.loadPageBytes(name);
        if (_disposed) return;
        _cache.put(name, bytes);
      } catch (_) {
        // Prefetch failures are silent; explicit navigation surfaces errors.
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    // ignore: discarded_futures
    _source.dispose();
    super.dispose();
  }
}
