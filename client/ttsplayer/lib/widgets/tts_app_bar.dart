import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../features/search/search_navigation.dart';
import 'home_button.dart';

/// Unified application bar used on every non-player screen.
///
/// Layout:
///   Left   — auto back-button (Flutter default) when Navigator has a previous route
///   Centre — [title]
///   Right  — [extraActions] → Home (when [showHome]) → Search → Settings
class TtsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showHome;
  final List<Widget> extraActions;

  const TtsAppBar({
    super.key,
    required this.title,
    this.showHome = true,
    this.extraActions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        ...extraActions,
        if (showHome) const HomeButton(),
        IconButton(
          icon: const Icon(Icons.search_outlined),
          tooltip: 'Search',
          onPressed: () => openSearchScreen(context),
        ),
        const _DisabledActionButton(
          icon: Icons.settings_outlined,
          label: 'Settings',
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

class _DisabledActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DisabledActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.textLow),
      tooltip: '$label — Coming Soon',
      onPressed: () {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label is coming soon.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
