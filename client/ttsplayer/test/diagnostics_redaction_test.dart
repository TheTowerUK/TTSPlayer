import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_export_formatter.dart';
import 'package:ttsplayer/services/diagnostics/diagnostics_redaction.dart';

import 'support/diagnostics_test_harness.dart';

void main() {
  group('redactIdentity', () {
    test('returns short identities unchanged', () {
      expect(redactIdentity('abc'), 'abc');
    });

    test('truncates long identities', () {
      expect(
        redactIdentity('abcdefghijklmnopqrstuvwxyz'),
        'abcdefghijkl…',
      );
      expect(
        redactIdentity('2026-07-01T20:14:53Z-8F2A1B'),
        '2026-07-01T2…',
      );
    });
  });

  group('redactSensitiveText', () {
    const samples = <String>[
      r'Y:\Media\catalog.json',
      r'\\SERVER\Share\catalog.json',
      '/volume1/Media/catalog.json',
      'file:///C:/Users/example/catalog.json',
      'https://host.example/media/catalog.json?token=secret',
      'https://user:password@host.example/catalog.json',
    ];

    for (final sample in samples) {
      test('removes sensitive content from: $sample', () {
        final redacted = redactSensitiveText('Load failed at $sample');
        expect(containsSensitivePatterns(redacted), isFalse);
        expect(redacted.contains('secret'), isFalse);
        expect(redacted.contains('password'), isFalse);
        expect(redacted.contains(r'Y:\Media'), isFalse);
        expect(redacted.contains(r'\\SERVER'), isFalse);
      });
    }

    test('preserves non-sensitive diagnostic labels', () {
      final redacted = redactSensitiveText('Provider health: failed');
      expect(redacted, contains('Provider health'));
      expect(redacted, contains('failed'));
    });
  });

  group('formatDiagnosticsExport', () {
    test('uses stable section headings', () {
      final export = formatDiagnosticsExport(minimalSnapshot());
      expect(export, contains('=== Application ==='));
      expect(export, contains('=== Provider ==='));
      expect(export, contains('=== Catalogue ==='));
      expect(export, contains('=== Cache ==='));
      expect(export, contains('=== Search ==='));
      expect(export, contains('=== Playback ==='));
      expect(export, contains('=== Library ==='));
      expect(exportContainsSensitiveData(export), isFalse);
    });

    test('renders unavailable values consistently', () {
      final export = formatDiagnosticsExport(minimalSnapshot());
      expect(export, isNot(contains('Instance of')));
    });
  });
}
