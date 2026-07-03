import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';

Catalog _catalogWithItems() {
  return Catalog.fromJson({
    'generated_at': '2026-07-01T10:00:00+00:00',
    'total_items': 3,
    'sources': [
      {
        'name': 'NAS Media',
        'root_path': r'Y:\Media',
        'type': 'smb',
        'accessible': true,
      },
    ],
    'catalogue': {
      'id': 'test-catalogue-1',
      'scanner_version': '0.3.0',
      'catalogue_version': 2,
      'supported_extensions': ['mp4', 'mkv'],
    },
    'folders': [
      const MediaFolder(
        id: 'lib-videos',
        name: 'Videos',
        path: r'Y:\Media\Videos',
        itemCount: 2,
        items: [
          MediaItem(
            id: 'item-1',
            title: 'The Grand Adventure',
            filePath: r'Y:\Media\Videos\grand_adventure.mp4',
          ),
          MediaItem(
            id: 'item-2',
            title: 'Ocean Documentary',
            filePath: r'Y:\Media\Videos\Docs\ocean.mkv',
          ),
        ],
        subfolders: [
          MediaFolder(
            id: 'sub-docs',
            name: 'Docs',
            path: r'Y:\Media\Videos\Docs',
            itemCount: 1,
            items: [],
            subfolders: [],
          ),
        ],
      ).toJson(),
      const MediaFolder(
        id: 'lib-music',
        name: 'Music',
        path: r'Y:\Media\Music',
        itemCount: 1,
        items: [
          MediaItem(
            id: 'item-3',
            title: 'Live Concert',
            filePath: r'Y:\Media\Music\concert.mp4',
          ),
        ],
        subfolders: [],
      ).toJson(),
    ],
  });
}

void main() {
  late SearchService service;

  setUp(() {
    service = SearchService();
    service.buildIndex(_catalogWithItems());
  });

  test('empty query returns no results', () {
    expect(service.search('', const SearchFilters.empty()), isEmpty);
    expect(service.search('   ', const SearchFilters.empty()), isEmpty);
  });

  test('matches title tokens with AND logic', () {
    final results = service.search('grand adventure', const SearchFilters.empty());
    expect(results, isNotEmpty);
    expect(results.first.item.id, 'item-1');
  });

  test('matches filename and path', () {
    final byFile = service.search('ocean.mkv', const SearchFilters.empty());
    expect(byFile.any((r) => r.item.id == 'item-2'), isTrue);

    final byPath = service.search(r'videos\docs', const SearchFilters.empty());
    expect(byPath.any((r) => r.item.id == 'item-2'), isTrue);
  });

  test('library filter limits results', () {
    final results = service.search(
      'mp4',
      const SearchFilters(libraryName: 'Music'),
    );
    expect(results.every((r) => r.libraryName == 'Music'), isTrue);
    expect(results.any((r) => r.item.id == 'item-3'), isTrue);
    expect(results.any((r) => r.item.id == 'item-1'), isFalse);
  });

  test('extension filter limits results', () {
    final results = service.search(
      'ocean',
      const SearchFilters(extension: 'mkv'),
    );
    expect(results, hasLength(1));
    expect(results.first.item.extension, 'mkv');
  });

  test('ranks exact title matches ahead of path-only matches', () {
    final results = service.search('Ocean Documentary', const SearchFilters.empty());
    expect(results.first.item.id, 'item-2');
  });

  test('includes folder context on results', () {
    final results = service.search('ocean', const SearchFilters.empty());
    expect(results.first.libraryName, 'Videos');
    expect(results.first.folderContext, contains('Videos'));
  });
}
