import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_book_field_keys.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_source.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_field_value.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/normalized_book_metadata.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_attribution.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/provider_book_candidate.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_item.dart' show MediaItemStatus;
import 'package:ttsplayer/models/media_kind.dart';

/// Deterministic Phase 7.3.6 runtime fixture catalogue (synthetic only).
class Phase736Fixtures {
  Phase736Fixtures._();

  static const catalogIdentity = 'PHASE736-RUNTIME';
  static const providerId = 'phase736_fake';
  static const providerDisplayName = 'Phase 736 Fake Books';

  static const bookAId = 'm736-book-a';
  static const bookBId = 'm736-book-b';
  static const bookCId = 'm736-book-c';
  static const bookDId = 'm736-book-d';
  static const bookEId = 'm736-book-e';
  static const bookFId = 'm736-book-f';
  static const bookGId = 'm736-book-g';
  static const videoId = 'm736-video';

  static const bookATitle = 'PHASE736 Book A Strong Match';
  static const bookBTitle = 'PHASE736 Book B Conflict';
  static const bookCTitle = 'PHASE736 Book C Manual Link';
  static const bookDTitle = 'PHASE736 Book D Ignored';
  static const bookETitle = 'PHASE736 Book E Rematch';
  static const bookFTitle = 'PHASE736 Book F Empty';
  static const bookGTitle = 'PHASE736 Book G Failure';
  static const videoTitle = 'PHASE736 Sample Video';

  static const recordStrong = '/books/M736-A-STRONG';
  static const recordSecondary = '/books/M736-A-SECONDARY';
  static const recordConflict = '/books/M736-B-CONFLICT';
  static const recordLinkedC = '/books/M736-C-LINKED';
  static const recordLinkedE = '/books/M736-E-LINKED';
  static const recordAltE = '/books/M736-E-ALT';

  static final fetchedAt = DateTime.utc(2026, 8, 3, 12);

  static const attribution = ProviderAttribution(
    providerId: providerId,
    displayName: providerDisplayName,
  );

  static MediaItem bookA() => _book(
        id: bookAId,
        title: bookATitle,
        author: 'Author Alpha',
        year: 2020,
        path: r'C:\Runtime\PHASE736\Books\book-a.epub',
      );

  static MediaItem bookB() => _book(
        id: bookBId,
        title: bookBTitle,
        author: 'Author Beta',
        year: 2019,
        path: r'C:\Runtime\PHASE736\Books\book-b.epub',
      );

  static MediaItem bookC() => _book(
        id: bookCId,
        title: bookCTitle,
        author: 'Author Gamma',
        year: 2018,
        path: r'C:\Runtime\PHASE736\Books\book-c.epub',
      );

  static MediaItem bookD() => _book(
        id: bookDId,
        title: bookDTitle,
        author: 'Author Delta',
        year: 2017,
        path: r'C:\Runtime\PHASE736\Books\book-d.epub',
      );

  static MediaItem bookE() => _book(
        id: bookEId,
        title: bookETitle,
        author: 'Author Epsilon',
        year: 2016,
        path: r'C:\Runtime\PHASE736\Books\book-e.epub',
      );

  static MediaItem bookF() => _book(
        id: bookFId,
        title: bookFTitle,
        author: 'Author Zeta',
        year: 2015,
        path: r'C:\Runtime\PHASE736\Books\book-f.epub',
      );

  static MediaItem bookG() => _book(
        id: bookGId,
        title: bookGTitle,
        author: 'Author Eta',
        year: 2014,
        path: r'C:\Runtime\PHASE736\Books\book-g.epub',
      );

  static MediaItem videoItem() => MediaItem(
        id: videoId,
        title: videoTitle,
        filePath: r'C:\Runtime\PHASE736\Movies\sample.mp4',
        status: MediaItemStatus.available,
        mediaKindRaw: MediaKind.video.catalogueValue,
      );

  static List<MediaItem> allBooks() => [
        bookA(),
        bookB(),
        bookC(),
        bookD(),
        bookE(),
        bookF(),
        bookG(),
      ];

  static MetadataEnrichmentRecord seedManualLinkC() {
    return MetadataEnrichmentRecord(
      itemId: bookCId,
      matchState: EnrichmentMatchState.linkedManual,
      providerId: providerId,
      providerRecordId: recordLinkedC,
      matchMethod: EnrichmentMatchMethod.manual,
      confidence: 0.92,
      fields: {
        EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
          value: bookCTitle,
          source: EnrichmentFieldSource.provider,
        ),
        EnrichmentBookFieldKeys.authors: EnrichmentFieldValue(
          value: 'Author Gamma',
          source: EnrichmentFieldSource.provider,
        ),
      },
      fetchedAt: fetchedAt,
    );
  }

  static MetadataEnrichmentRecord seedIgnoredD() {
    return MetadataEnrichmentRecord(
      itemId: bookDId,
      matchState: EnrichmentMatchState.ignored,
      fetchedAt: fetchedAt,
    );
  }

  static MetadataEnrichmentRecord seedRematchE() {
    return MetadataEnrichmentRecord(
      itemId: bookEId,
      matchState: EnrichmentMatchState.linkedManual,
      providerId: providerId,
      providerRecordId: recordLinkedE,
      matchMethod: EnrichmentMatchMethod.manual,
      confidence: 0.88,
      fields: {
        EnrichmentBookFieldKeys.title: EnrichmentFieldValue(
          value: 'Provider Title E',
          source: EnrichmentFieldSource.provider,
        ),
        EnrichmentBookFieldKeys.authors: EnrichmentFieldValue(
          value: 'Author Epsilon',
          source: EnrichmentFieldSource.provider,
          locked: true,
        ),
        EnrichmentBookFieldKeys.publishers: EnrichmentFieldValue(
          value: 'Stale Publisher',
          source: EnrichmentFieldSource.provider,
        ),
      },
      lockedFields: [EnrichmentBookFieldKeys.authors],
      fetchedAt: fetchedAt,
    );
  }

  static ProviderBookCandidate candidate({
    required String recordId,
    required String title,
    required List<String> authors,
    int? year,
    List<String> isbn13 = const [],
    List<String> publishers = const ['Fixture Publisher'],
    List<String> languages = const ['eng'],
    List<String> subjects = const ['Fantasy series'],
    String? subtitle,
  }) {
    return ProviderBookCandidate(
      metadata: NormalizedBookMetadata(
        providerId: providerId,
        providerRecordId: recordId,
        editionId: recordId,
        workId: '/works/${recordId.hashCode}',
        canonicalTitle: title,
        subtitle: subtitle,
        authors: authors,
        publicationYear: year,
        publishers: publishers,
        languages: languages,
        subjects: subjects,
        isbn13Values: isbn13,
        fetchedAt: fetchedAt,
      ),
    );
  }

  static List<ProviderBookCandidate> bookASearchResults() => [
        candidate(
          recordId: recordStrong,
          title: bookATitle,
          authors: const ['Author Alpha'],
          year: 2020,
          isbn13: const ['9780000000001'],
          publishers: const ['Alpha Press'],
          languages: const ['eng'],
          subjects: const ['Alpha series'],
          subtitle: 'Volume 1',
        ),
        candidate(
          recordId: recordSecondary,
          title: bookATitle,
          authors: const ['Other Author'],
          year: 2021,
          isbn13: const ['9780000000002'],
          languages: const ['fre'],
          subtitle: 'Alternate edition',
        ),
      ];

  static List<ProviderBookCandidate> bookBSearchResults() => [
        candidate(
          recordId: recordConflict,
          title: bookBTitle,
          authors: const ['Different Author'],
          year: 2019,
          isbn13: const ['9780000000099'],
        ),
      ];

  static List<ProviderBookCandidate> bookERematchResults() => [
        candidate(
          recordId: recordAltE,
          title: bookETitle,
          authors: const ['Author Epsilon'],
          year: 2016,
          isbn13: const ['9780000000005'],
          publishers: const ['Rematch Press'],
        ),
        candidate(
          recordId: recordLinkedE,
          title: bookETitle,
          authors: const ['Author Epsilon'],
          year: 2016,
          isbn13: const ['9780000000004'],
        ),
      ];

  static MediaItem _book({
    required String id,
    required String title,
    required String author,
    required int year,
    required String path,
  }) {
    return MediaItem(
      id: id,
      title: title,
      author: author,
      year: year,
      filePath: path,
      status: MediaItemStatus.available,
      mediaKindRaw: MediaKind.book.catalogueValue,
    );
  }
}
