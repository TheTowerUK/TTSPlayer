import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/metadata_enrichment/models/metadata_enrichment_record.dart';
import '../../features/metadata_enrichment/services/metadata_enrichment_repository.dart';
import '../../features/metadata_enrichment/artwork/metadata_artwork_resolution.dart';
import '../../models/media_folder.dart';
import '../../models/media_item.dart';
import '../../services/artwork/artwork_candidate.dart';
import '../../services/artwork/artwork_presentation_service.dart';
import '../../services/artwork/artwork_service.dart';
import 'artwork_image.dart';

/// Renders media-item artwork via [ArtworkPresentationService] (M7.4.6).
///
/// Falls back to [ArtworkService] when the presentation service is absent.
/// Watches enrichment repository so link/unlink updates presentation without
/// widget-level precedence logic.
class ResolvedMediaArtworkImage extends StatelessWidget {
  const ResolvedMediaArtworkImage({
    super.key,
    required this.item,
    this.parentFolder,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.iconSize,
    this.logicalDecodeSize,
  });

  final MediaItem item;
  final MediaFolder? parentFolder;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? iconSize;
  final Size? logicalDecodeSize;

  @override
  Widget build(BuildContext context) {
    final presentation = _readPresentationService(context);
    if (presentation == null) {
      final candidate = context.read<ArtworkService>().forMediaItem(
            item,
            parentFolder: parentFolder,
          );
      return ArtworkImage(
        candidate: candidate,
        fit: fit,
        borderRadius: borderRadius,
        iconSize: iconSize,
        logicalDecodeSize: logicalDecodeSize,
      );
    }

    MetadataEnrichmentRepository? repository;
    try {
      repository = context.watch<MetadataEnrichmentRepository>();
    } on ProviderNotFoundException {
      final candidate = presentation.localCandidateForMediaItem(
        item,
        parentFolder: parentFolder,
      );
      return ArtworkImage(
        candidate: candidate,
        fit: fit,
        borderRadius: borderRadius,
        iconSize: iconSize,
        logicalDecodeSize: logicalDecodeSize,
      );
    }

    final record = repository.getByItemId(item.id);
    final signature = _signatureFor(item.id, record);
    final local = presentation.localCandidateForMediaItem(
      item,
      parentFolder: parentFolder,
    );

    return _ResolvedArtworkGate(
      key: ValueKey<String>(signature),
      initialCandidate: local,
      resolve: () => presentation.resolveForMediaItem(
        item: item,
        parentFolder: parentFolder,
      ),
      fit: fit,
      borderRadius: borderRadius,
      iconSize: iconSize,
      logicalDecodeSize: logicalDecodeSize,
    );
  }

  static ArtworkPresentationService? _readPresentationService(
    BuildContext context,
  ) {
    try {
      return Provider.of<ArtworkPresentationService?>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  static String _signatureFor(
    String itemId,
    MetadataEnrichmentRecord? record,
  ) {
    if (record == null) {
      return '$itemId|none';
    }
    final artwork = record.artworkReference;
    return '$itemId|${record.matchState}|${record.providerRecordId}|'
        '${artwork?.cacheKey}|${artwork?.cacheState}|'
        '${artwork?.localRelativePath}';
  }
}

class _ResolvedArtworkGate extends StatefulWidget {
  const _ResolvedArtworkGate({
    super.key,
    required this.initialCandidate,
    required this.resolve,
    required this.fit,
    this.borderRadius,
    this.iconSize,
    this.logicalDecodeSize,
  });

  final ArtworkCandidate initialCandidate;
  final Future<MetadataArtworkResolution> Function() resolve;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? iconSize;
  final Size? logicalDecodeSize;

  @override
  State<_ResolvedArtworkGate> createState() => _ResolvedArtworkGateState();
}

class _ResolvedArtworkGateState extends State<_ResolvedArtworkGate> {
  late ArtworkCandidate _candidate;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _candidate = widget.initialCandidate;
    _startResolve();
  }

  void _startResolve() {
    final generation = ++_generation;
    widget.resolve().then((resolution) {
      if (!mounted || generation != _generation) {
        return;
      }
      final candidate = resolution.candidate;
      if (_candidate.filePath == candidate.filePath &&
          _candidate.source == candidate.source) {
        return;
      }
      setState(() => _candidate = candidate);
    }).catchError((_) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _candidate = widget.initialCandidate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ArtworkImage(
      candidate: _candidate,
      fit: widget.fit,
      borderRadius: widget.borderRadius,
      iconSize: widget.iconSize,
      logicalDecodeSize: widget.logicalDecodeSize,
    );
  }
}
