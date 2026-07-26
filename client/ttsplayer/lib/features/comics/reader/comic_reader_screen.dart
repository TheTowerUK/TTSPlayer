import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../archive/comic_archive_errors.dart';
import '../archive/comic_archive_source.dart';
import 'comic_reader_controller.dart';

/// Fullscreen paged comic reader (CBZ / CBR).
///
/// Keyboard (when no text field owns focus):
/// - Left / PageUp: previous page
/// - Right / PageDown: next page
/// - Home: first page
/// - End: last page
/// - Escape: pop reader
class ComicReaderScreen extends StatefulWidget {
  const ComicReaderScreen({
    super.key,
    required this.item,
    required this.source,
    @visibleForTesting this.debugController,
  });

  final MediaItem item;
  final ComicArchiveSource source;

  /// When set (tests only), skips [ComicReaderController.open] so real dart:io
  /// work can be completed outside the widget-test fake-async zone.
  @visibleForTesting
  final ComicReaderController? debugController;

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen> {
  late final ComicReaderController _controller;
  final FocusNode _focusNode = FocusNode();
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    final injected = widget.debugController;
    if (injected != null) {
      _controller = injected;
      _ownsController = false;
    } else {
      _controller = ComicReaderController(source: widget.source);
      _ownsController = true;
      // ignore: discarded_futures
      _controller.open();
    }
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
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
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      // ignore: discarded_futures
      _controller.previousPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      // ignore: discarded_futures
      _controller.nextPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      // ignore: discarded_futures
      _controller.firstPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      // ignore: discarded_futures
      _controller.lastPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
            key: const Key('comic_reader_back'),
            tooltip: 'Close reader',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(child: _buildBody()),
            _ControlsBar(controller: _controller),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final state = _controller.state;
    if (state == ComicReaderLoadState.loadingPages) {
      return Center(
        child: Semantics(
          label: 'Loading comic pages',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (state == ComicReaderLoadState.error &&
        _controller.currentPageBytes == null &&
        _controller.pages.isEmpty) {
      return _ErrorPane(
        error: _controller.error,
        onRetry: () {
          // ignore: discarded_futures
          _controller.open();
        },
        onClose: () => Navigator.of(context).maybePop(),
      );
    }

    final bytes = _controller.currentPageBytes;
    final imageBytes =
        bytes == null ? null : Uint8List.fromList(bytes);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageBytes != null)
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.memory(
                key: ValueKey(_controller.currentPage?.entryName),
                imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'This page image could not be displayed.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          )
        else if (state == ComicReaderLoadState.loadingPage)
          const Center(child: CircularProgressIndicator())
        else if (_controller.error != null)
          _ErrorPane(
            error: _controller.error,
            onRetry: () {
              // ignore: discarded_futures
              _controller.retryCurrentPage();
            },
            onClose: () => Navigator.of(context).maybePop(),
          ),
        if (state == ComicReaderLoadState.loadingPage && imageBytes != null)
          const Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({required this.controller});

  final ComicReaderController controller;

  @override
  Widget build(BuildContext context) {
    final ready = controller.pages.isNotEmpty;
    return Material(
      color: Colors.black87,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const Key('comic_reader_first'),
                tooltip: 'First page',
                icon: const Icon(Icons.first_page),
                color: Colors.white,
                onPressed: ready && controller.canGoPrevious
                    ? () {
                        // ignore: discarded_futures
                        controller.firstPage();
                      }
                    : null,
              ),
              IconButton(
                key: const Key('comic_reader_prev'),
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                color: Colors.white,
                onPressed: ready && controller.canGoPrevious
                    ? () {
                        // ignore: discarded_futures
                        controller.previousPage();
                      }
                    : null,
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: controller.pageIndicatorLabel,
                  child: Text(
                    key: const Key('comic_reader_page_indicator'),
                    controller.pageIndicatorLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('comic_reader_next'),
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                color: Colors.white,
                onPressed: ready && controller.canGoNext
                    ? () {
                        // ignore: discarded_futures
                        controller.nextPage();
                      }
                    : null,
              ),
              IconButton(
                key: const Key('comic_reader_last'),
                tooltip: 'Last page',
                icon: const Icon(Icons.last_page),
                color: Colors.white,
                onPressed: ready && controller.canGoNext
                    ? () {
                        // ignore: discarded_futures
                        controller.lastPage();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  final ComicArchiveException? error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final message = error?.userMessage ?? 'This comic could not be opened.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              key: const Key('comic_reader_error_message'),
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  key: const Key('comic_reader_retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
                TextButton(
                  key: const Key('comic_reader_error_close'),
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
