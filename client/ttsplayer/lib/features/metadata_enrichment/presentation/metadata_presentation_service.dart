import 'dart:convert';

import '../../../models/media_item.dart';
import '../matching/isbn_equivalence.dart';
import '../models/enrichment_book_field_keys.dart';
import '../models/enrichment_field_source.dart';
import '../models/enrichment_field_value.dart';
import '../models/metadata_enrichment_record.dart';
import '../services/book_metadata_match_transition.dart';
import 'media_item_presentation.dart';
import 'metadata_presentation_field.dart';

/// Builds immutable [MediaItemPresentation] projections (M7.5.2).
///
/// **Single owner** of display merge, match-state gating, typed provenance,
/// and structured search-field classification for persisted enrichment.
///
/// Callers supply an already-loaded [MediaItem] and optional enrichment
/// record. This service performs no repository, provider, HTTP, or disk I/O.
///
/// The metadata feature gate is intentionally **not** consulted: persisted
/// accepted metadata and user overrides remain readable when live provider
/// retrieval is disabled. The gate controls provider operations elsewhere.
///
/// Precedence (ADR-029; tiers present in current models):
/// user override → catalogue/filesystem (embedded already folded in) →
/// accepted linked provider → omit/fallback.
/// Sidecar-as-separate-layer is reserved and not represented on [MediaItem].
class MetadataPresentationService {
  const MetadataPresentationService();

  /// Maximum subjects retained for detail presentation after trim/dedupe.
  static const int maxDisplaySubjects = 12;

  /// Maximum subjects retained for structured search after trim/dedupe.
  static const int maxSearchSubjects = 8;

  /// Builds a deterministic projection for [item] and optional [record].
  MediaItemPresentation build({
    required MediaItem item,
    MetadataEnrichmentRecord? record,
  }) {
    if (!item.isBook) {
      return _catalogueOnly(item, record: null, ignoreRecord: true);
    }
    if (record == null) {
      return _catalogueOnly(item, record: null, ignoreRecord: false);
    }
    return _buildBook(item, record);
  }

  MediaItemPresentation _catalogueOnly(
    MediaItem item, {
    required MetadataEnrichmentRecord? record,
    required bool ignoreRecord,
  }) {
    final title = _trimOrNull(item.title) ?? item.title;
    final authors = _singleToList(item.author);
    final series = _trimOrNull(item.series);
    final year = item.year?.toString();

    return MediaItemPresentation(
      item: item,
      displayTitle: title,
      titleField: MetadataPresentationField(
        value: title,
        provenance: MetadataPresentationProvenance.catalogue,
      ),
      subtitleField: MetadataPresentationField.absent,
      authorsField: authors.isEmpty
          ? MetadataPresentationListField.absent
          : MetadataPresentationListField(
              values: authors,
              provenance: MetadataPresentationProvenance.catalogue,
            ),
      seriesField: series == null
          ? MetadataPresentationField.absent
          : MetadataPresentationField(
              value: series,
              provenance: MetadataPresentationProvenance.catalogue,
            ),
      publisherField: MetadataPresentationListField.absent,
      publicationYearField: year == null
          ? MetadataPresentationField.absent
          : MetadataPresentationField(
              value: year,
              provenance: MetadataPresentationProvenance.catalogue,
            ),
      isbnsField: MetadataPresentationListField.absent,
      subjectsField: MetadataPresentationListField.absent,
      descriptionField: MetadataPresentationField.absent,
      searchTitles: _dedupePreserveOrder([title]),
      searchSubtitles: const [],
      searchAuthors: authors,
      searchSeries: series == null ? const [] : [series],
      searchPublishers: const [],
      searchPublicationYears: year == null ? const [] : [year],
      searchIsbns: const [],
      searchSubjects: const [],
      matchState: ignoreRecord ? null : record?.matchState,
      hasEnrichmentRecord: !ignoreRecord && record != null,
      hasVisibleProviderMetadata: false,
      hasUserOverrides: false,
    );
  }

  MediaItemPresentation _buildBook(
    MediaItem item,
    MetadataEnrichmentRecord record,
  ) {
    final providerVisible =
        BookMetadataMatchTransition.isProviderLinked(record);
    final hasUserOverrides = _recordHasUserOverrides(record);

    final titleResolved = _resolveScalar(
      key: EnrichmentBookFieldKeys.title,
      record: record,
      providerVisible: providerVisible,
      catalogueValue: _trimOrNull(item.title),
    );
    // Catalogue title is required on MediaItem; keep a non-empty display title.
    final displayTitle =
        titleResolved.value ?? _trimOrNull(item.title) ?? item.title;
    final titleField = titleResolved.value == null
        ? MetadataPresentationField(
            value: displayTitle,
            provenance: MetadataPresentationProvenance.catalogue,
          )
        : titleResolved;

    final subtitleField = _resolveScalar(
      key: EnrichmentBookFieldKeys.subtitle,
      record: record,
      providerVisible: providerVisible,
      catalogueValue: null,
    );

    final authorsField = _resolveList(
      key: EnrichmentBookFieldKeys.authors,
      record: record,
      providerVisible: providerVisible,
      catalogueValues: _singleToList(item.author),
    );

    // No enrichment series key in EnrichmentBookFieldKeys — catalogue only.
    final seriesValue = _trimOrNull(item.series);
    final seriesField = seriesValue == null
        ? MetadataPresentationField.absent
        : MetadataPresentationField(
            value: seriesValue,
            provenance: MetadataPresentationProvenance.catalogue,
          );

    final publisherField = _resolveList(
      key: EnrichmentBookFieldKeys.publishers,
      record: record,
      providerVisible: providerVisible,
      catalogueValues: const [],
    );

    final yearField = _resolveScalar(
      key: EnrichmentBookFieldKeys.publicationYear,
      record: record,
      providerVisible: providerVisible,
      catalogueValue: item.year?.toString(),
    );

    final isbn10 = _resolveList(
      key: EnrichmentBookFieldKeys.isbn10,
      record: record,
      providerVisible: providerVisible,
      catalogueValues: const [],
    );
    final isbn13 = _resolveList(
      key: EnrichmentBookFieldKeys.isbn13,
      record: record,
      providerVisible: providerVisible,
      catalogueValues: const [],
    );
    final isbnsField = _mergeIsbnDisplay(isbn13, isbn10);

    final subjectsResolved = _resolveList(
      key: EnrichmentBookFieldKeys.subjects,
      record: record,
      providerVisible: providerVisible,
      catalogueValues: const [],
      maxValues: maxDisplaySubjects,
    );

    final descriptionField = _resolveScalar(
      key: EnrichmentBookFieldKeys.description,
      record: record,
      providerVisible: providerVisible,
      catalogueValue: null,
    );

    final visibleProvider = _usedProviderProvenance(
      titleField,
      subtitleField,
      authorsField,
      publisherField,
      yearField,
      isbnsField,
      subjectsResolved,
      descriptionField,
    );

    final search = _buildSearchFields(
      item: item,
      record: record,
      providerVisible: providerVisible,
      displayTitle: displayTitle,
      subtitleField: subtitleField,
      authorsField: authorsField,
      seriesValue: seriesValue,
      publisherField: publisherField,
      yearField: yearField,
      isbnsField: isbnsField,
      subjectsDisplay: subjectsResolved,
    );

    return MediaItemPresentation(
      item: item,
      displayTitle: displayTitle,
      titleField: titleField,
      subtitleField: subtitleField,
      authorsField: authorsField,
      seriesField: seriesField,
      publisherField: publisherField,
      publicationYearField: yearField,
      isbnsField: isbnsField,
      subjectsField: subjectsResolved,
      descriptionField: descriptionField,
      searchTitles: search.titles,
      searchSubtitles: search.subtitles,
      searchAuthors: search.authors,
      searchSeries: search.series,
      searchPublishers: search.publishers,
      searchPublicationYears: search.years,
      searchIsbns: search.isbns,
      searchSubjects: search.subjects,
      matchState: record.matchState,
      hasEnrichmentRecord: true,
      hasVisibleProviderMetadata: visibleProvider,
      hasUserOverrides: hasUserOverrides,
    );
  }

  bool _usedProviderProvenance(
    MetadataPresentationField title,
    MetadataPresentationField subtitle,
    MetadataPresentationListField authors,
    MetadataPresentationListField publishers,
    MetadataPresentationField year,
    MetadataPresentationListField isbns,
    MetadataPresentationListField subjects,
    MetadataPresentationField description,
  ) {
    return title.provenance == MetadataPresentationProvenance.provider ||
        subtitle.provenance == MetadataPresentationProvenance.provider ||
        authors.provenance == MetadataPresentationProvenance.provider ||
        publishers.provenance == MetadataPresentationProvenance.provider ||
        year.provenance == MetadataPresentationProvenance.provider ||
        isbns.provenance == MetadataPresentationProvenance.provider ||
        subjects.provenance == MetadataPresentationProvenance.provider ||
        description.provenance == MetadataPresentationProvenance.provider;
  }

  MetadataPresentationField _resolveScalar({
    required String key,
    required MetadataEnrichmentRecord record,
    required bool providerVisible,
    required String? catalogueValue,
  }) {
    final override = _overrideValue(record, key);
    if (override != null) {
      return MetadataPresentationField(
        value: override,
        provenance: MetadataPresentationProvenance.userOverride,
      );
    }

    final catalogue = _trimOrNull(catalogueValue);
    if (catalogue != null) {
      return MetadataPresentationField(
        value: catalogue,
        provenance: MetadataPresentationProvenance.catalogue,
      );
    }

    if (providerVisible) {
      final provider = _providerValue(record, key);
      if (provider != null) {
        return MetadataPresentationField(
          value: provider,
          provenance: MetadataPresentationProvenance.provider,
          providerId: record.fields[key]?.providerId ?? record.providerId,
        );
      }
    }

    return MetadataPresentationField.absent;
  }

  MetadataPresentationListField _resolveList({
    required String key,
    required MetadataEnrichmentRecord record,
    required bool providerVisible,
    required List<String> catalogueValues,
    int? maxValues,
  }) {
    final override = _overrideList(record, key);
    if (override.isNotEmpty) {
      return MetadataPresentationListField(
        values: _cap(_dedupePreserveOrder(override), maxValues),
        provenance: MetadataPresentationProvenance.userOverride,
      );
    }

    final catalogue = _dedupePreserveOrder(
      catalogueValues.map(_trimOrNull).whereType<String>(),
    );
    if (catalogue.isNotEmpty) {
      return MetadataPresentationListField(
        values: _cap(catalogue, maxValues),
        provenance: MetadataPresentationProvenance.catalogue,
      );
    }

    if (providerVisible) {
      final provider = _providerList(record, key);
      if (provider.isNotEmpty) {
        return MetadataPresentationListField(
          values: _cap(_dedupePreserveOrder(provider), maxValues),
          provenance: MetadataPresentationProvenance.provider,
          providerId: record.fields[key]?.providerId ?? record.providerId,
        );
      }
    }

    return MetadataPresentationListField.absent;
  }

  MetadataPresentationListField _mergeIsbnDisplay(
    MetadataPresentationListField isbn13,
    MetadataPresentationListField isbn10,
  ) {
    final values = _dedupePreserveOrder([
      ...isbn13.values,
      ...isbn10.values,
    ]);
    if (values.isEmpty) {
      return MetadataPresentationListField.absent;
    }

    // Prefer the higher-precedence provenance among contributing ISBN fields.
    final provenance = _preferredListProvenance(isbn13, isbn10);
    final providerId = provenance == MetadataPresentationProvenance.provider
        ? (isbn13.providerId ?? isbn10.providerId)
        : null;
    return MetadataPresentationListField(
      values: values,
      provenance: provenance,
      providerId: providerId,
    );
  }

  MetadataPresentationProvenance _preferredListProvenance(
    MetadataPresentationListField a,
    MetadataPresentationListField b,
  ) {
    const order = [
      MetadataPresentationProvenance.userOverride,
      MetadataPresentationProvenance.catalogue,
      MetadataPresentationProvenance.provider,
      MetadataPresentationProvenance.absent,
    ];
    for (final candidate in order) {
      if (a.provenance == candidate && a.hasValue) return candidate;
      if (b.provenance == candidate && b.hasValue) return candidate;
    }
    return MetadataPresentationProvenance.absent;
  }

  _SearchBuckets _buildSearchFields({
    required MediaItem item,
    required MetadataEnrichmentRecord record,
    required bool providerVisible,
    required String displayTitle,
    required MetadataPresentationField subtitleField,
    required MetadataPresentationListField authorsField,
    required String? seriesValue,
    required MetadataPresentationListField publisherField,
    required MetadataPresentationField yearField,
    required MetadataPresentationListField isbnsField,
    required MetadataPresentationListField subjectsDisplay,
  }) {
    final catalogueTitle = _trimOrNull(item.title) ?? item.title;
    final titles = _dedupePreserveOrder([
      catalogueTitle,
      if (displayTitle != catalogueTitle) displayTitle,
      ..._eligibleEnrichmentScalars(
        record,
        EnrichmentBookFieldKeys.title,
        providerVisible: providerVisible,
      ),
    ]);

    final subtitles = _dedupePreserveOrder([
      if (subtitleField.hasValue) subtitleField.value!,
      ..._eligibleEnrichmentScalars(
        record,
        EnrichmentBookFieldKeys.subtitle,
        providerVisible: providerVisible,
      ),
    ]);

    final authors = _dedupePreserveOrder([
      ..._singleToList(item.author),
      ...authorsField.values,
      ..._eligibleEnrichmentLists(
        record,
        EnrichmentBookFieldKeys.authors,
        providerVisible: providerVisible,
      ),
    ]);

    final series = seriesValue == null
        ? const <String>[]
        : _dedupePreserveOrder([seriesValue]);

    final publishers = _dedupePreserveOrder([
      ...publisherField.values,
      ..._eligibleEnrichmentLists(
        record,
        EnrichmentBookFieldKeys.publishers,
        providerVisible: providerVisible,
      ),
    ]);

    final years = _dedupePreserveOrder([
      if (item.year != null) item.year.toString(),
      if (yearField.hasValue) yearField.value!,
      ..._eligibleEnrichmentScalars(
        record,
        EnrichmentBookFieldKeys.publicationYear,
        providerVisible: providerVisible,
      ),
    ]);

    final isbnDisplay = isbnsField.values;
    final isbnSearch = <String>[
      ...isbnDisplay,
      ..._eligibleEnrichmentLists(
        record,
        EnrichmentBookFieldKeys.isbn13,
        providerVisible: providerVisible,
      ),
      ..._eligibleEnrichmentLists(
        record,
        EnrichmentBookFieldKeys.isbn10,
        providerVisible: providerVisible,
      ),
    ];
    final isbns = _dedupePreserveOrder([
      for (final value in isbnSearch) ..._isbnSearchForms(value),
    ]);

    final subjects = _cap(
      _dedupePreserveOrder([
        ...subjectsDisplay.values,
        ..._eligibleEnrichmentLists(
          record,
          EnrichmentBookFieldKeys.subjects,
          providerVisible: providerVisible,
        ),
      ]),
      maxSearchSubjects,
    );

    return _SearchBuckets(
      titles: titles,
      subtitles: subtitles,
      authors: authors,
      series: series,
      publishers: publishers,
      years: years,
      isbns: isbns,
      subjects: subjects,
    );
  }

  Iterable<String> _eligibleEnrichmentScalars(
    MetadataEnrichmentRecord record,
    String key, {
    required bool providerVisible,
  }) {
    final field = record.fields[key];
    if (field == null) return const [];
    if (!_fieldEligible(field, providerVisible: providerVisible)) {
      return const [];
    }
    // List-encoded scalars should not appear here; parse safely.
    final parsed = _parseFieldValues(field.value);
    if (parsed.length == 1) return parsed;
    if (parsed.isEmpty) {
      final scalar = _trimOrNull(field.value);
      return scalar == null ? const [] : [scalar];
    }
    return parsed;
  }

  Iterable<String> _eligibleEnrichmentLists(
    MetadataEnrichmentRecord record,
    String key, {
    required bool providerVisible,
  }) {
    final field = record.fields[key];
    if (field == null) return const [];
    if (!_fieldEligible(field, providerVisible: providerVisible)) {
      return const [];
    }
    return _parseFieldValues(field.value);
  }

  bool _fieldEligible(
    EnrichmentFieldValue field, {
    required bool providerVisible,
  }) {
    if (field.source == EnrichmentFieldSource.userOverride) return true;
    if (field.source == EnrichmentFieldSource.provider) {
      return providerVisible;
    }
    return false;
  }

  bool _recordHasUserOverrides(MetadataEnrichmentRecord record) {
    for (final field in record.fields.values) {
      if (field.source != EnrichmentFieldSource.userOverride) continue;
      if (_parseFieldValues(field.value).isNotEmpty) return true;
      if (_trimOrNull(field.value) != null) return true;
    }
    return false;
  }

  String? _overrideValue(MetadataEnrichmentRecord record, String key) {
    final field = record.fields[key];
    if (field == null || field.source != EnrichmentFieldSource.userOverride) {
      return null;
    }
    final values = _parseFieldValues(field.value);
    if (values.length == 1) return values.first;
    if (values.isEmpty) return _trimOrNull(field.value);
    // Multi-value stored under a scalar key: join for display.
    return values.join(', ');
  }

  List<String> _overrideList(MetadataEnrichmentRecord record, String key) {
    final field = record.fields[key];
    if (field == null || field.source != EnrichmentFieldSource.userOverride) {
      return const [];
    }
    return _parseFieldValues(field.value);
  }

  String? _providerValue(MetadataEnrichmentRecord record, String key) {
    final field = record.fields[key];
    if (field == null || field.source != EnrichmentFieldSource.provider) {
      return null;
    }
    final values = _parseFieldValues(field.value);
    if (values.length == 1) return values.first;
    if (values.isEmpty) return _trimOrNull(field.value);
    return values.join(', ');
  }

  List<String> _providerList(MetadataEnrichmentRecord record, String key) {
    final field = record.fields[key];
    if (field == null || field.source != EnrichmentFieldSource.provider) {
      return const [];
    }
    return _parseFieldValues(field.value);
  }

  /// Parses enrichment field storage: JSON array string or scalar.
  List<String> _parseFieldValues(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return _dedupePreserveOrder(
            decoded
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty),
          );
        }
      } catch (_) {
        // Fall through to scalar handling.
      }
    }

    return [trimmed];
  }

  List<String> _isbnSearchForms(String value) {
    final forms = <String>[];
    final trimmed = value.trim();
    if (trimmed.isEmpty) return forms;
    forms.add(trimmed);

    final valid = IsbnEquivalence.normalizeValid(trimmed);
    if (valid != null) {
      forms.add(valid);
    } else {
      final digits = trimmed.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
      if (digits.isNotEmpty && digits != trimmed) {
        forms.add(digits);
      }
    }
    return forms;
  }

  List<String> _singleToList(String? value) {
    final trimmed = _trimOrNull(value);
    return trimmed == null ? const [] : [trimmed];
  }

  List<String> _dedupePreserveOrder(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      result.add(trimmed);
    }
    return result;
  }

  List<String> _cap(List<String> values, int? max) {
    if (max == null || values.length <= max) return values;
    return values.sublist(0, max);
  }

  String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _SearchBuckets {
  const _SearchBuckets({
    required this.titles,
    required this.subtitles,
    required this.authors,
    required this.series,
    required this.publishers,
    required this.years,
    required this.isbns,
    required this.subjects,
  });

  final List<String> titles;
  final List<String> subtitles;
  final List<String> authors;
  final List<String> series;
  final List<String> publishers;
  final List<String> years;
  final List<String> isbns;
  final List<String> subjects;
}
