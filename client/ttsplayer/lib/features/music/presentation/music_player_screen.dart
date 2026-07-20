import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../models/playback/playback_error_kind.dart';
import '../../../services/playback/playback_error_messages.dart';
import '../../../services/playback_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tts_app_bar.dart';
import '../services/music_playback_queue_controller.dart';
import '../widgets/music_artwork_thumbnail.dart';

/// Dedicated music player (M5.3) — shared [PlaybackService] + queue coordinator.
class MusicPlayerScreen extends StatefulWidget {
  /// Where playback begins:
  /// - null           → start from the beginning
  /// - Duration.zero  → start from the beginning
  /// - any other      → seek to that exact position
  final Duration? startPosition;

  /// When false, [MusicPlaybackQueueController.playCurrent] is not invoked
  /// automatically (tests).
  @visibleForTesting
  final bool autoPlay;

  const MusicPlayerScreen({
    super.key,
    this.startPosition,
    this.autoPlay = true,
  });

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  late final PlaybackService _playback;
  late final MusicPlaybackQueueController _queueController;

  @override
  void initState() {
    super.initState();
    _playback = context.read<PlaybackService>();
    _queueController = context.read<MusicPlaybackQueueController>();
    _queueController.onPlayerRouteOpened();
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _queueController.playCurrent(startPosition: widget.startPosition);
      });
    }
  }

  @override
  void dispose() {
    final controller = _queueController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(controller.onPlayerRouteClosed());
    });
    super.dispose();
  }

  Future<void> _goBack() async {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicPlaybackQueueController>(
      builder: (context, queueController, _) {
        final track = queueController.currentTrack;
        if (track == null) {
          return Scaffold(
            appBar: TtsAppBar(title: 'Music', showHome: false),
            body: const Center(child: Text('No track in queue.')),
          );
        }

        return Scaffold(
          key: const Key('music_player_screen'),
          appBar: TtsAppBar(title: track.title, showHome: false),
          body: Consumer<PlaybackService>(
            builder: (context, service, _) {
              if (service.errorMessage != null) {
                return _MusicPlayerErrorView(
                  kind: service.playbackErrorKind,
                  onRetry: () => queueController.retryCurrent(
                    startPosition: widget.startPosition,
                  ),
                  onBack: _goBack,
                );
              }

              if (service.isInitializing || !service.isReady) {
                return _MusicPlayerLoadingView(onGoBack: _goBack);
              }

              if (service.isCompleted) {
                return _MusicPlayerCompletedView(
                  item: track,
                  onReplay: () => queueController.replayCurrent(),
                  onBack: _goBack,
                );
              }

              return _MusicPlayerReadyView(
                item: track,
                service: service,
                queueController: queueController,
              );
            },
          ),
        );
      },
    );
  }
}

class _MusicPlayerReadyView extends StatelessWidget {
  final MediaItem item;
  final PlaybackService service;
  final MusicPlaybackQueueController queueController;

  const _MusicPlayerReadyView({
    required this.item,
    required this.service,
    required this.queueController,
  });

  @override
  Widget build(BuildContext context) {
    final position = service.position;
    final duration = service.duration;
    final remaining = duration - position;
    final seekEnabled = duration > Duration.zero;
    final queue = queueController.queue;

    final artist = _label(item.artist ?? item.albumArtist, 'Unknown Artist');
    final album = _label(item.album, 'Unknown Album');
    final yearGenre = _yearGenreLine(item);

    return SafeArea(
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          key: Key('music_player_ready_${item.id}'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (queue.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '${queue.currentIndex + 1} of ${queue.length}',
                  key: const Key('music_player_queue_position'),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption,
                ),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth;
                      return MusicArtworkThumbnail(item: item, size: side);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              item.title,
              key: Key('music_player_title_${item.id}'),
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              artist,
              key: Key('music_player_artist_${item.id}'),
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              album,
              key: Key('music_player_album_${item.id}'),
              style: AppTypography.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            if (yearGenre != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                yearGenre,
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            if (service.isBuffering)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Buffering…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: AppTypography.size12,
                  ),
                ),
              ),
            _MusicPlayerProgressBar(
              position: position,
              duration: duration,
              onSeek: service.seekTo,
            ),
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  key: const Key('music_player_elapsed'),
                  style: AppTypography.playerTime,
                ),
                const Spacer(),
                Text(
                  seekEnabled
                      ? '-${_formatDuration(remaining.isNegative ? Duration.zero : remaining)}'
                      : _formatDuration(duration),
                  key: const Key('music_player_remaining'),
                  style: AppTypography.playerTime,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  button: true,
                  enabled: queueController.canGoPrevious,
                  label: 'Previous track',
                  child: IconButton(
                    key: const Key('music_player_previous'),
                    icon: const Icon(Icons.skip_previous),
                    color: queueController.canGoPrevious
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    onPressed:
                        queueController.canGoPrevious ? queueController.previous : null,
                  ),
                ),
                Semantics(
                  button: true,
                  label: service.isPlaying ? 'Pause' : 'Play',
                  child: IconButton(
                    key: const Key('music_player_play_pause'),
                    iconSize: AppIcons.hero,
                    onPressed: service.togglePlayPause,
                    icon: Icon(
                      service.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  enabled: queueController.hasNext,
                  label: 'Next track',
                  child: IconButton(
                    key: const Key('music_player_next'),
                    icon: const Icon(Icons.skip_next),
                    color: queueController.hasNext
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    onPressed: queueController.hasNext ? queueController.next : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String? value, String fallback) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? fallback : trimmed;
  }

  static String? _yearGenreLine(MediaItem item) {
    final parts = <String>[];
    if (item.year != null) parts.add('${item.year}');
    if (item.genre != null && item.genre!.trim().isNotEmpty) {
      parts.add(item.genre!.trim());
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _MusicPlayerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _MusicPlayerProgressBar({
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
          key: const Key('music_player_seek'),
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

class _MusicPlayerLoadingView extends StatelessWidget {
  final VoidCallback onGoBack;

  const _MusicPlayerLoadingView({required this.onGoBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('music_player_loading'),
      child: Padding(
        padding: AppSpacing.errorView,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.textMedium),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Preparing track…',
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

class _MusicPlayerErrorView extends StatelessWidget {
  final PlaybackErrorKind? kind;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _MusicPlayerErrorView({
    required this.kind,
    required this.onRetry,
    required this.onBack,
  });

  String get _primaryMessage {
    if (kind != null) return PlaybackErrorMessages.forKind(kind!);
    return PlaybackErrorMessages.forKind(PlaybackErrorKind.unknown);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('music_player_error'),
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
                  key: const Key('music_player_retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: AppIcons.md),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicPlayerCompletedView extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onReplay;
  final VoidCallback onBack;

  const _MusicPlayerCompletedView({
    required this.item,
    required this.onReplay,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('music_player_completed'),
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
                  key: const Key('music_player_replay'),
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay, size: AppIcons.md),
                  label: const Text('Play Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
