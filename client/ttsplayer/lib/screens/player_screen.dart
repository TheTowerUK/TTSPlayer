import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../models/playback/playback_audio_track.dart';
import '../models/playback/playback_error_kind.dart';
import '../models/playback/playback_rate_presets.dart';
import '../models/playback/playback_subtitle_track.dart';
import '../services/playback/playback_error_messages.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';

/// Sentinel for the subtitle Off menu entry (not a real track id).
const _subtitleOffValue = '__subtitle_off__';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;

  /// Where playback begins:
  /// - null           → resume from saved position (default)
  /// - Duration.zero  → ignore saved position, start from the beginning
  /// - any other      → seek to that exact position
  final Duration? startPosition;

  /// When false, [PlaybackService.play] is not invoked automatically (tests).
  @visibleForTesting
  final bool autoPlay;

  const PlayerScreen({
    super.key,
    required this.item,
    this.startPosition,
    this.autoPlay = true,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlaybackService _service;
  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'PlayerScreen');
  final GlobalKey<_PlaybackControlsOverlayState> _controlsKey =
      GlobalKey<_PlaybackControlsOverlayState>();

  bool _controlsVisible = true;
  bool _menuOpen = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _service = context.read<PlaybackService>();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _service.play(widget.item, startPosition: widget.startPosition);
      });
    }
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playerFocusNode.dispose();
    _service.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _goBack() {
    _service.stop();
    Navigator.of(context).pop();
  }

  void _onMenuOpenChanged(bool open) {
    if (_menuOpen == open) return;
    setState(() => _menuOpen = open);
    if (open) {
      _showControls();
    } else {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    if (_menuOpen) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_shouldPinControls(_service)) return;
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
        service.errorMessage != null ||
        _menuOpen ||
        (service.isReady && !service.isCompleted && !service.isPlaying);
  }

  bool _shouldIgnoreShortcuts() {
    if (_menuOpen) return true;
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    return focus.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_shouldIgnoreShortcuts()) return KeyEventResult.ignored;

    final service = _service;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _goBack();
      return KeyEventResult.handled;
    }

    if (service.errorMessage != null ||
        service.isInitializing ||
        !service.isReady ||
        service.isCompleted) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      service.togglePlayPause();
      _showControls();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      service.seekTo(service.position - const Duration(seconds: 10));
      _showControls();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      service.seekTo(service.position + const Duration(seconds: 30));
      _showControls();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.comma) {
      if (service.canChangePlaybackRate) {
        final slower = PlaybackRatePresets.stepRate(service.playbackRate, -1);
        if (slower != null) {
          unawaited(_applyPlaybackRate(slower));
        }
        _showControls();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.period) {
      if (service.canChangePlaybackRate) {
        final faster = PlaybackRatePresets.stepRate(service.playbackRate, 1);
        if (faster != null) {
          unawaited(_applyPlaybackRate(faster));
        }
        _showControls();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyA && service.canSelectAudioTracks) {
      _controlsKey.currentState?.openAudioMenu();
      _showControls();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyS &&
        service.canSelectSubtitleTracks) {
      _controlsKey.currentState?.openSubtitleMenu();
      _showControls();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _applyPlaybackRate(double rate) async {
    final result = await _service.setPlaybackRate(rate);
    if (!result.isSuccess && mounted) {
      _showActionFeedback('Playback speed could not be changed.');
    }
    _showControls();
  }

  void _showActionFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _playerFocusNode,
      autofocus: true,
      onKeyEvent: (_, event) => _handleKeyEvent(event),
      child: Scaffold(
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
                        key: _controlsKey,
                        service: service,
                        onInteraction: _showControls,
                        onMenuOpenChanged: _onMenuOpenChanged,
                        onRateSelected: _applyPlaybackRate,
                        onActionFeedback: _showActionFeedback,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainLayer(PlaybackService service) {
    if (service.errorMessage != null) {
      return _ErrorView(
        kind: service.playbackErrorKind,
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
    if (service.usesMediaKit && service.mediaKitVideoController != null) {
      return Video(controller: service.mediaKitVideoController!);
    }
    if (service.controller != null) {
      return VideoPlayer(service.controller!);
    }
    return const ColoredBox(color: AppColors.playerBg);
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

class _PlaybackControlsOverlay extends StatefulWidget {
  final PlaybackService service;
  final VoidCallback onInteraction;
  final ValueChanged<bool> onMenuOpenChanged;
  final Future<void> Function(double rate) onRateSelected;
  final ValueChanged<String> onActionFeedback;

  const _PlaybackControlsOverlay({
    super.key,
    required this.service,
    required this.onInteraction,
    required this.onMenuOpenChanged,
    required this.onRateSelected,
    required this.onActionFeedback,
  });

  @override
  State<_PlaybackControlsOverlay> createState() =>
      _PlaybackControlsOverlayState();
}

class _PlaybackControlsOverlayState extends State<_PlaybackControlsOverlay> {
  final GlobalKey<PopupMenuButtonState<double>> _speedMenuKey =
      GlobalKey<PopupMenuButtonState<double>>();
  final GlobalKey<PopupMenuButtonState<String>> _audioMenuKey =
      GlobalKey<PopupMenuButtonState<String>>();
  final GlobalKey<PopupMenuButtonState<String>> _subtitleMenuKey =
      GlobalKey<PopupMenuButtonState<String>>();

  void openAudioMenu() => _audioMenuKey.currentState?.showButtonMenu();
  void openSubtitleMenu() => _subtitleMenuKey.currentState?.showButtonMenu();

  PlaybackService get service => widget.service;

  @override
  Widget build(BuildContext context) {
    final position = service.position;
    final duration = service.duration;
    final showTrackRow = service.canChangePlaybackRate ||
        service.canSelectAudioTracks ||
        service.canSelectSubtitleTracks;

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
                    widget.onInteraction();
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
                        widget.onInteraction();
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
                        widget.onInteraction();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_30,
                          color: AppColors.textPrimary),
                      onPressed: () {
                        service.seekTo(position + const Duration(seconds: 30));
                        widget.onInteraction();
                      },
                    ),
                    const Spacer(),
                    Text(_fmt(duration), style: AppTypography.playerTime),
                  ],
                ),
                if (showTrackRow) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (service.canChangePlaybackRate)
                        _SpeedMenuButton(
                          menuKey: _speedMenuKey,
                          service: service,
                          onMenuOpenChanged: widget.onMenuOpenChanged,
                          onRateSelected: widget.onRateSelected,
                          onInteraction: widget.onInteraction,
                        ),
                      if (service.canSelectAudioTracks) ...[
                        if (service.canChangePlaybackRate)
                          const SizedBox(width: AppSpacing.sm),
                        _AudioTrackMenuButton(
                          menuKey: _audioMenuKey,
                          service: service,
                          onMenuOpenChanged: widget.onMenuOpenChanged,
                          onInteraction: widget.onInteraction,
                          onActionFeedback: widget.onActionFeedback,
                        ),
                      ],
                      if (service.canSelectSubtitleTracks) ...[
                        if (service.canChangePlaybackRate ||
                            service.canSelectAudioTracks)
                          const SizedBox(width: AppSpacing.sm),
                        _SubtitleTrackMenuButton(
                          menuKey: _subtitleMenuKey,
                          service: service,
                          onMenuOpenChanged: widget.onMenuOpenChanged,
                          onInteraction: widget.onInteraction,
                          onActionFeedback: widget.onActionFeedback,
                        ),
                      ],
                    ],
                  ),
                ],
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

class _SpeedMenuButton extends StatelessWidget {
  final GlobalKey<PopupMenuButtonState<double>> menuKey;
  final PlaybackService service;
  final ValueChanged<bool> onMenuOpenChanged;
  final Future<void> Function(double rate) onRateSelected;
  final VoidCallback onInteraction;

  const _SpeedMenuButton({
    required this.menuKey,
    required this.service,
    required this.onMenuOpenChanged,
    required this.onRateSelected,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      key: menuKey,
      tooltip: 'Playback speed',
      onOpened: () => onMenuOpenChanged(true),
      onCanceled: () => onMenuOpenChanged(false),
      onSelected: (rate) {
        onMenuOpenChanged(false);
        onInteraction();
        onRateSelected(rate);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          PlaybackRatePresets.compactLabel(service.playbackRate),
          style: AppTypography.playerTime.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      itemBuilder: (context) {
        return PlaybackRatePresets.supported.map((rate) {
          final selected = (service.playbackRate - rate).abs() < 0.001;
          return PopupMenuItem<double>(
            value: rate,
            child: Row(
              children: [
                if (selected)
                  const Icon(Icons.check, size: AppIcons.sm, color: AppColors.primary)
                else
                  const SizedBox(width: AppIcons.sm),
                const SizedBox(width: AppSpacing.xs),
                Text(PlaybackRatePresets.compactLabel(rate)),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class _AudioTrackMenuButton extends StatelessWidget {
  final GlobalKey<PopupMenuButtonState<String>> menuKey;
  final PlaybackService service;
  final ValueChanged<bool> onMenuOpenChanged;
  final VoidCallback onInteraction;
  final ValueChanged<String> onActionFeedback;

  const _AudioTrackMenuButton({
    required this.menuKey,
    required this.service,
    required this.onMenuOpenChanged,
    required this.onInteraction,
    required this.onActionFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: menuKey,
      tooltip: 'Audio track',
      onOpened: () => onMenuOpenChanged(true),
      onCanceled: () => onMenuOpenChanged(false),
      onSelected: (trackId) async {
        onMenuOpenChanged(false);
        onInteraction();
        final result = await service.selectAudioTrack(trackId);
        if (!result.isSuccess) {
          onActionFeedback('Audio track could not be changed.');
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Audio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTypography.size12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      itemBuilder: (context) {
        final tracks = service.availableAudioTracks;
        return [
          for (var i = 0; i < tracks.length; i++)
            _trackMenuItem(
              value: tracks[i].id,
              label: _audioTrackLabel(tracks[i], i),
              selected: service.selectedAudioTrackId == tracks[i].id,
            ),
        ];
      },
    );
  }
}

class _SubtitleTrackMenuButton extends StatelessWidget {
  final GlobalKey<PopupMenuButtonState<String>> menuKey;
  final PlaybackService service;
  final ValueChanged<bool> onMenuOpenChanged;
  final VoidCallback onInteraction;
  final ValueChanged<String> onActionFeedback;

  const _SubtitleTrackMenuButton({
    required this.menuKey,
    required this.service,
    required this.onMenuOpenChanged,
    required this.onInteraction,
    required this.onActionFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: menuKey,
      tooltip: 'Subtitles',
      onOpened: () => onMenuOpenChanged(true),
      onCanceled: () => onMenuOpenChanged(false),
      onSelected: (value) async {
        onMenuOpenChanged(false);
        onInteraction();
        if (value == _subtitleOffValue) {
          final result = await service.disableSubtitles();
          if (!result.isSuccess) {
            onActionFeedback('Subtitles could not be turned off.');
          }
          return;
        }
        final result = await service.selectSubtitleTrack(value);
        if (!result.isSuccess) {
          onActionFeedback('Subtitle track could not be changed.');
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Subtitles',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTypography.size12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      itemBuilder: (context) {
        final tracks = service.availableSubtitleTracks;
        return [
          _trackMenuItem(
            value: _subtitleOffValue,
            label: 'Off',
            selected: service.selectedSubtitleTrackId == null,
          ),
          for (var i = 0; i < tracks.length; i++)
            _trackMenuItem(
              value: tracks[i].id,
              label: _subtitleTrackLabel(tracks[i], i),
              selected: service.selectedSubtitleTrackId == tracks[i].id,
            ),
        ];
      },
    );
  }
}

PopupMenuItem<String> _trackMenuItem({
  required String value,
  required String label,
  required bool selected,
}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        if (selected)
          const Icon(Icons.check, size: AppIcons.sm, color: AppColors.primary)
        else
          const SizedBox(width: AppIcons.sm),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}

String _audioTrackLabel(PlaybackAudioTrack track, int index) {
  final hasMeta = (track.title?.isNotEmpty ?? false) ||
      (track.language?.isNotEmpty ?? false);
  if (hasMeta) return track.displayLabel;
  return 'Audio ${index + 1}';
}

String _subtitleTrackLabel(PlaybackSubtitleTrack track, int index) {
  final hasMeta = (track.title?.isNotEmpty ?? false) ||
      (track.language?.isNotEmpty ?? false);
  if (hasMeta) return track.displayLabel;
  return 'Subtitle ${index + 1}';
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
  final PlaybackErrorKind? kind;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorView({
    required this.kind,
    required this.onRetry,
    required this.onBack,
  });

  String get _primaryMessage {
    if (kind != null) return PlaybackErrorMessages.forKind(kind!);
    return PlaybackErrorMessages.forKind(PlaybackErrorKind.unknown);
  }

  String? get _providerHint {
    if (kind == PlaybackErrorKind.resolverFailed) {
      return 'Open Provider Status in Settings to review media access configuration.';
    }
    return null;
  }

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
              _primaryMessage,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(height: 1.5),
            ),
            if (_providerHint != null) ...[
              const SizedBox(height: AppSpacing.base),
              Text(
                _providerHint!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: AppSpacing.base),
            Text(
              PlaybackErrorMessages.playbackFailedNote,
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
