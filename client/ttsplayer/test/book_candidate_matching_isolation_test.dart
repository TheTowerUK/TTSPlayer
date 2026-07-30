import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('book candidate matching isolation', () {
    final matchingDir = Directory(
      'lib/features/metadata_enrichment/matching',
    );

    test('matching layer source files avoid persistence and networking imports', () {
      final forbidden = [
        'metadata_enrichment_repository.dart',
        'book_metadata_refresh_service.dart',
        'metadata_http_transport.dart',
        'http_metadata_http_transport.dart',
        'open_library',
        'package:http/',
        'package:flutter/',
      ];

      for (final file in matchingDir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.dart')) {
          continue;
        }
        final contents = file.readAsStringSync();
        for (final token in forbidden) {
          expect(
            contents.contains(token),
            isFalse,
            reason: '${file.path} must not import $token',
          );
        }
      }
    });

    test('matching tests avoid provider and repository imports', () {
      final tests = [
        'test/book_match_normalizer_test.dart',
        'test/isbn_equivalence_test.dart',
        'test/book_candidate_evaluator_test.dart',
        'test/book_candidate_ranker_test.dart',
      ];
      final forbidden = [
        'metadata_enrichment_repository.dart',
        'book_metadata_refresh_service.dart',
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
  });
}
