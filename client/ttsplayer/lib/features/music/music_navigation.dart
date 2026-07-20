import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import 'services/music_playback_queue_controller.dart';
import 'presentation/music_player_screen.dart';
import 'screens/music_album_detail_screen.dart';
import 'screens/music_albums_screen.dart';
import 'screens/music_artist_detail_screen.dart';
import 'screens/music_artists_screen.dart';
import 'screens/music_screen.dart';
import 'screens/music_track_detail_screen.dart';
import 'screens/music_tracks_screen.dart';

void openMusicScreen(BuildContext context) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'music'),
      builder: (_) => const MusicScreen(),
    ),
  );
}

void openMusicArtistsScreen(BuildContext context) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'music:artists'),
      builder: (_) => const MusicArtistsScreen(),
    ),
  );
}

void openMusicAlbumsScreen(BuildContext context) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'music:albums'),
      builder: (_) => const MusicAlbumsScreen(),
    ),
  );
}

void openMusicTracksScreen(BuildContext context) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'music:tracks'),
      builder: (_) => const MusicTracksScreen(),
    ),
  );
}

void openMusicArtistDetailScreen(
  BuildContext context, {
  required String artistGroupKey,
}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'music:artist:$artistGroupKey'),
      builder: (_) => MusicArtistDetailScreen(artistGroupKey: artistGroupKey),
    ),
  );
}

void openMusicAlbumDetailScreen(
  BuildContext context, {
  required String albumGroupKey,
}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'music:album:$albumGroupKey'),
      builder: (_) => MusicAlbumDetailScreen(albumGroupKey: albumGroupKey),
    ),
  );
}

void openMusicTrackDetailScreen(
  BuildContext context, {
  required String trackId,
}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'music:track:$trackId'),
      builder: (_) => MusicTrackDetailScreen(trackId: trackId),
    ),
  );
}

void openMusicPlayerScreen(
  BuildContext context, {
  required MediaItem track,
}) {
  if (!track.isAudio || !track.status.isPlayable) return;

  context.read<MusicPlaybackQueueController>().seedSingleTrack(track);

  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'music:player:${track.id}'),
      builder: (_) => const MusicPlayerScreen(),
    ),
  );
}
