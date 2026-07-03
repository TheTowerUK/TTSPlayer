import 'package:flutter/material.dart';

/// Root navigator for app-wide navigation actions (e.g. after catalogue refresh).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pops all routes until HomeScreen so browsing uses the latest catalogue tree.
void popNavigationToHome() {
  rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}
