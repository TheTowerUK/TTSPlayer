import 'dart:async';

import 'package:flutter/widgets.dart';

import '../features/music/services/music_playback_session_coordinator.dart';

/// Observes Flutter application lifecycle and flushes playback-session state.
///
/// Delegates to [MusicPlaybackSessionCoordinator.onAppLifecyclePaused] only when
/// coordinator persistence is enabled (after cold-start restore completes).
class MusicPlaybackSessionLifecycleObserver extends StatefulWidget {
  const MusicPlaybackSessionLifecycleObserver({
    super.key,
    required this.coordinator,
    required this.child,
  });

  final MusicPlaybackSessionCoordinator coordinator;
  final Widget child;

  @override
  State<MusicPlaybackSessionLifecycleObserver> createState() =>
      _MusicPlaybackSessionLifecycleObserverState();
}

class _MusicPlaybackSessionLifecycleObserverState
    extends State<MusicPlaybackSessionLifecycleObserver>
    with WidgetsBindingObserver {
  bool _backgroundFlushHandled = false;
  bool _lifecycleFlushInFlight = false;

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
    if (state == AppLifecycleState.resumed) {
      _backgroundFlushHandled = false;
      return;
    }

    if (!_isBackgroundPersistState(state)) {
      return;
    }

    if (_backgroundFlushHandled || _lifecycleFlushInFlight) {
      return;
    }

    if (!widget.coordinator.persistenceEnabled) {
      return;
    }

    _lifecycleFlushInFlight = true;
    unawaited(
      widget.coordinator.onAppLifecyclePaused().whenComplete(() {
        if (!mounted) return;
        _lifecycleFlushInFlight = false;
        _backgroundFlushHandled = true;
      }),
    );
  }

  @visibleForTesting
  void handleAppLifecycleStateChangedForTest(AppLifecycleState state) {
    didChangeAppLifecycleState(state);
  }

  @visibleForTesting
  bool get backgroundFlushHandledForTest => _backgroundFlushHandled;

  @visibleForTesting
  bool get lifecycleFlushInFlightForTest => _lifecycleFlushInFlight;

  static bool _isBackgroundPersistState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        return true;
      case AppLifecycleState.resumed:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
