import 'dart:io';

import 'package:flutter/foundation.dart';

import 'media_access/media_location_resolver.dart';

/// Windows MVP uses media_kit — video_player has no Windows implementation.
bool get useMediaKitPlayback => !kIsWeb && Platform.isWindows;

/// Injectable override for tests — when null, uses [useMediaKitPlayback].
@visibleForTesting
bool Function()? playbackSpeedSettingsSupportedOverride;

/// Whether default playback speed can be edited and applied on this platform.
bool get playbackSpeedSettingsSupported =>
    playbackSpeedSettingsSupportedOverride?.call() ?? useMediaKitPlayback;

/// Normalises a resolved URI (or legacy filesystem path) for the playback engine.
///
/// Catalogue paths must be resolved via [MediaLocationResolver] in
/// [PlaybackService.play] before calling this.
String mediaUriForPlayback(
  String pathOrUri, {
  MediaLocationResolver? resolver,
}) {
  if (resolver != null &&
      !pathOrUri.startsWith('http://') &&
      !pathOrUri.startsWith('https://') &&
      !pathOrUri.startsWith('file://')) {
    final resolved = resolver.resolve(pathOrUri);
    if (resolved.isPlayable && resolved.uri != null) {
      return resolved.uri!;
    }
  }

  if (pathOrUri.startsWith('http://') || pathOrUri.startsWith('https://')) {
    return pathOrUri;
  }
  if (pathOrUri.startsWith('file://')) {
    return pathOrUri;
  }
  return Uri.file(pathOrUri).toString();
}
