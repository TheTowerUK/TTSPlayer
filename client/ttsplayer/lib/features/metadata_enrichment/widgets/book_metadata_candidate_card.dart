import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../presentation/book_metadata_candidate_presentation.dart';
import '../presentation/book_metadata_warning_presentation.dart';

/// Selectable metadata candidate card (M7.3.4).
class BookMetadataCandidateCard extends StatelessWidget {
  const BookMetadataCandidateCard({
    super.key,
    required this.presentation,
    required this.groupValue,
    required this.selected,
    required this.onSelected,
  });

  final BookMetadataCandidatePresentation presentation;
  final String? groupValue;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final suffix =
        BookMetadataCandidatePresentation.keySuffixForRecordId(presentation.recordId);

    return Semantics(
      selected: selected,
      label:
          '${presentation.title}, ${presentation.matchSummary}${presentation.author == null ? '' : ', ${presentation.author}'}',
      child: Card(
        key: Key('book_metadata_candidate_card_$suffix'),
        color: selected ? AppColors.card.withValues(alpha: 0.9) : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () => onSelected(presentation.recordId),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<String>(
                  key: Key('book_metadata_candidate_radio_$suffix'),
                  value: presentation.recordId,
                  groupValue: groupValue,
                  onChanged: (_) => onSelected(presentation.recordId),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presentation.title,
                        key: Key('book_metadata_candidate_title_$suffix'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.size14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (presentation.subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          presentation.subtitle!,
                          style: AppTypography.labelMuted,
                        ),
                      ],
                      if (presentation.author != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          presentation.author!,
                          key: Key('book_metadata_candidate_author_$suffix'),
                          style: const TextStyle(
                            color: AppColors.textHigh,
                            fontSize: AppTypography.size13,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        presentation.matchSummary,
                        key: Key('book_metadata_candidate_match_$suffix'),
                        style: const TextStyle(
                          color: AppColors.textHigh,
                          fontSize: AppTypography.size12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final detail in _detailLines(presentation))
                            Text(
                              detail,
                              style: AppTypography.labelMuted,
                            ),
                        ],
                      ),
                      if (presentation.warnings.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ...presentation.warnings.map(_warningLine),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _detailLines(BookMetadataCandidatePresentation presentation) {
    final lines = <String>[];
    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        lines.add('$label: $value');
      }
    }

    add('Year', presentation.publicationYear);
    add('Publisher', presentation.publisher);
    add('Edition', presentation.edition);
    add('Language', presentation.language);
    add('Series', presentation.series);
    add('Volume', presentation.volume);
    add('ISBN', presentation.isbn);
    return lines;
  }

  Widget _warningLine(BookMetadataWarningPresentation warning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        warning.message,
        key: Key(
          'book_metadata_candidate_warning_${warning.isCritical ? 'critical' : 'info'}_${warning.message.hashCode}',
        ),
        style: TextStyle(
          color: warning.isCritical ? AppColors.textHigh : AppColors.textMedium,
          fontSize: AppTypography.size12,
          fontWeight: warning.isCritical ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
