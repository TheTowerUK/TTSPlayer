import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/config/metadata_enrichment_feature_config.dart';

void main() {
  group('book metadata matching coordinator isolation', () {
    final serviceDir = Directory(
      'lib/features/metadata_enrichment/services',
    );

    final coordinatorFiles = [
      'book_metadata_matching_coordinator.dart',
      'book_metadata_matching_result.dart',
      'book_candidate_selection_context.dart',
      'book_metadata_match_transition.dart',
    ];

    test('coordinator layer avoids Flutter UI and HTTP implementation imports', () {
      final forbidden = [
        'package:flutter/',
        'BuildContext',
        'http_metadata_http_transport.dart',
        'open_library_book_metadata_provider.dart',
        'package:http/',
      ];

      for (final name in coordinatorFiles) {
        final file = File('${serviceDir.path}/$name');
        final contents = file.readAsStringSync();
        for (final token in forbidden) {
          expect(
            contents.contains(token),
            isFalse,
            reason: '${file.path} must not reference $token',
          );
        }
      }
    });

    test('coordinator constructor does not invoke provider', () {
      final contents = File(
        '${serviceDir.path}/book_metadata_matching_coordinator.dart',
      ).readAsStringSync();

      expect(contents.contains('Timer('), isFalse);
      final start = contents.indexOf('BookMetadataMatchingCoordinator({');
      final end = contents.indexOf('})  : _provider = provider,');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final constructorParams = contents.substring(start, end);
      expect(constructorParams.contains('_provider.'), isFalse);
      expect(constructorParams.contains('lookupByIsbn'), isFalse);
      expect(constructorParams.contains('.search('), isFalse);
    });

    test('coordinator tests avoid Open Library implementation imports', () {
      final tests = [
        'test/book_metadata_matching_coordinator_test.dart',
        'test/book_metadata_matching_transitions_test.dart',
        'test/book_metadata_enrichment_section_test.dart',
        'test/item_detail_screen_test.dart',
      ];
      final forbidden = [
        'open_library_book_metadata_provider.dart',
        'http_metadata_http_transport.dart',
      ];

      for (final path in tests) {
        final contents = File(path).readAsStringSync();
        for (final token in forbidden) {
          expect(
            contents.contains(token),
            isFalse,
            reason: '$path must not import $token',
          );
        }
      }
    });

    test('enrichment section widget avoids provider implementation imports', () {
      final widgetFile = File(
        'lib/features/metadata_enrichment/widgets/book_metadata_enrichment_section.dart',
      );
      final contents = widgetFile.readAsStringSync();
      final forbidden = [
        'open_library_book_metadata_provider.dart',
        'http_metadata_http_transport.dart',
        'package:http/',
      ];
      for (final token in forbidden) {
        expect(
          contents.contains(token),
          isFalse,
          reason: '${widgetFile.path} must not reference $token',
        );
      }
      expect(contents.contains('selectCandidate'), isFalse);
      expect(contents.contains('Timer('), isFalse);
    });

    test('feature gate defaults off', () {
      expect(
        MetadataEnrichmentFeatureConfig.defaults
            .metadataEnrichmentDevelopmentEnabled,
        isFalse,
      );
    });
  });
}
