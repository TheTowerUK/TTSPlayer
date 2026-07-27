import 'package:flutter/material.dart';

import '../features/reading/services/reading_progress_coordinator.dart';

/// Flushes reading progress when the app moves to the background (M6.5).
class ReadingProgressLifecycleObserver extends StatefulWidget {
  const ReadingProgressLifecycleObserver({
    super.key,
    required this.coordinator,
    required this.child,
  });

  final ReadingProgressCoordinator coordinator;
  final Widget child;

  @override
  State<ReadingProgressLifecycleObserver> createState() =>
      _ReadingProgressLifecycleObserverState();
}

class _ReadingProgressLifecycleObserverState
    extends State<ReadingProgressLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // ignore: discarded_futures
      widget.coordinator.onAppLifecyclePaused();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
