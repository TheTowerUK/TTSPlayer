import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';

import 'support/reading_progress_test_support.dart';

/// Calibre-style duplicate copies: same title, different folder IDs and paths.
const _id1233 = 'item-blott-1233';
const _id2722 = 'item-blott-2722';
const _path1233 =
    r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Blott on the Landscape (1233)\Blott on the Landscape.epub';
const _path2722 =
    r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Blott on the Landscape (2722)\Blott on the Landscape.epub';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Continue Reading identity', () {
    test(
      'folder, search, and Continue Reading share one record for the same catalogue item',
      () async {
        SharedPreferences.setMockInitialValues({});
        final catalog = _blottCatalog();
        final folderItem = catalog.findItemById(_id1233)!;
        final repository = await initializedReadingProgressRepository();
        final clock = Phase65TestClock();
        final coordinator = ReadingProgressCoordinator(
          repository: repository,
          now: clock.fn,
        );

        await _readVia(coordinator, clock, item: folderItem, spineIndex: 2);

        final search = SearchService();
        final hits = await search.searchCatalog(
          catalog,
          'Blott',
          const SearchFilters.empty(),
        );
        final searchHit = hits.singleWhere((hit) => hit.item.id == _id1233);
        final searchItem = catalog.findItemById(searchHit.item.id)!;
        expect(searchItem.id, folderItem.id);
        expect(searchItem.filePath, folderItem.filePath);

        await _readVia(coordinator, clock, item: searchItem, spineIndex: 5);

        final continueItem = const ContinueReadingProjection()
            .build(catalog: catalog, repository: repository)
            .single
            .item;
        await _readVia(coordinator, clock, item: continueItem, spineIndex: 8);

        expect(repository.allRecords, hasLength(1));
        expect(repository.allRecords.single.mediaId, _id1233);
        expect(
          (repository.allRecords.single.location as EpubReadingLocationPayload)
              .spineIndex,
          8,
        );

        final reloaded = ReadingProgressRepository();
        await reloaded.load();
        final afterRestart = const ContinueReadingProjection().build(
          catalog: catalog,
          repository: reloaded,
        );
        expect(afterRestart, hasLength(1));
        expect(afterRestart.single.item.id, _id1233);
        expect(afterRestart.single.item.filePath, _path1233);
        expect(
          (afterRestart.single.record.location as EpubReadingLocationPayload)
              .spineIndex,
          8,
        );

        coordinator.dispose();
      },
    );

    test(
      'two distinct files that share a title stay two Continue Reading rows',
      () async {
        SharedPreferences.setMockInitialValues({});
        final catalog = _blottCatalog();
        final copy1233 = catalog.findItemById(_id1233)!;
        final copy2722 = catalog.findItemById(_id2722)!;
        expect(copy1233.title, copy2722.title);
        expect(copy1233.id, isNot(copy2722.id));
        expect(copy1233.filePath, isNot(copy2722.filePath));

        final search = SearchService();
        final hits = await search.searchCatalog(
          catalog,
          'Blott on the Landscape',
          const SearchFilters.empty(),
        );
        expect(hits.map((hit) => hit.item.id).toSet(), {_id1233, _id2722});

        final repository = await initializedReadingProgressRepository();
        final clock = Phase65TestClock();
        final coordinator = ReadingProgressCoordinator(
          repository: repository,
          now: clock.fn,
        );

        await _readVia(coordinator, clock, item: copy1233, spineIndex: 2);
        await _readVia(coordinator, clock, item: copy2722, spineIndex: 6);

        var entries = const ContinueReadingProjection().build(
          catalog: catalog,
          repository: repository,
        );
        expect(entries, hasLength(2));
        expect(
          entries.map((entry) => entry.item.id).toSet(),
          {_id1233, _id2722},
        );
        expect(
          entries.map((entry) => entry.item.filePath).toSet(),
          {_path1233, _path2722},
        );

        final reloaded = ReadingProgressRepository();
        await reloaded.load();
        entries = const ContinueReadingProjection().build(
          catalog: catalog,
          repository: reloaded,
        );
        expect(entries, hasLength(2));
        final byId = {
          for (final entry in entries) entry.item.id: entry,
        };
        expect(
          (byId[_id1233]!.record.location as EpubReadingLocationPayload)
              .spineIndex,
          2,
        );
        expect(
          (byId[_id2722]!.record.location as EpubReadingLocationPayload)
              .spineIndex,
          6,
        );
        expect(byId[_id1233]!.item.filePath, _path1233);
        expect(byId[_id2722]!.item.filePath, _path2722);

        coordinator.dispose();
      },
    );
  });
}

Future<void> _readVia(
  ReadingProgressCoordinator coordinator,
  Phase65TestClock clock, {
  required MediaItem item,
  required int spineIndex,
}) async {
  coordinator.beginSession(
    item: item,
    readerFormat: ReadingReaderFormat.epub,
    initialLocation: const EpubReadingLocationPayload(
      spineIndex: 0,
      spineHref: 'ch1.xhtml',
      spineCountAtSave: 12,
    ),
    progressFraction: 0,
  );
  coordinator.markLayoutReady();
  coordinator.onLocationChanged(
    location: EpubReadingLocationPayload(
      spineIndex: spineIndex,
      spineHref: 'ch$spineIndex.xhtml',
      spineCountAtSave: 12,
    ),
    progressFraction: 0.2,
  );
  clock.advancePastDebounce();
  await Future<void>.delayed(ReadingProgressPolicy.persistDebounce);
  await coordinator.waitForIdleForTest();
}

Catalog _blottCatalog() {
  return Catalog.fromJson({
    'generated_at': '2026-11-10T00:00:00+00:00',
    'total_items': 2,
    'catalogue': {
      'id': 'BLOTT',
      'scanner_version': '1.0',
      'catalogue_version': 4,
    },
    'folders': [
      {
        'id': 'tom-sharpe',
        'name': 'Tom Sharpe',
        'path': r'Y:\Media\Literature\Books\Calibre\Tom Sharpe',
        'item_count': 0,
        'items': <Map<String, dynamic>>[],
        'subfolders': [
          {
            'id': 'folder-1233',
            'name': 'Blott on the Landscape (1233)',
            'path':
                r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Blott on the Landscape (1233)',
            'item_count': 1,
            'items': [
              {
                'id': _id1233,
                'title': 'Blott on the Landscape',
                'file_path': _path1233,
                'status': 'available',
                'media_kind': 'book',
              },
            ],
            'subfolders': <Map<String, dynamic>>[],
          },
          {
            'id': 'folder-2722',
            'name': 'Blott on the Landscape (2722)',
            'path':
                r'Y:\Media\Literature\Books\Calibre\Tom Sharpe\Blott on the Landscape (2722)',
            'item_count': 1,
            'items': [
              {
                'id': _id2722,
                'title': 'Blott on the Landscape',
                'file_path': _path2722,
                'status': 'available',
                'media_kind': 'book',
              },
            ],
            'subfolders': <Map<String, dynamic>>[],
          },
        ],
      },
    ],
  });
}
