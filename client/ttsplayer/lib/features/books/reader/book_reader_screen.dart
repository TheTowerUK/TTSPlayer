import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../archive/book_opener.dart';
import '../archive/book_reader_errors.dart';
import '../epub/epub_book_controller.dart';
import '../epub/epub_chapter_view.dart';
import '../models/book_format.dart';

/// Fullscreen book reader for PDF and EPUB.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.item,
    required this.target,
    this.debugEpubController,
  });

  final MediaItem item;
  final BookOpenTarget target;
  final EpubBookController? debugEpubController;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final FocusNode _focusNode = FocusNode();
  PdfViewerController? _pdfController;
  EpubBookController? _epubController;
  BookReaderException? _fatalError;

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
        _epubController!.open();
      }
    }
  }

  void _onPdfChanged() {
    if (mounted) setState(() {});
  }

  void _onEpubChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pdfController?.removeListener(_onPdfChanged);
    _epubController?.removeListener(_onEpubChanged);
    _epubController?.disposeDocument();
    _focusNode.dispose();
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
      Navigator.of(context).maybePop();
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
            onPressed: () => Navigator.of(context).maybePop(),
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
        params: const PdfViewerParams(),
      );
    }

    final c = _epubController!;
    if (c.state == EpubReaderLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
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
    return Center(
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
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Close'),
            ),
          ],
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
