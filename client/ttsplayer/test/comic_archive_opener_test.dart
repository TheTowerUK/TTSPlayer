import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_errors.dart';
import 'package:ttsplayer/features/comics/archive/comic_archive_opener.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';

import 'support/comic_test_fixtures.dart';

void main() {
  late Directory tmp;
  final resolver = MediaLocationResolver(
    config: MediaAccessConfig.defaults(),
    isWindowsDesktop: true,
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tts_opener_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('opens CBZ and rejects non-comic kinds', () async {
    final file = writeCbz(tmp, 'ok.cbz', {'page_001.png': tinyPng()});
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(file.path);
    expect(await source.listPages(), isNotEmpty);
    await source.dispose();

    expect(
      () => opener.openItem(
        MediaItem(
          id: 'b1',
          title: 'Book',
          filePath: file.path,
          mediaKindRaw: MediaKind.book.name,
          status: MediaItemStatus.available,
        ),
      ),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          ComicArchiveErrorKind.unsupportedArchiveType,
        ),
      ),
    );
  });

  test('corrupt CBZ maps to corruptArchive', () async {
    // Non-ZIP payload (not a truncated PK header that decodes as empty).
    final bad = File('${tmp.path}${Platform.pathSeparator}bad.cbz')
      ..writeAsBytesSync(List<int>.filled(64, 0x7F));
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(bad.path);
    await expectLater(
      source.listPages(),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          anyOf(
            ComicArchiveErrorKind.corruptArchive,
            ComicArchiveErrorKind.emptyArchive,
            ComicArchiveErrorKind.noReadableImages,
          ),
        ),
      ),
    );
    await source.dispose();
  });

  test('renamed RAR with .cbz extension fails as invalid ZIP', () async {
    final mislabeled = File('${tmp.path}${Platform.pathSeparator}mislabeled.cbz')
      ..writeAsBytesSync(const [0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x00]);
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    final source = opener.openPath(mislabeled.path);
    await expectLater(
      source.listPages(),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          anyOf(
            ComicArchiveErrorKind.corruptArchive,
            ComicArchiveErrorKind.emptyArchive,
            ComicArchiveErrorKind.noReadableImages,
          ),
        ),
      ),
    );
    await source.dispose();
  });

  test('CBR path throws conversion guidance message', () {
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    expect(
      () => opener.openPath(r'C:\library\issue.cbr'),
      throwsA(
        isA<ComicArchiveException>()
            .having(
              (e) => e.kind,
              'kind',
              ComicArchiveErrorKind.unsupportedArchiveType,
            )
            .having(
              (e) => e.userMessage,
              'userMessage',
              kCbrConversionGuidance,
            ),
      ),
    );
  });

  test('unsupported extension rejected', () {
    final opener = ComicArchiveOpener(mediaLocationResolver: resolver);
    expect(
      () => opener.openPath(r'C:\library\notes.txt'),
      throwsA(
        isA<ComicArchiveException>().having(
          (e) => e.kind,
          'kind',
          ComicArchiveErrorKind.unsupportedArchiveType,
        ),
      ),
    );
  });
}
