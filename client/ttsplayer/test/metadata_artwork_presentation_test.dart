import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_method.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/enrichment_match_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/models/metadata_enrichment_record.dart';
import 'package:ttsplayer/features/metadata_enrichment/presentation/metadata_artwork_presentation.dart';

import 'support/metadata_artwork_test_fixtures.dart';

void main() {
  group('MetadataArtworkPresentation', () {
    test('unlinked record exposes no actions', () {
      final presentation = MetadataArtworkPresentation.forRecord(null);
      expect(presentation.permittedActions, isEmpty);
      expect(presentation.statusLabel, 'Cover unavailable');
    });

    test('linked available reference offers download', () {
      final record = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.linkedManual,
        providerId: 'open_library',
        providerRecordId: '/books/OL123M',
        providerMediaType: 'book',
        matchMethod: EnrichmentMatchMethod.manual,
        artworkReference: MetadataArtworkTestFixtures.sampleReference(),
      ).normalized();

      final presentation = MetadataArtworkPresentation.forRecord(record);
      expect(presentation.statusLabel, 'Cover available');
      expect(presentation.permits(MetadataArtworkAction.downloadCover), isTrue);
      expect(presentation.permits(MetadataArtworkAction.refreshCover), isFalse);
    });

    test('downloaded reference offers refresh', () {
      final record = MetadataEnrichmentRecord(
        itemId: 'book-1',
        matchState: EnrichmentMatchState.linkedManual,
        providerId: 'open_library',
        providerRecordId: '/books/OL123M',
        providerMediaType: 'book',
        matchMethod: EnrichmentMatchMethod.manual,
        artworkReference: MetadataArtworkTestFixtures.sampleReference().copyWith(
          cacheState: MetadataArtworkCacheState.downloaded,
          localRelativePath: 'abc.png',
        ),
      ).normalized();

      final presentation = MetadataArtworkPresentation.forRecord(record);
      expect(presentation.statusLabel, 'Cover downloaded');
      expect(presentation.permits(MetadataArtworkAction.refreshCover), isTrue);
      expect(presentation.permits(MetadataArtworkAction.downloadCover), isFalse);
    });
  });
}
