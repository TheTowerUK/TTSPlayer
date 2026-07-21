import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/catalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_card.dart';
import '../../../widgets/tts_app_bar.dart';
import '../music_library_service.dart';
import '../music_listening_presentation.dart';
import '../music_navigation.dart';
import '../models/music_listening_policy.dart';
import '../services/music_listening_repository.dart';
import '../widgets/music_artwork_thumbnail.dart';

/// Full Recently Played list for music listening history (M5.4).
class MusicRecentlyPlayedScreen extends StatelessWidget {
  const MusicRecentlyPlayedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TtsAppBar(title: 'Recently Played'),
      body: Consumer2<CatalogService, MusicListeningRepository>(
        builder: (context, catalogService, listeningRepository, _) {
          if (!listeningRepository.isLoaded) {
            return const LoadingCard(message: 'Loading listening history…');
          }

          final catalog = catalogService.catalog;
          if (catalog == null) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No catalogue loaded.',
              subtitle: 'Load a catalogue to browse recently played tracks.',
            );
          }

          final projection =
              context.read<MusicLibraryService>().projectionFor(catalog);
          final records = listeningRepository.recentlyPlayed(
            limit: MusicListeningPolicy.defaultRecentlyPlayedQueryCap,
          );
          final entries = resolveListeningEntries(records, projection);

          if (entries.isEmpty) {
            return const EmptyState(
              key: Key('music_recently_played_empty'),
              icon: Icons.history,
              title: 'Nothing played yet.',
              subtitle: 'Tracks you listen to will appear here.',
            );
          }

          return ListView.separated(
            key: const Key('music_recently_played_list'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _RecentlyPlayedTile(entry: entries[index]);
            },
          );
        },
      ),
    );
  }
}

class _RecentlyPlayedTile extends StatelessWidget {
  const _RecentlyPlayedTile({required this.entry});

  final MusicListeningListEntry entry;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final playable = entry.isPlayable;
    final progress = listeningProgressFraction(record);
    final actionLabel = record.completed ? 'Replay' : 'Play';

    return Semantics(
      button: playable,
      enabled: playable,
      label: '${entry.displayTitle}, ${entry.displayArtist}',
      child: ListTile(
        key: Key('music_recently_played_tile_${record.trackId}'),
        enabled: playable,
        leading: MusicArtworkThumbnail(
          item: entry.mediaItem,
          size: 56,
        ),
        title: Text(
          entry.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.displayArtist} · ${entry.displayAlbum}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.completed ? 'Completed' : listeningProgressLabel(record),
              style: AppTypography.cardSubtitle,
            ),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: AppColors.progressTrack,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
        trailing: playable
            ? IconButton(
                icon: Icon(
                  record.completed
                      ? Icons.replay_outlined
                      : Icons.play_arrow_outlined,
                ),
                tooltip: actionLabel,
                onPressed: () => openMusicPlayerFromListeningRecord(
                  context,
                  record: record,
                ),
              )
            : null,
        onTap: playable
            ? () => openMusicPlayerFromListeningRecord(
                  context,
                  record: record,
                )
            : null,
      ),
    );
  }
}
