import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/artwork/artwork_candidate.dart';
import '../../services/artwork/artwork_kind.dart';
import '../../services/artwork/library_visual_kind.dart';
import '../../services/media_access/media_location_resolver.dart';
import 'media_placeholder.dart';

/// Loads artwork with graceful fallback to [MediaPlaceholder].
///
/// Filesystem paths on [ArtworkCandidate] are resolved at load time via
/// [MediaLocationResolver]; discovery in [ArtworkService] stays on raw paths.
class ArtworkImage extends StatelessWidget {
  final ArtworkCandidate candidate;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? iconSize;

  /// Optional override for tests; otherwise read from [Provider].
  final MediaLocationResolver? mediaLocationResolver;

  const ArtworkImage({
    super.key,
    required this.candidate,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize,
    this.mediaLocationResolver,
  });

  /// Convenience constructor when only a path and visual kind are known.
  ArtworkImage.fromPath({
    super.key,
    required String? filePath,
    required LibraryVisualKind visualKind,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize,
    this.mediaLocationResolver,
  }) : candidate = ArtworkCandidate(
          kind: ArtworkKind.mediaItem,
          source: filePath != null
              ? ArtworkSource.sidecar
              : ArtworkSource.placeholder,
          filePath: filePath,
          visualKind: visualKind,
        );

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    Widget child;

    final resolver = mediaLocationResolver ??
        Provider.of<MediaLocationResolver>(context, listen: false);

    final loadUri = candidate.hasFile
        ? loadUriForArtworkPath(candidate.filePath!, resolver)
        : null;

    if (loadUri != null && _isNetworkUri(loadUri)) {
      child = Image.network(
        loadUri,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (loadUri != null) {
      child = Image.file(
        _fileForLocalUri(loadUri),
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      child = _placeholder();
    }

    if (radius != null) {
      child = ClipRRect(borderRadius: radius, child: child);
    }
    return child;
  }

  /// Resolves a catalogue filesystem path to a load URI at the artwork boundary.
  @visibleForTesting
  static String? loadUriForArtworkPath(
    String filePath,
    MediaLocationResolver resolver,
  ) {
    final result = resolver.resolve(filePath);
    return result.isPlayable ? result.uri : null;
  }

  static File _fileForLocalUri(String uri) {
    if (uri.startsWith('file://')) {
      return File.fromUri(Uri.parse(uri));
    }
    return File(uri);
  }

  Widget _placeholder() => MediaPlaceholder(
        kind: candidate.visualKind,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  static bool _isNetworkUri(String uri) {
    final lower = uri.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}
