import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/artwork/artwork_decode_size.dart';
import '../services/artwork/artwork_service.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork/artwork_image.dart';
import '../widgets/favourite_toggle_button.dart';
import '../widgets/tts_app_bar.dart';
import 'player_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final MediaItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TtsAppBar(
        title: item.title,
        extraActions: [
          FavouriteItemToggle(itemId: item.id),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PosterArea(item: item),
            _MetadataPanel(item: item),
            _PlaySection(item: item),
            _FileInfo(item: item),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Poster — 16:9, placeholder on null or load failure
// ---------------------------------------------------------------------------

class _PosterArea extends StatelessWidget {
  final MediaItem item;

  const _PosterArea({required this.item});

  @override
  Widget build(BuildContext context) {
    final candidate = context.read<ArtworkService>().forMediaItem(item);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArtworkImage(
            candidate: candidate,
            iconSize: 64,
            logicalDecodeSize: ArtworkSurfaceSizes.itemDetailPoster(
              MediaQuery.sizeOf(context).width,
            ),
          ),
          if (item.status != MediaItemStatus.available)
            Positioned(
              top: 12,
              right: 12,
              child: _StatusBadge(status: item.status),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MediaItemStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MediaItemStatus.missing     => ('Missing',     AppColors.statusMissing),
      MediaItemStatus.unavailable => ('Unavailable', AppColors.statusUnavailable),
      MediaItemStatus.restricted  => ('Restricted',  AppColors.statusRestricted),
      MediaItemStatus.unsupported => ('Unsupported', AppColors.statusDefault),
      MediaItemStatus.skipped     => ('Skipped',     AppColors.statusDefault),
      _                           => ('Unknown',     AppColors.statusDefault),
    };

    return Container(
      padding: AppSpacing.chip,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTypography.size11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata — title always shown; year, duration, extension shown if present
// ---------------------------------------------------------------------------

class _MetadataPanel extends StatelessWidget {
  final MediaItem item;

  const _MetadataPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (item.year != null) '${item.year}',
      if (item.formattedDuration != null) item.formattedDuration!,
      item.extension.toUpperCase(),
    ];

    return Padding(
      padding: AppSpacing.metadataSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.iconGap),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.labelGap,
              children: chips.map((l) => _Chip(label: l)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.chip,
      decoration: const BoxDecoration(
        color: AppColors.chip,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textHigh,
          fontSize: AppTypography.size12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Play section
// ---------------------------------------------------------------------------

class _PlaySection extends StatelessWidget {
  final MediaItem item;

  const _PlaySection({required this.item});

  @override
  Widget build(BuildContext context) {
    if (!item.status.isPlayable) return _buildDisabled(context);

    return FutureBuilder<ResumeInfo?>(
      future: context.read<PlaybackService>().resumeInfoFor(item.id),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final resume = (info != null && info.shouldOffer) ? info : null;
        return _buildPlayable(context, resume);
      },
    );
  }

  Widget _buildPlayable(BuildContext context, ResumeInfo? resume) {
    return Padding(
      padding: AppSpacing.playSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                shape: AppRadius.buttonShape,
              ),
              icon: Icon(
                resume != null ? Icons.play_circle_outline : Icons.play_arrow,
                size: AppIcons.playButton,
              ),
              label: Text(
                resume != null
                    ? 'Resume from ${resume.formattedPosition}'
                    : 'Play',
                style: const TextStyle(
                  fontSize: AppTypography.size16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _openPlayer(context, startPosition: null),
            ),
          ),

          if (resume != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => _openPlayer(context, startPosition: Duration.zero),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textLow,
                  padding: AppSpacing.buttonAction,
                ),
                child: const Text(
                  'Start from beginning',
                  style: TextStyle(fontSize: AppTypography.size13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPlayer(BuildContext context, {Duration? startPosition}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(item: item, startPosition: startPosition),
      ),
    );
  }

  Widget _buildDisabled(BuildContext context) {
    return Padding(
      padding: AppSpacing.playSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white30,
                shape: AppRadius.buttonShape,
              ),
              icon: const Icon(Icons.block, size: AppIcons.standard),
              label: Text(
                _buttonLabel(item.status),
                style: const TextStyle(
                    fontSize: AppTypography.size16, fontWeight: FontWeight.w700),
              ),
              onPressed: null,
            ),
          ),
          const SizedBox(height: AppSpacing.iconGap),
          Text(
            _reasonMessage(item.status),
            style: AppTypography.labelMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _buttonLabel(MediaItemStatus status) => switch (status) {
        MediaItemStatus.missing     => 'File Missing',
        MediaItemStatus.unavailable => 'Unavailable',
        MediaItemStatus.restricted  => 'Restricted',
        MediaItemStatus.unsupported => 'Unsupported',
        MediaItemStatus.skipped     => 'Skipped',
        _                           => 'Not Available',
      };

  String _reasonMessage(MediaItemStatus status) => switch (status) {
        MediaItemStatus.missing =>
          'This file was not found during the last scan. Rescan to update the catalogue.',
        MediaItemStatus.unavailable =>
          'This file could not be read. Check NAS access and permissions.',
        MediaItemStatus.restricted  => 'Access to this file is restricted.',
        MediaItemStatus.unsupported => 'This file type is not supported by the player.',
        MediaItemStatus.skipped     => 'This file was excluded from the last scan.',
        _                           => 'This item cannot be played.',
      };
}

// ---------------------------------------------------------------------------
// File info — path and size at the bottom
// ---------------------------------------------------------------------------

class _FileInfo extends StatelessWidget {
  final MediaItem item;

  const _FileInfo({required this.item});

  String? get _formattedSize {
    final b = item.sizeBytes;
    if (b == null) return null;
    if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(1)} GB';
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(0)} MB';
    return '$b B';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.fileInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.filePath, style: AppTypography.monoFaint),
          if (_formattedSize != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_formattedSize!, style: AppTypography.monoFaint),
          ],
        ],
      ),
    );
  }
}
