import 'package:flutter/material.dart';

import '../features/settings/settings_navigation.dart';
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
        IconButton(
          key: const Key('open_settings'),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () {
            openMediaProviderSettingsScreen(context);
          },
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
