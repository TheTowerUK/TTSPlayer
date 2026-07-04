import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/constants/supported_extensions.dart';

/// Expected extensions — must match backend/indexer.py SUPPORTED_EXTENSIONS.
const _expectedExtensions = [
  'avi',
  'bmp',
  'gif',
  'jpeg',
  'jpg',
  'm4v',
  'mkv',
  'mov',
  'mp4',
  'png',
  'tif',
  'tiff',
  'webp',
];

void main() {
  test('SupportedExtensions includes image and video types', () {
    expect(SupportedExtensions.all, _expectedExtensions);
    for (final ext in ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tif', 'tiff']) {
      expect(
        SupportedExtensions.all,
        contains(ext),
        reason: 'image extension $ext must be indexed',
      );
    }
  });
}
