import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/constants/supported_extensions.dart';

/// Expected extensions — must match backend/indexer.py SUPPORTED_EXTENSIONS.
const _expectedExtensions = [
  'aac',
  'avi',
  'bmp',
  'cbz',
  'epub',
  'flac',
  'gif',
  'jpeg',
  'jpg',
  'm4a',
  'm4v',
  'mkv',
  'mov',
  'mp3',
  'mp4',
  'ogg',
  'opus',
  'pdf',
  'png',
  'tif',
  'tiff',
  'wav',
  'webp',
  'wma',
];

void main() {
  test('SupportedExtensions matches indexer including book/comic', () {
    expect(SupportedExtensions.all, _expectedExtensions);
    for (final ext in ['pdf', 'epub', 'cbz']) {
      expect(
        SupportedExtensions.all,
        contains(ext),
        reason: 'book/comic extension $ext must be indexed',
      );
    }
  });
}
