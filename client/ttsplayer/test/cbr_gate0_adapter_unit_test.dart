import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/spike/cbr_path_safety.dart';

void main() {
  group('cbr path safety (no native load)', () {
    test('rejects parent traversal', () {
      expect(cbrIsUnsafeEntryName(r'..\x.png'), isTrue);
      expect(cbrIsUnsafeEntryName('nested/../x.png'), isTrue);
    });

    test('rejects absolute windows paths', () {
      expect(cbrIsUnsafeEntryName(r'C:\Windows\a.png'), isTrue);
    });

    test('accepts normal comic page names', () {
      expect(cbrIsUnsafeEntryName('page_001.png'), isFalse);
      expect(cbrIsUnsafeEntryName('nested/page_002.jpg'), isFalse);
    });

    test('image extension detection', () {
      expect(cbrIsImageEntryName('a.PNG'), isTrue);
      expect(cbrIsImageEntryName('notes.txt'), isFalse);
    });

    test('natural compare orders page numbers', () {
      final names = ['page_10.png', 'page_2.png', 'page_1.png'];
      names.sort(cbrNaturalCompare);
      expect(names, ['page_1.png', 'page_2.png', 'page_10.png']);
    });
  });
}
