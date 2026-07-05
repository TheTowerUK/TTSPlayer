import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/artwork/artwork_candidate.dart';
import '../../services/artwork/artwork_kind.dart';
import '../../services/artwork/library_visual_kind.dart';
import 'media_placeholder.dart';

/// Loads local/UNC artwork with graceful fallback to [MediaPlaceholder].
class ArtworkImage extends StatelessWidget {
  final ArtworkCandidate candidate;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? iconSize;

  const ArtworkImage({
    super.key,
    required this.candidate,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize,
  });

  /// Convenience constructor when only a path and visual kind are known.
  ArtworkImage.fromPath({
    super.key,
    required String? filePath,
    required LibraryVisualKind visualKind,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize,
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

    if (candidate.hasFile && !_isNetworkPath(candidate.filePath!)) {
      child = Image.file(
        File(candidate.filePath!),
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (candidate.hasFile && _isNetworkPath(candidate.filePath!)) {
      // Reserved for future HTTP — not used in M3 Sprint 3.
      child = Image.network(
        candidate.filePath!,
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

  Widget _placeholder() => MediaPlaceholder(
        kind: candidate.visualKind,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  static bool _isNetworkPath(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}
