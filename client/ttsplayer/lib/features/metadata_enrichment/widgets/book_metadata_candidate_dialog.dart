import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../../theme/app_theme.dart';
import '../matching/book_candidate_match_evaluation.dart';
import '../presentation/book_metadata_candidate_presentation.dart';
import '../presentation/book_metadata_warning_presentation.dart';
import '../presentation/metadata_enrichment_ui_messages.dart';
import '../services/book_candidate_review_policy.dart';
import '../services/book_candidate_selection_context.dart';
import '../services/book_metadata_matching_coordinator.dart';
import '../services/book_metadata_matching_result.dart';
import 'book_metadata_candidate_card.dart';

/// Result of the metadata candidate review dialog (M7.3.4).
sealed class BookMetadataCandidateDialogResult {
  const BookMetadataCandidateDialogResult();
}

class BookMetadataCandidateDialogCancelled
    extends BookMetadataCandidateDialogResult {
  const BookMetadataCandidateDialogCancelled();
}

class BookMetadataCandidateDialogSuccess
    extends BookMetadataCandidateDialogResult {
  const BookMetadataCandidateDialogSuccess({
    required this.recordId,
    required this.message,
  });

  final String recordId;
  final String message;
}

class BookMetadataCandidateDialogFailure
    extends BookMetadataCandidateDialogResult {
  const BookMetadataCandidateDialogFailure(this.message);

  final String message;
}

class BookMetadataCandidateDialogInvalidContext
    extends BookMetadataCandidateDialogResult {
  const BookMetadataCandidateDialogInvalidContext();
}

/// Dialog closed because the detail item changed (M7.3.4).
class BookMetadataCandidateDialogDismissedByItemChange
    extends BookMetadataCandidateDialogResult {
  const BookMetadataCandidateDialogDismissedByItemChange();
}

/// Tracks whether a candidate-review session is still active for its item.
class BookMetadataCandidateDialogScope {
  BookMetadataCandidateDialogScope({
    required this.itemId,
    required this.sessionGeneration,
  });

  final String itemId;
  final int sessionGeneration;
  bool _invalidated = false;

  bool get isActive => !_invalidated;

  void invalidate() {
    _invalidated = true;
  }
}

/// Handle for an open candidate-review dialog owned by the enrichment section.
class BookMetadataCandidateDialogSession {
  BookMetadataCandidateDialogSession({
    required this.itemId,
    required this.sessionGeneration,
    required this.scope,
    required this.navigator,
    required this.result,
    required void Function(BookMetadataCandidateDialogResult result)
        dismissWithResult,
  }) : _dismissWithResult = dismissWithResult;

  final String itemId;
  final int sessionGeneration;
  final BookMetadataCandidateDialogScope scope;
  final NavigatorState navigator;
  final Future<BookMetadataCandidateDialogResult?> result;
  final void Function(BookMetadataCandidateDialogResult result)
      _dismissWithResult;
  bool _dismissed = false;

  void dismissByItemChange() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    scope.invalidate();
    _dismissWithResult(
      const BookMetadataCandidateDialogDismissedByItemChange(),
    );
  }
}

/// Explicit candidate review and selection dialog (M7.3.4).
class BookMetadataCandidateDialog extends StatefulWidget {
  const BookMetadataCandidateDialog({
    super.key,
    required this.item,
    required this.selectionContext,
    required this.coordinator,
    required this.isRelink,
    required this.scope,
  });

  static const routeName = 'book_metadata_candidate_dialog';

  final MediaItem item;
  final BookCandidateSelectionContext selectionContext;
  final BookMetadataMatchingCoordinator coordinator;
  final bool isRelink;
  final BookMetadataCandidateDialogScope scope;

  static Future<BookMetadataCandidateDialogResult?> show({
    required BuildContext context,
    required MediaItem item,
    required BookCandidateSelectionContext selectionContext,
    required BookMetadataMatchingCoordinator coordinator,
    required bool isRelink,
    BookMetadataCandidateDialogScope? scope,
  }) {
    final resolvedScope = scope ??
        BookMetadataCandidateDialogScope(
          itemId: item.id,
          sessionGeneration: 0,
        );
    return showDialog<BookMetadataCandidateDialogResult>(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: routeName),
      builder: (context) => BookMetadataCandidateDialog(
        item: item,
        selectionContext: selectionContext,
        coordinator: coordinator,
        isRelink: isRelink,
        scope: resolvedScope,
      ),
    );
  }

  static BookMetadataCandidateDialogSession open({
    required BuildContext context,
    required MediaItem item,
    required BookCandidateSelectionContext selectionContext,
    required BookMetadataMatchingCoordinator coordinator,
    required bool isRelink,
    required int sessionGeneration,
  }) {
    final scope = BookMetadataCandidateDialogScope(
      itemId: item.id,
      sessionGeneration: sessionGeneration,
    );
    final navigator = Navigator.of(context);

    final result = show(
      context: context,
      item: item,
      selectionContext: selectionContext,
      coordinator: coordinator,
      isRelink: isRelink,
      scope: scope,
    );

    return BookMetadataCandidateDialogSession(
      itemId: item.id,
      sessionGeneration: sessionGeneration,
      scope: scope,
      navigator: navigator,
      result: result,
      dismissWithResult: (dialogResult) {
        popRoute(navigator, dialogResult);
      },
    );
  }

  static void popRoute(
    NavigatorState navigator,
    BookMetadataCandidateDialogResult result,
  ) {
    if (!navigator.canPop()) {
      return;
    }

    var foundCandidateDialog = false;
    navigator.popUntil((route) {
      if (route.settings.name == routeName) {
        foundCandidateDialog = true;
        return true;
      }
      return false;
    });

    if (foundCandidateDialog && navigator.canPop()) {
      navigator.pop(result);
    }
  }

  @override
  State<BookMetadataCandidateDialog> createState() =>
      _BookMetadataCandidateDialogState();
}

class _BookMetadataCandidateDialogState extends State<BookMetadataCandidateDialog> {
  String? _selectedRecordId;
  bool _saving = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final recordIds = BookMetadataCandidatePresentation.orderedReviewableRecordIds(
      widget.selectionContext,
    );
    final presentations = recordIds
        .map(
          (recordId) => BookMetadataCandidatePresentation.fromContext(
            context: widget.selectionContext,
            providerRecordId: recordId,
          ),
        )
        .whereType<BookMetadataCandidatePresentation>()
        .toList();

    final title = widget.isRelink
        ? 'Replace metadata link'
        : 'Review metadata candidates';
    final countLabel =
        '${presentations.length} metadata candidate${presentations.length == 1 ? '' : 's'}';

    return Dialog(
      key: const Key('book_metadata_candidate_dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                countLabel,
                key: const Key('book_metadata_candidate_count'),
                style: AppTypography.labelMuted,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_statusMessage != null) ...[
                Text(
                  _statusMessage!,
                  key: const Key('book_metadata_candidate_message'),
                  style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: AppTypography.size13,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_saving) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: AppSpacing.sm),
              ],
              Expanded(
                child: Scrollbar(
                  child: ListView.separated(
                    key: const Key('book_metadata_candidate_list'),
                    itemCount: presentations.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final presentation = presentations[index];
                      return BookMetadataCandidateCard(
                        presentation: presentation,
                        groupValue: _selectedRecordId,
                        selected: _selectedRecordId == presentation.recordId,
                        onSelected: _saving ? (_) {} : _selectRecord,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const Key('book_metadata_candidate_cancel'),
                    onPressed: _saving ? null : () => _closeCancelled(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const Key('book_metadata_candidate_use'),
                    onPressed: _saving || _selectedRecordId == null
                        ? null
                        : _beginUseSelected,
                    child: const Text('Use this metadata'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectRecord(String recordId) {
    setState(() {
      _selectedRecordId = recordId;
      _statusMessage = null;
    });
  }

  Future<void> _beginUseSelected() async {
    final recordId = _selectedRecordId;
    if (recordId == null || _saving) {
      return;
    }
    final evaluation = widget.selectionContext.evaluationForRecordId(recordId);
    if (evaluation == null) {
      _closeInvalidContext();
      return;
    }

    final needsCriticalOverride =
        BookCandidateReviewPolicy.requiresCriticalConflictOverride(evaluation);

    if (needsCriticalOverride) {
      final overrideConfirmed = await _confirmCriticalOverride(evaluation);
      if (!mounted || !overrideConfirmed) {
        return;
      }
      await _persistSelection(
        recordId,
        confirmation: BookCandidateSelectionConfirmation.overrideCriticalConflicts,
      );
      return;
    }

    final confirmed = await _confirmOrdinarySelection();
    if (!mounted || !confirmed) {
      return;
    }
    await _persistSelection(recordId);
  }

  Future<bool> _confirmOrdinarySelection() async {
    final message = widget.isRelink
        ? 'Replace the current external metadata link? Your local file and any locked or user-edited fields will remain authoritative.'
        : 'Use metadata from this candidate? Your local file remains the source of truth.';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.isRelink ? 'Replace metadata link?' : 'Use this metadata?'),
        content: Text(message),
        actions: [
          TextButton(
            key: const Key('book_metadata_candidate_confirm_cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('book_metadata_candidate_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(widget.isRelink ? 'Replace link' : 'Use metadata'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmCriticalOverride(
    BookCandidateMatchEvaluation evaluation,
  ) async {
    final warnings = BookMetadataWarningPresentation.forEvaluation(evaluation)
        .where((warning) => warning.isCritical)
        .map((warning) => warning.message)
        .toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review warnings'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This candidate conflicts with local book information.\n\n'
                'Review the warnings before continuing. Choosing it will link the external '
                'metadata, but your local file and locked or user-edited fields will remain '
                'authoritative.',
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      warning,
                      key: const Key('book_metadata_candidate_critical_warning'),
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('book_metadata_candidate_critical_cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('book_metadata_candidate_critical_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Use candidate anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _persistSelection(
    String recordId, {
    BookCandidateSelectionConfirmation confirmation =
        BookCandidateSelectionConfirmation.normal,
  }) async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    final result = widget.isRelink
        ? await widget.coordinator.relinkCandidate(
            item: widget.item,
            context: widget.selectionContext,
            providerRecordId: recordId,
            confirmation: confirmation,
          )
        : await widget.coordinator.selectCandidate(
            item: widget.item,
            context: widget.selectionContext,
            providerRecordId: recordId,
            confirmation: confirmation,
          );

    if (!mounted || !widget.scope.isActive) {
      return;
    }

    switch (result) {
      case BookCandidateSelectionConflictConfirmationRequired():
        setState(() {
          _saving = false;
        });
        final evaluation =
            widget.selectionContext.evaluationForRecordId(recordId);
        if (evaluation == null) {
          _closeInvalidContext();
          return;
        }
        final overrideConfirmed = await _confirmCriticalOverride(evaluation);
        if (!mounted || !overrideConfirmed) {
          return;
        }
        await _persistSelection(
          recordId,
          confirmation: BookCandidateSelectionConfirmation.overrideCriticalConflicts,
        );
      case BookCandidateSelectionSuccess(:final record):
        if (!mounted || !widget.scope.isActive) {
          return;
        }
        final sameRecordRelink = widget.isRelink &&
            widget.selectionContext.itemId == record.itemId &&
            record.providerRecordId == recordId;
        Navigator.of(context).pop(
          BookMetadataCandidateDialogSuccess(
            recordId: recordId,
            message: sameRecordRelink
                ? 'This metadata is already linked.'
                : MetadataEnrichmentUiMessages.selectionSuccessMessage,
          ),
        );
      case BookCandidateSelectionRepositoryFailure():
        setState(() {
          _saving = false;
          _statusMessage = MetadataEnrichmentUiMessages.repositoryFailureMessage;
        });
      case BookCandidateSelectionInvalidContext():
        _closeInvalidContext();
      case BookCandidateSelectionRejected():
        setState(() {
          _saving = false;
          _statusMessage =
              MetadataEnrichmentUiMessages.selectionResultMessage(result);
        });
    }
  }

  void _closeCancelled() {
    Navigator.of(context).pop(const BookMetadataCandidateDialogCancelled());
  }

  void _closeInvalidContext() {
    Navigator.of(context).pop(const BookMetadataCandidateDialogInvalidContext());
  }
}
