import 'package:flutter/material.dart';

/// Root navigator for app-wide navigation actions (e.g. after catalogue refresh).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Observes route changes so the dashboard can refresh when it becomes visible.
final routeObserver = RouteObserver<ModalRoute<void>>();

/// Pops all routes until HomeScreen so browsing uses the latest catalogue tree.
void popNavigationToHome() {
  rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}
