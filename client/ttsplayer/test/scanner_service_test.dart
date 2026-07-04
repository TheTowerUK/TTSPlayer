import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/scanner_service.dart';

void main() {
  group('ScannerService navigation', () {
    test('full scan navigates home after success', () {
      expect(ScannerService.navigatesHomeAfterSuccess(const []), isTrue);
    });

    test('library scan stays in current navigation context', () {
      expect(
        ScannerService.navigatesHomeAfterSuccess(
          const ['--library-path', r'Y:\Media\Videos'],
        ),
        isFalse,
      );
    });
  });
}
