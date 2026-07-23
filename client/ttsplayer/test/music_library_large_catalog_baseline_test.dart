import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/models/music_library_projection.dart';
import 'package:ttsplayer/features/music/music_constants.dart';
import 'package:ttsplayer/features/music/music_library_service.dart';
import 'package:ttsplayer/features/music/screens/music_album_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_albums_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artist_detail_screen.dart';
import 'package:ttsplayer/features/music/screens/music_artists_screen.dart';
import 'package:ttsplayer/features/music/screens/music_tracks_screen.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/widgets/music_list_tiles.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/services/scan_history_service.dart';
import 'package:ttsplayer/services/scanner_service.dart';
import 'package:ttsplayer/services/settings/settings_repository.dart';

import 'support/phase_56_large_music_catalog_fixture.dart';
import 'support/phase_56_performance_baseline.dart';

/// Phase 5.6 Step 2 — large-library fixtures and informational baselines (MP1–MP18).
///
/// Timing is informational. Correctness assertions are blocking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseline = Phase56PerformanceBaseline();

  setUpAll(() async {
    await baseline.captureEnvironment();
  });

  tearDownAll(() => baseline.printReport());

  group('Phase 5.6 fixture generator', () {
    test('profiles produce exact deterministic audio counts', () {
      final small = phase56SmallCatalog();
      final medium = phase56MediumCatalog();
      final large = phase56LargeCatalog();
      final mixed = phase56MixedCatalog();

      expect(
        small.allItems.where((i) => i.isAudio).length,
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.small),
      );
      expect(
        medium.allItems.where((i) => i.isAudio).length,
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.medium),
      );
      expect(
        large.allItems.where((i) => i.isAudio).length,
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.large),
      );
      expect(
        mixed.allItems.where((i) => i.isAudio).length,
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.mixed),
      );
      expect(mixed.allItems.where((i) => i.isVideo).length, 25);
      expect(mixed.allItems.where((i) => i.isImage).length, 25);

      baseline.observe(
        'fixture_small_audio',
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.small),
      );
      baseline.observe(
        'fixture_medium_audio',
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.medium),
      );
      baseline.observe(
        'fixture_large_audio',
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.large),
      );
      baseline.observe('fixture_mixed_total', mixed.totalItems);
    });

    test('IDs are unique and stable across regenerations', () {
      final a = phase56SmallCatalog();
      final b = phase56SmallCatalog();
      final idsA = a.allItems.map((i) => i.id).toList()..sort();
      final idsB = b.allItems.map((i) => i.id).toList()..sort();
      expect(idsA.toSet().length, idsA.length);
      expect(idsA, idsB);
    });
  });

  group('Phase 5.6 MP projection baselines', () {
    test('MP1 — 1,000-track projection', () {
      _runProjectionScenario(
        baseline: baseline,
        scenarioId: 'MP1',
        profile: Phase56CatalogProfile.small,
      );
    });

    test('MP2 — 10,000-track projection', () {
      _runProjectionScenario(
        baseline: baseline,
        scenarioId: 'MP2',
        profile: Phase56CatalogProfile.medium,
      );
    });

    test('MP3 — 40,000-track projection', () {
      _runProjectionScenario(
        baseline: baseline,
        scenarioId: 'MP3',
        profile: Phase56CatalogProfile.large,
      );
    });

    test('MP4 — mixed-media projection', () {
      final genSw = Stopwatch()..start();
      final catalog = phase56MixedCatalog();
      genSw.stop();
      baseline.observe('mp4_fixture_gen_ms', genSw.elapsedMilliseconds);

      late MusicLibraryProjection projection;
      final samples = baseline.measureSyncSamples(
        operation: () {
          projection = MusicLibraryProjection.build(catalog);
        },
      );

      expect(
        projection.trackCount,
        phase56ExpectedAudioCount(profile: Phase56CatalogProfile.mixed),
      );
      expect(projection.tracks.every((t) => t.isAudio), isTrue);
      expect(catalog.allItems.where((i) => i.isVideo).length, 25);
      expect(catalog.allItems.where((i) => i.isImage).length, 25);
      expect(
        projection.tracks.any((t) => t.id.startsWith('p56-video-')),
        isFalse,
      );
      expect(
        projection.tracks.any((t) => t.id.startsWith('p56-image-')),
        isFalse,
      );

      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP4',
          operation: 'projection_build_mixed',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: projection.trackCount,
          artistCount: projection.artistCount,
          albumCount: projection.albumCount,
          samples: samples,
          classification: 'informational',
          notes: 'video/image excluded from music projection',
        ),
      );
    });

    test('MP5 — missing metadata projection', () {
      final catalog = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeMissingMetadata: true,
        includeCompilations: false,
        includeSentinels: false,
        includeUnicodeNames: false,
      );
      final projection = MusicLibraryProjection.build(catalog);

      final missing = projection.tracks
          .where((t) => t.id.startsWith('p56-a000-b00-t0'))
          .toList();
      expect(missing, isNotEmpty);
      // Fallback grouping uses Unknown Artist / Unknown Album constants.
      expect(
        projection.artists.any(
          (a) =>
              a.displayName == MusicConstants.unknownArtist ||
              a.groupKey.contains('unknown'),
        ),
        isTrue,
      );
      expect(projection.trackCount, greaterThan(0));
      baseline.observe('mp5_unknown_artist_present', true);
    });

    test('MP6 — compilation grouping', () {
      final catalog = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeCompilations: true,
        includeSentinels: false,
        includeMissingMetadata: false,
      );
      final projection = MusicLibraryProjection.build(catalog);

      final compAlbum = projection.findAlbumByGroupKey(
        Phase56Sentinels.compilationAlbumKey,
      );
      expect(compAlbum, isNotNull);
      expect(compAlbum!.tracks.length, 4);
      expect(
        compAlbum.tracks.map((t) => t.artist).toSet().length,
        greaterThan(1),
      );
      // Current semantics: display artist is deterministic sorted-first of
      // track artists (not redefined in Step 2).
      expect(compAlbum.displayArtist, isNotEmpty);

      final various = projection.findArtistByGroupKey(
        Phase56Sentinels.compilationArtistKey,
      );
      expect(various, isNotNull);
      expect(various!.tracks.length, 4);
      baseline.observe('mp6_compilation_tracks', compAlbum.tracks.length);
    });

    test('MP7 — repeated projection consistency', () {
      final catalog = phase56SmallCatalog();
      final first = MusicLibraryProjection.build(catalog);
      final samples = baseline.measureSyncSamples(
        operation: () {
          final next = MusicLibraryProjection.build(catalog);
          expect(next.trackCount, first.trackCount);
          expect(next.artistCount, first.artistCount);
          expect(next.albumCount, first.albumCount);
          expect(
            next.tracks.map((t) => t.id).toList(),
            first.tracks.map((t) => t.id).toList(),
          );
          expect(
            next.artists.map((a) => a.groupKey).toList(),
            first.artists.map((a) => a.groupKey).toList(),
          );
          expect(
            next.albums.map((a) => a.groupKey).toList(),
            first.albums.map((a) => a.groupKey).toList(),
          );
          expect(
            next.findTrackById(first.tracks.first.id)?.id,
            first.tracks.first.id,
          );
        },
      );

      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP7',
          operation: 'repeated_projection_consistency',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: first.trackCount,
          artistCount: first.artistCount,
          albumCount: first.albumCount,
          samples: samples,
          classification: 'informational',
        ),
      );
    });

    test('MP8 — catalogue-generation replacement', () {
      final catalogA = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: true,
        catalogueIdentityOverride: 'PHASE56-GEN-A',
      );
      final catalogB = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        includeSentinels: false,
        includeCompilations: false,
        catalogueIdentityOverride: 'PHASE56-GEN-B',
      );

      late MusicLibraryProjection projectionB;
      final samples = baseline.measureSyncSamples(
        prepare: () {
          MusicLibraryProjection.build(catalogA);
        },
        operation: () {
          projectionB = MusicLibraryProjection.build(catalogB);
        },
      );

      expect(
        projectionB.findTrackById(Phase56Sentinels.titleTrackId),
        isNull,
      );
      expect(projectionB.findTrackById('p56-a000-b00-t00'), isNotNull);
      expect(
        projectionB.findAlbumByGroupKey(Phase56Sentinels.compilationAlbumKey),
        isNull,
      );
      expect(projectionB.catalogueIdentity, 'PHASE56-GEN-B');

      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP8',
          operation: 'projection_after_catalogue_replace',
          catalogueItemCount: catalogB.totalItems,
          audioItemCount: projectionB.trackCount,
          artistCount: projectionB.artistCount,
          albumCount: projectionB.albumCount,
          samples: samples,
          classification: 'informational',
        ),
      );
    });
  });

  group('Phase 5.6 MusicLibraryService memoisation baseline', () {
    test('reuses projection for equivalent catalogue identity', () {
      final catalog = phase56SmallCatalog();
      final service = MusicLibraryService();
      final first = service.projectionFor(catalog);
      final second = service.projectionFor(catalog);
      expect(identical(first, second), isTrue);
      expect(service.hasCachedProjectionFor(catalog.catalogueIdentity), isTrue);
      baseline.observe('memoisation_reuse', true);
    });

    test('invalidate and identity change produce new projections', () {
      final catalogA = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        catalogueIdentityOverride: 'PHASE56-MEMO-A',
      );
      final catalogB = generatePhase56MusicCatalog(
        profile: Phase56CatalogProfile.small,
        catalogueIdentityOverride: 'PHASE56-MEMO-B',
      );
      final service = MusicLibraryService();
      final first = service.projectionFor(catalogA);
      service.invalidate();
      expect(service.hasCachedProjectionFor('PHASE56-MEMO-A'), isFalse);
      final afterInvalidate = service.projectionFor(catalogA);
      expect(identical(first, afterInvalidate), isFalse);

      final forB = service.projectionFor(catalogB);
      expect(identical(afterInvalidate, forB), isFalse);
      expect(forB.catalogueIdentity, 'PHASE56-MEMO-B');
      baseline.observe('memoisation_invalidate', true);
    });

    test('uncached projectionFor still rebuilds on miss (Step 3 evidence)', () {
      final catalog = phase56MediumCatalog();
      final service = MusicLibraryService();
      final samples = baseline.measureSyncSamples(
        prepare: () => service.invalidate(),
        operation: () {
          service.projectionFor(catalog);
        },
        includePrepareInSamples: false,
      );
      // Cold builds only (invalidate outside timed section).
      final coldSamples = <Duration>[];
      for (var i = 0; i < 3; i++) {
        service.invalidate();
        final sw = Stopwatch()..start();
        service.projectionFor(catalog);
        sw.stop();
        coldSamples.add(sw.elapsed);
      }
      final hotSamples = baseline.measureSyncSamples(
        operation: () {
          service.projectionFor(catalog);
        },
      );

      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MEMO-COLD',
          operation: 'projectionFor_cold_after_invalidate',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: phase56ExpectedAudioCount(
            profile: Phase56CatalogProfile.medium,
          ),
          artistCount: 0,
          albumCount: 0,
          samples: coldSamples,
          classification: 'informational',
          notes: 'evidence for Step 3 — cold rebuild cost',
        ),
      );
      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MEMO-HOT',
          operation: 'projectionFor_cached_hit',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: phase56ExpectedAudioCount(
            profile: Phase56CatalogProfile.medium,
          ),
          artistCount: 0,
          albumCount: 0,
          samples: hotSamples,
          classification: 'informational',
          notes: 'identity memoisation hit',
        ),
      );
      // Silence unused warning if analyzer complains about samples.
      expect(samples, isNotEmpty);
    });
  });

  group('Phase 5.6 MP search baselines', () {
    test('MP9 — empty-query behaviour', () async {
      final catalog = phase56SmallCatalog();
      final search = SearchService();
      await search.ensureIndex(catalog);

      late List results;
      final samples = await baseline.measureSamples(
        operation: () async {
          results = await search.searchCatalog(
            catalog,
            '   ',
            const SearchFilters(),
          );
        },
      );

      // Product contract: empty/whitespace query → empty result list.
      expect(results, isEmpty);
      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP9',
          operation: 'search_empty_query',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: phase56ExpectedAudioCount(
            profile: Phase56CatalogProfile.small,
          ),
          artistCount: 0,
          albumCount: 0,
          samples: samples,
          classification: 'informational',
          notes: 'contract: empty trim → []',
        ),
      );
    });

    test('MP10 — title search', () async {
      await _runSearchScenario(
        baseline: baseline,
        scenarioId: 'MP10',
        profile: Phase56CatalogProfile.medium,
        query: Phase56Sentinels.titleToken,
        expectMatchId: Phase56Sentinels.titleTrackId,
      );
    });

    test('MP11 — artist search', () async {
      await _runSearchScenario(
        baseline: baseline,
        scenarioId: 'MP11',
        profile: Phase56CatalogProfile.medium,
        query: Phase56Sentinels.artistToken,
        expectMatchId: Phase56Sentinels.artistTrackId,
      );
    });

    test('MP12 — album search', () async {
      await _runSearchScenario(
        baseline: baseline,
        scenarioId: 'MP12',
        profile: Phase56CatalogProfile.medium,
        query: Phase56Sentinels.albumToken,
        expectMatchId: Phase56Sentinels.albumTrackId,
      );
    });

    test('MP13 — rapid query replacement', () async {
      final catalog = phase56MediumCatalog();
      final search = SearchService();
      await search.ensureIndex(catalog);

      // SearchService is synchronous after index build — sequential replacement.
      final queries = [
        Phase56Sentinels.titleToken,
        Phase56Sentinels.artistToken,
        Phase56Sentinels.albumToken,
        Phase56Sentinels.absentToken,
        Phase56Sentinels.titleToken,
      ];
      List? last;
      for (final q in queries) {
        last = await search.searchCatalog(catalog, q, const SearchFilters());
      }
      expect(last, isNotEmpty);
      expect(
        last!.any((r) => r.item.id == Phase56Sentinels.titleTrackId),
        isTrue,
      );
      baseline.observe(
        'mp13_note',
        'SearchService sync after index; async stale discard is SearchScreen '
            '(150ms debounce) — Step 4',
      );
    });

    test('MP14 — no-results behaviour', () async {
      final catalog = phase56MediumCatalog();
      final search = SearchService();
      await search.ensureIndex(catalog);

      // Seed a prior successful search, then query absent sentinel.
      final prior = await search.searchCatalog(
        catalog,
        Phase56Sentinels.titleToken,
        const SearchFilters(),
      );
      expect(prior, isNotEmpty);

      late List results;
      final samples = await baseline.measureSamples(
        operation: () async {
          results = await search.searchCatalog(
            catalog,
            Phase56Sentinels.absentToken,
            const SearchFilters(),
          );
        },
      );

      expect(results, isEmpty);
      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP14',
          operation: 'search_no_results',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: phase56ExpectedAudioCount(
            profile: Phase56CatalogProfile.medium,
          ),
          artistCount: 0,
          albumCount: 0,
          samples: samples,
          classification: 'informational',
        ),
      );
    });
  });

  group('Phase 5.6 MP widget baselines', () {
    testWidgets('MP15 — artist-list initial render', (tester) async {
      final catalog = phase56SmallCatalog();
      final projection = MusicLibraryProjection.build(catalog);
      await _configureViewport(tester);

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _musicHarness(catalog: catalog, child: const MusicArtistsScreen()),
      );
      await tester.pump();
      sw.stop();

      expect(find.byKey(const Key('music_artists_list')), findsOneWidget);
      final mountedTiles = find.byType(MusicArtistListTile).evaluate().length;
      expect(mountedTiles, greaterThan(0));
      expect(mountedTiles, lessThan(projection.artistCount));
      expect(
        find.byKey(Key('music_artist_${projection.artists.first.groupKey}')),
        findsOneWidget,
      );

      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP15',
          operation: 'artist_list_initial_pump',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: projection.trackCount,
          artistCount: projection.artistCount,
          albumCount: projection.albumCount,
          samples: [sw.elapsed],
          classification: 'informational',
          notes: 'mounted_artist_tiles=$mountedTiles / '
              '${projection.artistCount}',
        ),
      );
    });

    testWidgets('MP16 — album-list initial render', (tester) async {
      final catalog = phase56SmallCatalog();
      final projection = MusicLibraryProjection.build(catalog);
      await _configureViewport(tester);

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _musicHarness(catalog: catalog, child: const MusicAlbumsScreen()),
      );
      await tester.pump();
      sw.stop();

      expect(find.byKey(const Key('music_albums_list')), findsOneWidget);
      final mountedTiles = find.byType(MusicAlbumListTile).evaluate().length;
      expect(mountedTiles, greaterThan(0));
      expect(mountedTiles, lessThan(projection.albumCount));

      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP16',
          operation: 'album_list_initial_pump',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: projection.trackCount,
          artistCount: projection.artistCount,
          albumCount: projection.albumCount,
          samples: [sw.elapsed],
          classification: 'informational',
          notes: 'mounted_album_tiles=$mountedTiles / '
              '${projection.albumCount}',
        ),
      );
    });

    testWidgets('MP17 — large track-list scrolling', (tester) async {
      final catalog = phase56SmallCatalog();
      final projection = MusicLibraryProjection.build(catalog);
      await _configureViewport(tester);

      await tester.pumpWidget(
        _musicHarness(
          catalog: catalog,
          child: const MusicTracksScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('music_tracks_list')), findsOneWidget);
      final beforeKeys = _mountedTrackKeys(tester);
      expect(beforeKeys, isNotEmpty);
      expect(beforeKeys.length, lessThan(projection.trackCount));

      await tester.drag(
        find.byKey(const Key('music_tracks_list')),
        const Offset(0, -2400),
      );
      await tester.pumpAndSettle();

      final afterKeys = _mountedTrackKeys(tester);
      expect(afterKeys, isNotEmpty);
      expect(afterKeys.length, lessThan(projection.trackCount));
      // Scrolling should reveal different track identities.
      expect(
        afterKeys.intersection(beforeKeys).length,
        lessThan(afterKeys.length),
      );

      baseline.observe('mp17_mounted_before', beforeKeys.length);
      baseline.observe('mp17_mounted_after', afterKeys.length);
      baseline.observe('mp17_track_count', projection.trackCount);
      baseline.observe(
        'mp17_album_detail_note',
        'MusicAlbumDetailScreen eagerly spreads all track tiles into ListView '
            'children — Step 4 rendering candidate',
      );
    });

    testWidgets('MP18 — navigation and scroll-state retention baseline',
        (tester) async {
      final catalog = phase56SmallCatalog();
      final service = MusicLibraryService();
      final projection = service.projectionFor(catalog);
      final artist = projection.artists.first;
      final album = artist.albums.first;
      await _configureViewport(tester);

      await tester.pumpWidget(
        _musicHarness(
          catalog: catalog,
          musicLibrary: service,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll artists list.
      await tester.drag(
        find.byKey(const Key('music_artists_list')),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _musicHarness(
          catalog: catalog,
          musicLibrary: service,
          child: MusicArtistDetailScreen(artistGroupKey: artist.groupKey),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(artist.displayName), findsWidgets);

      await tester.pumpWidget(
        _musicHarness(
          catalog: catalog,
          musicLibrary: service,
          child: MusicAlbumDetailScreen(albumGroupKey: album.groupKey),
        ),
      );
      await tester.pumpAndSettle();

      // Return to artists list — current production pattern rebuilds the
      // screen widget; MaterialPageRoute scroll retention is not used here.
      await tester.pumpWidget(
        _musicHarness(
          catalog: catalog,
          musicLibrary: service,
          child: const MusicArtistsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('music_artists_list')), findsOneWidget);

      // Projection must remain the memoised instance across navigations.
      expect(
        identical(service.projectionFor(catalog), projection),
        isTrue,
      );
      baseline.observe(
        'mp18_scroll_retention',
        'not retained across pumped screen replacements — baseline documented; '
            'Navigator route retention deferred to Step 4 if needed',
      );
      baseline.observe('mp18_projection_reused', true);
    });
  });

  group('Phase 5.6 optional live catalogue', () {
    test('MP-LIVE — skipped without PHASE_56_LOCAL_CATALOG', () async {
      final path = Platform.environment['PHASE_56_LOCAL_CATALOG'];
      if (path == null || path.isEmpty) {
        baseline.liveCatalogStatus = 'skipped — PHASE_56_LOCAL_CATALOG unset';
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
      final samples = baseline.measureSyncSamples(
        operation: () {
          projection = MusicLibraryProjection.build(catalog!);
        },
      );

      final audioCount = catalog!.allItems.where((i) => i.isAudio).length;
      baseline.liveCatalogStatus =
          'loaded schema=${catalog.catalogueInfo?.catalogueVersion} '
          'total=${catalog.totalItems} audio=$audioCount '
          'artists=${projection.artistCount} albums=${projection.albumCount} '
          'load_ms=${loadSw.elapsedMilliseconds}';
      baseline.add(
        Phase56BaselineResult(
          scenarioId: 'MP-LIVE',
          operation: 'live_projection_build',
          catalogueItemCount: catalog.totalItems,
          audioItemCount: audioCount,
          artistCount: projection.artistCount,
          albumCount: projection.albumCount,
          samples: samples,
          classification: 'informational',
          notes: 'aggregates only — no paths printed',
        ),
      );
    });
  });
}

void _runProjectionScenario({
  required Phase56PerformanceBaseline baseline,
  required String scenarioId,
  required Phase56CatalogProfile profile,
}) {
  final genSw = Stopwatch()..start();
  final catalog = generatePhase56MusicCatalog(profile: profile);
  genSw.stop();
  baseline.observe(
    '${scenarioId.toLowerCase()}_fixture_gen_ms',
    genSw.elapsedMilliseconds,
  );

  final expectedAudio = phase56ExpectedAudioCount(profile: profile);
  late MusicLibraryProjection projection;
  final samples = baseline.measureSyncSamples(
    operation: () {
      projection = MusicLibraryProjection.build(catalog);
    },
  );

  expect(projection.trackCount, expectedAudio);
  expect(projection.artistCount, greaterThan(0));
  expect(projection.albumCount, greaterThan(0));
  expect(projection.tracks.every((t) => t.isAudio), isTrue);
  for (final track in projection.tracks) {
    expect(projection.findTrackById(track.id)?.id, track.id);
  }
  expect(projection.tracks.any((t) => t.isVideo || t.isImage), isFalse);

  baseline.add(
    Phase56BaselineResult(
      scenarioId: scenarioId,
      operation: 'projection_build',
      catalogueItemCount: catalog.totalItems,
      audioItemCount: projection.trackCount,
      artistCount: projection.artistCount,
      albumCount: projection.albumCount,
      samples: samples,
      classification: 'informational',
    ),
  );
}

Future<void> _runSearchScenario({
  required Phase56PerformanceBaseline baseline,
  required String scenarioId,
  required Phase56CatalogProfile profile,
  required String query,
  required String expectMatchId,
}) async {
  final catalog = generatePhase56MusicCatalog(profile: profile);
  final search = SearchService();

  final indexSw = Stopwatch()..start();
  await search.ensureIndex(catalog);
  indexSw.stop();
  baseline.observe(
    '${scenarioId.toLowerCase()}_index_ms',
    indexSw.elapsedMilliseconds,
  );

  late List results;
  final samples = await baseline.measureSamples(
    operation: () async {
      results = await search.searchCatalog(
        catalog,
        query,
        const SearchFilters(),
      );
    },
  );

  expect(results, isNotEmpty);
  expect(results.any((r) => r.item.id == expectMatchId), isTrue);
  final orderedIds = results.map((r) => r.item.id).toList();
  final again = await search.searchCatalog(
    catalog,
    query,
    const SearchFilters(),
  );
  expect(again.map((r) => r.item.id).toList(), orderedIds);

  final projection = MusicLibraryProjection.build(catalog);
  baseline.add(
    Phase56BaselineResult(
      scenarioId: scenarioId,
      operation: 'search_$query'.replaceAll('PHASE56-SENTINEL-', ''),
      catalogueItemCount: catalog.totalItems,
      audioItemCount: projection.trackCount,
      artistCount: projection.artistCount,
      albumCount: projection.albumCount,
      samples: samples,
      classification: 'informational',
      notes: 'hits=${results.length} (capped at ${SearchService.maxResults})',
    ),
  );
}

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  // ignore: prefer_final_fields — stub may swap catalogue in future tests
  Catalog? _catalog;

  @override
  Catalog? get catalog => _catalog;

  @override
  bool get isLoading => false;
}

Widget _musicHarness({
  required Catalog catalog,
  required Widget child,
  MusicLibraryService? musicLibrary,
}) {
  SharedPreferences.setMockInitialValues({});
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsRepository>.value(
        value: SettingsRepository(),
      ),
      ChangeNotifierProvider<LibraryMetadataRepository>(
        create: (_) => LibraryMetadataRepository(),
      ),
      Provider<MediaLocationResolver>.value(
        value: MediaLocationResolver(
          config: MediaAccessConfig.defaults(),
          isWindowsDesktop: false,
        ),
      ),
      Provider<ArtworkService>.value(
        value: ArtworkService(fileExists: (_) => false),
      ),
      Provider<SearchService>.value(value: SearchService()),
      Provider<MusicLibraryService>.value(
        value: musicLibrary ?? MusicLibraryService(),
      ),
      ChangeNotifierProvider<CatalogService>.value(
        value: _FakeCatalogService(catalog),
      ),
      ChangeNotifierProvider<PlaybackService>.value(value: PlaybackService()),
      ChangeNotifierProvider<MusicListeningRepository>.value(
        value: MusicListeningRepository(),
      ),
      ChangeNotifierProvider<ScannerService>.value(value: ScannerService()),
      ChangeNotifierProvider<ScanHistoryService>.value(
        value: ScanHistoryService(),
      ),
      ChangeNotifierProvider<MediaProviderConfigService>(
        create: (_) => MediaProviderConfigService(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> _configureViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Set<String> _mountedTrackKeys(WidgetTester tester) {
  return find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('music_track_'),
      )
      .evaluate()
      .map((e) => (e.widget.key as ValueKey<String>).value)
      .toSet();
}
