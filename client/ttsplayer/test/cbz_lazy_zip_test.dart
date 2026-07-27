import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_lazy_reader.dart';

import 'support/comic_test_fixtures.dart';
import 'support/phase_66_reader_fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_cbz_lazy_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('lists and reads single entry without full-archive decode object', () async {
    final file = writeCbz(tmp, 'small.cbz', {
      'page_1.png': tinyPng(1),
      'page_2.png': tinyPng(2),
      'notes.txt': [1, 2, 3],
    });
    final reader = CbzZipLazyReader(file.path);
    final entries = await reader.centralEntries();
    expect(entries.map((e) => e.name), contains('page_1.png'));

    final page1 = await reader.readEntryBytes(
      entries.firstWhere((e) => e.name == 'page_1.png'),
    );
    expect(page1, isNotEmpty);
  });

  test('large generated CBZ exposes many pages via central directory only', () async {
    final file = generatePhase66Cbz(
      tmp,
      profile: Phase66CbzProfile.medium,
    );
    final reader = CbzZipLazyReader(file.path);
    final entries = await reader.centralEntries();
    expect(entries.length, greaterThanOrEqualTo(Phase66CbzProfile.medium.pageCount));

    final firstImage = entries.firstWhere((e) => e.name.endsWith('.png'));
    final bytes = await reader.readEntryBytes(firstImage);
    expect(bytes.length, greaterThan(0));
  });
}
