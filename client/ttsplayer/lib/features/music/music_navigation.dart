import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import 'models/music_album.dart';
import 'models/music_artist.dart';
import 'music_queue_seeding.dart';
import 'presentation/music_player_screen.dart';
import 'services/music_playback_queue_controller.dart';
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

void _popExistingMusicPlayerRoutes(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.popUntil((route) {
    final name = route.settings.name;
    return name == null || !name.startsWith('music:player:');
  });
}

void _pushMusicPlayerScreen(BuildContext context, {required String trackId}) {
  _popExistingMusicPlayerRoutes(context);
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'music:player:$trackId'),
      builder: (_) => const MusicPlayerScreen(),
    ),
  );
}

void _showNoPlayableTracksMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No playable tracks are available.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Seeds a one-track queue (ungrouped contexts: search, global tracks, track detail).
void openMusicPlayerScreen(
  BuildContext context, {
  required MediaItem track,
}) {
  if (!track.isAudio || !track.status.isPlayable) return;

  context.read<MusicPlaybackQueueController>().seedSingleTrack(track);
  _pushMusicPlayerScreen(context, trackId: track.id);
}

/// Seeds the full album queue from the first playable track.
bool openMusicPlayerFromAlbum(
  BuildContext context, {
  required MusicAlbum album,
}) {
  final controller = context.read<MusicPlaybackQueueController>();
  if (!controller.seedAlbumQueue(album)) {
    _showNoPlayableTracksMessage(context);
    return false;
  }

  final current = controller.currentTrack;
  if (current == null) return false;

  _pushMusicPlayerScreen(context, trackId: current.id);
  return true;
}

/// Seeds the full album queue starting at [track].
bool openMusicPlayerFromAlbumTrack(
  BuildContext context, {
  required MusicAlbum album,
  required MediaItem track,
}) {
  if (!track.isAudio || !track.status.isPlayable) return false;

  final sourceIndex = MusicQueueSeeding.indexInOrderedList(album.tracks, track);
  final controller = context.read<MusicPlaybackQueueController>();
  if (!controller.seedAlbumQueue(album, sourceIndex: sourceIndex)) {
    _showNoPlayableTracksMessage(context);
    return false;
  }

  _pushMusicPlayerScreen(context, trackId: track.id);
  return true;
}

/// Seeds the full artist queue from the first playable track.
bool openMusicPlayerFromArtist(
  BuildContext context, {
  required MusicArtist artist,
}) {
  final controller = context.read<MusicPlaybackQueueController>();
  if (!controller.seedArtistQueue(artist)) {
    _showNoPlayableTracksMessage(context);
    return false;
  }

  final current = controller.currentTrack;
  if (current == null) return false;

  _pushMusicPlayerScreen(context, trackId: current.id);
  return true;
}

/// Seeds the full artist queue starting at [track].
bool openMusicPlayerFromArtistTrack(
  BuildContext context, {
  required MusicArtist artist,
  required MediaItem track,
}) {
  if (!track.isAudio || !track.status.isPlayable) return false;

  final sourceIndex =
      MusicQueueSeeding.indexInOrderedList(artist.tracksInAlbumOrder, track);
  final controller = context.read<MusicPlaybackQueueController>();
  if (!controller.seedArtistQueue(artist, sourceIndex: sourceIndex)) {
    _showNoPlayableTracksMessage(context);
    return false;
  }

  _pushMusicPlayerScreen(context, trackId: track.id);
  return true;
}
