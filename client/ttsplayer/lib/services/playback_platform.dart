import 'dart:io';

import 'package:flutter/foundation.dart';

/// Windows MVP uses media_kit — video_player has no Windows implementation.
bool get useMediaKitPlayback => !kIsWeb && Platform.isWindows;

/// Normalise catalogue file paths to a URI [MediaKit] can open.
String mediaUriForPlayback(String filePath) {
  if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
    return filePath;
  }
  if (filePath.startsWith('file://')) {
    return filePath;
  }
  return Uri.file(filePath).toString();
}
