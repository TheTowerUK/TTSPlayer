import 'package:flutter/material.dart';

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
