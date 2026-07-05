import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('checkFilePresence', () {
    test('remote URL is not checked locally', () async {
      final result = await checkFilePresence('https://nas.example/video.mp4');

      expect(result.isLocal, isFalse);
      expect(result.exists, isNull);
    });

    test('missing local file reports exists false', () async {
      final result = await checkFilePresence(r'Z:\does-not-exist\video.mp4');

      expect(result.isLocal, isTrue);
      expect(result.exists, isFalse);
      expect(result.isPresent, isFalse);
    });

    test('existing local file URI passes through checkFilePresence', () async {
      final temp = await Directory.systemTemp.createTemp('ttsplayer_preflight_');
      final file = File('${temp.path}/sample.mp4');
      await file.writeAsBytes([0, 1, 2, 3]);

      final fileUri = Uri.file(file.path).toString();
      final result = await checkFilePresence(fileUri);

      expect(result.isLocal, isTrue);
      expect(result.exists, isTrue);
      expect(result.lengthBytes, 4);

      temp.deleteSync(recursive: true);
    });
  });

  test('initProbeQuestionLabel mentions MediaKit on Windows', () {
    if (Platform.isWindows) {
      expect(
        initProbeQuestionLabel(),
        contains('Can Windows initialise a MediaKit Player for it?'),
      );
    }
  });
}
