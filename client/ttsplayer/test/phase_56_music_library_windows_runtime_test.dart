@Tags(['phase56-runtime'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_constants.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_albums_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artists_screen.dart';
import 'package:ttsplayer/features/music/screens/music_screen.dart';
import 'package:ttsplayer/features/music/screens/music_tracks_screen.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/widgets/music_artwork_thumbnail.dart';
import 'package:ttsplayer/features/music/widgets/music_list_tiles.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_screen.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';
import 'package:ttsplayer/widgets/artwork/media_placeholder.dart';

import 'support/phase_56_large_music_catalog_fixture.dart';
import 'support/phase_56_runtime_baseline.dart';
import 'support/phase_56_runtime_harness.dart';

/// Windows Phase 5.6 music library runtime validation (Step 6).
///
/// ```powershell
/// cd client\ttsplayer
/// $env:PHASE_56_RUNTIME='1'
/// flutter test test/phase_56_music_library_windows_runtime_test.dart --tags phase56-runtime
/// Remove-Item Env:PHASE_56_RUNTIME -ErrorAction SilentlyContinue
/// ```
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['PHASE_56_RUNTIME'] != '1') {
    test(
      'skipped — set PHASE_56_RUNTIME=1 to run Phase 5.6 music library runtime',
      () {},
      skip: true,
    );
    return;
  }

  if (!Platform.isWindows) {
    test(
      'skipped — Phase 5.6 music library runtime is Windows-only',
      () {},
      skip: true,
    );
    return;
  }

  final libmpv = phase56ResolveLibMpvPath();
  MediaKit.ensureInitialized(libmpv: libmpv);

  final baseline = Phase56RuntimeBaseline();
  baseline.observe(
    'runtime_timestamp_utc',
    DateTime.now().toUtc().toIso8601String(),
  );
  baseline.observe(
    'release_exe_exists',
    File(r'build\windows\x64\runner\Release\ttsplayer.exe').existsSync(),
  );
  baseline.observe(
      'libmpv_resolved', File(libmpv).existsSync() || libmpv == 'libmpv-2.dll');

  group('Phase 5.6 Step 6 — Windows music library runtime', () {
    tearDownAll(baseline.printReport);

    late Phase56RuntimeContext ctx;
    late int expectedAudio;
    var originalCatalogLoaded = false;

    setUpAll(() async {
      ctx = await Phase56RuntimeContext.create(
        baseline: baseline,
        profile: Phase56CatalogProfile.large,
      );
      expectedAudio = phase56ExpectedAudioCount(
        profile: Phase56CatalogProfile.large,
      );
      originalCatalogLoaded = true;
      baseline.observe('expected_audio_count', expectedAudio);
      baseline.observe(
        'catalog_total_items',
        ctx.catalogService.catalog?.totalItems,
      );
    });

    tearDownAll(() async {
      if (originalCatalogLoaded) {
        await ctx.dispose();
      }
    });

    setUp(() async {
      await ctx.resetScenarioState();
      if (ctx.catalogService.catalog?.catalogueIdentity !=
          phase56CatalogueIdentity(Phase56CatalogProfile.large)) {
        await ctx.reloadOriginalCatalog();
      }
    });

    test('P56-RT1 — runtime gate entered', () {
      expect(Platform.environment['PHASE_56_RUNTIME'], '1');
      expect(Platform.isWindows, isTrue);
      expect(ctx.catalogService.catalog, isNotNull);
      expect(ctx.listeningRepository.isLoaded, isTrue);
      expect(ctx.sessionRepository.isLoaded, isTrue);
      baseline.recordScenario('P56-RT1', 'pass', notes: 'gate enabled');
    });

    test('P56-RT2 — deterministic large catalogue load', () {
      final catalog = ctx.catalogService.catalog!;
      final audio = catalog.allItems.where((i) => i.isAudio).length;
      final video = catalog.allItems.where((i) => i.isVideo).length;
      final image = catalog.allItems.where((i) => i.isImage).length;

      expect(audio, expectedAudio);
      expect(video, 0);
      expect(image, 0);

      final projection = ctx.projection;
      expect(projection.trackCount, expectedAudio);
      expect(projection.tracks.every((t) => t.isAudio), isTrue);
      expect(projection.tracks.any((t) => t.isVideo || t.isImage), isFalse);

      baseline.observe('rt2_audio_count', audio);
      baseline.observe('rt2_artist_count', projection.artistCount);
      baseline.observe('rt2_album_count', projection.albumCount);
      baseline.recordScenario('P56-RT2', 'pass');
    });

    test('P56-RT3 — production music projection (informational)', () {
      final catalog = ctx.catalogService.catalog!;
      ctx.musicLibrary.invalidate();

      final median = baseline.measureSyncMedianMs(
        prepare: () => ctx.musicLibrary.invalidate(),
        operation: () {
          ctx.musicLibrary.projectionFor(catalog);
        },
      );

      final projection = ctx.projection;
      expect(projection.trackCount, expectedAudio);
      expect(projection.artistCount, greaterThan(0));
      expect(projection.albumCount, greaterThan(0));
      expect(
        projection.findTrackById(Phase56Sentinels.titleTrackId),
        isNotNull,
      );
      expect(
        projection.findArtistByGroupKey(
          Phase56Sentinels.artistToken.toLowerCase(),
        ),
        isNotNull,
      );

      // Deterministic ordering: artists sorted, first key stable across builds.
      final again = MusicLibraryProjection.build(catalog);
      expect(
        again.artists.map((a) => a.groupKey).toList(),
        projection.artists.map((a) => a.groupKey).toList(),
      );

      baseline.observe('rt3_projection_median_ms', median);
      baseline.observe('rt3_artists', projection.artistCount);
      baseline.observe('rt3_albums', projection.albumCount);
      baseline.recordScenario(
        'P56-RT3',
        'pass',
        notes: 'median_ms=$median informational',
      );
    });

    test('P56-RT4 — memoised projection reuse', () {
      final catalog = ctx.catalogService.catalog!;
      final first = ctx.musicLibrary.projectionFor(catalog);
      final second = ctx.musicLibrary.projectionFor(catalog);
      expect(identical(first, second), isTrue);
      expect(
        ctx.musicLibrary.hasCachedProjectionFor(catalog.catalogueIdentity),
        isTrue,
      );
      expect(first.trackCount, second.trackCount);
      expect(
        first.findTrackById(ctx.playableTrackId)?.id,
        second.findTrackById(ctx.playableTrackId)?.id,
      );
      baseline.recordScenario('P56-RT4', 'pass');
    });

    test('P56-RT5 — catalogue replacement', () async {
      final before = ctx.projection;
      final oldTitleId = Phase56Sentinels.titleTrackId;
      expect(before.findTrackById(oldTitleId), isNotNull);

      final replacement = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: false,
        includeCompilations: false,
        catalogueIdentityOverride: 'PHASE56-RUNTIME-REPLACE',
      );
      expect(
        MusicLibraryProjection.build(replacement).findTrackById(oldTitleId),
        isNull,
      );

      await ctx.replaceCatalog(replacement);
      final after = ctx.projection;
      expect(after.catalogueIdentity, 'PHASE56-RUNTIME-REPLACE');
      expect(after.findTrackById(oldTitleId), isNull);
      expect(
          after.trackCount,
          phase56ExpectedAudioCount(
            profile: Phase56CatalogProfile.small,
            includeSentinels: false,
            includeCompilations: false,
          ));
      expect(
        ctx.musicLibrary.hasCachedProjectionFor(
          phase56CatalogueIdentity(Phase56CatalogProfile.large),
        ),
        isFalse,
      );

      await ctx.reloadOriginalCatalog();
      final restored = ctx.projection;
      expect(
        restored.catalogueIdentity,
        phase56CatalogueIdentity(Phase56CatalogProfile.large),
      );
      expect(restored.findTrackById(oldTitleId), isNotNull);

      baseline.recordScenario('P56-RT5', 'pass');
    });

    test('P56-RT6 — title search at scale (informational)', () async {
      final catalog = ctx.catalogService.catalog!;
      await ctx.search.ensureIndex(catalog);

      late List results;
      final median = await baseline.measureAsyncMedianMs(
        operation: () async {
          results = await ctx.search.searchCatalog(
            catalog,
            Phase56Sentinels.titleToken,
            const SearchFilters(),
          );
        },
      );

      expect(results, isNotEmpty);
      expect(
        results.any((r) => r.item.id == Phase56Sentinels.titleTrackId),
        isTrue,
      );
      final ordered = results.map((r) => r.item.id).toList();
      final again = await ctx.search.searchCatalog(
        catalog,
        Phase56Sentinels.titleToken,
        const SearchFilters(),
      );
      expect(again.map((r) => r.item.id).toList(), ordered);

      baseline.observe('rt6_title_search_median_ms', median);
      baseline.observe('rt6_title_result_count', results.length);
      baseline.recordScenario(
        'P56-RT6',
        'pass',
        notes: 'median_ms=$median informational',
      );
    });

    test('P56-RT7 — artist and album search at scale (informational)',
        () async {
      final catalog = ctx.catalogService.catalog!;
      await ctx.search.ensureIndex(catalog);

      final artistMedian = await baseline.measureAsyncMedianMs(
        operation: () async {
          await ctx.search.searchCatalog(
            catalog,
            Phase56Sentinels.artistToken,
            const SearchFilters(),
          );
        },
      );
      final artistResults = await ctx.search.searchCatalog(
        catalog,
        Phase56Sentinels.artistToken,
        const SearchFilters(),
      );
      expect(
        artistResults.any((r) => r.item.id == Phase56Sentinels.artistTrackId),
        isTrue,
      );

      final albumMedian = await baseline.measureAsyncMedianMs(
        operation: () async {
          await ctx.search.searchCatalog(
            catalog,
            Phase56Sentinels.albumToken,
            const SearchFilters(),
          );
        },
      );
      final albumResults = await ctx.search.searchCatalog(
        catalog,
        Phase56Sentinels.albumToken,
        const SearchFilters(),
      );
      expect(
        albumResults.any((r) => r.item.id == Phase56Sentinels.albumTrackId),
        isTrue,
      );

      baseline.observe('rt7_artist_search_median_ms', artistMedian);
      baseline.observe('rt7_album_search_median_ms', albumMedian);
      baseline.recordScenario(
        'P56-RT7',
        'pass',
        notes: 'informational',
      );
    });

    testWidgets('P56-RT8 — rapid query replacement', (tester) async {
      await phase56ConfigureViewport(tester);
      await ctx.search.ensureIndex(ctx.catalogService.catalog!);
      ctx.search.debugSearchDelay = const Duration(milliseconds: 80);

      await tester.pumpWidget(ctx.wrap(const SearchScreen(autofocus: true)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('search_query_field')),
        Phase56Sentinels.titleToken,
      );
      await tester.pump(const Duration(milliseconds: 20));

      ctx.search.debugSearchDelay = Duration.zero;
      await tester.enterText(
        find.byKey(const Key('search_query_field')),
        Phase56Sentinels.absentToken,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      expect(find.text('No results found'), findsOneWidget);
      expect(find.byKey(Key('search_result_${Phase56Sentinels.titleTrackId}')),
          findsNothing);

      // Dispose must not publish.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);

      baseline.recordScenario('P56-RT8', 'pass');
    });

    testWidgets('P56-RT9 — artist browse initial render (informational)',
        (tester) async {
      await phase56ConfigureViewport(tester);
      final projection = ctx.projection;

      final sw = Stopwatch()..start();
      await tester.pumpWidget(ctx.wrap(const MusicArtistsScreen()));
      await tester.pump();
      sw.stop();

      expect(find.byKey(const PageStorageKey<String>('music_artists_list')),
          findsOneWidget);
      final mounted = find.byType(MusicArtistListTile).evaluate().length;
      expect(mounted, greaterThan(0));
      expect(mounted, lessThan(projection.artistCount));
      expect(find.byKey(const Key('music_catalog_loading')), findsNothing);
      expect(tester.takeException(), isNull);

      baseline.observe('rt9_first_render_ms', sw.elapsedMilliseconds);
      baseline.observe('rt9_mounted_artists', mounted);
      baseline.recordScenario(
        'P56-RT9',
        'pass',
        notes: 'mounted=$mounted/${projection.artistCount}',
      );
    });

    testWidgets('P56-RT10 — album browse initial render (informational)',
        (tester) async {
      await phase56ConfigureViewport(tester);
      final projection = ctx.projection;

      final sw = Stopwatch()..start();
      await tester.pumpWidget(ctx.wrap(const MusicAlbumsScreen()));
      await tester.pump();
      sw.stop();

      expect(find.byKey(const PageStorageKey<String>('music_albums_list')),
          findsOneWidget);
      final mounted = find.byType(MusicAlbumListTile).evaluate().length;
      expect(mounted, greaterThan(0));
      expect(mounted, lessThan(projection.albumCount));
      expect(tester.takeException(), isNull);

      baseline.observe('rt10_first_render_ms', sw.elapsedMilliseconds);
      baseline.observe('rt10_mounted_albums', mounted);
      baseline.recordScenario(
        'P56-RT10',
        'pass',
        notes: 'mounted=$mounted/${projection.albumCount}',
      );
    });

    testWidgets('P56-RT11 — large track-list scrolling', (tester) async {
      await phase56ConfigureViewport(tester);
      final trackCount = ctx.projection.trackCount;
      expect(trackCount, greaterThan(1000));

      await tester.pumpWidget(ctx.wrap(const MusicTracksScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const PageStorageKey<String>('music_tracks_list')),
          findsOneWidget);
      final before = find.byType(MusicTrackListTile).evaluate().length;
      expect(before, greaterThan(0));
      expect(before, lessThan(trackCount));

      final keysBefore = _mountedTrackKeys(tester);
      expect(keysBefore, isNotEmpty);
      await tester.drag(
        find.byKey(const PageStorageKey<String>('music_tracks_list')),
        const Offset(0, -2400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final after = find.byType(MusicTrackListTile).evaluate().length;
      expect(after, greaterThan(0));
      expect(after, lessThan(trackCount));
      final keysAfter = _mountedTrackKeys(tester);
      expect(keysAfter, isNotEmpty);
      expect(keysAfter.length, equals(keysAfter.toSet().length));
      // Scrolling should reveal different track identities.
      expect(
        keysAfter.intersection(keysBefore).length,
        lessThan(keysAfter.length),
      );
      expect(tester.takeException(), isNull);

      baseline.observe('rt11_mounted_before', before);
      baseline.observe('rt11_mounted_after', after);
      baseline.observe(
        'rt11_keys_overlap',
        keysBefore.intersection(keysAfter).length,
      );
      baseline.recordScenario('P56-RT11', 'pass');
    });

    testWidgets('P56-RT12 — navigation and scroll retention', (tester) async {
      await phase56ConfigureViewport(tester);
      final catalog = ctx.catalogService.catalog!;
      final projection = ctx.musicLibrary.projectionFor(catalog);

      await tester.pumpWidget(ctx.wrap(const MusicArtistsScreen()));
      await tester.pumpAndSettle();

      final listFinder =
          find.byKey(const PageStorageKey<String>('music_artists_list'));
      await tester.drag(listFinder, const Offset(0, -900));
      await tester.pumpAndSettle();
      final offsetBefore = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(offsetBefore, greaterThan(0));

      await tester.tap(find.byType(MusicArtistListTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(MusicArtistDetailScreen), findsOneWidget);

      final albumTile = find.byType(MusicAlbumListTile);
      if (albumTile.evaluate().isNotEmpty) {
        await tester.tap(albumTile.first);
        await tester.pumpAndSettle();
        expect(find.byType(MusicAlbumDetailScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(MusicAlbumDetailScreen))).pop();
        await tester.pumpAndSettle();
      }

      Navigator.of(tester.element(find.byType(MusicArtistDetailScreen))).pop();
      await tester.pumpAndSettle();

      final offsetAfter = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(offsetAfter, closeTo(offsetBefore, 1.0));
      expect(
        identical(ctx.musicLibrary.projectionFor(catalog), projection),
        isTrue,
      );

      baseline.observe('rt12_offset_before', offsetBefore);
      baseline.observe('rt12_offset_after', offsetAfter);
      baseline.recordScenario('P56-RT12', 'pass');
    });

    testWidgets('P56-RT13 — artwork success and fallback', (tester) async {
      await phase56ConfigureViewport(tester);
      final artPath = await ctx.writeValidArtworkJpeg();
      final withArt = MediaItem(
        id: 'p56-art-ok',
        title: 'Artwork Track',
        filePath: r'Y:\Media\Music\art-ok.mp3',
        mediaKindRaw: 'audio',
        thumbnailPath: artPath,
      );
      final missing = MediaItem(
        id: 'p56-art-missing',
        title: 'Missing Art',
        filePath: r'Y:\Media\Music\art-missing.mp3',
        mediaKindRaw: 'audio',
      );
      final invalid = MediaItem(
        id: 'p56-art-bad',
        title: 'Bad Art',
        filePath: r'Y:\Media\Music\art-bad.mp3',
        mediaKindRaw: 'audio',
        thumbnailPath: r'Y:\Media\Music\does-not-exist.jpg',
      );

      await tester.pumpWidget(
        ctx.wrap(
          Scaffold(
            body: Row(
              children: [
                MusicArtworkThumbnail(
                  key: const Key('art_ok'),
                  item: withArt,
                  size: 64,
                ),
                MusicArtworkThumbnail(
                  key: const Key('art_missing'),
                  item: missing,
                  size: 64,
                ),
                MusicArtworkThumbnail(
                  key: const Key('art_bad'),
                  item: invalid,
                  size: 64,
                ),
                MusicArtworkThumbnail(
                  key: const Key('art_shared'),
                  item: withArt,
                  size: 64,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
          tester.getSize(find.byKey(const Key('art_ok'))), const Size(64, 64));
      expect(
        tester.getSize(find.byKey(const Key('art_missing'))),
        const Size(64, 64),
      );
      expect(
          tester.getSize(find.byKey(const Key('art_bad'))), const Size(64, 64));
      expect(find.byType(MediaPlaceholder), findsWidgets);
      expect(tester.takeException(), isNull);

      final export = await ctx.exportDiagnostics();
      phase56AssertNoForbiddenContent(export);
      expect(export.contains(artPath), isFalse);

      baseline.recordScenario('P56-RT13', 'pass');
    });

    testWidgets('P56-RT14 — UI-state matrix', (tester) async {
      await phase56ConfigureViewport(tester);

      Future<void> pumpCase(Widget harness) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(harness);
        await tester.pump();
      }

      // Loading
      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_loading'),
          catalogService: _FakeCatalogService()..markLoading(),
          child: const MusicScreen(),
        ),
      );
      expect(find.byKey(const Key('music_catalog_loading')), findsOneWidget);

      // Empty music library
      final empty = Catalog.fromJson({
        'generated_at': '2026-07-23T12:00:00+00:00',
        'total_items': 0,
        'catalogue': {
          'id': 'EMPTY-AUDIO',
          'scanner_version': '0.4.0',
          'catalogue_version': 3,
        },
        'folders': [],
      });
      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_empty'),
          catalogService: _FakeCatalogService(empty),
          child: const MusicScreen(),
        ),
      );
      expect(find.byKey(const Key('music_library_empty')), findsOneWidget);

      // No artists / no albums
      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_no_artists'),
          catalogService: _FakeCatalogService(empty),
          child: const MusicArtistsScreen(),
        ),
      );
      expect(find.byKey(const Key('music_artists_empty')), findsOneWidget);

      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_no_albums'),
          catalogService: _FakeCatalogService(empty),
          child: const MusicAlbumsScreen(),
        ),
      );
      expect(find.byKey(const Key('music_albums_empty')), findsOneWidget);

      // Missing album / artist routes
      final small = phase56SmallCatalog();
      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_missing_album'),
          catalogService: _FakeCatalogService(small),
          child: const MusicAlbumDetailScreen(albumGroupKey: 'missing-album'),
        ),
      );
      expect(find.byKey(const Key('music_album_missing')), findsOneWidget);

      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_missing_artist'),
          catalogService: _FakeCatalogService(small),
          child:
              const MusicArtistDetailScreen(artistGroupKey: 'missing-artist'),
        ),
      );
      expect(find.byKey(const Key('music_artist_missing')), findsOneWidget);

      // Degraded retained catalogue
      await pumpCase(
        _uiStateHarness(
          key: const Key('rt14_degraded'),
          catalogService: _FakeCatalogService(small)
            ..setError('Reload failed; showing previous catalogue.'),
          child: const MusicArtistsScreen(),
        ),
      );
      expect(
        find.byKey(const Key('music_catalog_degraded_banner')),
        findsOneWidget,
      );

      // No search results (production SearchScreen)
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await ctx.search.ensureIndex(ctx.catalogService.catalog!);
      await tester.pumpWidget(ctx.wrap(const SearchScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('search_query_field')),
        Phase56Sentinels.absentToken,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('No results found'), findsOneWidget);

      baseline.recordScenario('P56-RT14', 'pass');
    });

    test('P56-RT15 — partial metadata', () {
      final projection = ctx.projection;
      final fallbackTracks = projection.tracks
          .where((t) => t.id.startsWith('p56-a000-b00-t0'))
          .take(2)
          .toList();
      expect(fallbackTracks, isNotEmpty);

      for (final track in fallbackTracks) {
        expect(musicDisplayTitle(track), isNotEmpty);
      }

      // Whitespace / missing helpers used by production UI.
      final synthetic = MediaItem(
        id: 'partial',
        title: '   ',
        filePath: r'Y:\Media\Music\partial.mp3',
        mediaKindRaw: 'audio',
        artist: '  ',
        album: null,
      );
      expect(musicDisplayTitle(synthetic), MusicConstants.unknownTrack);
      expect(musicDisplayArtist(synthetic), MusicConstants.unknownArtist);
      expect(musicDisplayAlbum(synthetic), MusicConstants.unknownAlbum);

      expect(projection.artistCount, greaterThan(0));
      expect(projection.albumCount, greaterThan(0));
      baseline.recordScenario('P56-RT15', 'pass');
    });

    test('P56-RT16 — playback and queue integration', () async {
      final track = ctx.trackById(ctx.playableTrackId);
      expect(track, isNotNull);
      final album = ctx.projection.findAlbumByGroupKey(track!.albumGroupKey!);
      expect(album, isNotNull);

      final beforeProjection = ctx.projection;
      final seeded = ctx.queue.seedAlbumQueue(album!, startTrack: track);
      expect(seeded, isTrue);
      expect(ctx.queue.currentTrack?.id, track.id);
      expect(ctx.queue.queue.items.first.id, isNot(equals('')));
      expect(
        ctx.queue.queue.items.map((e) => e.id).toSet().length,
        ctx.queue.queue.items.length,
      );

      await ctx.queue.playCurrent();
      expect(ctx.playback.currentItem?.id, track.id);
      expect(
        identical(ctx.musicLibrary.projectionFor(ctx.catalogService.catalog!),
            beforeProjection),
        isTrue,
      );

      baseline.observe('rt16_queue_length', ctx.queue.queue.length);
      baseline.recordScenario('P56-RT16', 'pass');
    });

    test('P56-RT17 — listening-history and session isolation', () async {
      const videoProbeId = 'phase56-video-probe';
      const videoPosKey = 'position_$videoProbeId';
      const videoDurKey = 'duration_$videoProbeId';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(videoPosKey, 12345);
      await prefs.setInt(videoDurKey, 99999);

      final track = ctx.trackById(ctx.playableTrackId)!;
      await ctx.simulatePlayForSeconds(track, 45);

      expect(ctx.listeningRepository.storedRecordCount, greaterThan(0));
      expect(ctx.listeningRepository.recentlyPlayed(), isNotEmpty);
      expect(ctx.listeningRepository.continueListening(), isNotEmpty);

      await ctx.sessionCoordinator.drainPendingWrites();
      expect(ctx.sessionRepository.hasPersistedSession, isTrue);
      expect(ctx.playback.isPlaying, isFalse);

      expect(prefs.getInt(videoPosKey), 12345);
      expect(prefs.getInt(videoDurKey), 99999);

      baseline.observe(
        'rt17_continue_count',
        ctx.listeningRepository.continueListening().length,
      );
      baseline.observe(
        'rt17_recent_count',
        ctx.listeningRepository.recentlyPlayed().length,
      );
      baseline.recordScenario('P56-RT17', 'pass');
    });

    test('P56-RT18 — diagnostics redaction', () async {
      final track = ctx.trackById(ctx.playableTrackId)!;
      await ctx.simulatePlayForSeconds(track, 20);
      await ctx.search.ensureIndex(ctx.catalogService.catalog!);
      await ctx.search.searchCatalog(
        ctx.catalogService.catalog!,
        Phase56Sentinels.titleToken,
        const SearchFilters(),
      );

      final export = await ctx.exportDiagnostics();
      phase56AssertNoForbiddenContent(export);
      expect(export.contains(Phase56Sentinels.titleToken), isFalse);
      expect(export.contains(ctx.catalogPath), isFalse);

      baseline.observe('rt18_export_chars', export.length);
      baseline.recordScenario('P56-RT18', 'pass');
    });

    test('P56-RT19 — optional live catalogue', () async {
      final path = Platform.environment['PHASE_56_LOCAL_CATALOG'];
      if (path == null || path.isEmpty) {
        baseline.liveCatalogStatus = 'skipped — PHASE_56_LOCAL_CATALOG unset';
        baseline.recordScenario('P56-RT19', 'skipped');
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        baseline.liveCatalogStatus = 'failed — file missing';
        fail('PHASE_56_LOCAL_CATALOG path does not exist');
      }

      final settings = SettingsRepository();
      await settings.initialize();
      final catalogService = CatalogService(settingsRepository: settings)
        ..includeLegacyCataloguePaths = false;

      final loadSw = Stopwatch()..start();
      await catalogService.loadFromFile(path);
      loadSw.stop();
      final catalog = catalogService.catalog;
      expect(catalog, isNotNull);

      late MusicLibraryProjection projection;
      final median = baseline.measureSyncMedianMs(
        operation: () {
          projection = MusicLibraryProjection.build(catalog!);
        },
      );

      final audioCount = catalog!.allItems.where((i) => i.isAudio).length;
      final search = SearchService();
      await search.ensureIndex(catalog);
      final searchMedian = await baseline.measureAsyncMedianMs(
        operation: () async {
          await search.searchCatalog(catalog, 'a', const SearchFilters());
        },
      );

      final export = await ctx.exportDiagnostics();
      phase56AssertNoForbiddenContent(export);

      baseline.liveCatalogStatus =
          'loaded total=${catalog.totalItems} audio=$audioCount '
          'artists=${projection.artistCount} albums=${projection.albumCount} '
          'load_ms=${loadSw.elapsedMilliseconds} '
          'projection_median_ms=$median search_median_ms=$searchMedian';
      baseline.recordScenario('P56-RT19', 'pass');
    });

    test('P56-RT20 — runtime cleanup and state isolation', () async {
      await ctx.resetScenarioState();
      expect(ctx.queue.queue.isEmpty, isTrue);
      expect(ctx.listeningRepository.storedRecordCount, 0);
      expect(ctx.sessionRepository.hasPersistedSession, isFalse);

      // Fixture lives only under system temp, not the repo.
      final repoRoot = Directory.current.path.toLowerCase();
      expect(
        ctx.tempCatalogDir.path.toLowerCase().contains(repoRoot) &&
            ctx.tempCatalogDir.path.toLowerCase().contains('test'),
        isFalse,
      );
      expect(ctx.tempCatalogDir.existsSync(), isTrue);

      baseline.observe('rt20_temp_catalog_exists_pre_dispose', true);
      baseline.recordScenario('P56-RT20', 'pass');
    });

    test('mixed-media isolation (supporting)', () {
      final mixed = phase56MixedCatalog();
      final projection = MusicLibraryProjection.build(mixed);
      expect(mixed.allItems.where((i) => i.isVideo).length, 25);
      expect(mixed.allItems.where((i) => i.isImage).length, 25);
      expect(projection.tracks.every((t) => t.isAudio), isTrue);
      expect(
          projection.trackCount,
          phase56ExpectedAudioCount(
            profile: Phase56CatalogProfile.mixed,
          ));
      baseline.observe('mixed_audio', projection.trackCount);
      baseline.observe('mixed_excluded_non_audio', 50);
    });
  });
}

Set<String> _mountedTrackKeys(WidgetTester tester) {
  // Keys are on the inner ListTile (`music_track_<id>`), not MusicTrackListTile.
  return find
      .byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('music_track_') &&
            !key.value.startsWith('music_track_play_');
      })
      .evaluate()
      .map((e) => (e.widget.key! as ValueKey<String>).value)
      .toSet();
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService([this._catalog]);

  Catalog? _catalog;
  bool _loading = false;
  String? _error;

  void markLoading() {
    _loading = true;
    _catalog = null;
    _error = null;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    _loading = false;
    notifyListeners();
  }

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => _loading;

  @override
  String? get errorMessage => _error;

  @override
  Future<void> refreshCatalogue() async {
    _error = null;
    notifyListeners();
  }
}

Widget _uiStateHarness({
  Key? key,
  required CatalogService catalogService,
  required Widget child,
}) {
  SharedPreferences.setMockInitialValues({});
  final metadata = LibraryMetadataRepository();
  final listening = MusicListeningRepository();
  return MultiProvider(
    key: key ?? UniqueKey(),
    providers: [
      ChangeNotifierProvider<SettingsRepository>.value(
        value: SettingsRepository(),
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>.value(value: metadata),
      Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: MediaAccessConfig.defaults(),
          isWindowsDesktop: true,
        ),
      ),
      Provider<ArtworkService>.value(
        value: ArtworkService(fileExists: (_) => false),
      ),
      Provider<MusicLibraryService>.value(value: MusicLibraryService()),
      ChangeNotifierProvider<CatalogService>.value(value: catalogService),
      ChangeNotifierProvider<PlaybackService>.value(value: PlaybackService()),
      ChangeNotifierProvider<MusicListeningRepository>.value(value: listening),
    ],
    child: MaterialApp(home: child),
  );
}
