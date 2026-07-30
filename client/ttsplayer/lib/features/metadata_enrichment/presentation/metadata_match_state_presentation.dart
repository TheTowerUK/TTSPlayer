import 'package:flutter/material.dart';

import '../models/enrichment_match_state.dart';

/// Explicit coordinator actions exposed by the detail enrichment section.
enum MetadataEnrichmentAction {
  lookupIsbn,
  searchMetadata,
  changeMetadata,
  reviewCandidates,
  unlink,
  ignore,
  resumeMatching,
  markNoMatch,
}

/// Bounded presentation for [EnrichmentMatchState] (M7.3.3).
class MetadataMatchStatePresentation {
  const MetadataMatchStatePresentation({
    required this.label,
    required this.explanation,
    required this.icon,
    required this.permittedActions,
  });

  final String label;
  final String explanation;
  final IconData icon;
  final Set<MetadataEnrichmentAction> permittedActions;

  bool permits(MetadataEnrichmentAction action) =>
      permittedActions.contains(action);

  static MetadataMatchStatePresentation forNoRecord() {
    return const MetadataMatchStatePresentation(
      label: 'Not linked',
      explanation:
          'Optional external metadata has not been linked to this book yet.',
      icon: Icons.link_off_outlined,
      permittedActions: {
        MetadataEnrichmentAction.lookupIsbn,
        MetadataEnrichmentAction.searchMetadata,
      },
    );
  }

  static MetadataMatchStatePresentation forState(EnrichmentMatchState state) {
    return switch (state) {
      EnrichmentMatchState.unmatched => const MetadataMatchStatePresentation(
          label: 'No metadata match selected',
          explanation:
              'No external metadata link is active for this book.',
          icon: Icons.search_outlined,
          permittedActions: {
            MetadataEnrichmentAction.lookupIsbn,
            MetadataEnrichmentAction.searchMetadata,
            MetadataEnrichmentAction.ignore,
          },
        ),
      EnrichmentMatchState.linkedByIdentifier =>
        const MetadataMatchStatePresentation(
          label: 'Linked by ISBN',
          explanation:
              'External metadata was linked using an explicit ISBN lookup.',
          icon: Icons.qr_code_2_outlined,
          permittedActions: {
            MetadataEnrichmentAction.changeMetadata,
            MetadataEnrichmentAction.unlink,
          },
        ),
      EnrichmentMatchState.linkedHighConfidence =>
        const MetadataMatchStatePresentation(
          label: 'Automatically linked',
          explanation:
              'External metadata was linked automatically with high confidence.',
          icon: Icons.auto_awesome_outlined,
          permittedActions: {
            MetadataEnrichmentAction.changeMetadata,
            MetadataEnrichmentAction.unlink,
          },
        ),
      EnrichmentMatchState.linkedManual => const MetadataMatchStatePresentation(
          label: 'Manually linked',
          explanation:
              'External metadata was linked after explicit confirmation.',
          icon: Icons.edit_note_outlined,
          permittedActions: {
            MetadataEnrichmentAction.changeMetadata,
            MetadataEnrichmentAction.unlink,
          },
        ),
      EnrichmentMatchState.ambiguous => const MetadataMatchStatePresentation(
          label: 'Metadata review required',
          explanation:
              'Multiple or conflicting metadata candidates need review.',
          icon: Icons.rule_outlined,
          permittedActions: {
            MetadataEnrichmentAction.reviewCandidates,
            MetadataEnrichmentAction.lookupIsbn,
            MetadataEnrichmentAction.searchMetadata,
            MetadataEnrichmentAction.ignore,
          },
        ),
      EnrichmentMatchState.ignored => const MetadataMatchStatePresentation(
          label: 'Metadata suggestions ignored',
          explanation:
              'Metadata suggestions are suppressed for this book.',
          icon: Icons.notifications_off_outlined,
          permittedActions: {
            MetadataEnrichmentAction.resumeMatching,
          },
        ),
      EnrichmentMatchState.stale => const MetadataMatchStatePresentation(
          label: 'Metadata link may be stale',
          explanation:
              'The saved metadata link may no longer match this catalogue item.',
          icon: Icons.history_outlined,
          permittedActions: {
            MetadataEnrichmentAction.lookupIsbn,
            MetadataEnrichmentAction.searchMetadata,
            MetadataEnrichmentAction.unlink,
          },
        ),
    };
  }
}
