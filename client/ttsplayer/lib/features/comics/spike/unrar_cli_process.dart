import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Structured subprocess runner for UnRAR — never uses a shell command string.
class UnrarCliProcessResult {
  const UnrarCliProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
    required this.duration,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final Duration duration;
}

class UnrarCliProcessRunner {
  UnrarCliProcessRunner({
    this.defaultTimeout = const Duration(seconds: 30),
    this.maxOutputBytes = 2 * 1024 * 1024,
  });

  final Duration defaultTimeout;
  final int maxOutputBytes;

  /// Runs [executablePath] with [arguments] (no shell).
  Future<UnrarCliProcessResult> run({
    required String executablePath,
    required List<String> arguments,
    Duration? timeout,
    String? workingDirectory,
  }) async {
    final sw = Stopwatch()..start();
    final process = await Process.start(
      executablePath,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
      // Avoid inheriting a console that can hang headless tests.
    );

    final stdoutChunks = <List<int>>[];
    final stderrChunks = <List<int>>[];
    var stdoutBytes = 0;
    var stderrBytes = 0;
    var stdoutTruncated = false;
    var stderrTruncated = false;

    final stdoutSub = process.stdout.listen((chunk) {
      if (stdoutTruncated) return;
      if (stdoutBytes + chunk.length > maxOutputBytes) {
        final remain = maxOutputBytes - stdoutBytes;
        if (remain > 0) {
          stdoutChunks.add(chunk.sublist(0, remain));
          stdoutBytes += remain;
        }
        stdoutTruncated = true;
      } else {
        stdoutChunks.add(chunk);
        stdoutBytes += chunk.length;
      }
    });
    final stderrSub = process.stderr.listen((chunk) {
      if (stderrTruncated) return;
      if (stderrBytes + chunk.length > maxOutputBytes) {
        final remain = maxOutputBytes - stderrBytes;
        if (remain > 0) {
          stderrChunks.add(chunk.sublist(0, remain));
          stderrBytes += remain;
        }
        stderrTruncated = true;
      } else {
        stderrChunks.add(chunk);
        stderrBytes += chunk.length;
      }
    });

    var timedOut = false;
    final limit = timeout ?? defaultTimeout;
    try {
      await process.exitCode.timeout(limit);
    } on TimeoutException {
      timedOut = true;
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Best-effort kill.
      }
    }

    await stdoutSub.cancel();
    await stderrSub.cancel();
    sw.stop();

    final exitCode = timedOut ? -1 : await process.exitCode;
    return UnrarCliProcessResult(
      exitCode: exitCode,
      stdout: _decodeBounded(stdoutChunks),
      stderr: _decodeBounded(stderrChunks),
      timedOut: timedOut,
      duration: sw.elapsed,
    );
  }

  String _decodeBounded(List<List<int>> chunks) {
    final builder = BytesBuilder(copy: false);
    for (final c in chunks) {
      builder.add(c);
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }
}

/// Creates a unique temp directory under the system temp root.
Directory createOwnedTempDirectory(String prefix) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
  final dir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    '${prefix}_${stamp}_$rand',
  );
  dir.createSync(recursive: true);
  return dir;
}
