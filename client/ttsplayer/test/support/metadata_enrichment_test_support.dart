import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/metadata_enrichment/services/metadata_enrichment_repository.dart';

Future<MetadataEnrichmentRepository> initializedMetadataEnrichmentRepository({
  Map<String, Object>? initialPreferences,
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences ?? {});
  final repository = MetadataEnrichmentRepository();
  await repository.initialize();
  return repository;
}

String enrichmentEnvelopeJson(List<Map<String, Object?>> records) {
  return jsonEncode({
    'stateVersion': MetadataEnrichmentRepository.currentStateVersion,
    'records': records,
  });
}
