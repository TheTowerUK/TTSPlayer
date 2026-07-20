import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Metadata for a generated Gate 0 audio fixture (not committed).
class GeneratedAudioFixture {
  final File file;
  final String format;
  final Duration duration;
  final int sampleRate;
  final int channels;
  final String generationMethod;

  const GeneratedAudioFixture({
    required this.file,
    required this.format,
    required this.duration,
    required this.sampleRate,
    required this.channels,
    required this.generationMethod,
  });

  String get path => file.path;

  Uri get fileUri => file.uri;
}

/// Writes a deterministic mono 16-bit PCM WAV (generated at test runtime).
Future<GeneratedAudioFixture> writeMonoWavFixture({
  Duration duration = const Duration(seconds: 2),
  int sampleRate = 44100,
  double frequencyHz = 440.0,
  String basename = 'gate_tone',
}) async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_audio_gate_');
  final file = File('${dir.path}/$basename.wav');

  final sampleCount = (sampleRate * duration.inMilliseconds / 1000).round();
  final bytes = ByteData(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final sample = (sin(2 * pi * frequencyHz * t) * 0.4 * 0x7FFF).round();
    bytes.setInt16(i * 2, sample, Endian.little);
  }

  final header = _wavHeader(
    dataSize: bytes.lengthInBytes,
    sampleRate: sampleRate,
    channels: 1,
    bitsPerSample: 16,
  );

  await file.writeAsBytes([...header, ...bytes.buffer.asUint8List()]);

  return GeneratedAudioFixture(
    file: file,
    format: 'wav',
    duration: duration,
    sampleRate: sampleRate,
    channels: 1,
    generationMethod: 'dart_pcm_sine',
  );
}

/// Writes invalid bytes with a .mp3 extension for error-path tests.
Future<GeneratedAudioFixture> writeCorruptMp3Fixture({
  String basename = 'corrupt',
}) async {
  final dir = await Directory.systemTemp.createTemp('ttsplayer_audio_gate_');
  final file = File('${dir.path}/$basename.mp3');
  await file.writeAsBytes([0xFF, 0xFB, 0x00, 0x00, 0x01, 0x02, 0x03]);

  return GeneratedAudioFixture(
    file: file,
    format: 'mp3-corrupt',
    duration: Duration.zero,
    sampleRate: 0,
    channels: 0,
    generationMethod: 'dart_random_bytes',
  );
}

/// Optional MP3 via ffmpeg when available on the test host.
Future<GeneratedAudioFixture?> tryWriteMp3ViaFfmpeg({
  Duration duration = const Duration(seconds: 2),
}) async {
  final wav = await writeMonoWavFixture(
    duration: duration,
    basename: 'ffmpeg_src',
  );
  final mp3 = File('${wav.file.parent.path}/gate_tone.mp3');

  try {
    final result = await Process.run(
      'ffmpeg',
      [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        wav.path,
        '-codec:a',
        'libmp3lame',
        '-q:a',
        '4',
        mp3.path,
      ],
      runInShell: true,
    );
    if (result.exitCode != 0 || !mp3.existsSync()) {
      return null;
    }
    return GeneratedAudioFixture(
      file: mp3,
      format: 'mp3',
      duration: duration,
      sampleRate: 44100,
      channels: 1,
      generationMethod: 'ffmpeg_from_wav',
    );
  } catch (_) {
    return null;
  }
}

List<int> _wavHeader({
  required int dataSize,
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final chunkSize = 36 + dataSize;

  final header = ByteData(44);
  header.setUint8(0, 0x52); // R
  header.setUint8(1, 0x49); // I
  header.setUint8(2, 0x46); // F
  header.setUint8(3, 0x46); // F
  header.setUint32(4, chunkSize, Endian.little);
  header.setUint8(8, 0x57); // W
  header.setUint8(9, 0x41); // A
  header.setUint8(10, 0x56); // V
  header.setUint8(11, 0x45); // E
  header.setUint8(12, 0x66); // f
  header.setUint8(13, 0x6D); // m
  header.setUint8(14, 0x74); // t
  header.setUint8(15, 0x20); // space
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  header.setUint8(36, 0x64); // d
  header.setUint8(37, 0x61); // a
  header.setUint8(38, 0x74); // t
  header.setUint8(39, 0x61); // a
  header.setUint32(40, dataSize, Endian.little);
  return header.buffer.asUint8List();
}
