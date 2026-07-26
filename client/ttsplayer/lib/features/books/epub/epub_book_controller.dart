import 'package:flutter/foundation.dart';

import '../archive/book_reader_errors.dart';
import '../models/book_location.dart';
import 'epub_book_document.dart';
import 'epub_parser.dart';

enum EpubReaderLoadState { loading, ready, error }

/// Session EPUB reader controller (no Phase 6.5 persistence).
class EpubBookController extends ChangeNotifier {
  EpubBookController({
    required this.documentId,
    required this.filePath,
    EpubParser? parser,
  }) : _parser = parser ?? EpubParser();

  final String documentId;
  final String filePath;
  final EpubParser _parser;

  EpubBookDocument? _document;
  int _spineIndex = 0;
  double _textScale = 1.0;
  EpubReaderLoadState _state = EpubReaderLoadState.loading;
  BookReaderException? _error;
  double _scrollOffset = 0;

  EpubBookDocument? get document => _document;
  EpubReaderLoadState get state => _state;
  BookReaderException? get error => _error;
  int get spineIndex => _spineIndex;
  double get textScale => _textScale;
  double get scrollOffset => _scrollOffset;

  EpubSpineChapter? get currentChapter =>
      _document == null ? null : _document!.spine[_spineIndex];

  int get chapterCount => _document?.spine.length ?? 0;
  bool get canGoPrevious => _spineIndex > 0;
  bool get canGoNext =>
      _document != null && _spineIndex < _document!.spine.length - 1;

  String get locationLabel {
    if (_document == null) return 'Loading…';
    return 'Chapter ${_spineIndex + 1} of ${_document!.spine.length}';
  }

  EpubBookLocation? get location {
    final doc = _document;
    final chapter = currentChapter;
    if (doc == null || chapter == null) return null;
    final progress = chapterCount <= 1
        ? 100.0
        : ((_spineIndex + 1) / chapterCount) * 100.0;
    return EpubBookLocation(
      documentId: documentId,
      spineIndex: _spineIndex,
      spineHref: chapter.href,
      chapterTitle: chapter.title,
      scrollOffset: _scrollOffset,
      progressPercent: progress,
    );
  }

  Future<void> open() async {
    _state = EpubReaderLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _document = await _parser.parseFile(filePath);
      _spineIndex = 0;
      _scrollOffset = 0;
      _state = EpubReaderLoadState.ready;
      notifyListeners();
    } on BookReaderException catch (e) {
      _error = e;
      _state = EpubReaderLoadState.error;
      notifyListeners();
    } catch (_) {
      _error = BookReaderException(
        kind: BookReaderErrorKind.unknown,
        userMessage: 'This book could not be opened.',
      );
      _state = EpubReaderLoadState.error;
      notifyListeners();
    }
  }

  void setScrollOffset(double offset) {
    _scrollOffset = offset;
  }

  Future<void> goToChapter(int index) async {
    if (_document == null) return;
    _spineIndex = index.clamp(0, _document!.spine.length - 1);
    _scrollOffset = 0;
    notifyListeners();
  }

  Future<void> nextChapter() => goToChapter(_spineIndex + 1);
  Future<void> previousChapter() => goToChapter(_spineIndex - 1);
  Future<void> firstChapter() => goToChapter(0);
  Future<void> lastChapter() => goToChapter(chapterCount - 1);

  void increaseTextScale() {
    _textScale = (_textScale + 0.1).clamp(0.8, 2.0);
    notifyListeners();
  }

  void decreaseTextScale() {
    _textScale = (_textScale - 0.1).clamp(0.8, 2.0);
    notifyListeners();
  }

  void resetTextScale() {
    _textScale = 1.0;
    notifyListeners();
  }

  void disposeDocument() {
    _document = null;
  }
}
