import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../config/metadata_enrichment_feature_config.dart';
import '../models/book_search_request.dart';
import '../models/metadata_enrichment_record.dart';
import '../presentation/metadata_enrichment_ui_messages.dart';
import '../presentation/metadata_match_state_presentation.dart';
import '../presentation/metadata_provider_presentation.dart';
import '../services/book_metadata_match_transition.dart';
import '../services/book_candidate_selection_context.dart';
import '../services/book_metadata_matching_coordinator.dart';
import '../services/book_metadata_matching_result.dart';
import '../services/metadata_enrichment_repository.dart';
import 'book_metadata_candidate_dialog.dart';

enum _PendingOperation {
  none,
  isbnLookup,
  search,
  unlink,
  ignore,
  resume,
  markNoMatch,
}

/// Transient search summary shown after an explicit search action (M7.3.3).
class _TransientSearchSummary {
  const _TransientSearchSummary({
    required this.message,
    this.showReviewPlaceholder = false,
    this.showMarkNoMatch = false,
    this.selectionContext,
  });

  final String message;
  final bool showReviewPlaceholder;
  final bool showMarkNoMatch;
  final BookCandidateSelectionContext? selectionContext;
}

/// Development-gated book metadata enrichment section (M7.3.3).
class BookMetadataEnrichmentSection extends StatefulWidget {
  const BookMetadataEnrichmentSection({
    super.key,
    required this.item,
  });

  final MediaItem item;

  @override
  State<BookMetadataEnrichmentSection> createState() =>
      _BookMetadataEnrichmentSectionState();
}

class _BookMetadataEnrichmentSectionState
    extends State<BookMetadataEnrichmentSection> {
  _PendingOperation _pending = _PendingOperation.none;
  String? _statusMessage;
  _TransientSearchSummary? _searchSummary;
  int _candidateReviewGeneration = 0;
  BookMetadataCandidateDialogSession? _activeCandidateReview;

  @override
  void didUpdateWidget(covariant BookMetadataEnrichmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _dismissActiveCandidateReviewByItemChange();
      _resetTransientState();
    }
  }

  @override
  void dispose() {
    _dismissActiveCandidateReviewByItemChange();
    super.dispose();
  }

  void _dismissActiveCandidateReviewByItemChange() {
    _candidateReviewGeneration++;
    final session = _activeCandidateReview;
    _activeCandidateReview = null;
    session?.dismissByItemChange();
  }

  void _resetTransientState() {
    _pending = _PendingOperation.none;
    _statusMessage = null;
    _searchSummary = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.item.isBook) {
      return const SizedBox.shrink();
    }

    final config = context.read<MetadataEnrichmentFeatureConfig?>() ??
        MetadataEnrichmentFeatureConfig.defaults;
    if (!config.metadataEnrichmentDevelopmentEnabled) {
      return const SizedBox.shrink();
    }

    context.watch<MetadataEnrichmentRepository>();
    final repository = context.read<MetadataEnrichmentRepository>();
    final record = repository.getByItemId(widget.item.id);
    final presentation = record == null
        ? MetadataMatchStatePresentation.forNoRecord()
        : MetadataMatchStatePresentation.forState(record.matchState);
    final providerLine = _providerAttributionLine(record);
    final fetchedLine = _fetchedLine(record);
    final busy = _pending != _PendingOperation.none;

    return Semantics(
      container: true,
      label: 'Metadata enrichment',
      child: Padding(
        key: const Key('book_metadata_enrichment_section'),
        padding: AppSpacing.metadataSection,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Metadata enrichment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Local catalogue metadata remains authoritative. External metadata is optional enrichment.',
                  style: AppTypography.labelMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      presentation.icon,
                      size: AppIcons.standard,
                      color: AppColors.textHigh,
                      semanticLabel: presentation.label,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            presentation.label,
                            key: const Key('book_metadata_enrichment_status'),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.size14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            presentation.explanation,
                            style: AppTypography.labelMuted,
                          ),
                          if (providerLine != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              providerLine,
                              key: const Key('book_metadata_enrichment_provider'),
                              style: const TextStyle(
                                color: AppColors.textHigh,
                                fontSize: AppTypography.size13,
                              ),
                            ),
                          ],
                          if (fetchedLine != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              fetchedLine,
                              key: const Key('book_metadata_enrichment_fetched'),
                              style: AppTypography.labelMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (busy) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _statusMessage!,
                    key: const Key('book_metadata_enrichment_message'),
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: AppTypography.size13,
                    ),
                  ),
                ],
                if (_searchSummary != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _searchSummary!.message,
                    key: const Key('book_metadata_enrichment_search_summary'),
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: AppTypography.size13,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _buildActions(
                    context,
                    presentation: presentation,
                    record: record,
                    busy: busy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context, {
    required MetadataMatchStatePresentation presentation,
    required MetadataEnrichmentRecord? record,
    required bool busy,
  }) {
    final coordinator = context.watch<BookMetadataMatchingCoordinator?>();
    if (coordinator == null) {
      return const [
        Text(
          'Matching coordinator is not configured.',
          style: AppTypography.labelMuted,
        ),
      ];
    }

    final actions = <Widget>[];

    void addAction({
      required Key key,
      required MetadataEnrichmentAction action,
      required String label,
      required Future<void> Function() onPressed,
      bool outlined = true,
    }) {
      if (!presentation.permits(action)) {
        return;
      }
      final button = outlined
          ? OutlinedButton(
              key: key,
              onPressed: _pending != _PendingOperation.none
                  ? null
                  : () {
                      if (_pending != _PendingOperation.none) {
                        return;
                      }
                      onPressed();
                    },
              child: Text(label),
            )
          : FilledButton(
              key: key,
              onPressed: _pending != _PendingOperation.none
                  ? null
                  : () {
                      if (_pending != _PendingOperation.none) {
                        return;
                      }
                      onPressed();
                    },
              child: Text(label),
            );
      actions.add(button);
    }

    addAction(
      key: const Key('book_metadata_enrichment_lookup_isbn'),
      action: MetadataEnrichmentAction.lookupIsbn,
      label: 'Look up by ISBN',
      onPressed: () => _lookupByIsbn(coordinator),
    );
    addAction(
      key: const Key('book_metadata_enrichment_search'),
      action: MetadataEnrichmentAction.searchMetadata,
      label: 'Search metadata',
      onPressed: () => _searchMetadata(coordinator, changeExisting: false),
    );
    addAction(
      key: const Key('book_metadata_enrichment_change_metadata'),
      action: MetadataEnrichmentAction.changeMetadata,
      label: 'Change metadata',
      onPressed: () => _searchMetadata(coordinator, changeExisting: true),
    );
    addAction(
      key: const Key('book_metadata_enrichment_unlink'),
      action: MetadataEnrichmentAction.unlink,
      label: 'Unlink metadata',
      onPressed: () => _unlink(coordinator),
    );
    addAction(
      key: const Key('book_metadata_enrichment_ignore'),
      action: MetadataEnrichmentAction.ignore,
      label: 'Ignore suggestions',
      onPressed: () => _ignore(coordinator),
    );
    addAction(
      key: const Key('book_metadata_enrichment_resume'),
      action: MetadataEnrichmentAction.resumeMatching,
      label: 'Resume matching',
      onPressed: () => _resumeMatching(coordinator),
    );

    final reviewContext = _searchSummary?.selectionContext;
    if (reviewContext != null && reviewContext.hasReviewableCandidates) {
      actions.add(
        OutlinedButton(
          key: const Key('book_metadata_enrichment_review_candidates'),
          onPressed: busy
              ? null
              : () => _openCandidateReview(
                    context,
                    coordinator: coordinator,
                    selectionContext: reviewContext,
                    record: record,
                  ),
          child: const Text('Review candidates'),
        ),
      );
    }

    if (_searchSummary?.showMarkNoMatch == true) {
      actions.add(
        OutlinedButton(
          key: const Key('book_metadata_enrichment_mark_no_match'),
          onPressed: busy ? null : () => _markNoMatch(coordinator),
          child: const Text('Mark as no match'),
        ),
      );
    }

    return actions;
  }

  String? _providerAttributionLine(MetadataEnrichmentRecord? record) {
    if (record?.providerId == null) {
      return null;
    }
    return MetadataProviderPresentation.forProviderId(record!.providerId)
        .attributionLine;
  }

  String? _fetchedLine(MetadataEnrichmentRecord? record) {
    final fetchedAt = record?.fetchedAt;
    if (fetchedAt == null) {
      return null;
    }
    final date =
        '${fetchedAt.year}-${fetchedAt.month.toString().padLeft(2, '0')}-${fetchedAt.day.toString().padLeft(2, '0')}';
    return 'Metadata fetched $date';
  }

  Future<void> _lookupByIsbn(BookMetadataMatchingCoordinator coordinator) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }
    final isbn = await _promptIsbn(context);
    if (!mounted || isbn == null) {
      return;
    }
    if (isbn.trim().isEmpty) {
      setState(() {
        _statusMessage = MetadataEnrichmentUiMessages.invalidIsbnMessage;
      });
      return;
    }

    _pending = _PendingOperation.isbnLookup;
    setState(() {
      _statusMessage = null;
      _searchSummary = null;
    });

    final result = await coordinator.lookupByIsbn(
      item: widget.item,
      isbnInput: isbn,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _pending = _PendingOperation.none;
      _statusMessage = MetadataEnrichmentUiMessages.isbnResultMessage(result);
    });
  }

  Future<void> _searchMetadata(
    BookMetadataMatchingCoordinator coordinator, {
    required bool changeExisting,
  }) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }

    _pending = _PendingOperation.search;
    setState(() {
      _statusMessage = null;
      _searchSummary = null;
    });

    final request = BookSearchRequest.create(
      title: widget.item.title,
      author: widget.item.author,
      publicationYear: widget.item.year,
    );
    final result = await coordinator.searchAndEvaluate(
      item: widget.item,
      searchRequest: request,
    );
    if (!mounted) {
      return;
    }

    final summary = _summaryForSearchResult(result);
    setState(() {
      _pending = _PendingOperation.none;
      _searchSummary = summary;
      if (changeExisting) {
        _statusMessage =
            'Existing link retained until you confirm a replacement candidate.';
      }
    });
  }

  Future<void> _openCandidateReview(
    BuildContext context, {
    required BookMetadataMatchingCoordinator coordinator,
    required BookCandidateSelectionContext selectionContext,
    required MetadataEnrichmentRecord? record,
  }) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }

    final isRelink = BookMetadataMatchTransition.isProviderLinked(record);
    final generation = _candidateReviewGeneration;
    final itemId = widget.item.id;
    final session = BookMetadataCandidateDialog.open(
      context: context,
      item: widget.item,
      selectionContext: selectionContext,
      coordinator: coordinator,
      isRelink: isRelink,
      sessionGeneration: generation,
    );
    _activeCandidateReview = session;

    final dialogResult = await session.result;
    _activeCandidateReview = null;

    if (!mounted ||
        generation != _candidateReviewGeneration ||
        widget.item.id != itemId) {
      return;
    }

    if (dialogResult == null) {
      return;
    }

    switch (dialogResult) {
      case BookMetadataCandidateDialogCancelled():
      case BookMetadataCandidateDialogDismissedByItemChange():
        return;
      case BookMetadataCandidateDialogInvalidContext():
        setState(() {
          _searchSummary = null;
          _statusMessage =
              'These metadata candidates are no longer valid. Search again.';
        });
      case BookMetadataCandidateDialogFailure(:final message):
        setState(() {
          _statusMessage = message;
        });
      case BookMetadataCandidateDialogSuccess(:final message):
        setState(() {
          _searchSummary = null;
          _statusMessage = message;
        });
    }
  }

  _TransientSearchSummary _summaryForSearchResult(
    BookCandidateSearchEvaluationResult result,
  ) {
    switch (result) {
      case BookCandidateSearchNoProviderCandidates():
        return const _TransientSearchSummary(
          message: 'No metadata candidates found.',
        );
      case BookCandidateSearchEvaluationRejected():
        return _TransientSearchSummary(
          message: MetadataEnrichmentUiMessages.searchResultMessage(result),
        );
      case BookCandidateSearchEvaluationProviderFailure():
        return _TransientSearchSummary(
          message: MetadataEnrichmentUiMessages.searchResultMessage(result),
        );
      case BookCandidateSearchEvaluationSuccess(
          :final hasReviewableCandidates,
          :final requiresConflictReview,
          :final selectionContext,
          :final matchSet,
        ):
        if (!hasReviewableCandidates) {
          return const _TransientSearchSummary(
            message: 'No suitable metadata candidates found.',
            showMarkNoMatch: true,
          );
        }
        if (requiresConflictReview) {
          return _TransientSearchSummary(
            message: 'Metadata review is required.',
            showReviewPlaceholder: true,
            selectionContext: selectionContext,
          );
        }
        final top = matchSet.topCandidate;
        final highConfidence = top != null && top.finalScore >= 0.85;
        return _TransientSearchSummary(
          message: highConfidence
              ? 'A likely metadata match was found.'
              : 'Metadata candidates are available for review.',
          showReviewPlaceholder: true,
          selectionContext: selectionContext,
        );
    }
  }

  Future<void> _unlink(BookMetadataMatchingCoordinator coordinator) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }
    final confirmed = await _confirm(
      context,
      title: 'Remove metadata link?',
      message:
          'Remove the external metadata link? Your local book and any user-edited metadata will be kept.',
      confirmLabel: 'Unlink',
    );
    if (!confirmed || !mounted) {
      return;
    }

    _pending = _PendingOperation.unlink;
    setState(() {
      _statusMessage = null;
    });
    final result = await coordinator.unlink(item: widget.item);
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = _PendingOperation.none;
      _statusMessage = MetadataEnrichmentUiMessages.linkTransitionMessage(result);
      _searchSummary = null;
    });
  }

  Future<void> _ignore(BookMetadataMatchingCoordinator coordinator) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }
    final confirmed = await _confirm(
      context,
      title: 'Ignore metadata suggestions?',
      message:
          'Ignore metadata suggestions for this book? You can resume matching later.',
      confirmLabel: 'Ignore',
    );
    if (!confirmed || !mounted) {
      return;
    }

    _pending = _PendingOperation.ignore;
    setState(() {
      _statusMessage = null;
      _searchSummary = null;
    });
    final result = await coordinator.ignore(item: widget.item);
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = _PendingOperation.none;
      _statusMessage = MetadataEnrichmentUiMessages.linkTransitionMessage(result);
    });
  }

  Future<void> _resumeMatching(
    BookMetadataMatchingCoordinator coordinator,
  ) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }
    _pending = _PendingOperation.resume;
    setState(() {
      _statusMessage = null;
      _searchSummary = null;
    });
    final result = await coordinator.resumeMatching(item: widget.item);
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = _PendingOperation.none;
      _statusMessage = MetadataEnrichmentUiMessages.linkTransitionMessage(result);
    });
  }

  Future<void> _markNoMatch(BookMetadataMatchingCoordinator coordinator) async {
    if (_pending != _PendingOperation.none || !mounted) {
      return;
    }
    _pending = _PendingOperation.markNoMatch;
    setState(() {});
    final result = await coordinator.recordNoMatchOutcome(
      item: widget.item,
      reason: BookNoMatchPersistenceReason.noReviewableCandidates,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = _PendingOperation.none;
      _statusMessage = MetadataEnrichmentUiMessages.linkTransitionMessage(result);
      _searchSummary = null;
    });
  }

  Future<String?> _promptIsbn(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Look up by ISBN'),
        content: TextField(
          key: const Key('book_metadata_enrichment_isbn_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ISBN',
            hintText: 'ISBN-10 or ISBN-13',
          ),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            key: const Key('book_metadata_enrichment_isbn_cancel'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('book_metadata_enrichment_isbn_submit'),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
