import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One ZIP central-directory entry (metadata only — no decompressed bytes).
class ZipCentralEntry {
  const ZipCentralEntry({
    required this.name,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });

  final String name;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

/// Lightweight ZIP central-directory reader for CBZ lazy page access (M6.6).
///
/// Reads only the central directory to list entries, then decompresses individual
/// entries on demand. Does **not** decode the full archive into memory.
class CbzZipLazyReader {
  CbzZipLazyReader(this.archivePath);

  final String archivePath;
  List<ZipCentralEntry>? _entries;

  Future<List<ZipCentralEntry>> centralEntries() async {
    if (_entries != null) return _entries!;
    _entries = await _readCentralDirectory();
    return _entries!;
  }

  Future<List<int>> readEntry(ZipCentralEntry entry) => readEntryBytes(entry);

  Future<List<int>> readEntryBytes(ZipCentralEntry entry) async {
    final file = await File(archivePath).open(mode: FileMode.read);
    try {
      await file.setPosition(entry.localHeaderOffset);
      final header = Uint8List(30);
      await _readFully(file, header);
      final sig = _le32(header, 0);
      if (sig != 0x04034b50) {
        throw const FormatException('Invalid ZIP local header');
      }
      final method = _le16(header, 8);
      final compressedSize = _le32(header, 18);
      final uncompressedSize = _le32(header, 22);
      final nameLen = _le16(header, 26);
      final extraLen = _le16(header, 28);
      final skip = nameLen + extraLen;
      if (skip > 0) {
        await file.setPosition(entry.localHeaderOffset + 30 + skip);
      }

      if (method == 0) {
        final stored = Uint8List(compressedSize);
        await _readFully(file, stored);
        if (stored.length != uncompressedSize && uncompressedSize != 0) {
          throw const FormatException('Stored ZIP size mismatch');
        }
        return stored;
      }
      if (method == 8) {
        final compressed = Uint8List(compressedSize);
        await _readFully(file, compressed);
        final inflated = Inflate(compressed).getBytes();
        if (uncompressedSize != 0 && inflated.length != uncompressedSize) {
          throw const FormatException('Deflate ZIP size mismatch');
        }
        return inflated;
      }
      throw FormatException('Unsupported ZIP compression method $method');
    } finally {
      await file.close();
    }
  }

  Future<List<ZipCentralEntry>> _readCentralDirectory() async {
    final bytes = await File(archivePath).readAsBytes();
    if (bytes.length < 22) {
      throw const FormatException('ZIP too small');
    }
    final eocdOffset = _findEocdOffset(bytes);
    if (eocdOffset < 0) {
      throw const FormatException('ZIP end-of-central-directory not found');
    }
    final totalEntries = _le16(bytes, eocdOffset + 10);
    final cdOffset = _le32(bytes, eocdOffset + 16);
    final entries = <ZipCentralEntry>[];
    var pos = cdOffset;
    for (var i = 0; i < totalEntries; i++) {
      if (pos + 46 > bytes.length) {
        throw const FormatException('Truncated ZIP central directory');
      }
      if (_le32(bytes, pos) != 0x02014b50) {
        throw const FormatException('Invalid ZIP central directory entry');
      }
      final method = _le16(bytes, pos + 10);
      final compressedSize = _le32(bytes, pos + 20);
      final uncompressedSize = _le32(bytes, pos + 24);
      final nameLen = _le16(bytes, pos + 28);
      final extraLen = _le16(bytes, pos + 30);
      final commentLen = _le16(bytes, pos + 32);
      final localOffset = _le32(bytes, pos + 42);
      final nameStart = pos + 46;
      final nameEnd = nameStart + nameLen;
      if (nameEnd > bytes.length) {
        throw const FormatException('Truncated ZIP entry name');
      }
      final name = String.fromCharCodes(bytes.sublist(nameStart, nameEnd));
      entries.add(
        ZipCentralEntry(
          name: name.replaceAll('\\', '/'),
          compressionMethod: method,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          localHeaderOffset: localOffset,
        ),
      );
      pos = nameEnd + extraLen + commentLen;
    }
    return entries;
  }

  static int _findEocdOffset(Uint8List bytes) {
    final min = bytes.length - 65557;
    final start = min < 0 ? 0 : min;
    for (var i = bytes.length - 22; i >= start; i--) {
      if (_le32(bytes, i) == 0x06054b50) return i;
    }
    return -1;
  }

  static Future<void> _readFully(RandomAccessFile file, Uint8List buffer) async {
    var offset = 0;
    while (offset < buffer.length) {
      final read = await file.readInto(buffer, offset, buffer.length - offset);
      if (read <= 0) {
        throw const FormatException('Unexpected end of ZIP entry data');
      }
      offset += read;
    }
  }

  static int _le16(List<int> b, int o) => b[o] | (b[o + 1] << 8);
  static int _le32(List<int> b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
}
