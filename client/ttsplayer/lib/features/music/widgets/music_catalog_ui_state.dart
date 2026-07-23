import 'package:flutter/material.dart';

import '../../../services/catalog_service.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_card.dart';

/// Shared catalogue loading / missing / failure gates for music surfaces
/// (Phase 5.6 Step 5). Returns null when [catalogService.catalog] is usable.
Widget? musicCatalogUnavailableBody(CatalogService catalogService) {
  if (catalogService.isLoading && catalogService.catalog == null) {
    return const LoadingCard(
      key: Key('music_catalog_loading'),
      message: 'Loading music…',
    );
  }

  if (catalogService.catalog != null) {
    return null;
  }

  final error = catalogService.errorMessage?.trim();
  if (error != null && error.isNotEmpty) {
    return EmptyState(
      key: const Key('music_catalog_load_error'),
      icon: Icons.error_outline,
      title: 'Could not load catalogue.',
      subtitle: sanitizeMusicCatalogError(error),
      actionLabel: 'Retry',
      onAction: () {
        catalogService.refreshCatalogue();
      },
    );
  }

  return const EmptyState(
    key: Key('music_catalog_missing'),
    icon: Icons.library_music_outlined,
    title: 'No catalogue loaded.',
    subtitle: 'Load a catalogue to browse music.',
  );
}

/// Soft reload warning when a previous catalogue is still shown (graceful
/// degradation). Never includes raw filesystem paths beyond what CatalogService
/// already sanitised into [errorMessage].
Widget? musicCatalogDegradedBanner(CatalogService catalogService) {
  final catalog = catalogService.catalog;
  final error = catalogService.errorMessage?.trim();
  if (catalog == null || error == null || error.isEmpty) {
    return null;
  }

  return Material(
    key: const Key('music_catalog_degraded_banner'),
    color: Colors.orange.shade50,
    child: ListTile(
      dense: true,
      leading:
          Icon(Icons.warning_amber_outlined, color: Colors.orange.shade800),
      title: Text(
        sanitizeMusicCatalogError(error),
        style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
      ),
    ),
  );
}

/// Strips accidental absolute path / URI leakage from user-facing errors.
@visibleForTesting
String sanitizeMusicCatalogError(String message) {
  var cleaned = message;
  cleaned = cleaned.replaceAll(
    RegExp(r'[A-Za-z]:\\[^\s]+'),
    '[path]',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'\\\\[^\s]+'),
    '[path]',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'file:[^\s]+', caseSensitive: false),
    '[path]',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'https?:[^\s]+', caseSensitive: false),
    '[location]',
  );
  return cleaned.trim().isEmpty
      ? 'Something went wrong loading the catalogue.'
      : cleaned.trim();
}
