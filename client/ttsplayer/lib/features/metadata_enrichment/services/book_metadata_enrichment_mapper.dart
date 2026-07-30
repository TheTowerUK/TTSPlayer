import 'dart:convert';

import '../models/enrichment_book_field_keys.dart';
import '../models/enrichment_field_source.dart';
import '../models/enrichment_field_value.dart';
import '../models/enrichment_match_method.dart';
import '../models/enrichment_match_state.dart';
import '../models/metadata_enrichment_record.dart';
import '../models/normalized_book_metadata.dart';

/// Maps provider-neutral book metadata to enrichment records (M7.2).
class BookMetadataEnrichmentMapper {
  const BookMetadataEnrichmentMapper();

  /// Collection fields are stored as JSON array strings for Phase 7.1 scalar
  /// compatibility without a schema version bump.
  Map<String, EnrichmentFieldValue> fieldsFromMetadata(
    NormalizedBookMetadata metadata, {
    required DateTime updatedAt,
    Set<String> lockedFields = const {},
  }) {
    final providerId = metadata.providerId;
    final fields = <String, EnrichmentFieldValue>{};

    void addScalar(String key, String? value) {
      if (value == null || value.trim().isEmpty) return;
      if (lockedFields.contains(key)) return;
      fields[key] = EnrichmentFieldValue(
        value: value.trim(),
        source: EnrichmentFieldSource.provider,
        providerId: providerId,
        updatedAt: updatedAt,
      );
    }

    void addList(String key, List<String> values) {
      if (values.isEmpty) return;
      if (lockedFields.contains(key)) return;
      final sorted = List<String>.from(values)..sort();
      fields[key] = EnrichmentFieldValue(
        value: jsonEncode(sorted),
        source: EnrichmentFieldSource.provider,
        providerId: providerId,
        updatedAt: updatedAt,
      );
    }

    addScalar(EnrichmentBookFieldKeys.title, metadata.canonicalTitle);
    addScalar(EnrichmentBookFieldKeys.subtitle, metadata.subtitle);
    addList(EnrichmentBookFieldKeys.authors, metadata.authors);
    addScalar(EnrichmentBookFieldKeys.description, metadata.description);
    addList(EnrichmentBookFieldKeys.publishers, metadata.publishers);
    addScalar(EnrichmentBookFieldKeys.publicationDate, metadata.publicationDate);
    if (metadata.publicationYear != null) {
      addScalar(
        EnrichmentBookFieldKeys.publicationYear,
        metadata.publicationYear.toString(),
      );
    }
    addList(EnrichmentBookFieldKeys.languages, metadata.languages);
    addList(EnrichmentBookFieldKeys.subjects, metadata.subjects);
    addList(EnrichmentBookFieldKeys.isbn10, metadata.isbn10Values);
    addList(EnrichmentBookFieldKeys.isbn13, metadata.isbn13Values);

    return fields;
  }

  /// Merges provider fields into [existing].
  ///
  /// Locked keys are skipped. Unlocked keys present in [metadata] are updated.
  /// Keys absent from the new provider response are retained unchanged — refresh
  /// does not clear previously enriched fields or user overrides.
  MetadataEnrichmentRecord mergeProviderFields({
    required MetadataEnrichmentRecord existing,
    required NormalizedBookMetadata metadata,
    required EnrichmentMatchState matchState,
    required EnrichmentMatchMethod matchMethod,
    required double confidence,
    required DateTime fetchedAt,
  }) {
    final locked = existing.lockedFields.toSet();
    final incoming = fieldsFromMetadata(
      metadata,
      updatedAt: fetchedAt,
      lockedFields: locked,
    );

    final mergedFields = Map<String, EnrichmentFieldValue>.from(existing.fields);
    for (final entry in incoming.entries) {
      mergedFields[entry.key] = entry.value;
    }

    return existing.copyWith(
      matchState: matchState,
      providerId: metadata.providerId,
      providerRecordId: metadata.providerRecordId,
      providerMediaType: 'book',
      matchMethod: matchMethod,
      confidence: confidence,
      fields: mergedFields,
      fetchedAt: fetchedAt,
      clearLastErrorCategory: true,
    ).normalized();
  }

  MetadataEnrichmentRecord createLinkedRecord({
    required String itemId,
    required NormalizedBookMetadata metadata,
    required EnrichmentMatchMethod matchMethod,
    required double confidence,
    required DateTime fetchedAt,
  }) {
    return MetadataEnrichmentRecord(
      itemId: itemId,
      matchState: EnrichmentMatchState.linkedByIdentifier,
      providerId: metadata.providerId,
      providerRecordId: metadata.providerRecordId,
      providerMediaType: 'book',
      matchMethod: matchMethod,
      confidence: confidence,
      fields: fieldsFromMetadata(metadata, updatedAt: fetchedAt),
      fetchedAt: fetchedAt,
    ).normalized();
  }

  /// Returns confidence `1.0` when [lookupKeyConfirmed] is true (Books API
  /// response present under the exact `ISBN:<value>` bibkey) or when the
  /// normalized lookup ISBN appears in the metadata identifier lists.
  double confidenceForExactIsbn(
    NormalizedBookMetadata metadata,
    String normalizedLookupIsbn, {
    bool lookupKeyConfirmed = false,
  }) {
    if (lookupKeyConfirmed) return 1.0;

    final allIsbns = [
      ...metadata.isbn10Values,
      ...metadata.isbn13Values,
    ].map((value) => value.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase());
    if (allIsbns.contains(normalizedLookupIsbn)) {
      return 1.0;
    }
    return 0.0;
  }
}
