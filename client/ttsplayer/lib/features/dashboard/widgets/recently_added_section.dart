import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';

/// Recently Added — empty state for Sprint 1.
///
/// TODO(M3+): Populate from catalogue item [addedAt] once the indexer emits
/// per-item timestamps. See docs/roadmap/m3-personal-media-experience.md.
class RecentlyAddedSection extends StatelessWidget {
  const RecentlyAddedSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Recently Added'),
        SizedBox(height: AppSpacing.md),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: EmptyState(
            icon: Icons.new_releases_outlined,
            title: 'Recently Added is not available yet.',
            subtitle:
                'This section will list new items after the scanner '
                'records when each file was indexed.',
          ),
        ),
      ],
    );
  }
}
