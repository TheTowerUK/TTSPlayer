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

  group('ScannerService scoped scan arguments', () {
    for (final fixture in <({String kind, String path})>[
      (kind: 'book', path: r'Y:\Literature\Books\Series A'),
      (kind: 'comic', path: r'\\nas\library\Comics\Publisher'),
    ]) {
      test('${fixture.kind} path is forwarded exactly', () {
        expect(
          ScannerService.libraryScanArguments(fixture.path),
          ['--library-path', fixture.path],
        );
      });
    }
  });
}
