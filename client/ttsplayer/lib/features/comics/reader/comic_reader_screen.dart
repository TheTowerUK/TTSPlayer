import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../../reading/models/reading_location_payload.dart';
import '../../reading/models/reading_progress_record.dart';
import '../../reading/reading_navigation.dart';
import '../../reading/services/reading_progress_coordinator.dart';
import '../archive/comic_archive_errors.dart';
import '../archive/comic_archive_source.dart';
import 'comic_fit_mode.dart';
import 'comic_page_failure.dart';
import 'comic_reader_controller.dart';
import 'comic_viewport.dart';

/// Fullscreen paged comic reader (CBZ).
///
/// Input routing (when no text field owns focus):
/// - Left / PageUp: previous page
/// - Right / PageDown: next page
/// - Home / End: first / last page
/// - Escape: show chrome if hidden, else close
/// - Wheel at base transform: previous / next page
/// - Side tap zones: previous / next; centre toggles chrome
/// - Horizontal swipe (contain, base transform): previous / next page
class ComicReaderScreen extends StatefulWidget {
  const ComicReaderScreen({
    super.key,
    required this.item,
    required this.source,
    @visibleForTesting this.debugController,
    this.restorePlan,
    this.startFromBeginning = false,
  });

  final MediaItem item;
  final ComicArchiveSource source;
  final ReadingProgressRestorePlan? restorePlan;
  final bool startFromBeginning;

  @visibleForTesting
  final ComicReaderController? debugController;

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen> {
  late final ComicReaderController _controller;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ComicViewportState> _viewportKey =
      GlobalKey<ComicViewportState>();
  late final bool _ownsController;
  ReadingProgressCoordinator? _coordinator;
  ReadingReaderFormat? _readerFormat;
  bool _layoutReady = false;
  bool _closeHandled = false;
  int? _lastPageIndex;
  ComicFitMode _fitMode = ComicFitMode.contain;
  bool _chromeVisible = true;
  bool _progressSessionBegun = false;

  ReadingReaderFormat get readerFormat =>
      _readerFormat ?? ReadingReaderFormat.cbz;

  @visibleForTesting
  ComicFitMode get fitMode => _fitMode;

  @visibleForTesting
  bool get chromeVisible => _chromeVisible;

  @override
  void initState() {
    super.initState();
    _readerFormat =
        readerFormatForComicExtension(_extension(widget.item.filePath)) ??
            ReadingReaderFormat.cbz;
    final injected = widget.debugController;
    if (injected != null) {
      _controller = injected;
      _ownsController = false;
      _layoutReady = _controller.state == ComicReaderLoadState.ready;
      _lastPageIndex = _controller.pageIndex;
    } else {
      _controller = ComicReaderController(source: widget.source);
      _ownsController = true;
      // ignore: discarded_futures
      _openWithRestore();
    }
    _controller.addListener(_onChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= context.read<ReadingProgressCoordinator>();
    _ensureProgressSessionStarted();
  }

  void _ensureProgressSessionStarted() {
    if (_progressSessionBegun || !_layoutReady || _controller.pageCount <= 0) {
      return;
    }
    _progressSessionBegun = true;
    _beginProgressSession();
    _coordinator?.markLayoutReady();
  }

  Future<void> _openWithRestore() async {
    await _controller.open();
    if (!mounted) return;
    final plan = widget.restorePlan;
    if (plan != null &&
        !widget.startFromBeginning &&
        _controller.pageCount > 0) {
      final names = _controller.pages.map((page) => page.entryName).toList();
      final restored = plan.comicLocation(
        entryNames: names,
        currentPageCount: _controller.pageCount,
      );
      if (restored != null && restored.pageIndex > 0) {
        await _navigatePage(() => _controller.goToIndex(restored.pageIndex));
      }
    }
    _layoutReady = _controller.state == ComicReaderLoadState.ready;
    if (_layoutReady) {
      _ensureProgressSessionStarted();
      _persistProgress(force: true);
    }
  }

  Future<void> _navigatePage(Future<void> Function() action) async {
    await action();
    _resetViewportForPageChange();
  }

  void _resetViewportForPageChange() {
    _viewportKey.currentState?.resetTransform();
  }

  void _setFitMode(ComicFitMode mode) {
    if (_fitMode == mode) return;
    setState(() {
      _fitMode = mode;
    });
    _viewportKey.currentState?.resetTransform();
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _beginProgressSession() {
    if (_controller.pageCount <= 0) return;
    final location = _currentLocation();
    if (location == null) return;
    _coordinator?.beginSession(
      item: widget.item,
      readerFormat: readerFormat,
      initialLocation: location,
      progressFraction: ReadingProgressRecord.fractionForComic(
        _controller.pageIndex,
        _controller.pageCount,
      ),
    );
  }

  ComicReadingLocationPayload? _currentLocation() {
    if (_controller.pageCount <= 0) return null;
    return ComicReadingLocationPayload(
      pageIndex: _controller.pageIndex,
      pageCountAtSave: _controller.pageCount,
      entryName: _controller.currentPage?.entryName,
      archiveFormat: readerFormat,
    );
  }

  void _persistProgress({bool force = false}) {
    if (!_layoutReady || _controller.pageCount <= 0) return;
    if (!force && _lastPageIndex == _controller.pageIndex) return;
    _lastPageIndex = _controller.pageIndex;
    final location = _currentLocation();
    if (location == null) return;
    _coordinator?.onLocationChanged(
      location: location,
      progressFraction: ReadingProgressRecord.fractionForComic(
        _controller.pageIndex,
        _controller.pageCount,
      ),
      force: force,
    );
  }

  Future<void> _handleClose() async {
    if (_closeHandled) return;
    _closeHandled = true;
    await _coordinator?.onReaderClosed();
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  void _onChanged() {
    if (_controller.state == ComicReaderLoadState.ready && !_layoutReady) {
      _layoutReady = true;
      _ensureProgressSessionStarted();
      _persistProgress(force: true);
    } else if (_layoutReady) {
      if (_lastPageIndex != null &&
          _lastPageIndex != _controller.pageIndex) {
        _resetViewportForPageChange();
      }
      _persistProgress();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (!_closeHandled) {
      // ignore: discarded_futures
      _coordinator?.onReaderClosed();
    }
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
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
      _navigatePage(_controller.previousPage);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      // ignore: discarded_futures
      _navigatePage(_controller.nextPage);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      // ignore: discarded_futures
      _navigatePage(_controller.firstPage);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      // ignore: discarded_futures
      _navigatePage(_controller.lastPage);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (!_chromeVisible) {
        setState(() => _chromeVisible = true);
        return KeyEventResult.handled;
      }
      // ignore: discarded_futures
      _handleClose();
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
        appBar: _chromeVisible
            ? AppBar(
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
                  onPressed: () {
                    // ignore: discarded_futures
                    _handleClose();
                  },
                ),
              )
            : null,
        body: Column(
          children: [
            Expanded(child: _buildBody()),
            if (_chromeVisible)
              _ControlsBar(
                controller: _controller,
                fitMode: _fitMode,
                onFitModeSelected: _setFitMode,
                onToggleChrome: _toggleChrome,
                onNavigatePage: _navigatePage,
              ),
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
        onClose: () {
          // ignore: discarded_futures
          _handleClose();
        },
      );
    }

    final bytes = _controller.currentPageBytes;
    final pageFailure = _controller.currentPageFailure;
    final imageBytes = bytes == null ? null : Uint8List.fromList(bytes);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageBytes != null)
          ComicViewport(
            key: _viewportKey,
            imageBytes: imageBytes,
            pageKey: _controller.currentPage?.entryName ?? _controller.pageIndex,
            fitMode: _fitMode,
            canGoPrevious: _controller.canGoPrevious,
            canGoNext: _controller.canGoNext,
            onImageDecodeFailed: _controller.reportCurrentPageDecodeFailed,
            onPreviousPage: () {
              // ignore: discarded_futures
              _navigatePage(_controller.previousPage);
            },
            onNextPage: () {
              // ignore: discarded_futures
              _navigatePage(_controller.nextPage);
            },
            onToggleChrome: _toggleChrome,
          )
        else if (pageFailure != null && state == ComicReaderLoadState.ready)
          _PageFailurePane(
            failure: pageFailure,
            pageIndicator: _controller.pageIndicatorLabel,
            onRetry: pageFailure.canRetry
                ? () {
                    // ignore: discarded_futures
                    _controller.retryCurrentPage();
                  }
                : null,
          )
        else if (state == ComicReaderLoadState.loadingPage)
          const Center(child: CircularProgressIndicator()),
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
  const _ControlsBar({
    required this.controller,
    required this.fitMode,
    required this.onFitModeSelected,
    required this.onToggleChrome,
    required this.onNavigatePage,
  });

  final ComicReaderController controller;
  final ComicFitMode fitMode;
  final ValueChanged<ComicFitMode> onFitModeSelected;
  final VoidCallback onToggleChrome;
  final Future<void> Function(Future<void> Function()) onNavigatePage;

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
                        onNavigatePage(controller.firstPage);
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
                        onNavigatePage(controller.previousPage);
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
                        onNavigatePage(controller.nextPage);
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
                        onNavigatePage(controller.lastPage);
                      }
                    : null,
              ),
              PopupMenuButton<ComicFitMode>(
                key: const Key('comic_reader_fit_mode_menu'),
                tooltip: fitMode.semanticsLabel,
                icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                initialValue: fitMode,
                onSelected: onFitModeSelected,
                itemBuilder: (context) => ComicFitMode.values
                    .map(
                      (mode) => PopupMenuItem<ComicFitMode>(
                        key: Key('comic_reader_fit_${mode.name}'),
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
              ),
              IconButton(
                key: const Key('comic_reader_immersive_toggle'),
                tooltip: 'Hide reader controls',
                icon: const Icon(Icons.fullscreen),
                color: Colors.white,
                onPressed: onToggleChrome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageFailurePane extends StatelessWidget {
  const _PageFailurePane({
    required this.failure,
    required this.pageIndicator,
    this.onRetry,
  });

  final ComicPageFailure failure;
  final String pageIndicator;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              key: const Key('comic_reader_page_failure_message'),
              failure.userMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              key: const Key('comic_reader_page_failure_indicator'),
              pageIndicator,
              style: const TextStyle(color: Colors.white70),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('comic_reader_page_retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
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
