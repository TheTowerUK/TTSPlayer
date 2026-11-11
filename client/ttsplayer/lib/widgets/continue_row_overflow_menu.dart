import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Overflow control for dismissing a Continue Watching or Continue Reading card.
void showContinueRowRemovedSnackBar(
  BuildContext context, {
  required String message,
  required String undoLabel,
  required Key snackBarKey,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      key: snackBarKey,
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: undoLabel,
        onPressed: onUndo,
      ),
    ),
  );
}

/// Overflow control for dismissing a Continue Watching or Continue Reading card.
class ContinueRowOverflowMenu extends StatelessWidget {
  const ContinueRowOverflowMenu({
    super.key,
    required this.menuKey,
    required this.removeKey,
    required this.tooltip,
    required this.removeLabel,
    required this.onRemove,
  });

  final Key menuKey;
  final Key removeKey;
  final String tooltip;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<String>(
        key: menuKey,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: AppIcons.md),
        color: AppColors.surface,
        onSelected: (value) {
          if (value == 'remove') onRemove();
        },
        itemBuilder: (context) {
          return [
            PopupMenuItem<String>(
              key: removeKey,
              value: 'remove',
              child: Text(removeLabel),
            ),
          ];
        },
      ),
    );
  }
}
