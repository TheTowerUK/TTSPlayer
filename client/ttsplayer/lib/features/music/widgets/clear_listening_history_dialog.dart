import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme.dart';
import '../services/music_listening_repository.dart';

/// Result of [ClearListeningHistoryDialog].
enum ClearListeningHistoryDialogResult {
  cancelled,
  cleared,
  failed,
}

/// Confirmation dialog for clearing all music listening history (M5.4 Step 6).
class ClearListeningHistoryDialog extends StatefulWidget {
  const ClearListeningHistoryDialog({super.key});

  @override
  State<ClearListeningHistoryDialog> createState() =>
      _ClearListeningHistoryDialogState();
}

class _ClearListeningHistoryDialogState
    extends State<ClearListeningHistoryDialog> {
  bool _clearing = false;

  Future<void> _onClear() async {
    if (_clearing) return;

    setState(() => _clearing = true);
    final result = await context.read<MusicListeningRepository>().clearAll();
    if (!mounted) return;

    switch (result.outcome) {
      case MusicListeningClearOutcome.cleared:
      case MusicListeningClearOutcome.alreadyEmpty:
        Navigator.pop(context, ClearListeningHistoryDialogResult.cleared);
      case MusicListeningClearOutcome.persistenceFailed:
        Navigator.pop(context, ClearListeningHistoryDialogResult.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('music_clear_listening_history_dialog'),
      title: const Text('Clear listening history?'),
      content: const Text(
        'This removes Continue Listening and Recently Played entries. '
        'Your music files, queues, favourites, and video watch history '
        'are not affected.',
      ),
      actions: [
        TextButton(
          onPressed: _clearing
              ? null
              : () => Navigator.pop(
                    context,
                    ClearListeningHistoryDialogResult.cancelled,
                  ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_clear_listening_history'),
          onPressed: _clearing ? null : _onClear,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _clearing
              ? const SizedBox(
                  width: AppIcons.md,
                  height: AppIcons.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Clear'),
        ),
      ],
    );
  }
}
