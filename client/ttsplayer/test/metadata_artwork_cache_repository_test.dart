import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_entry.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_repository.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_cache_state.dart';
import 'package:ttsplayer/features/metadata_enrichment/artwork/metadata_artwork_filesystem.dart';

void main() {
  late Directory tempRoot;
  late MetadataArtworkFilesystem filesystem;
  late MetadataArtworkCacheRepository repository;

  MetadataArtworkCacheEntry sampleEntry({
    required String cacheKey,
    required String relativePath,
    int byteSize = 100,
    DateTime? lastAccessedAt,
  }) {
    final now = DateTime.utc(2026, 8, 3, 12);
    return MetadataArtworkCacheEntry(
      cacheKey: cacheKey,
      providerId: 'open_library',
      providerRecordId: '/books/OL123M',
      artworkId: '8230111',
      relativePath: relativePath,
      contentType: 'image/png',
      width: 1,
      height: 1,
      byteSize: byteSize,
      createdAt: now,
      lastValidatedAt: now,
      lastAccessedAt: lastAccessedAt ?? now,
      cacheState: MetadataArtworkCacheState.downloaded,
    ).normalized();
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp
        .createTemp('ttsplayer_artwork_cache_test_');
    filesystem = MetadataArtworkFilesystem(cacheRoot: tempRoot);
    repository = MetadataArtworkCacheRepository(
      filesystem: filesystem,
      maxTotalBytes: 300,
      evictionTargetRatio: 0.8,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await repository.initialize();
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('MetadataArtworkFilesystem', () {
    test('atomic index write leaves no part file', () async {
      await filesystem.writeIndexAtomically('{"indexVersion":1,"entries":[]}');
      expect(await filesystem.indexFile.exists(), isTrue);
      expect(await File('${filesystem.indexFile.path}.part').exists(), isFalse);
    });

    test('promoteTempFile writes final cache file', () async {
      final relative = 'abc123.png';
      final temp = filesystem.tempFileForRelativePath(relative);
      final target = filesystem.fileForRelativePath(relative);
      await filesystem.writeTempBytes(temp, Uint8List.fromList([1, 2, 3]));
      await filesystem.promoteTempFile(temp, target);

      expect(await target.exists(), isTrue);
      expect(await temp.exists(), isFalse);
    });
  });

  group('MetadataArtworkCacheRepository', () {
    test('round trips cache entry with relative path', () async {
      final entry = sampleEntry(
        cacheKey: 'key-a',
        relativePath: 'key-a.png',
      );
      final file = filesystem.fileForRelativePath('key-a.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      await repository.upsertEntry(entry);
      await repository.initialize();

      expect(repository.entryForKey('key-a')?.relativePath, 'key-a.png');
    });

    test('lookup updates lastAccessedAt and returns absolute path', () async {
      final entry = sampleEntry(
        cacheKey: 'key-b',
        relativePath: 'key-b.png',
      );
      final file = filesystem.fileForRelativePath('key-b.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      await repository.upsertEntry(entry);

      final lookup = await repository.lookup('key-b');
      expect(lookup, isNotNull);
      expect(lookup!.absoluteFilePath, file.path);
    });

    test('lookup removes missing file metadata', () async {
      await repository.upsertEntry(
        sampleEntry(cacheKey: 'missing', relativePath: 'missing.png'),
      );

      final lookup = await repository.lookup('missing');
      expect(lookup, isNull);
      expect(repository.entryForKey('missing'), isNull);
    });

    test('cleanup evicts LRU entries over quota', () async {
      final oldFile = filesystem.fileForRelativePath('old.png');
      final newFile = filesystem.fileForRelativePath('new.png');
      await oldFile.parent.create(recursive: true);
      await oldFile.writeAsBytes(List<int>.filled(200, 1));
      await newFile.writeAsBytes(List<int>.filled(200, 2));

      await repository.upsertEntry(
        sampleEntry(
          cacheKey: 'old',
          relativePath: 'old.png',
          byteSize: 200,
          lastAccessedAt: DateTime.utc(2026, 8, 1),
        ),
      );
      await repository.upsertEntry(
        sampleEntry(
          cacheKey: 'new',
          relativePath: 'new.png',
          byteSize: 200,
          lastAccessedAt: DateTime.utc(2026, 8, 3),
        ),
      );

      await repository.cleanup();

      expect(repository.entryForKey('old'), isNull);
      expect(repository.entryForKey('new'), isNotNull);
      expect(repository.totalBytes, lessThanOrEqualTo(240));
    });

    test('cleanup removes orphan files and orphan metadata', () async {
      final orphanFile = filesystem.fileForRelativePath('orphan.png');
      await orphanFile.parent.create(recursive: true);
      await orphanFile.writeAsBytes([9, 9, 9]);

      await repository.upsertEntry(
        sampleEntry(cacheKey: 'ghost', relativePath: 'ghost.png'),
      );

      await repository.cleanup();

      expect(await orphanFile.exists(), isFalse);
      expect(repository.entryForKey('ghost'), isNull);
    });
  });
}
