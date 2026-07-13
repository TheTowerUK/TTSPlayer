import 'package:flutter/material.dart';

import '../models/media_folder.dart';
import '../screens/folder_screen.dart';

/// Route name for a [FolderScreen] keyed by catalogue folder id (ADR-009).
String folderRouteName(String folderId) => 'folder:$folderId';

/// Opens [folder] with a fresh push and a stable route identity.
void openFolderScreen(BuildContext context, MediaFolder folder) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: folderRouteName(folder.id)),
      builder: (_) => FolderScreen.fromFolder(folder),
    ),
  );
}

/// Navigates to a breadcrumb ancestor folder (ADR-009).
///
/// - Current segment: no-op.
/// - Ancestor already on the route stack: [Navigator.popUntil] to that route.
/// - Otherwise: pops to the nearest stop (dashboard if ancestor absent), then
///   pushes the target folder.
///
/// Predictable over complex stack surgery; does not persist routes.
Future<void> navigateToBreadcrumbFolder(
  BuildContext context, {
  required MediaFolder target,
  required String currentFolderId,
}) async {
  if (target.id == currentFolderId) return;

  final navigator = Navigator.of(context);
  final targetName = folderRouteName(target.id);
  var foundTarget = false;

  navigator.popUntil((route) {
    if (route.settings.name == targetName) {
      foundTarget = true;
      return true;
    }
    if (route.isFirst) return true;
    return false;
  });

  if (foundTarget) return;

  await navigator.push<void>(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: targetName),
      builder: (_) => FolderScreen.fromFolder(target),
    ),
  );
}
