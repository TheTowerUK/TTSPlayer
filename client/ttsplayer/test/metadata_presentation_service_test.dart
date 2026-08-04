import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/media_item_presentation.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_presentation_field.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_presentation_service.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';

void main() {
  const service = MetadataPresentationService();

  MediaItem book({
    String id = 'book-1',
    String title = 'Catalogue Title',
    String? author = 'Catalogue Author',
    String? series = 'Catalogue Series',
    int? year = 1999,
    String path = r'D:\media\Books\catalogue.epub',
  }) {
    return MediaItem(
      id: id,
      title: title,
      author: author,
      series: series,
      year: year,
      filePath: path,
      mediaKindRaw: MediaKind.book.catalogueValue,
    );
  }

  EnrichmentFieldValue providerField(String value, {String? providerId}) {
    return EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.provider,
      providerId: providerId ?? 'open_library',
    );
  }

  EnrichmentFieldValue overrideField(String value) {
    return EnrichmentFieldValue(
      value: value,
      source: EnrichmentFieldSource.userOverride,
    );
  }

  EnrichmentFieldValue providerList(List<String> values) {
    return providerField(jsonEncode(values));
  }

  EnrichmentFieldValue overrideList(List<String> values) {
    return overrideField(jsonEncode(values));
  }

  MetadataEnrichmentRecord record({
    EnrichmentMatchState matchState = EnrichmentMatchState.linkedManual,
    Map<String, EnrichmentFieldValue> fields = const {},
    String? providerId = 'open_library',
  }) {
    return MetadataEnrichmentRecord(
      itemId: 'book-1',
      matchState: matchState,
      providerId: providerId,
      providerRecordId: '/books/OL1M',
      fields: fields,
    );
  }

  group('catalogue-only projection', () {
    test('no record returns catalogue title and metadata', () {
      final item = book();
      final projection = service.build(item: item);

      expect(projection.displayTitle, 'Catalogue Title');
      expect(projection.displayAuthors, ['Catalogue Author']);
      expect(projection.displaySeries, 'Catalogue Series');
      expect(projection.displaySubtitle, isNull);
      expect(projection.displayPublishers, isEmpty);
      expect(projection.displayIsbns, isEmpty);
      expect(projection.displaySubjects, isEmpty);
      expect(projection.displayDescription, isNull);
      expect(projection.hasEnrichmentRecord, isFalse);
      expect(projection.hasVisibleProviderMetadata, isFalse);
      expect(projection.matchState, isNull);
      expect(projection.searchTitles, ['Catalogue Title']);
      expect(projection.searchAuthors, ['Catalogue Author']);
      expect(projection.searchSeries, ['Catalogue Series']);
      expect(projection.searchPublicationYears, ['1999']);
      expect(projection.titleField.provenance,
          MetadataPresentationProvenance.catalogue);
    });

    test('non-book kinds ignore enrichment records', () {
      for (final kind in [
        MediaKind.video,
        MediaKind.audio,
        MediaKind.image,
        MediaKind.comic,
        MediaKind.unknown,
      ]) {
        final item = MediaItem(
          id: 'item-${kind.name}',
          title: 'Local ${kind.name}',
          author: 'Should Not Leak',
          series: 'Series',
          filePath: 'x.${kind == MediaKind.audio ? 'mp3' : 'bin'}',
          mediaKindRaw: kind.catalogueValue,
        );
        final projection = service.build(
          item: item,
          record: record(
            fields: {
              EnrichmentBookFieldKeys.title: providerField('Provider Leak'),
              EnrichmentBookFieldKeys.authors:
                  providerList(['Provider Author']),
              EnrichmentBookFieldKeys.description:
                  providerField('Provider description'),
            },
          ),
        );

        expect(projection.displayTitle, 'Local ${kind.name}');
        expect(projection.hasEnrichmentRecord, isFalse);
        expect(projection.hasVisibleProviderMetadata, isFalse);
        expect(projection.displayDescription, isNull);
        expect(projection.searchTitles, ['Local ${kind.name}']);
        expect(projection.searchTitles, isNot(contains('Provider Leak')));
      }
    });
  });

  group('user override precedence', () {
    test('override wins over catalogue and provider for title and authors', () {
      final projection = service.build(
        item: book(),
        record: record(
          matchState: EnrichmentMatchState.linkedByIdentifier,
          fields: {
            EnrichmentBookFieldKeys.title: overrideField('Override Title'),
            EnrichmentBookFieldKeys.authors: overrideList(['Override Author']),
            EnrichmentBookFieldKeys.publishers:
                overrideList(['Override Press']),
            EnrichmentBookFieldKeys.description:
                overrideField('Override description'),
          },
        ),
      );

      expect(projection.displayTitle, 'Override Title');
      expect(projection.titleField.provenance,
          MetadataPresentationProvenance.userOverride);
      expect(projection.displayAuthors, ['Override Author']);
      expect(projection.authorsField.provenance,
          MetadataPresentationProvenance.userOverride);
      expect(projection.displayPublishers, ['Override Press']);
      expect(projection.displayDescription, 'Override description');
      expect(projection.hasUserOverrides, isTrue);
    });

    test('series remains catalogue-only (no enrichment series key)', () {
      final projection = service.build(
        item: book(series: 'Local Series'),
        record: record(
          fields: {
            EnrichmentBookFieldKeys.title: overrideField('Override Title'),
          },
        ),
      );
      expect(projection.displaySeries, 'Local Series');
      expect(projection.seriesField.provenance,
          MetadataPresentationProvenance.catalogue);
    });
  });

  group('catalogue precedence', () {
    test('catalogue title and author beat linked provider values', () {
      final projection = service.build(
        item: book(),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.title: providerField('Provider Title'),
            EnrichmentBookFieldKeys.authors: providerList(['Provider Author']),
            EnrichmentBookFieldKeys.subtitle: providerField('A Subtitle'),
            EnrichmentBookFieldKeys.publishers:
                providerList(['Provider Press']),
          },
        ),
      );

      expect(projection.displayTitle, 'Catalogue Title');
      expect(projection.titleField.provenance,
          MetadataPresentationProvenance.catalogue);
      expect(projection.displayAuthors, ['Catalogue Author']);
      expect(projection.displaySubtitle, 'A Subtitle');
      expect(projection.subtitleField.provenance,
          MetadataPresentationProvenance.provider);
      expect(projection.displayPublishers, ['Provider Press']);
      expect(projection.hasVisibleProviderMetadata, isTrue);
    });

    test('provider fills fields absent from catalogue', () {
      final projection = service.build(
        item: book(author: null, series: null, year: null, title: 'Only Title'),
        record: record(
          matchState: EnrichmentMatchState.linkedHighConfidence,
          fields: {
            EnrichmentBookFieldKeys.authors: providerList(['Prov Author']),
            EnrichmentBookFieldKeys.publicationYear: providerField('2012'),
            EnrichmentBookFieldKeys.isbn13: providerList(['978-0-14-044913-6']),
            EnrichmentBookFieldKeys.subjects:
                providerList(['Philosophy', 'Classics']),
            EnrichmentBookFieldKeys.description: providerField('A blurb'),
          },
        ),
      );

      expect(projection.displayAuthors, ['Prov Author']);
      expect(projection.authorsField.provenance,
          MetadataPresentationProvenance.provider);
      expect(projection.displayPublicationYear, '2012');
      expect(projection.displayIsbns, ['978-0-14-044913-6']);
      expect(projection.displaySubjects, ['Philosophy', 'Classics']);
      expect(projection.displayDescription, 'A blurb');
    });
  });

  group('linked provider states', () {
    for (final state in [
      EnrichmentMatchState.linkedByIdentifier,
      EnrichmentMatchState.linkedHighConfidence,
      EnrichmentMatchState.linkedManual,
    ]) {
      test('$state exposes provider presentation fields', () {
        final projection = service.build(
          item: book(author: null, year: null),
          record: record(
            matchState: state,
            fields: {
              EnrichmentBookFieldKeys.subtitle: providerField('Sub'),
              EnrichmentBookFieldKeys.authors: providerList(['A']),
              EnrichmentBookFieldKeys.publishers: providerList(['P']),
              EnrichmentBookFieldKeys.publicationYear: providerField('2001'),
              EnrichmentBookFieldKeys.isbn13: providerList(['9780140449136']),
              EnrichmentBookFieldKeys.subjects: providerList(['S1']),
              EnrichmentBookFieldKeys.description: providerField('Desc'),
            },
          ),
        );

        expect(projection.matchState, state);
        expect(projection.displaySubtitle, 'Sub');
        expect(projection.displayAuthors, ['A']);
        expect(projection.displayPublishers, ['P']);
        expect(projection.displayPublicationYear, '2001');
        expect(projection.displayIsbns, ['9780140449136']);
        expect(projection.displaySubjects, ['S1']);
        expect(projection.displayDescription, 'Desc');
        expect(projection.hasVisibleProviderMetadata, isTrue);
        expect(projection.searchIsbns, contains('9780140449136'));
        expect(projection.searchSubjects, contains('S1'));
      });
    }
  });

  group('excluded provider states', () {
    for (final state in [
      EnrichmentMatchState.ambiguous,
      EnrichmentMatchState.unmatched,
      EnrichmentMatchState.ignored,
      EnrichmentMatchState.stale,
    ]) {
      test('$state excludes provider text but keeps overrides', () {
        final projection = service.build(
          item: book(),
          record: record(
            matchState: state,
            fields: {
              EnrichmentBookFieldKeys.title: providerField('Provider Title'),
              EnrichmentBookFieldKeys.authors:
                  providerList(['Provider Author']),
              EnrichmentBookFieldKeys.publishers:
                  providerList(['Provider Press']),
              EnrichmentBookFieldKeys.description:
                  providerField('Provider description'),
              EnrichmentBookFieldKeys.isbn13: providerList(['9780140449136']),
              EnrichmentBookFieldKeys.subjects: providerList(['Hidden']),
              EnrichmentBookFieldKeys.subtitle: overrideField('Keep Sub'),
            },
          ),
        );

        expect(projection.matchState, state);
        expect(projection.isStale, state == EnrichmentMatchState.stale);
        expect(projection.displayTitle, 'Catalogue Title');
        expect(projection.displayAuthors, ['Catalogue Author']);
        expect(projection.displaySubtitle, 'Keep Sub');
        expect(projection.displayPublishers, isEmpty);
        expect(projection.displayDescription, isNull);
        expect(projection.displayIsbns, isEmpty);
        expect(projection.displaySubjects, isEmpty);
        expect(projection.hasVisibleProviderMetadata, isFalse);
        expect(projection.searchTitles, isNot(contains('Provider Title')));
        expect(projection.searchIsbns, isEmpty);
        expect(projection.searchSubjects, isEmpty);
        expect(projection.searchSubtitles, contains('Keep Sub'));
        expect(projection.hasUserOverrides, isTrue);
      });
    }
  });

  group('empty-value handling', () {
    test('blank override does not hide catalogue value', () {
      final projection = service.build(
        item: book(),
        record: record(
          fields: {
            EnrichmentBookFieldKeys.title: overrideField('   '),
            EnrichmentBookFieldKeys.authors: overrideList(['', '  ']),
          },
        ),
      );

      expect(projection.displayTitle, 'Catalogue Title');
      expect(projection.displayAuthors, ['Catalogue Author']);
    });

    test('blank catalogue permits linked provider fallback', () {
      final projection = service.build(
        item: book(author: '  ', year: null),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.authors: providerList(['Fallback Author']),
            EnrichmentBookFieldKeys.publicationYear: providerField('  '),
            EnrichmentBookFieldKeys.subtitle: providerField('Real Sub'),
          },
        ),
      );

      expect(projection.displayAuthors, ['Fallback Author']);
      expect(projection.displayPublicationYear, isNull);
      expect(projection.displaySubtitle, 'Real Sub');
    });

    test('whitespace is trimmed on display values', () {
      final projection = service.build(
        item: book(title: '  Trimmed Title  ', author: '  Auth  '),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.subtitle: providerField('  Sub  '),
          },
        ),
      );

      expect(projection.displayTitle, 'Trimmed Title');
      expect(projection.displayAuthors, ['Auth']);
      expect(projection.displaySubtitle, 'Sub');
    });
  });

  group('list normalisation', () {
    test('authors dedupe preserve order and lists are immutable', () {
      final projection = service.build(
        item: book(author: null),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.authors: providerList([
              'Ada',
              'ada',
              'Bea',
              '',
              'Bea',
            ]),
          },
        ),
      );

      expect(projection.displayAuthors, ['Ada', 'Bea']);
      expect(
        () => projection.displayAuthors.add('Mutate'),
        throwsUnsupportedError,
      );
    });

    test('subjects cap display at 12 and search at 8', () {
      final many = List<String>.generate(20, (i) => 'Subject $i');
      final projection = service.build(
        item: book(author: null),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.subjects: providerList(many),
          },
        ),
      );

      expect(projection.displaySubjects, hasLength(12));
      expect(projection.displaySubjects.first, 'Subject 0');
      expect(projection.displaySubjects.last, 'Subject 11');
      expect(projection.searchSubjects, hasLength(8));
      expect(projection.searchSubjects.last, 'Subject 7');
    });

    test('ISBNs dedupe across isbn10/isbn13 fields', () {
      final projection = service.build(
        item: book(author: null),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.isbn13:
                providerList(['9780140449136', '9780140449136']),
            EnrichmentBookFieldKeys.isbn10: providerList(['0140449132']),
          },
        ),
      );

      expect(projection.displayIsbns, ['9780140449136', '0140449132']);
    });
  });

  group('structured search projection', () {
    test('includes catalogue terms even when override changes display', () {
      final projection = service.build(
        item: book(),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.title: overrideField('Override Title'),
            EnrichmentBookFieldKeys.authors: overrideList(['Override Author']),
            EnrichmentBookFieldKeys.subtitle: providerField('Provider Sub'),
            EnrichmentBookFieldKeys.publishers:
                providerList(['Provider Press']),
            EnrichmentBookFieldKeys.isbn13: providerList(['9780140449136']),
            EnrichmentBookFieldKeys.subjects: providerList(['Ethics']),
            EnrichmentBookFieldKeys.description:
                providerField('Long description text'),
            EnrichmentBookFieldKeys.languages: providerList(['eng']),
          },
        ),
      );

      expect(projection.searchTitles,
          containsAll(['Catalogue Title', 'Override Title']));
      expect(
        projection.searchAuthors,
        containsAll(['Catalogue Author', 'Override Author']),
      );
      expect(projection.searchSeries, ['Catalogue Series']);
      expect(projection.searchSubtitles, contains('Provider Sub'));
      expect(projection.searchPublishers, contains('Provider Press'));
      expect(projection.searchPublicationYears, contains('1999'));
      expect(projection.searchIsbns, contains('9780140449136'));
      expect(projection.searchSubjects, contains('Ethics'));
      expect(projection.searchKeywords, isNot(contains('Long description')));
      expect(projection.searchKeywords.toLowerCase(), isNot(contains('eng')));
      expect(projection.searchKeywords, contains('Override Title'));
    });

    test('excluded states contribute no provider search values', () {
      final projection = service.build(
        item: book(),
        record: record(
          matchState: EnrichmentMatchState.stale,
          fields: {
            EnrichmentBookFieldKeys.title: providerField('Stale Title'),
            EnrichmentBookFieldKeys.isbn13: providerList(['9780140449136']),
            EnrichmentBookFieldKeys.subjects: providerList(['Stale Subject']),
          },
        ),
      );

      expect(projection.searchTitles, ['Catalogue Title']);
      expect(projection.searchIsbns, isEmpty);
      expect(projection.searchSubjects, isEmpty);
    });
  });

  group('provenance', () {
    test('reports override, catalogue, provider, and absent', () {
      final projection = service.build(
        item: book(author: 'Cat Author', year: null),
        record: record(
          matchState: EnrichmentMatchState.linkedManual,
          fields: {
            EnrichmentBookFieldKeys.title: overrideField('Override'),
            EnrichmentBookFieldKeys.subtitle: providerField('Sub'),
          },
        ),
      );

      expect(projection.titleField.provenance,
          MetadataPresentationProvenance.userOverride);
      expect(projection.authorsField.provenance,
          MetadataPresentationProvenance.catalogue);
      expect(projection.subtitleField.provenance,
          MetadataPresentationProvenance.provider);
      expect(projection.descriptionField.provenance,
          MetadataPresentationProvenance.absent);
      expect(projection.descriptionField.hasValue, isFalse);
    });
  });

  group('determinism and immutability', () {
    test('equivalent inputs produce equal projections', () {
      final item = book();
      final enrichment = record(
        matchState: EnrichmentMatchState.linkedManual,
        fields: {
          EnrichmentBookFieldKeys.subtitle: providerField('Sub'),
          EnrichmentBookFieldKeys.authors: providerList(['A', 'B']),
        },
      );

      final a = service.build(item: item, record: enrichment);
      final b = service.build(item: item, record: enrichment);

      expect(a, b);
      expect(a.searchTitles, b.searchTitles);
      expect(a.displayAuthors, b.displayAuthors);
      expect(
        () => a.searchTitles.add('x'),
        throwsUnsupportedError,
      );
    });
  });

  group('no provider I/O', () {
    test('build is pure and does not require provider wiring', () {
      // Compile-time: service depends only on models + IsbnEquivalence.
      // Runtime: building many projections never throws and stays offline.
      MediaItemPresentation? last;
      for (var i = 0; i < 20; i++) {
        last = service.build(
          item: book(id: 'book-$i', title: 'Title $i'),
          record: record(
            fields: {
              EnrichmentBookFieldKeys.subtitle: providerField('Sub $i'),
            },
          ),
        );
      }
      expect(last, isNotNull);
      expect(last!.displaySubtitle, 'Sub 19');
    });
  });
}
