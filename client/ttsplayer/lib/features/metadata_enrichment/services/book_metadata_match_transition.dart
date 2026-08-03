import '../models/isbn_lookup_request.dart';
import '../matching/isbn_equivalence.dart';
import '../models/enrichment_book_field_keys.dart';
import '../models/enrichment_field_source.dart';
import '../models/enrichment_field_value.dart';
import '../models/enrichment_match_method.dart';
import '../models/enrichment_match_state.dart';
import '../models/metadata_enrichment_record.dart';
import '../models/normalized_book_metadata.dart';
import 'book_metadata_enrichment_mapper.dart';

/// Deterministic enrichment record transitions for matching operations (M7.3.2).
class BookMetadataMatchTransition {
  const BookMetadataMatchTransition({
    BookMetadataEnrichmentMapper? mapper,
  }) : _mapper = mapper ?? const BookMetadataEnrichmentMapper();

  final BookMetadataEnrichmentMapper _mapper;

  static bool isProviderLinked(MetadataEnrichmentRecord? record) {
    if (record == null) {
      return false;
    }
    return record.matchState == EnrichmentMatchState.linkedByIdentifier ||
        record.matchState == EnrichmentMatchState.linkedManual ||
        record.matchState == EnrichmentMatchState.linkedHighConfidence;
  }

  MetadataEnrichmentRecord applyIsbnLink({
    required MetadataEnrichmentRecord? existing,
    required String itemId,
    required NormalizedBookMetadata metadata,
    required IsbnLookupRequest request,
    required DateTime fetchedAt,
    required bool lookupKeyConfirmed,
  }) {
    final confidence = _mapper.confidenceForExactIsbn(
      metadata,
      request.normalizedIsbn,
      lookupKeyConfirmed: lookupKeyConfirmed,
    );

    if (existing == null) {
      return _mapper.createLinkedRecord(
        itemId: itemId,
        metadata: metadata,
        matchMethod: EnrichmentMatchMethod.identifier,
        confidence: confidence,
        fetchedAt: fetchedAt,
      );
    }

    return _mapper.mergeProviderFields(
      existing: existing,
      metadata: metadata,
      matchState: EnrichmentMatchState.linkedByIdentifier,
      matchMethod: EnrichmentMatchMethod.identifier,
      confidence: confidence,
      fetchedAt: fetchedAt,
    );
  }

  MetadataEnrichmentRecord applyManualLink({
    required MetadataEnrichmentRecord? existing,
    required String itemId,
    required NormalizedBookMetadata metadata,
    required double confidence,
    required DateTime fetchedAt,
  }) {
    if (existing == null) {
      final fields = _mapper.fieldsFromMetadata(metadata, updatedAt: fetchedAt);
      return MetadataEnrichmentRecord(
        itemId: itemId,
        matchState: EnrichmentMatchState.linkedManual,
        providerId: metadata.providerId,
        providerRecordId: metadata.providerRecordId,
        providerMediaType: 'book',
        matchMethod: EnrichmentMatchMethod.manual,
        confidence: confidence,
        fields: fields,
        fetchedAt: fetchedAt,
        artworkReference: _mapper.artworkReferenceFromMetadata(
          metadata,
          fetchedAt: fetchedAt,
        ),
      ).normalized();
    }

    return _mapper.mergeProviderFields(
      existing: existing,
      metadata: metadata,
      matchState: EnrichmentMatchState.linkedManual,
      matchMethod: EnrichmentMatchMethod.manual,
      confidence: confidence,
      fetchedAt: fetchedAt,
    );
  }

  /// Replaces provider linkage and unlocked provider-owned fields.
  MetadataEnrichmentRecord applyRelink({
    required MetadataEnrichmentRecord existing,
    required NormalizedBookMetadata metadata,
    required double confidence,
    required DateTime fetchedAt,
  }) {
    final retained = _retainUserAndLockedFields(existing);
    final locks = existing.lockedFields.toSet();
    final incoming = _mapper.fieldsFromMetadata(
      metadata,
      updatedAt: fetchedAt,
      lockedFields: locks,
    );

    final merged = Map<String, EnrichmentFieldValue>.from(retained);
    for (final entry in incoming.entries) {
      final retainedField = merged[entry.key];
      if (retainedField?.source == EnrichmentFieldSource.userOverride) {
        continue;
      }
      if (locks.contains(entry.key)) {
        continue;
      }
      merged[entry.key] = entry.value;
    }

    return existing.copyWith(
      matchState: EnrichmentMatchState.linkedManual,
      providerId: metadata.providerId,
      providerRecordId: metadata.providerRecordId,
      providerMediaType: 'book',
      matchMethod: EnrichmentMatchMethod.manual,
      confidence: confidence,
      fields: merged,
      fetchedAt: fetchedAt,
      artworkReference: _mapper.artworkReferenceFromMetadata(
        metadata,
        fetchedAt: fetchedAt,
      ),
      clearArtworkReference: metadata.coverArtworkId == null ||
          metadata.coverArtworkId!.trim().isEmpty,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord applyAmbiguous({
    required MetadataEnrichmentRecord? existing,
    required String itemId,
    required String providerId,
    required double topScore,
    required DateTime fetchedAt,
  }) {
    final base = existing ??
        MetadataEnrichmentRecord(
          itemId: itemId,
          matchState: EnrichmentMatchState.ambiguous,
        );

    return base.copyWith(
      matchState: EnrichmentMatchState.ambiguous,
      providerId: providerId,
      clearProviderRecordId: true,
      clearProviderMediaType: true,
      clearMatchMethod: true,
      confidence: topScore,
      fetchedAt: fetchedAt,
      clearArtworkReference: true,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord applyNoMatch({
    required MetadataEnrichmentRecord? existing,
    required String itemId,
    required DateTime updatedAt,
  }) {
    if (existing == null) {
      return MetadataEnrichmentRecord(
        itemId: itemId,
        matchState: EnrichmentMatchState.unmatched,
      ).normalized();
    }

    return _clearProviderLinkage(existing).copyWith(
      matchState: EnrichmentMatchState.unmatched,
      fetchedAt: updatedAt,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord applyUnlink(MetadataEnrichmentRecord existing) {
    return _clearProviderLinkage(existing).copyWith(
      matchState: EnrichmentMatchState.unmatched,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord applyIgnore(MetadataEnrichmentRecord existing) {
    return _clearProviderLinkage(existing).copyWith(
      matchState: EnrichmentMatchState.ignored,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord applyResumeMatching(MetadataEnrichmentRecord existing) {
    if (existing.matchState != EnrichmentMatchState.ignored) {
      return existing;
    }
    return existing.copyWith(
      matchState: EnrichmentMatchState.unmatched,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord applyIgnoreForItem({
    required MetadataEnrichmentRecord? existing,
    required String itemId,
  }) {
    if (existing == null) {
      return MetadataEnrichmentRecord(
        itemId: itemId,
        matchState: EnrichmentMatchState.ignored,
      ).normalized();
    }
    return applyIgnore(existing);
  }

  bool isbnResponseConfirmed(
    NormalizedBookMetadata metadata,
    IsbnLookupRequest request, {
    bool lookupKeyConfirmed = true,
  }) {
    if (lookupKeyConfirmed) {
      return true;
    }
    final comparison = IsbnEquivalence.compareCollections(
      localIsbn10: request.isIsbn13 ? const [] : [request.normalizedIsbn],
      localIsbn13: request.isIsbn13 ? [request.normalizedIsbn] : const [],
      candidateIsbn10: metadata.isbn10Values,
      candidateIsbn13: metadata.isbn13Values,
    );
    return comparison == IsbnComparisonResult.match;
  }

  MetadataEnrichmentRecord _clearProviderLinkage(
    MetadataEnrichmentRecord existing,
  ) {
    return existing.copyWith(
      clearProviderId: true,
      clearProviderRecordId: true,
      clearProviderMediaType: true,
      clearMatchMethod: true,
      clearConfidence: true,
      clearArtworkReference: true,
      fields: _retainUserAndLockedFields(existing),
    ).normalized();
  }

  Map<String, EnrichmentFieldValue> _retainUserAndLockedFields(
    MetadataEnrichmentRecord existing,
  ) {
    final locks = existing.lockedFields.toSet();
    final retained = <String, EnrichmentFieldValue>{};
    for (final entry in existing.fields.entries) {
      final field = entry.value;
      if (field.source == EnrichmentFieldSource.userOverride ||
          locks.contains(entry.key)) {
        retained[entry.key] = field;
      }
    }
    return retained;
  }

  /// Keys written by [BookMetadataEnrichmentMapper.fieldsFromMetadata].
  static const providerOwnedBookFieldKeys = {
    EnrichmentBookFieldKeys.title,
    EnrichmentBookFieldKeys.subtitle,
    EnrichmentBookFieldKeys.authors,
    EnrichmentBookFieldKeys.description,
    EnrichmentBookFieldKeys.publishers,
    EnrichmentBookFieldKeys.publicationDate,
    EnrichmentBookFieldKeys.publicationYear,
    EnrichmentBookFieldKeys.languages,
    EnrichmentBookFieldKeys.subjects,
    EnrichmentBookFieldKeys.isbn10,
    EnrichmentBookFieldKeys.isbn13,
  };
}
