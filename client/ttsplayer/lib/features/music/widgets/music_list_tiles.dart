import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../models/music_album.dart';
import '../models/music_artist.dart';
import 'music_artwork_thumbnail.dart';

class MusicArtistListTile extends StatelessWidget {
  final MusicArtist artist;
  final VoidCallback onTap;

  const MusicArtistListTile({
    super.key,
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('music_artist_${artist.groupKey}'),
      leading: MusicArtworkThumbnail(item: artist.representativeTrack),
      title: Text(artist.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${artist.albumCount} albums · ${artist.trackCount} tracks',
        style: AppTypography.cardSubtitle,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class MusicAlbumListTile extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const MusicAlbumListTile({
    super.key,
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      album.displayArtist,
      if (album.year != null) '${album.year}',
      '${album.trackCount} tracks',
    ].join(' · ');

    return ListTile(
      key: Key('music_album_${album.groupKey}'),
      leading: MusicArtworkThumbnail(item: album.representativeTrack),
      title: Text(album.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class MusicTrackListTile extends StatelessWidget {
  final MediaItem track;
  final VoidCallback? onTap;

  const MusicTrackListTile({
    super.key,
    required this.track,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final artist = track.artist ?? track.albumArtist ?? 'Unknown Artist';
    final album = track.album ?? 'Unknown Album';
    final discTrack = _discTrackLabel(track);
    final duration = track.formattedDuration;

    final subtitleParts = <String>[
      artist,
      album,
      if (discTrack.isNotEmpty) discTrack,
      if (duration != null) duration,
    ];

    return ListTile(
      key: Key('music_track_${track.id}'),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.cardSubtitle,
      ),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  static String _discTrackLabel(MediaItem track) {
    final parts = <String>[];
    if (track.discNumber != null && track.discNumber! > 1) {
      parts.add('Disc ${track.discNumber}');
    }
    if (track.trackNumber != null) {
      parts.add('Track ${track.trackNumber}');
    }
    return parts.join(' ');
  }
}
