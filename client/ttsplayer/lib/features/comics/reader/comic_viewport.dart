import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'comic_fit_mode.dart';

/// Shared interaction constants for the comic viewport (Phase 6.4C).
abstract final class ComicViewportInteraction {
  static const sideZoneFraction = 0.25;
  static const tapMaxDragDistance = 12.0;
  static const swipeMinDistance = 48.0;
  static const scaleTolerance = 0.02;
  static const wheelDeltaThreshold = 120.0;
  static const minScale = 0.5;
  static const maxScale = 4.0;
}

/// Paged comic image viewport with fit modes, zoom/pan, and input routing.
class ComicViewport extends StatefulWidget {
  const ComicViewport({
    super.key,
    required this.imageBytes,
    required this.pageKey,
    required this.fitMode,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onToggleChrome,
    required this.canGoPrevious,
    required this.canGoNext,
    this.onImageDecodeFailed,
    this.onViewStateChanged,
    this.enableSwipeNavigation = true,
  });

  final Uint8List imageBytes;
  final Object pageKey;
  final ComicFitMode fitMode;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onToggleChrome;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onImageDecodeFailed;
  final VoidCallback? onViewStateChanged;

  /// Swipe page turns are enabled only at the base transform in [ComicFitMode.contain].
  final bool enableSwipeNavigation;

  @override
  State<ComicViewport> createState() => ComicViewportState();
}

class ComicViewportState extends State<ComicViewport> {
  final TransformationController _transformController =
      TransformationController();

  bool _zoomedBeyondBase = false;
  double _wheelDeltaAccumulated = 0;
  Offset? _pointerDown;
  double _horizontalDrag = 0;
  bool _dragExceededTapThreshold = false;
  bool _decodeErrorReported = false;

  TransformationController get transformController => _transformController;
  bool get isZoomedBeyondBase => _zoomedBeyondBase;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void didUpdateWidget(covariant ComicViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey ||
        oldWidget.fitMode != widget.fitMode) {
      resetTransform();
      _decodeErrorReported = false;
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void resetTransform() {
    _transformController.value = Matrix4.identity();
    _wheelDeltaAccumulated = 0;
    _setZoomedBeyondBase(false);
  }

  /// Test hook for wheel navigation when [Listener.onPointerSignal] is unavailable.
  @visibleForTesting
  void debugWheelDelta(double dy) {
    _handleWheel(
      PointerScrollEvent(
        timeStamp: Duration.zero,
        position: Offset.zero,
        scrollDelta: Offset(0, dy),
      ),
    );
  }

  void _setZoomedBeyondBase(bool value) {
    if (_zoomedBeyondBase == value) return;
    setState(() => _zoomedBeyondBase = value);
    widget.onViewStateChanged?.call();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final zoomed =
        (scale - 1.0).abs() > ComicViewportInteraction.scaleTolerance;
    _setZoomedBeyondBase(zoomed);
  }

  bool get _allowTapZoneNavigation => !_zoomedBeyondBase;

  bool get _allowSwipePageTurns =>
      !_zoomedBeyondBase &&
      widget.enableSwipeNavigation &&
      widget.fitMode == ComicFitMode.contain;

  void _handleWheel(PointerScrollEvent event) {
    if (_zoomedBeyondBase) return;
    _wheelDeltaAccumulated += event.scrollDelta.dy;
    if (_wheelDeltaAccumulated.abs() < ComicViewportInteraction.wheelDeltaThreshold) {
      return;
    }
    if (_wheelDeltaAccumulated > 0) {
      if (widget.canGoNext) widget.onNextPage();
    } else {
      if (widget.canGoPrevious) widget.onPreviousPage();
    }
    _wheelDeltaAccumulated = 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDown = event.localPosition;
    _horizontalDrag = 0;
    _dragExceededTapThreshold = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerDown == null) return;
    final delta = event.localPosition - _pointerDown!;
    _horizontalDrag += event.delta.dx;
    if (delta.distance > ComicViewportInteraction.tapMaxDragDistance) {
      _dragExceededTapThreshold = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event, Size size) {
    if (_pointerDown == null || _dragExceededTapThreshold) {
      _pointerDown = null;
      return;
    }
    if (!_allowTapZoneNavigation) {
      _pointerDown = null;
      return;
    }

    final x = event.localPosition.dx;
    final width = size.width;
    final leftBound = width * ComicViewportInteraction.sideZoneFraction;
    final rightBound = width * (1 - ComicViewportInteraction.sideZoneFraction);

    if (x < leftBound) {
      if (widget.canGoPrevious) widget.onPreviousPage();
    } else if (x > rightBound) {
      if (widget.canGoNext) widget.onNextPage();
    } else {
      widget.onToggleChrome();
    }
    _pointerDown = null;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_allowSwipePageTurns) return;
    if (_horizontalDrag.abs() < ComicViewportInteraction.swipeMinDistance) {
      return;
    }
    if (_horizontalDrag < 0) {
      if (widget.canGoNext) widget.onNextPage();
    } else {
      if (widget.canGoPrevious) widget.onPreviousPage();
    }
    _horizontalDrag = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _handleWheel(event);
            }
          },
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: (event) => _handlePointerUp(event, size),
          onPointerCancel: (_) => _pointerDown = null,
          child: GestureDetector(
            key: const Key('comic_reader_swipe_detector'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _allowSwipePageTurns
                ? (_) {
                    _horizontalDrag = 0;
                    _dragExceededTapThreshold = true;
                  }
                : null,
            onHorizontalDragUpdate: _allowSwipePageTurns
                ? (details) => _horizontalDrag += details.delta.dx
                : null,
            onHorizontalDragEnd:
                _allowSwipePageTurns ? _handleHorizontalDragEnd : null,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: ComicViewportInteraction.minScale,
              maxScale: ComicViewportInteraction.maxScale,
              panEnabled: true,
              scaleEnabled: true,
              onInteractionStart: (_) {
                _dragExceededTapThreshold = true;
              },
              child: Center(
                child: Image.memory(
                  key: ValueKey(widget.pageKey),
                  widget.imageBytes,
                  fit: widget.fitMode.boxFit,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) {
                    if (!_decodeErrorReported) {
                      _decodeErrorReported = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.onImageDecodeFailed?.call();
                      });
                    }
                    return const Center(
                      child: Text(
                        'This page image could not be displayed.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Returns whether [matrix] scale or pan differs from identity beyond [tolerance].
@visibleForTesting
bool comicViewportScaleBeyondBase(
  Matrix4 matrix, {
  double tolerance = ComicViewportInteraction.scaleTolerance,
}) {
  final scale = matrix.getMaxScaleOnAxis();
  if ((scale - 1.0).abs() > tolerance) return true;
  final t = matrix.getTranslation();
  return math.sqrt(t.x * t.x + t.y * t.y) > tolerance;
}
