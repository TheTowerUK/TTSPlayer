@Tags(['phase53-runtime'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/presentation/music_player_screen.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/services/music_playback_queue_controller.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/screens/player_screen.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:video_player/video_player.dart';

import 'support/audio_gate_fixtures.dart';
import 'support/music_playback_test_harness.dart';

const _runtimeArtist = 'Runtime Artist';
const _runtimeAlbum = 'Runtime Album';
const _runtimeAlbumB = 'Runtime Album B';
const _runtimeArtistFolder = r'C:\Runtime\Music\Runtime Artist';
const _runtimeAlbumFolder = r'C:\Runtime\Music\Runtime Artist\Runtime Album';
const _runtimeAlbumBFolder =
    r'C:\Runtime\Music\Runtime Artist\Runtime Album B';

/// Windows music queue validation (M5.3 Step 2–3).
///
/// Note: `[PlaybackService] Platform: android` in logs is expected under
/// `flutter test` — diagnostics use [defaultTargetPlatform], not the host OS.
/// Native MediaKit/libmpv still runs on Windows when `PHASE_53_RUNTIME=1`.
///
/// ```powershell
/// cd client\ttsplayer
/// flutter build windows
/// $env:PHASE_53_RUNTIME='1'
/// flutter test test/phase_53_music_player_windows_runtime_test.dart --tags phase53-runtime
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_53_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_53_RUNTIME=1 to run Phase 5.3 music player runtime',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.3 music player runtime is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final libmpv = _resolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  group('Phase 5.3 Step 2 — music queue runtime', () {
    GeneratedAudioFixture? wav1;
    GeneratedAudioFixture? wav2;
    GeneratedAudioFixture? wav3;
    PlaybackService? service;
    MusicPlaybackQueueController? queue;
    List<MediaItem>? tracks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wav1 = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'queue_track_1',
      );
      wav2 = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'queue_track_2',
      );
      wav3 = await writeMonoWavFixture(
        duration: const Duration(seconds: 2),
        basename: 'queue_track_3',
      );
      tracks = [
        MediaItem(
          id: 'runtime-track-1',
          title: 'Runtime Track One',
          filePath: wav1!.path,
          mediaKindRaw: 'audio',
          artist: 'Runtime Artist',
          album: 'Runtime Album',
        ),
        MediaItem(
          id: 'runtime-track-2',
          title: 'Runtime Track Two',
          filePath: wav2!.path,
          mediaKindRaw: 'audio',
          artist: 'Runtime Artist',
          album: 'Runtime Album',
        ),
        MediaItem(
          id: 'runtime-track-3',
          title: 'Runtime Track Three',
          filePath: wav3!.path,
          mediaKindRaw: 'audio',
          artist: 'Runtime Artist',
          album: 'Runtime Album',
        ),
      ];
      service = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        ),
      );
      queue = MusicPlaybackQueueController(playbackService: service!);
    });

    tearDown(() async {
      await queue?.onPlayerRouteClosed();
      await service?.stop();
    });

    testWidgets('three-track queue transport and lifecycle', (tester) async {
      final playback = service!;
      final queueController = queue!;
      final queueTracks = tracks!;

      queueController.replaceQueue(queueTracks);

      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(
            playback,
            queueController: queueController,
          ),
          child: const MaterialApp(home: MusicPlayerScreen()),
        ),
      );
      await tester.pump();

      queueController.onPlayerRouteOpened();
      await queueController.playCurrent();
      await _waitFor(() => playback.isReady);
      await tester.pumpAndSettle();

      expect(find.text('Runtime Track One'), findsWidgets);
      expect(find.text('1 of 3'), findsOneWidget);

      final next = find.byKey(const Key('music_player_next'));
      await tester.scrollUntilVisible(next, 100);
      await tester.tap(next);
      await _waitFor(() => playback.currentItem?.id == 'runtime-track-2');
      await tester.pumpAndSettle();

      expect(find.text('Runtime Track Two'), findsWidgets);
      expect(find.text('2 of 3'), findsOneWidget);

      await playback.seekToPosition(const Duration(milliseconds: 500));
      await _waitFor(
        () => playback.position >= const Duration(milliseconds: 400),
      );

      final previous = find.byKey(const Key('music_player_previous'));
      await tester.scrollUntilVisible(previous, 100);
      await tester.tap(previous);
      await _waitFor(() => playback.currentItem?.id == 'runtime-track-1');
      await tester.pumpAndSettle();
      expect(find.text('Runtime Track One'), findsWidgets);

      await queueController.next();
      await queueController.next();
      await _waitFor(() => playback.currentItem?.id == 'runtime-track-3');
      await tester.pumpAndSettle();
      expect(find.text('Runtime Track Three'), findsWidgets);

      await _waitFor(
        () => playback.isCompleted,
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('music_player_completed')), findsOneWidget);
      expect(queueController.currentTrack?.id, 'runtime-track-3');

      final prefs = await SharedPreferences.getInstance();
      for (final track in queueTracks) {
        expect(prefs.getInt('position_${track.id}'), isNull);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(playback.currentItem, isNull);
      expect(queueController.isEmpty, isTrue);

      final video = MediaItem(
        id: 'runtime-video',
        title: 'Runtime Video',
        filePath: wav1!.path,
        mediaKindRaw: 'video',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(
            playback,
            queueController: queueController,
          ),
          child: MaterialApp(home: PlayerScreen(item: video, autoPlay: false)),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(queueController.isEmpty, isTrue);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('one-item queue disables next and previous', (tester) async {
      final playback = service!;
      final queueController = queue!;

      queueController.seedSingleTrack(tracks!.first);
      queueController.onPlayerRouteOpened();
      await queueController.playCurrent();
      await _waitFor(() => playback.isReady);

      await tester.pumpWidget(
        MultiProvider(
          providers: musicPlayerTestProviders(
            playback,
            queueController: queueController,
          ),
          child: const MaterialApp(home: MusicPlayerScreen(autoPlay: false)),
        ),
      );
      await tester.pumpAndSettle();

      final previous = tester.widget<IconButton>(
        find.byKey(const Key('music_player_previous')),
      );
      final next = tester.widget<IconButton>(
        find.byKey(const Key('music_player_next')),
      );
      expect(previous.onPressed, isNull);
      expect(next.onPressed, isNull);
      expect(find.text('1 of 3'), findsNothing);

      expect(find.byType(Video), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byIcon(Icons.shuffle), findsNothing);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Phase 5.3 Step 3 — album and artist queue seeding', () {
    testWidgets('album and artist UI seeding with transport', (tester) async {
      PlaybackService? service;
      MusicPlaybackQueueController? queue;

      try {
        SharedPreferences.setMockInitialValues({});

        final albumWav1 = await writeMonoWavFixture(
          duration: const Duration(seconds: 2),
          basename: 'album_track_1',
        );
        final albumWav2 = await writeMonoWavFixture(
          duration: const Duration(seconds: 2),
          basename: 'album_track_2',
        );
        final albumWav3 = await writeMonoWavFixture(
          duration: const Duration(seconds: 2),
          basename: 'album_track_3',
        );
        final artistWav1 = await writeMonoWavFixture(
          duration: const Duration(seconds: 2),
          basename: 'artist_b_track_1',
        );
        final artistWav2 = await writeMonoWavFixture(
          duration: const Duration(seconds: 2),
          basename: 'artist_b_track_2',
        );

        MediaItem scratchTrack({
          required String album,
          required String folder,
        }) {
          return MediaItem(
            id: 'scratch',
            title: 'scratch',
            filePath: '$folder\\01.wav',
            mediaKindRaw: 'audio',
            artist: _runtimeArtist,
            album: album,
            albumArtist: _runtimeArtist,
          );
        }

        // Production grouping keys — assigned before catalog JSON is built.
        final derivedArtistKey = MusicLibraryProjection.artistGroupKeyForItem(
          scratchTrack(album: _runtimeAlbum, folder: _runtimeAlbumFolder),
        );
        final derivedAlbumAKey = MusicLibraryProjection.albumGroupKeyForItem(
          scratchTrack(album: _runtimeAlbum, folder: _runtimeAlbumFolder),
        );
        final derivedAlbumBKey = MusicLibraryProjection.albumGroupKeyForItem(
          scratchTrack(album: _runtimeAlbumB, folder: _runtimeAlbumBFolder),
        );

        final catalog = Catalog.fromJson({
          'generated_at': '2026-07-20T12:00:00+00:00',
          'total_items': 5,
          'catalogue': {'id': 'PHASE53-SEED', 'catalogue_version': 3},
          'folders': [
            {
              'id': 'music',
              'name': 'Music',
              'path': r'C:\Runtime\Music',
              'item_count': 5,
              'items': [],
              'subfolders': [
                {
                  'id': 'artist',
                  'name': _runtimeArtist,
                  'path': _runtimeArtistFolder,
                  'item_count': 5,
                  'items': [],
                  'subfolders': [
                    {
                      'id': 'album-a',
                      'name': _runtimeAlbum,
                      'path': _runtimeAlbumFolder,
                      'item_count': 3,
                      'items': [
                        {
                          'id': 'album-t1',
                          'title': 'Album Track One',
                          'file_path': albumWav1.path,
                          'status': 'available',
                          'media_kind': 'audio',
                          'artist': _runtimeArtist,
                          'album': _runtimeAlbum,
                          'album_artist': _runtimeArtist,
                          'track_number': 1,
                          'disc_number': 1,
                          'year': 2020,
                          'artist_group_key': derivedArtistKey,
                          'album_group_key': derivedAlbumAKey,
                        },
                        {
                          'id': 'album-t2',
                          'title': 'Album Track Two',
                          'file_path': albumWav2.path,
                          'status': 'available',
                          'media_kind': 'audio',
                          'artist': _runtimeArtist,
                          'album': _runtimeAlbum,
                          'album_artist': _runtimeArtist,
                          'track_number': 2,
                          'disc_number': 1,
                          'year': 2020,
                          'artist_group_key': derivedArtistKey,
                          'album_group_key': derivedAlbumAKey,
                        },
                        {
                          'id': 'album-t3',
                          'title': 'Album Track Three',
                          'file_path': albumWav3.path,
                          'status': 'available',
                          'media_kind': 'audio',
                          'artist': _runtimeArtist,
                          'album': _runtimeAlbum,
                          'album_artist': _runtimeArtist,
                          'track_number': 3,
                          'disc_number': 1,
                          'year': 2020,
                          'artist_group_key': derivedArtistKey,
                          'album_group_key': derivedAlbumAKey,
                        },
                      ],
                      'subfolders': [],
                    },
                    {
                      'id': 'album-b',
                      'name': _runtimeAlbumB,
                      'path': _runtimeAlbumBFolder,
                      'item_count': 2,
                      'items': [
                        {
                          'id': 'artist-b1',
                          'title': 'Artist B Track One',
                          'file_path': artistWav1.path,
                          'status': 'available',
                          'media_kind': 'audio',
                          'artist': _runtimeArtist,
                          'album': _runtimeAlbumB,
                          'album_artist': _runtimeArtist,
                          'track_number': 1,
                          'year': 2021,
                          'artist_group_key': derivedArtistKey,
                          'album_group_key': derivedAlbumBKey,
                        },
                        {
                          'id': 'artist-b2',
                          'title': 'Artist B Track Two',
                          'file_path': artistWav2.path,
                          'status': 'available',
                          'media_kind': 'audio',
                          'artist': _runtimeArtist,
                          'album': _runtimeAlbumB,
                          'album_artist': _runtimeArtist,
                          'track_number': 2,
                          'year': 2021,
                          'artist_group_key': derivedArtistKey,
                          'album_group_key': derivedAlbumBKey,
                        },
                      ],
                      'subfolders': [],
                    },
                  ],
                },
              ],
            },
          ],
        });

        final projection = MusicLibraryService().projectionFor(catalog);

        final artistGroup = projection.artists.firstWhere(
          (artist) => artist.displayName == _runtimeArtist,
          orElse: () => throw StateError(
            'Expected artist group "$_runtimeArtist" was not created.',
          ),
        );
        final albumGroup = projection.albums.firstWhere(
          (album) => album.displayTitle == _runtimeAlbum,
          orElse: () => throw StateError(
            'Expected album group "$_runtimeAlbum" was not created.',
          ),
        );

        final artistGroupKey = artistGroup.groupKey;
        final albumGroupKey = albumGroup.groupKey;
        expect(artistGroupKey, derivedArtistKey);
        expect(albumGroupKey, derivedAlbumAKey);
        expect(artistGroup.trackCount, 5);

        service = PlaybackService(
          mediaLocationResolver: MediaLocationResolver(
            config: MediaAccessConfig.development(),
            isWindowsDesktop: true,
          ),
        );
        queue = MusicPlaybackQueueController(playbackService: service!);

        Widget seedHarness(Widget home) {
          return MultiProvider(
            providers: [
              ...musicPlayerTestProviders(service!, queueController: queue!),
              Provider<MusicLibraryService>.value(value: MusicLibraryService()),
              ChangeNotifierProvider<CatalogService>.value(
                value: _InlineCatalogService(catalog),
              ),
            ],
            child: MaterialApp(home: home),
          );
        }

        final playback = service!;
        final queueController = queue!;

        await tester.pumpWidget(
          seedHarness(MusicAlbumDetailScreen(albumGroupKey: albumGroupKey)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('music_album_play')));
        await tester.pump();
        await _waitFor(() => playback.isReady);
        await tester.pumpAndSettle();

        expect(queueController.queue.length, 3);
        expect(queueController.currentTrack?.id, 'album-t1');
        expect(
          find.byKey(const Key('music_player_queue_position')),
          findsOneWidget,
        );
        expect(find.text('1 of 3'), findsOneWidget);

        final next = find.byKey(const Key('music_player_next'));
        await tester.scrollUntilVisible(next, 100);
        await tester.tap(next);
        await _waitFor(() => playback.currentItem?.id == 'album-t2');
        await tester.pumpAndSettle();
        expect(find.text('2 of 3'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(queueController.isEmpty, isTrue);

        await tester.pumpWidget(
          seedHarness(MusicAlbumDetailScreen(albumGroupKey: albumGroupKey)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('music_track_play_album-t2')));
        await tester.pump();
        await _waitFor(() => playback.currentItem?.id == 'album-t2');
        await tester.pumpAndSettle();
        expect(queueController.queue.length, 3);
        expect(queueController.queue.currentIndex, 1);

        final previous = find.byKey(const Key('music_player_previous'));
        await tester.scrollUntilVisible(previous, 100);
        expect(tester.widget<IconButton>(previous).onPressed, isNotNull);
        expect(tester.widget<IconButton>(next).onPressed, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        await tester.pumpWidget(
          seedHarness(MusicArtistDetailScreen(artistGroupKey: artistGroupKey)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('music_artist_play')));
        await tester.pump();
        await _waitFor(() => playback.isReady);
        await tester.pumpAndSettle();

        expect(queueController.queue.length, 5);
        expect(queueController.queue.items.map((t) => t.id), [
          'album-t1',
          'album-t2',
          'album-t3',
          'artist-b1',
          'artist-b2',
        ]);

        await queueController.next();
        await queueController.next();
        await queueController.next();
        await queueController.next();
        await _waitFor(() => playback.currentItem?.id == 'artist-b2');
        await _waitFor(
          () => playback.isCompleted,
          timeout: const Duration(seconds: 30),
        );
        expect(queueController.currentTrack?.id, 'artist-b2');
        expect(queueController.hasNext, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        await tester.pumpWidget(
          seedHarness(MusicAlbumDetailScreen(albumGroupKey: albumGroupKey)),
        );
        await tester.pumpAndSettle();

        final playAlbum = find.byKey(const Key('music_album_play'));
        await tester.scrollUntilVisible(playAlbum, 100);
        await tester.tap(playAlbum);
        await tester.pump();
        await _waitFor(() => playback.currentItem?.id == 'album-t1');
        await tester.pumpAndSettle();
        expect(queueController.queue.length, 3);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(playback.currentItem, isNull);
        expect(queueController.isEmpty, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('position_album-t1'), isNull);

        final video = MediaItem(
          id: 'runtime-video-seed',
          title: 'Runtime Video',
          filePath: albumWav1.path,
          mediaKindRaw: 'video',
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: musicPlayerTestProviders(
              playback,
              queueController: queueController,
            ),
            child: MaterialApp(home: PlayerScreen(item: video, autoPlay: false)),
          ),
        );
        await tester.pump();
        expect(queueController.isEmpty, isTrue);
      } finally {
        await queue?.onPlayerRouteClosed();
        await service?.stop();
      }
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}

class _InlineCatalogService extends CatalogService {
  _InlineCatalogService(this._catalog);

  final Catalog _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;
}

String _resolveLibMpvPath() {
  final fromEnv = Platform.environment['LIBMPV_LIBRARY_PATH'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return fromEnv;
  }

  for (final relative in [
    r'build\windows\x64\runner\Debug\libmpv-2.dll',
    r'build\windows\x64\runner\Release\libmpv-2.dll',
  ]) {
    final file = File(relative);
    if (file.existsSync()) return file.absolute.path;
  }

  fail(
    'libmpv-2.dll not found. Run `flutter build windows` or set LIBMPV_LIBRARY_PATH.',
  );
}

Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for condition');
}
