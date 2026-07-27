import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../../reading/models/reading_location_payload.dart';
import '../../reading/models/reading_progress_record.dart';
import '../../reading/reading_navigation.dart';
import '../../reading/services/reading_progress_coordinator.dart';
import '../archive/book_opener.dart';
import '../archive/book_reader_errors.dart';
import '../models/book_format.dart';
import '../epub/epub_book_controller.dart';
import '../epub/epub_chapter_view.dart';
import 'book_pdf_viewer_params.dart';
import '../../reading/services/reader_session_telemetry.dart';

/// Fullscreen book reader for PDF and EPUB.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.item,
    required this.target,
    this.debugEpubController,
    this.restorePlan,
    this.startFromBeginning = false,
  });

  final MediaItem item;
  final BookOpenTarget target;
  final EpubBookController? debugEpubController;
  final ReadingProgressRestorePlan? restorePlan;
  final bool startFromBeginning;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final FocusNode _focusNode = FocusNode();
  PdfViewerController? _pdfController;
  EpubBookController? _epubController;
  BookReaderException? _fatalError;
  ReadingProgressCoordinator? _coordinator;
  bool _pdfLayoutReady = false;
  bool _pdfRestoreApplied = false;
  bool _epubLayoutReady = false;
  bool _closeHandled = false;
  int? _lastPdfPage;

  @override
  void initState() {
    super.initState();
    if (widget.target.format == BookFormat.pdf) {
      _pdfController = PdfViewerController();
      _pdfController!.addListener(_onPdfChanged);
    } else {
      _epubController = widget.debugEpubController ??
          EpubBookController(
            documentId: widget.target.documentId,
            filePath: widget.target.localPath,
          );
      _epubController!.addListener(_onEpubChanged);
      if (widget.debugEpubController == null) {
        // ignore: discarded_futures
        _openEpubWithRestore();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= context.read<ReadingProgressCoordinator>();
  }

  Future<void> _openEpubWithRestore() async {
    final c = _epubController!;
    await c.open();
    if (!mounted) return;
    final plan = widget.restorePlan;
    if (plan != null && !widget.startFromBeginning) {
      final doc = c.document;
      if (doc != null) {
        final hrefs = doc.spine.map((chapter) => chapter.href).toList();
        final restored = plan.epubLocation(
          spineHrefs: hrefs,
          currentSpineCount: hrefs.length,
        );
        if (restored != null) {
          await c.goToChapter(restored.spineIndex);
          c.setScrollOffset(restored.sectionRelativeOffset);
        }
      }
    }
    _beginProgressSessionEpub();
    _epubLayoutReady = true;
    _coordinator?.markLayoutReady();
    _persistEpubProgress(force: true);
  }

  void _onPdfChanged() {
    final c = _pdfController;
    if (c?.isReady == true && !_pdfLayoutReady) {
      _pdfLayoutReady = true;
      _beginProgressSessionPdf();
      if (!_pdfRestoreApplied) {
        _applyPdfRestore();
        _pdfRestoreApplied = true;
      }
      _coordinator?.markLayoutReady();
      _persistPdfProgress(force: true);
    } else if (c?.isReady == true && _pdfLayoutReady) {
      _persistPdfProgress();
    }
    if (mounted) setState(() {});
  }

  void _applyPdfRestore() {
    final plan = widget.restorePlan;
    final c = _pdfController;
    if (plan == null || widget.startFromBeginning || c == null || !c.isReady) {
      return;
    }
    final restored = plan.pdfLocation(currentPageCount: c.pageCount);
    if (restored != null && restored.pageIndex > 0) {
      // ignore: discarded_futures
      c.goToPage(
        pageNumber: restored.pageIndex + 1,
        duration: Duration.zero,
      );
    }
  }

  void _beginProgressSessionPdf() {
    final c = _pdfController;
    if (c == null || !c.isReady) return;
    final pageIndex = (c.pageNumber ?? 1) - 1;
    _coordinator?.beginSession(
      item: widget.item,
      readerFormat: ReadingReaderFormat.pdf,
      initialLocation: PdfReadingLocationPayload(
        pageIndex: pageIndex,
        pageCountAtSave: c.pageCount,
      ),
      progressFraction: ReadingProgressRecord.fractionForPdf(
        pageIndex,
        c.pageCount,
      ),
    );
  }

  void _beginProgressSessionEpub() {
    final c = _epubController;
    final doc = c?.document;
    final chapter = c?.currentChapter;
    if (c == null || doc == null || chapter == null) return;
    final payload = EpubReadingLocationPayload(
      spineIndex: c.spineIndex,
      spineHref: chapter.href,
      spineCountAtSave: doc.spine.length,
      chapterTitle: chapter.title,
      sectionRelativeOffset: c.scrollOffset,
    );
    _coordinator?.beginSession(
      item: widget.item,
      readerFormat: ReadingReaderFormat.epub,
      initialLocation: payload,
      progressFraction: ReadingProgressRecord.fractionForEpub(
        spineIndex: c.spineIndex,
        spineCount: doc.spine.length,
        sectionRelativeOffset: c.scrollOffset,
        sectionExtent: 1,
      ),
    );
  }

  void _persistPdfProgress({bool force = false}) {
    final c = _pdfController;
    if (c == null || !c.isReady || !_pdfLayoutReady) return;
    final pageIndex = (c.pageNumber ?? 1) - 1;
    if (!force && _lastPdfPage == pageIndex) return;
    _lastPdfPage = pageIndex;
    final fraction = ReadingProgressRecord.fractionForPdf(pageIndex, c.pageCount);
    _coordinator?.onLocationChanged(
      location: PdfReadingLocationPayload(
        pageIndex: pageIndex,
        pageCountAtSave: c.pageCount,
      ),
      progressFraction: fraction,
      force: force,
    );
  }

  void _persistEpubProgress({bool force = false}) {
    final c = _epubController;
    final doc = c?.document;
    final chapter = c?.currentChapter;
    if (c == null || doc == null || chapter == null || !_epubLayoutReady) {
      return;
    }
    _coordinator?.onLocationChanged(
      location: EpubReadingLocationPayload(
        spineIndex: c.spineIndex,
        spineHref: chapter.href,
        spineCountAtSave: doc.spine.length,
        chapterTitle: chapter.title,
        sectionRelativeOffset: c.scrollOffset,
      ),
      progressFraction: ReadingProgressRecord.fractionForEpub(
        spineIndex: c.spineIndex,
        spineCount: doc.spine.length,
        sectionRelativeOffset: c.scrollOffset,
        sectionExtent: 1,
      ),
      force: force,
    );
  }

  void _onEpubChanged() {
    if (_epubController?.state == EpubReaderLoadState.ready && _epubLayoutReady) {
      _persistEpubProgress();
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleClose() async {
    if (_closeHandled) return;
    _closeHandled = true;
    await _coordinator?.onReaderClosed();
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    if (!_closeHandled) {
      // ignore: discarded_futures
      _coordinator?.onReaderClosed();
    }
    _pdfController?.removeListener(_onPdfChanged);
    _pdfController = null;
    _epubController?.removeListener(_onEpubChanged);
    _epubController?.disposeDocument();
    _epubController = null;
    _focusNode.dispose();
    ReaderSessionTelemetry.instance.recordCleanupResult('book_reader_disposed');
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (key == LogicalKeyboardKey.escape) {
      // ignore: discarded_futures
      _handleClose();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.equal) {
      _adjustZoom(increase: true);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.minus) {
      _adjustZoom(increase: false);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.digit0) {
      _resetZoom();
      return KeyEventResult.handled;
    }

    if (widget.target.format == BookFormat.pdf) {
      return _handlePdfKeys(key);
    }
    return _handleEpubKeys(key);
  }

  KeyEventResult _handlePdfKeys(LogicalKeyboardKey key) {
    final c = _pdfController;
    if (c == null || !c.isReady) return KeyEventResult.ignored;
    final page = c.pageNumber ?? 1;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      if (page > 1) {
        // ignore: discarded_futures
        c.goToPage(pageNumber: page - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      if (page < c.pageCount) {
        // ignore: discarded_futures
        c.goToPage(pageNumber: page + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      // ignore: discarded_futures
      c.goToPage(pageNumber: 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      // ignore: discarded_futures
      c.goToPage(pageNumber: c.pageCount);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleEpubKeys(LogicalKeyboardKey key) {
    final c = _epubController;
    if (c == null || c.state != EpubReaderLoadState.ready) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.pageUp && c.canGoPrevious) {
      // ignore: discarded_futures
      c.previousChapter();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown && c.canGoNext) {
      // ignore: discarded_futures
      c.nextChapter();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      // ignore: discarded_futures
      c.firstChapter();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      // ignore: discarded_futures
      c.lastChapter();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _adjustZoom({required bool increase}) {
    if (widget.target.format == BookFormat.epub) {
      if (increase) {
        _epubController?.increaseTextScale();
      } else {
        _epubController?.decreaseTextScale();
      }
      return;
    }
    final c = _pdfController;
    if (c == null || !c.isReady) return;
    // ignore: discarded_futures
    if (increase) {
      c.zoomUp();
    } else {
      c.zoomDown();
    }
  }

  void _resetZoom() {
    if (widget.target.format == BookFormat.epub) {
      _epubController?.resetTextScale();
      return;
    }
    final c = _pdfController;
    if (c == null || !c.isReady) return;
    final fit = c.alternativeFitScale ?? c.coverScale;
    // ignore: discarded_futures
    c.setZoom(c.centerPosition, fit);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: AppColors.textPrimary,
          title: Text(
            widget.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            key: const Key('book_reader_back'),
            tooltip: 'Close reader',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // ignore: discarded_futures
              _handleClose();
            },
          ),
          actions: _buildActions(),
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildLocationBar(),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (widget.target.format == BookFormat.epub &&
        _epubController?.document != null) {
      return [
        IconButton(
          key: const Key('book_reader_toc'),
          tooltip: 'Table of contents',
          icon: const Icon(Icons.list),
          onPressed: _showToc,
        ),
      ];
    }
    return const [];
  }

  Widget? _buildLocationBar() {
    final label = widget.target.format == BookFormat.pdf
        ? _pdfLocationLabel()
        : _epubController?.locationLabel ?? 'Loading…';
    return Material(
      color: Colors.black87,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.target.format == BookFormat.pdf)
                IconButton(
                  key: const Key('book_reader_prev'),
                  tooltip: 'Previous page',
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _pdfController?.isReady == true
                      ? () {
                          final p = _pdfController!.pageNumber ?? 1;
                          if (p > 1) {
                            // ignore: discarded_futures
                            _pdfController!.goToPage(pageNumber: p - 1);
                          }
                        }
                      : null,
                )
              else if (_epubController?.state == EpubReaderLoadState.ready)
                IconButton(
                  key: const Key('book_reader_prev'),
                  tooltip: 'Previous chapter',
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _epubController!.canGoPrevious
                      ? () {
                          // ignore: discarded_futures
                          _epubController!.previousChapter();
                        }
                      : null,
                ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: label,
                  child: Text(
                    key: const Key('book_reader_location'),
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (widget.target.format == BookFormat.pdf)
                IconButton(
                  key: const Key('book_reader_next'),
                  tooltip: 'Next page',
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _pdfController?.isReady == true
                      ? () {
                          final c = _pdfController!;
                          final p = c.pageNumber ?? 1;
                          if (p < c.pageCount) {
                            // ignore: discarded_futures
                            c.goToPage(pageNumber: p + 1);
                          }
                        }
                      : null,
                )
              else if (_epubController?.state == EpubReaderLoadState.ready) ...[
                IconButton(
                  key: const Key('book_reader_next'),
                  tooltip: 'Next chapter',
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _epubController!.canGoNext
                      ? () {
                          // ignore: discarded_futures
                          _epubController!.nextChapter();
                        }
                      : null,
                ),
                IconButton(
                  key: const Key('book_reader_text_smaller'),
                  tooltip: 'Decrease text size',
                  icon: const Icon(Icons.text_decrease, color: Colors.white),
                  onPressed: _epubController!.decreaseTextScale,
                ),
                IconButton(
                  key: const Key('book_reader_text_larger'),
                  tooltip: 'Increase text size',
                  icon: const Icon(Icons.text_increase, color: Colors.white),
                  onPressed: _epubController!.increaseTextScale,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _pdfLocationLabel() {
    final c = _pdfController;
    if (c == null || !c.isReady) return 'Loading…';
    final page = c.pageNumber ?? 1;
    return 'Page $page of ${c.pageCount}';
  }

  Widget _buildBody() {
    if (_fatalError != null) {
      return _errorPane(_fatalError!);
    }
    if (widget.target.format == BookFormat.pdf) {
      return PdfViewer.file(
        widget.target.localPath,
        key: const Key('book_reader_pdf_view'),
        controller: _pdfController,
        passwordProvider: () => null,
        params: ttsPlayerPdfViewerParams(
          onDocumentLoadFinished: (ref, succeeded) {
            if (succeeded) {
              ReaderSessionTelemetry.instance.recordCleanupResult('pdf_loaded');
            }
          },
        ),
      );
    }

    final c = _epubController!;
    if (c.state == EpubReaderLoadState.loading) {
      return Semantics(
        label: 'Loading book',
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (c.state == EpubReaderLoadState.error && c.error != null) {
      return _errorPane(c.error!);
    }
    final chapter = c.currentChapter;
    final doc = c.document;
    if (chapter == null || doc == null) {
      return const Center(
        child: Text('No readable content.', style: TextStyle(color: Colors.white70)),
      );
    }
    return EpubChapterView(
      key: ValueKey(chapter.href),
      chapter: chapter,
      document: doc,
      textScale: c.textScale,
      initialScrollOffset: c.scrollOffset,
      onScrollOffsetChanged: (offset) {
        c.setScrollOffset(offset);
        _persistEpubProgress();
      },
      onInternalLink: (href) {
        final index = doc.spine.indexWhere(
          (s) => s.href == href || s.href.endsWith('/$href') || s.href.endsWith(href),
        );
        if (index >= 0) {
          // ignore: discarded_futures
          c.goToChapter(index);
        }
      },
    );
  }

  Widget _errorPane(BookReaderException error) {
    return Semantics(
      liveRegion: true,
      label: error.userMessage,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                key: const Key('book_reader_error_message'),
                error.userMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('book_reader_error_close'),
                onPressed: () {
                  // ignore: discarded_futures
                  _handleClose();
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showToc() async {
    final c = _epubController;
    final doc = c?.document;
    if (doc == null || c == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (context) {
        return ListView(
          children: [
            for (final entry in doc.toc)
              ListTile(
                title: Text(
                  entry.title,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // ignore: discarded_futures
                  c.goToChapter(entry.spineIndex);
                },
              ),
          ],
        );
      },
    );
  }
}
