import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import '../../../models/media_item.dart';

import '../../../services/catalog_service.dart';

import '../../../theme/app_theme.dart';

import '../../../widgets/empty_state.dart';

import '../../../widgets/tts_app_bar.dart';

import '../music_library_service.dart';

import '../music_navigation.dart';

import '../widgets/music_artwork_thumbnail.dart';



/// Track metadata with a play action (M5.3 Step 1).

class MusicTrackDetailScreen extends StatelessWidget {

  final String trackId;



  const MusicTrackDetailScreen({super.key, required this.trackId});



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: const TtsAppBar(title: 'Track'),

      body: Consumer<CatalogService>(

        builder: (context, catalogService, _) {

          final catalog = catalogService.catalog;

          if (catalog == null) {

            return const EmptyState(

              icon: Icons.music_note_outlined,

              title: 'Track unavailable.',

            );

          }



          final track = context

              .read<MusicLibraryService>()

              .projectionFor(catalog)

              .findTrackById(trackId);



          if (track == null) {

            return EmptyState(

              icon: Icons.music_note_outlined,

              title: 'Track no longer in catalogue.',

              actionLabel: 'Back',

              onAction: () => Navigator.maybePop(context),

            );

          }



          return Scrollbar(

            thumbVisibility: true,

            child: ListView(

              key: Key('music_track_detail_$trackId'),

              padding: const EdgeInsets.all(AppSpacing.lg),

              children: [

                Center(

                  child: MusicArtworkThumbnail(item: track, size: 160),

                ),

                const SizedBox(height: AppSpacing.base),

                Text(track.title, style: AppTypography.sectionTitle),

                const SizedBox(height: AppSpacing.section),

                ..._metadataRows(track),

                const SizedBox(height: AppSpacing.section),

                if (track.status.isPlayable)

                  Semantics(

                    button: true,

                    label: 'Play ${track.title}',

                    child: FilledButton.icon(

                      key: Key('music_track_play_${track.id}'),

                      onPressed: () => openMusicPlayerScreen(context, track: track),

                      icon: const Icon(Icons.play_arrow),

                      label: const Text('Play'),

                      style: FilledButton.styleFrom(

                        backgroundColor: AppColors.primary,

                        minimumSize: const Size.fromHeight(48),

                      ),

                    ),

                  ),

              ],

            ),

          );

        },

      ),

    );

  }



  static List<Widget> _metadataRows(MediaItem track) {

    String label(String? value, String fallback) {

      final trimmed = value?.trim();

      return (trimmed == null || trimmed.isEmpty) ? fallback : trimmed;

    }



    final rows = <(String, String)>[

      ('Artist', label(track.artist ?? track.albumArtist, 'Unknown Artist')),

      ('Album', label(track.album, 'Unknown Album')),

      if (track.trackNumber != null) ('Track', '${track.trackNumber}'),

      if (track.discNumber != null) ('Disc', '${track.discNumber}'),

      if (track.year != null) ('Year', '${track.year}'),

      if (track.genre != null && track.genre!.trim().isNotEmpty)

        ('Genre', track.genre!.trim()),

      if (track.formattedDuration != null)

        ('Duration', track.formattedDuration!),

    ];



    return rows

        .map(

          (row) => Padding(

            padding: const EdgeInsets.only(bottom: AppSpacing.sm),

            child: Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                SizedBox(

                  width: 88,

                  child: Text(row.$1, style: AppTypography.caption),

                ),

                Expanded(

                  child: Text(row.$2, style: AppTypography.body),

                ),

              ],

            ),

          ),

        )

        .toList();

  }

}

