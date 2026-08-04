import '../../../models/media_item.dart';
import '../../../models/media_kind.dart';
import '../models/enrichment_match_state.dart';
import 'metadata_presentation_field.dart';

/// Immutable catalogue + enrichment presentation projection (M7.5.2).
///
/// Serialisation-free and repository/provider/UI-free. Callers supply an
/// already-loaded [MediaItem] and optional enrichment record to
/// [MetadataPresentationService.build].
class MediaItemPresentation {
  MediaItemPresentation({
    required this.item,
    required this.displayTitle,
    required this.titleField,
    required this.subtitleField,
    required this.authorsField,
    required this.seriesField,
    required this.publisherField,
    required this.publicationYearField,
    required this.isbnsField,
    required this.subjectsField,
    required this.descriptionField,
    required List<String> searchTitles,
    required List<String> searchSubtitles,
    required List<String> searchAuthors,
    required List<String> searchSeries,
    required List<String> searchPublishers,
    required List<String> searchPublicationYears,
    required List<String> searchIsbns,
    required List<String> searchSubjects,
    required this.matchState,
    required this.hasEnrichmentRecord,
    required this.hasVisibleProviderMetadata,
    required this.hasUserOverrides,
  })  : searchTitles = List<String>.unmodifiable(searchTitles),
        searchSubtitles = List<String>.unmodifiable(searchSubtitles),
        searchAuthors = List<String>.unmodifiable(searchAuthors),
        searchSeries = List<String>.unmodifiable(searchSeries),
        searchPublishers = List<String>.unmodifiable(searchPublishers),
        searchPublicationYears =
            List<String>.unmodifiable(searchPublicationYears),
        searchIsbns = List<String>.unmodifiable(searchIsbns),
        searchSubjects = List<String>.unmodifiable(searchSubjects);

  /// Authoritative catalogue item — identity and playback/read routing.
  final MediaItem item;

  /// Precedence-resolved title for UI surfaces.
  final String displayTitle;

  final MetadataPresentationField titleField;
  final MetadataPresentationField subtitleField;
  final MetadataPresentationListField authorsField;
  final MetadataPresentationField seriesField;
  final MetadataPresentationListField publisherField;
  final MetadataPresentationField publicationYearField;
  final MetadataPresentationListField isbnsField;
  final MetadataPresentationListField subjectsField;
  final MetadataPresentationField descriptionField;

  /// Structured search terms — catalogue retained independently of display.
  final List<String> searchTitles;
  final List<String> searchSubtitles;
  final List<String> searchAuthors;
  final List<String> searchSeries;
  final List<String> searchPublishers;
  final List<String> searchPublicationYears;
  final List<String> searchIsbns;
  final List<String> searchSubjects;

  final EnrichmentMatchState? matchState;
  final bool hasEnrichmentRecord;
  final bool hasVisibleProviderMetadata;
  final bool hasUserOverrides;

  String get itemId => item.id;
  MediaKind get mediaKind => item.mediaKind;
  String get filePath => item.filePath;
  String get catalogueTitle => item.title;

  bool get isStale => matchState == EnrichmentMatchState.stale;

  List<String> get displayAuthors => authorsField.values;

  String? get displaySubtitle => subtitleField.value;

  String? get displaySeries => seriesField.value;

  List<String> get displayPublishers => publisherField.values;

  String? get displayPublisher =>
      displayPublishers.isEmpty ? null : displayPublishers.join(', ');

  String? get displayPublicationYear => publicationYearField.value;

  List<String> get displayIsbns => isbnsField.values;

  List<String> get displaySubjects => subjectsField.values;

  String? get displayDescription => descriptionField.value;

  /// Flatten of structured search lists for broad token matching only.
  String get searchKeywords {
    final parts = <String>[
      ...searchTitles,
      ...searchSubtitles,
      ...searchAuthors,
      ...searchSeries,
      ...searchPublishers,
      ...searchPublicationYears,
      ...searchIsbns,
      ...searchSubjects,
    ];
    return parts.join(' ');
  }

  @override
  bool operator ==(Object other) {
    return other is MediaItemPresentation &&
        other.item.id == item.id &&
        other.item.title == item.title &&
        other.item.filePath == item.filePath &&
        other.item.author == item.author &&
        other.item.series == item.series &&
        other.item.year == item.year &&
        other.item.mediaKindRaw == item.mediaKindRaw &&
        other.displayTitle == displayTitle &&
        other.titleField == titleField &&
        other.subtitleField == subtitleField &&
        other.authorsField == authorsField &&
        other.seriesField == seriesField &&
        other.publisherField == publisherField &&
        other.publicationYearField == publicationYearField &&
        other.isbnsField == isbnsField &&
        other.subjectsField == subjectsField &&
        other.descriptionField == descriptionField &&
        _listEquals(other.searchTitles, searchTitles) &&
        _listEquals(other.searchSubtitles, searchSubtitles) &&
        _listEquals(other.searchAuthors, searchAuthors) &&
        _listEquals(other.searchSeries, searchSeries) &&
        _listEquals(other.searchPublishers, searchPublishers) &&
        _listEquals(other.searchPublicationYears, searchPublicationYears) &&
        _listEquals(other.searchIsbns, searchIsbns) &&
        _listEquals(other.searchSubjects, searchSubjects) &&
        other.matchState == matchState &&
        other.hasEnrichmentRecord == hasEnrichmentRecord &&
        other.hasVisibleProviderMetadata == hasVisibleProviderMetadata &&
        other.hasUserOverrides == hasUserOverrides;
  }

  @override
  int get hashCode => Object.hashAll([
        item.id,
        displayTitle,
        titleField,
        subtitleField,
        authorsField,
        seriesField,
        publisherField,
        publicationYearField,
        isbnsField,
        subjectsField,
        descriptionField,
        Object.hashAll(searchTitles),
        Object.hashAll(searchSubtitles),
        Object.hashAll(searchAuthors),
        Object.hashAll(searchSeries),
        Object.hashAll(searchPublishers),
        Object.hashAll(searchPublicationYears),
        Object.hashAll(searchIsbns),
        Object.hashAll(searchSubjects),
        matchState,
        hasEnrichmentRecord,
        hasVisibleProviderMetadata,
        hasUserOverrides,
      ]);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
