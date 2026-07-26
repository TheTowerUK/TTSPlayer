import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/cbz_zip_archive_source.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/comic_path_safety.dart';

import 'support/comic_test_fixtures.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_cbz_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('lists pages in natural order and ignores non-images', () async {
    final file = writeCbz(tmp, 'ordered.cbz', {
      'page_10.png': tinyPng(1),
      'notes.txt': [1, 2, 3],
      'page_2.png': tinyPng(2),
      'nested/page_1.png': tinyPng(3),
      'page_03.png': tinyPng(4),
    });
    final source = CbzZipArchiveSource(file.path);
    final pages = await source.listPages();
    expect(pages.map((p) => p.entryName).toList(), [
      'nested/page_1.png',
      'page_2.png',
      'page_03.png',
      'page_10.png',
    ]);
    final bytes = await source.loadPageBytes(pages.first.entryName);
    expect(bytes, isNotEmpty);
    await source.dispose();
  });

  test('rejects unsafe extract paths', () async {
    final file = writeCbz(tmp, 'safe.cbz', {'page_001.png': tinyPng()});
    final source = CbzZipArchiveSource(file.path);
    await expectLater(
      source.loadPageBytes('../evil.png'),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          ComicArchiveErrorKind.unsafeEntryPath,
        ),
      ),
    );
    await source.dispose();
  });

  test('empty / no-image archives fail clearly', () async {
    final empty = writeCbz(tmp, 'empty.cbz', {});
    final emptySource = CbzZipArchiveSource(empty.path);
    await expectLater(
      emptySource.listPages(),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          anyOf(
            ComicArchiveErrorKind.emptyArchive,
            ComicArchiveErrorKind.noReadableImages,
          ),
        ),
      ),
    );

    final textOnly = writeCbz(tmp, 'text.cbz', {
      'readme.txt': [65],
    });
    final textSource = CbzZipArchiveSource(textOnly.path);
    await expectLater(
      textSource.listPages(),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          ComicArchiveErrorKind.noReadableImages,
        ),
      ),
    );
  });

  test('path safety helpers', () {
    expect(comicIsUnsafeEntryName('../x.png'), isTrue);
    expect(comicIsImageEntryName('a.PNG'), isTrue);
    expect(comicNaturalCompare('page_2.png', 'page_10.png'), lessThan(0));
  });
}
