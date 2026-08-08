import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import 'package:ttsplayer/features/search/models/search_filters.dart';
import 'package:ttsplayer/features/search/search_service.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';

// -- Fixture helpers ---------------------------------------------------

Catalog _catalogWith(
  List<MediaItem> items, {
  String identity = 'cat-rank-1',
  String libraryName = 'Books',
  String libraryPath = r'Y:\Media\Books',
}) {
  return Catalog.fromJson({
    'generated_at': '2026-08-06T00:00:00+00:00',
    'total_items': items.length,
    'catalogue': {
      'id': identity,
      'scanner_version': '0.8.0',
      'catalogue_version': 4,
    },
    'folders': [
      MediaFolder(
        id: 'lib-main',
        name: libraryName,
        path: libraryPath,
        itemCount: items.length,
        items: items,
        subfolders: const [],
      ).toJson(),
    ],
  });
}

MediaItem _book({
  required String id,
  required String title,
  String? author,
  String? series,
  int? year,
  String? path,
}) {
  return MediaItem(
    id: id,
    title: title,
    author: author,
    series: series,
    year: year,
    filePath: path ?? 'Y:\\Media\\Books\\$id.epub',
    mediaKindRaw: MediaKind.book.catalogueValue,
  );
}

MediaItem _video({required String id, required String title, String? path}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: path ?? 'Y:\\Media\\Books\\$id.mp4',
    mediaKindRaw: MediaKind.video.catalogueValue,
  );
}

EnrichmentFieldValue _providerField(String value) => EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.provider,
      providerId: 'open_library',
    );

EnrichmentFieldValue _overrideField(String value) => EnrichmentFieldValue(
    value: value, source: EnrichmentFieldSource.userOverride);

EnrichmentFieldValue _providerList(List<String> values) =>
    _providerField(jsonEncode(values));

MetadataEnrichmentRecord _record({
  required String itemId,
  EnrichmentMatchState matchState = EnrichmentMatchState.linkedManual,
  Map<String, EnrichmentFieldValue> fields = const {},
}) {
  return MetadataEnrichmentRecord(
    itemId: itemId,
    matchState: matchState,
    providerId: 'open_library',
    fields: fields,
  );
}

SearchService _serviceFor(
  Catalog catalog, {
  List<MetadataEnrichmentRecord> records = const [],
}) {
  final repository = MetadataEnrichmentRepository(initialRecords: records);
  final service = SearchService(enrichmentRepository: repository);
  service.buildIndex(catalog);
  return service;
}

int _scoreOf(SearchService service, String query, String itemId) {
  final results = service.search(query, const SearchFilters.empty());
  final hit = results.where((r) => r.item.id == itemId);
  expect(hit, isNotEmpty, reason: 'expected "$itemId" to match "$query"');
  return hit.first.score;
}

void _expectAbsent(SearchService service, String query, String itemId) {
  final results = service.search(query, const SearchFilters.empty());
  expect(
    results.any((r) => r.item.id == itemId),
    isFalse,
    reason: 'expected "$itemId" to be absent for "$query"',
  );
}

void main() {
  group('1. Catalogue title scoring unchanged', () {
    test('exact, prefix, and contains scores', () {
      final exactService = _serviceFor(
          _catalogWith([_book(id: 'exact-item', title: 'Copper Wren')]));
      expect(_scoreOf(exactService, 'copper wren', 'exact-item'), 100);

      final prefixService = _serviceFor(
        _catalogWith([_book(id: 'prefix-item', title: 'Copper Wren Rises')]),
      );
      expect(_scoreOf(prefixService, 'copper wren', 'prefix-item'), 80);

      final containsService = _serviceFor(
        _catalogWith(
            [_book(id: 'contains-item', title: 'The Copper Wren Sings')]),
      );
      expect(_scoreOf(containsService, 'copper wren', 'contains-item'), 60);
    });
  });

  group('2. Exact normalized ISBN score', () {
    test('ISBN-only match scores exactly 70', () {
      final catalog =
          _catalogWith([_book(id: 'isbn-only', title: 'Quiet Star')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'isbn-only',
            fields: {
              EnrichmentBookFieldKeys.isbn13: _providerField('9780134685991'),
            },
          ),
        ],
      );

      expect(_scoreOf(service, '9780134685991', 'isbn-only'), 70);
    });
  });

  group('3. Formatted and unformatted ISBN equivalence', () {
    test('hyphenated and unformatted queries score identically', () {
      final catalog =
          _catalogWith([_book(id: 'isbn-only', title: 'Quiet Star')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'isbn-only',
            fields: {
              EnrichmentBookFieldKeys.isbn13: _providerField('9780134685991'),
            },
          ),
        ],
      );

      final unformatted = _scoreOf(service, '9780134685991', 'isbn-only');
      final formatted = _scoreOf(service, '978-0-13-468599-1', 'isbn-only');
      expect(formatted, unformatted);
      expect(formatted, 70);
    });
  });

  group('4. Eligible enriched-title scores', () {
    test('exact, prefix, and contains', () {
      final exactService = _serviceFor(
        _catalogWith([_book(id: 'title-exact', title: 'Machine Nine')]),
        records: [
          _record(
            itemId: 'title-exact',
            fields: {
              EnrichmentBookFieldKeys.title: _providerField('Galactic Voyage')
            },
          ),
        ],
      );
      expect(_scoreOf(exactService, 'galactic voyage', 'title-exact'), 55);

      final prefixService = _serviceFor(
        _catalogWith([_book(id: 'title-prefix', title: 'Machine Nine')]),
        records: [
          _record(
            itemId: 'title-prefix',
            fields: {
              EnrichmentBookFieldKeys.title:
                  _providerField('Galactic Voyage Chronicles'),
            },
          ),
        ],
      );
      expect(_scoreOf(prefixService, 'galactic voyage', 'title-prefix'), 45);

      final containsService = _serviceFor(
        _catalogWith([_book(id: 'title-contains', title: 'Machine Nine')]),
        records: [
          _record(
            itemId: 'title-contains',
            fields: {
              EnrichmentBookFieldKeys.title:
                  _providerField('The Galactic Voyage Begins'),
            },
          ),
        ],
      );
      expect(
          _scoreOf(containsService, 'galactic voyage', 'title-contains'), 35);
    });
  });

  group('5. Enriched title equal to catalogue title', () {
    test('does not double-score', () {
      final catalog =
          _catalogWith([_book(id: 'same-title', title: 'Same Title Book')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'same-title',
            fields: {
              EnrichmentBookFieldKeys.title: _providerField('SAME TITLE BOOK'),
            },
          ),
        ],
      );

      expect(_scoreOf(service, 'same title book', 'same-title'), 100);
    });
  });

  group('6. Catalogue and enriched author dedupe', () {
    test('identical values contribute the author tier once', () {
      final catalog = _catalogWith([
        _book(id: 'author-dedupe', title: 'Quiet Harbor', author: 'Jane Doe'),
      ]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'author-dedupe',
            fields: {
              EnrichmentBookFieldKeys.authors: _providerList(['Jane Doe']),
            },
          ),
        ],
      );

      expect(_scoreOf(service, 'jane doe', 'author-dedupe'), 25);
    });
  });

  group('7. Publisher, subject, and year matching', () {
    test('each contributes the combined tier once', () {
      final catalog =
          _catalogWith([_book(id: 'combined-item', title: 'Quiet Orbit')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'combined-item',
            fields: {
              EnrichmentBookFieldKeys.publishers: _providerList(['Acme Press']),
              EnrichmentBookFieldKeys.subjects: _providerList(['Astrophysics']),
              EnrichmentBookFieldKeys.publicationYear: _providerField('2011'),
            },
          ),
        ],
      );

      expect(_scoreOf(service, 'acme press', 'combined-item'), 15);
      expect(_scoreOf(service, 'astrophysics', 'combined-item'), 15);
      expect(_scoreOf(service, '2011', 'combined-item'), 15);
    });
  });

  group('8. Each ranking category contributes at most once', () {
    test('multiple matching title values still score the best tier once', () {
      final catalog =
          _catalogWith([_book(id: 'multi-title', title: 'Quiet Base')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'multi-title',
            fields: {
              EnrichmentBookFieldKeys.title: _providerField(
                jsonEncode([
                  'Exact Match Title Extended',
                  'Exact Match Title',
                ]),
              ),
            },
          ),
        ],
      );

      expect(_scoreOf(service, 'exact match title', 'multi-title'), 55);
    });

    test('multiple matching authors still score the author tier once', () {
      final catalog =
          _catalogWith([_book(id: 'multi-author', title: 'Quiet Base Two')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'multi-author',
            fields: {
              EnrichmentBookFieldKeys.authors:
                  _providerList(['Painter John', 'Painter Johnny']),
            },
          ),
        ],
      );

      expect(_scoreOf(service, 'painter john', 'multi-author'), 25);
    });
  });

  group('9. Additive score across categories', () {
    test('title, author, and publisher tiers sum', () {
      final catalog = _catalogWith([
        _book(
          id: 'additive-item',
          title: 'The Orion Relay Chronicles',
          author: 'Orion Relay Team',
        ),
      ]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'additive-item',
            fields: {
              EnrichmentBookFieldKeys.publishers:
                  _providerList(['Orion Relay Press']),
            },
          ),
        ],
      );

      // title contains (60) + author (25) + publisher (15) = 100.
      expect(_scoreOf(service, 'orion relay', 'additive-item'), 100);
    });
  });

  group('10. AND-based token eligibility', () {
    test('all tokens must match across catalogue and enrichment fields', () {
      final catalog = _catalogWith([_book(id: 'widget-item', title: 'Widget')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'widget-item',
            fields: {
              EnrichmentBookFieldKeys.authors: _providerList(['Painter'])
            },
          ),
        ],
      );

      expect(
        service.search('widget painter', const SearchFilters.empty()),
        isNotEmpty,
      );
      expect(
        service.search('widget zzznotfound', const SearchFilters.empty()),
        isEmpty,
      );
    });
  });

  group('11. Deterministic tie-breaks', () {
    test('equal scores fall back to title then MediaItem.id', () {
      final catalog = _catalogWith([
        _book(id: 'beta-item', title: 'Echo Point'),
        _book(id: 'alpha-item', title: 'Echo Point'),
      ]);
      final service = _serviceFor(catalog);

      final results = service.search('echo point', const SearchFilters.empty());
      expect(
          results.map((r) => r.item.id).toList(), ['alpha-item', 'beta-item']);
    });
  });

  group('12. Local terms remain searchable when enrichment disagrees', () {
    test('catalogue and enriched titles are both independently searchable', () {
      final catalog =
          _catalogWith([_book(id: 'disagree-item', title: 'Old World')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'disagree-item',
            fields: {
              EnrichmentBookFieldKeys.title: _providerField('New World')
            },
          ),
        ],
      );

      expect(_scoreOf(service, 'old world', 'disagree-item'), 100);
      expect(_scoreOf(service, 'new world', 'disagree-item'), 55);
    });
  });

  group('13. Provider fields excluded outside accepted linked states', () {
    for (final state in [
      EnrichmentMatchState.ambiguous,
      EnrichmentMatchState.unmatched,
      EnrichmentMatchState.ignored,
      EnrichmentMatchState.stale,
    ]) {
      test('${state.name} hides provider terms but keeps catalogue title', () {
        final itemId = 'excluded-${state.name}';
        final catalog = _catalogWith([
          _book(id: itemId, title: 'Visible Catalogue Title ${state.name}')
        ]);
        final service = _serviceFor(
          catalog,
          records: [
            _record(
              itemId: itemId,
              matchState: state,
              fields: {
                EnrichmentBookFieldKeys.title:
                    _providerField('Hidden Provider Title'),
              },
            ),
          ],
        );

        _expectAbsent(service, 'hidden provider title', itemId);
        expect(
          _scoreOf(service, 'visible catalogue title ${state.name}', itemId),
          100,
        );
      });
    }
  });

  group('14. User overrides remain searchable in every match state', () {
    for (final state in EnrichmentMatchState.values) {
      test('${state.name} keeps override title searchable', () {
        final itemId = 'override-${state.name}';
        final catalog = _catalogWith(
            [_book(id: itemId, title: 'Base Title ${state.name}')]);
        final service = _serviceFor(
          catalog,
          records: [
            _record(
              itemId: itemId,
              matchState: state,
              fields: {
                EnrichmentBookFieldKeys.title:
                    _overrideField('Override Visible Title ${state.name}'),
              },
            ),
          ],
        );

        expect(
          service
              .search('override visible title ${state.name}',
                  const SearchFilters.empty())
              .any((r) => r.item.id == itemId),
          isTrue,
        );
      });
    }
  });

  group('15. Description and languages remain excluded', () {
    test('neither field is searchable', () {
      final catalog =
          _catalogWith([_book(id: 'desc-item', title: 'Plain Book Title')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'desc-item',
            fields: {
              EnrichmentBookFieldKeys.description:
                  _providerField('Secretwordxyz'),
              EnrichmentBookFieldKeys.languages: _providerField('Klingonish'),
            },
          ),
        ],
      );

      _expectAbsent(service, 'secretwordxyz', 'desc-item');
      _expectAbsent(service, 'klingonish', 'desc-item');
      expect(_scoreOf(service, 'plain book title', 'desc-item'), 100);
    });
  });

  group('16. Subject cap behaviour', () {
    test('only the first 8 subjects remain searchable', () {
      final catalog =
          _catalogWith([_book(id: 'subjects-item', title: 'Cap Test Book')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'subjects-item',
            fields: {
              EnrichmentBookFieldKeys.subjects: _providerList(
                List.generate(10, (i) => 'Sub${i + 1}'),
              ),
            },
          ),
        ],
      );

      for (var i = 1; i <= 8; i++) {
        expect(
          service.search('sub$i', const SearchFilters.empty()).any(
                (r) => r.item.id == 'subjects-item',
              ),
          isTrue,
          reason: 'Sub$i should be searchable',
        );
      }
      _expectAbsent(service, 'sub9', 'subjects-item');
      _expectAbsent(service, 'sub10', 'subjects-item');
    });
  });

  group('17. Cross-item enrichment isolation', () {
    test('one item\'s enrichment terms do not leak onto another', () {
      final catalog = _catalogWith([
        _book(id: 'iso-a', title: 'Isolation Alpha'),
        _book(id: 'iso-b', title: 'Isolation Beta'),
      ]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'iso-a',
            fields: {
              EnrichmentBookFieldKeys.isbn13: _providerField('9780134685991'),
            },
          ),
          _record(
            itemId: 'iso-b',
            fields: {
              EnrichmentBookFieldKeys.authors: _providerList(['Zephyr Cole']),
            },
          ),
        ],
      );

      final isbnHits =
          service.search('9780134685991', const SearchFilters.empty());
      expect(isbnHits.any((r) => r.item.id == 'iso-a'), isTrue);
      expect(isbnHits.any((r) => r.item.id == 'iso-b'), isFalse);

      final authorHits =
          service.search('zephyr cole', const SearchFilters.empty());
      expect(authorHits.any((r) => r.item.id == 'iso-b'), isTrue);
      expect(authorHits.any((r) => r.item.id == 'iso-a'), isFalse);
    });
  });

  group('18. No-record fallback', () {
    test('catalogue-only presentation still drives title and author scoring',
        () {
      final catalog = _catalogWith([
        _book(
          id: 'fallback-item',
          title: 'Fallback Title Case',
          author: 'Fallback Author',
        ),
      ]);
      final service = _serviceFor(catalog);

      expect(_scoreOf(service, 'fallback title case', 'fallback-item'), 100);
      expect(_scoreOf(service, 'fallback author', 'fallback-item'), 25);
    });
  });

  group('19. Non-book compatibility', () {
    test('stray enrichment record for a non-book item never leaks', () {
      final catalog =
          _catalogWith([_video(id: 'video-item', title: 'Racing Highlights')]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'video-item',
            fields: {
              EnrichmentBookFieldKeys.title: _providerField('Should Not Leak'),
            },
          ),
        ],
      );

      _expectAbsent(service, 'should not leak', 'video-item');
      expect(_scoreOf(service, 'racing highlights', 'video-item'), 100);
    });
  });

  group('Intentional ranking examples', () {
    test('exact ISBN vs. combined filename + path + folder contributions', () {
      final catalog = _catalogWith([
        _book(id: 'isbn-only', title: 'Quiet Star'),
        _book(
          id: 'filename-match',
          title: 'Bright Comet',
          path: r'Y:\Media\Books\9780134685991.epub',
        ),
        _book(
          id: 'folder-match',
          title: 'Silent Comet',
          path: r'Y:\Media\Books\9780134685991\9780134685991.epub',
        ),
      ]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'isbn-only',
            fields: {
              EnrichmentBookFieldKeys.isbn13: _providerField('9780134685991'),
            },
          ),
        ],
      );

      expect(_scoreOf(service, '9780134685991', 'isbn-only'), 70);
      expect(_scoreOf(service, '9780134685991', 'filename-match'), 70);
      expect(_scoreOf(service, '9780134685991', 'folder-match'), 90);
    });

    test('exact enriched title vs. combined author + publisher contributions',
        () {
      final catalog = _catalogWith([
        _book(id: 'title-exact', title: 'Star Log One'),
        _book(id: 'combo-item', title: 'Star Log Two'),
      ]);
      final service = _serviceFor(
        catalog,
        records: [
          _record(
            itemId: 'title-exact',
            fields: {
              EnrichmentBookFieldKeys.title: _providerField('Nebula Drift'),
            },
          ),
          _record(
            itemId: 'combo-item',
            fields: {
              EnrichmentBookFieldKeys.authors:
                  _providerList(['Nebula Drift Society']),
              EnrichmentBookFieldKeys.publishers:
                  _providerList(['Nebula Drift House']),
            },
          ),
        ],
      );

      final titleScore = _scoreOf(service, 'nebula drift', 'title-exact');
      final comboScore = _scoreOf(service, 'nebula drift', 'combo-item');
      expect(titleScore, 55);
      expect(comboScore, 40); // author (25) + publisher (15)
      expect(titleScore, greaterThan(comboScore));
    });
  });
}
