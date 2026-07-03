import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;

  /// Where playback begins:
  /// - null           → resume from saved position (default)
  /// - Duration.zero  → ignore saved position, start from the beginning
  /// - any other      → seek to that exact position
  final Duration? startPosition;

  const PlayerScreen({super.key, required this.item, this.startPosition});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlaybackService _service;

  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _service = context.read<PlaybackService>();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.play(widget.item, startPosition: widget.startPosition);
    });
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _service.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _goBack() {
    _service.stop();
    Navigator.of(context).pop();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_service.isPlaying &&
          !_service.isBuffering &&
          !_service.isInitializing &&
          _service.errorMessage == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  bool _shouldPinControls(PlaybackService service) {
    return service.isInitializing ||
        service.isBuffering ||
        service.errorMessage != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.playerBg,
      body: Consumer<PlaybackService>(
        builder: (context, service, _) {
          final pinControls = _shouldPinControls(service);
          if (pinControls && !_controlsVisible) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _controlsVisible = true);
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildMainLayer(service),
              _PlayerTopBar(
                title: widget.item.title,
                onBack: _goBack,
              ),
              if (service.errorMessage == null &&
                  !service.isInitializing &&
                  service.isReady &&
                  !service.isCompleted)
                AnimatedOpacity(
                  opacity: _controlsVisible || pinControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !(_controlsVisible || pinControls),
                    child: _PlaybackControlsOverlay(
                      service: service,
                      onSeek: _showControls,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainLayer(PlaybackService service) {
    if (service.errorMessage != null) {
      return _ErrorView(
        message: service.errorMessage!,
        onRetry: () => service.retry(startPosition: widget.startPosition),
        onBack: _goBack,
      );
    }

    if (service.isInitializing || !service.isReady) {
      return _PreparingView(onGoBack: _goBack);
    }

    if (service.isCompleted) {
      return _CompletedView(
        item: widget.item,
        service: service,
        onBack: _goBack,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: service.aspectRatio,
              child: _VideoSurface(service: service),
            ),
          ),
          if (service.isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.textMedium,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video surface — media_kit on Windows, video_player elsewhere
// ---------------------------------------------------------------------------

class _VideoSurface extends StatelessWidget {
  final PlaybackService service;

  const _VideoSurface({required this.service});

  @override
  Widget build(BuildContext context) {
    if (service.usesMediaKit) {
      return Video(controller: service.mediaKitVideoController!);
    }
    return VideoPlayer(service.controller!);
  }
}

// ---------------------------------------------------------------------------
// Always-visible top bar
// ---------------------------------------------------------------------------

class _PlayerTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PlayerTopBar({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.playerOverlay, Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                tooltip: 'Go Back',
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.playerTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preparing / loading view
// ---------------------------------------------------------------------------

class _PreparingView extends StatelessWidget {
  final VoidCallback onGoBack;

  const _PreparingView({required this.onGoBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.textMedium),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Preparing video…',
              style: AppTypography.body.copyWith(color: AppColors.textHigh),
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton.icon(
              onPressed: onGoBack,
              icon: const Icon(Icons.close, size: AppIcons.md),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textHigh,
                side: const BorderSide(color: AppColors.textDisabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playback controls overlay (bottom bar only — back is in top bar)
// ---------------------------------------------------------------------------

class _PlaybackControlsOverlay extends StatelessWidget {
  final PlaybackService service;
  final VoidCallback onSeek;

  const _PlaybackControlsOverlay({
    required this.service,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final position = service.position;
    final duration = service.duration;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [AppColors.playerOverlay, Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: AppSpacing.playerControls,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (service.isBuffering)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Buffering…',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: AppTypography.size12,
                      ),
                    ),
                  ),
                _PlaybackProgressBar(
                  position: position,
                  duration: duration,
                  onSeek: (target) {
                    service.seekTo(target);
                    onSeek();
                  },
                ),
                Row(
                  children: [
                    Text(_fmt(position), style: AppTypography.playerTime),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.replay_10,
                          color: AppColors.textPrimary),
                      onPressed: () {
                        service.seekTo(position - const Duration(seconds: 10));
                        onSeek();
                      },
                    ),
                    IconButton(
                      iconSize: AppIcons.playerControl,
                      icon: Icon(
                        service.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        service.togglePlayPause();
                        onSeek();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_30,
                          color: AppColors.textPrimary),
                      onPressed: () {
                        service.seekTo(position + const Duration(seconds: 30));
                        onSeek();
                      },
                    ),
                    const Spacer(),
                    Text(_fmt(duration), style: AppTypography.playerTime),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _PlaybackProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _PlaybackProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds;
    final enabled = maxMs > 0;
    final valueMs =
        enabled ? position.inMilliseconds.clamp(0, maxMs).toDouble() : 0.0;

    return Padding(
      padding: AppSpacing.seekBar,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: SliderComponentShape.noOverlay,
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.textFaint,
          thumbColor: AppColors.primary,
        ),
        child: Slider(
          value: valueMs,
          max: enabled ? maxMs.toDouble() : 1,
          onChanged: enabled
              ? (ms) => onSeek(Duration(milliseconds: ms.round()))
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: AppIcons.hero),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              PlaybackService.playbackFailedNote,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: AppIcons.md),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textHigh,
                    side: const BorderSide(color: AppColors.textDisabled),
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: AppIcons.md),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Completed view
// ---------------------------------------------------------------------------

class _CompletedView extends StatelessWidget {
  final MediaItem item;
  final PlaybackService service;
  final VoidCallback onBack;

  const _CompletedView({
    required this.item,
    required this.service,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.textMedium, size: AppIcons.hero),
            const SizedBox(height: AppSpacing.base),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTypography.size18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: AppIcons.md),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textHigh,
                    side: const BorderSide(color: AppColors.textDisabled),
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                FilledButton.icon(
                  onPressed: () => service
                      .seekTo(Duration.zero)
                      .then((_) => service.togglePlayPause()),
                  icon: const Icon(Icons.replay, size: AppIcons.md),
                  label: const Text('Watch Again'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
