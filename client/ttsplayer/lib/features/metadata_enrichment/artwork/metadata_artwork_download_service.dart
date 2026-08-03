import 'dart:typed_data';

import '../transport/http_metadata_http_transport.dart';
import '../transport/metadata_http_transport.dart';
import 'metadata_artwork_cache_entry.dart';
import 'metadata_artwork_cache_repository.dart';
import 'metadata_artwork_cache_state.dart';
import 'metadata_artwork_download_generation_guard.dart';
import 'metadata_artwork_download_result.dart';
import 'metadata_artwork_download_url_resolver.dart';
import 'metadata_artwork_filesystem.dart';
import 'metadata_artwork_http_client.dart';
import 'metadata_artwork_reference.dart';
import 'metadata_artwork_validator.dart';

/// Explicit provider artwork retrieval, validation, and atomic cache writes (M7.4.3).
///
/// Never performs precedence resolution or UI work.
class MetadataArtworkDownloadService {
  MetadataArtworkDownloadService({
    required MetadataArtworkCacheRepository cacheRepository,
    required MetadataArtworkHttpClient httpClient,
    MetadataArtworkDownloadUrlResolver? urlResolver,
    MetadataArtworkValidator? validator,
    MetadataArtworkDownloadGenerationGuard? generationGuard,
    DateTime Function()? clock,
  })  : _cacheRepository = cacheRepository,
        _httpClient = httpClient,
        _urlResolver = urlResolver,
        _validator = validator ?? const MetadataArtworkValidator(),
        _generationGuard = generationGuard,
        _clock = clock ?? DateTime.now;

  final MetadataArtworkCacheRepository _cacheRepository;
  final MetadataArtworkHttpClient _httpClient;
  final MetadataArtworkDownloadUrlResolver? _urlResolver;
  final MetadataArtworkValidator _validator;
  final MetadataArtworkDownloadGenerationGuard? _generationGuard;
  final DateTime Function() _clock;

  Future<MetadataArtworkCacheLookup?> lookup(
    MetadataArtworkReference reference,
  ) {
    return _cacheRepository.lookup(reference.cacheKey);
  }

  Future<void> remove(MetadataArtworkReference reference) {
    return _cacheRepository.remove(reference.cacheKey);
  }

  Future<void> cleanup() {
    return _cacheRepository.cleanup();
  }

  Future<MetadataArtworkDownloadResult> download({
    required MetadataArtworkReference reference,
    String? itemId,
    int? expectedGeneration,
    Uri? overrideDownloadUrl,
  }) {
    return _retrieve(
      reference: reference,
      refresh: false,
      itemId: itemId,
      expectedGeneration: expectedGeneration,
      overrideDownloadUrl: overrideDownloadUrl,
    );
  }

  Future<MetadataArtworkDownloadResult> refresh({
    required MetadataArtworkReference reference,
    String? itemId,
    int? expectedGeneration,
    Uri? overrideDownloadUrl,
  }) {
    return _retrieve(
      reference: reference,
      refresh: true,
      itemId: itemId,
      expectedGeneration: expectedGeneration,
      overrideDownloadUrl: overrideDownloadUrl,
    );
  }

  Future<MetadataArtworkDownloadResult> _retrieve({
    required MetadataArtworkReference reference,
    required bool refresh,
    String? itemId,
    int? expectedGeneration,
    Uri? overrideDownloadUrl,
  }) async {
    if (!_generationIsCurrent(itemId, expectedGeneration)) {
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.staleGeneration,
        message: 'Artwork download superseded by a newer item lifecycle.',
      );
    }

    if (!refresh) {
      final existing = await _cacheRepository.lookup(reference.cacheKey);
      if (existing != null) {
        return MetadataArtworkDownloadSuccess(
          cacheEntry: existing.entry,
          updatedReference: _referenceFromEntry(reference, existing.entry),
        );
      }
    }

    final downloadUri =
        overrideDownloadUrl ?? _urlResolver?.resolveDownloadUrl(reference);
    if (downloadUri == null) {
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.urlUnavailable,
        message: 'No download URL available for artwork reference.',
        updatedReference: reference.copyWith(
          cacheState: MetadataArtworkCacheState.unavailable,
        ),
      );
    }

    MetadataArtworkHttpResponse response;
    try {
      response = await _httpClient.getBytes(downloadUri);
    } on MetadataArtworkInsecureUriException {
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.insecureUri,
        updatedReference: reference.copyWith(
          cacheState: MetadataArtworkCacheState.failed,
        ),
      );
    } on MetadataTransportTimeoutException {
      return _failurePreservingCache(
        reference,
        MetadataArtworkDownloadFailureCategory.timeout,
        refresh: refresh,
      );
    } on MetadataTransportCancelledException {
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.cancelled,
      );
    } on MetadataTransportNetworkException {
      return _failurePreservingCache(
        reference,
        MetadataArtworkDownloadFailureCategory.network,
        refresh: refresh,
      );
    } catch (_) {
      return _failurePreservingCache(
        reference,
        MetadataArtworkDownloadFailureCategory.network,
        refresh: refresh,
      );
    }

    if (!_generationIsCurrent(itemId, expectedGeneration)) {
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.staleGeneration,
        message: 'Artwork download superseded before validation.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _failurePreservingCache(
        reference,
        MetadataArtworkDownloadFailureCategory.httpError,
        refresh: refresh,
        message: 'HTTP ${response.statusCode}',
      );
    }

    MetadataArtworkValidationResult validation;
    try {
      validation = await _validator.validate(
        bytes: response.bodyBytes,
        contentTypeHeader: response.contentType,
      );
    } on MetadataArtworkValidationException {
      if (refresh) {
        return _failurePreservingCache(
          reference,
          MetadataArtworkDownloadFailureCategory.validation,
          refresh: true,
        );
      }
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.validation,
        updatedReference: reference.copyWith(
          cacheState: MetadataArtworkCacheState.failed,
        ),
      );
    }

    if (!_generationIsCurrent(itemId, expectedGeneration)) {
      return MetadataArtworkDownloadFailure(
        category: MetadataArtworkDownloadFailureCategory.staleGeneration,
        message: 'Artwork download superseded before cache write.',
      );
    }

    try {
      final cacheEntry = await _writeValidatedEntry(
        reference: reference,
        bytes: response.bodyBytes,
        validation: validation,
        validator: response.validator,
        refresh: refresh,
      );
      return MetadataArtworkDownloadSuccess(
        cacheEntry: cacheEntry,
        updatedReference: _referenceFromEntry(reference, cacheEntry),
      );
    } on MetadataArtworkFilesystemException catch (error) {
      return _failurePreservingCache(
        reference,
        MetadataArtworkDownloadFailureCategory.filesystem,
        refresh: refresh,
        message: error.message,
      );
    } catch (_) {
      return _failurePreservingCache(
        reference,
        MetadataArtworkDownloadFailureCategory.filesystem,
        refresh: refresh,
      );
    }
  }

  Future<MetadataArtworkCacheEntry> _writeValidatedEntry({
    required MetadataArtworkReference reference,
    required Uint8List bytes,
    required MetadataArtworkValidationResult validation,
    required bool refresh,
    String? validator,
  }) async {
    final fs = await _cacheRepository.filesystem();
    final relativePath =
        fs.relativePathForCacheKey(reference.cacheKey, validation.contentType);
    final targetFile = fs.fileForRelativePath(relativePath);
    final tempFile = fs.tempFileForRelativePath(relativePath);

    final existing = _cacheRepository.entryForKey(reference.cacheKey);
    if (existing != null &&
        existing.relativePath != relativePath &&
        refresh) {
      await fs.deleteRelativeFile(existing.relativePath);
    }

    try {
      await fs.writeTempBytes(tempFile, bytes);
      await fs.promoteTempFile(tempFile, targetFile);
    } catch (error) {
      await fs.deleteTempFile(tempFile);
      rethrow;
    }

    final now = _clock().toUtc();
    final entry = MetadataArtworkCacheEntry(
      cacheKey: reference.cacheKey,
      providerId: reference.providerId,
      providerRecordId: reference.providerRecordId,
      artworkId: reference.artworkId,
      relativePath: relativePath,
      contentType: validation.contentType,
      width: validation.width,
      height: validation.height,
      byteSize: validation.byteSize,
      createdAt: existing?.createdAt ?? now,
      lastValidatedAt: now,
      lastAccessedAt: now,
      validator: validator ?? existing?.validator,
      cacheState: MetadataArtworkCacheState.downloaded,
    ).normalized();

    return _cacheRepository.upsertEntry(entry);
  }

  MetadataArtworkReference _referenceFromEntry(
    MetadataArtworkReference reference,
    MetadataArtworkCacheEntry entry,
  ) {
    return reference.copyWith(
      contentType: entry.contentType,
      width: entry.width,
      height: entry.height,
      validatedAt: entry.lastValidatedAt,
      cacheState: MetadataArtworkCacheState.downloaded,
      localRelativePath: entry.relativePath,
      validator: entry.validator,
    ).normalized();
  }

  Future<MetadataArtworkDownloadFailure> _failurePreservingCache(
    MetadataArtworkReference reference,
    MetadataArtworkDownloadFailureCategory category, {
    required bool refresh,
    String? message,
  }) async {
    if (refresh) {
      final existing = await _cacheRepository.lookup(reference.cacheKey);
      if (existing != null) {
        return MetadataArtworkDownloadFailure(
          category: category,
          message: message,
          updatedReference: _referenceFromEntry(reference, existing.entry),
        );
      }
    }
    return MetadataArtworkDownloadFailure(
      category: category,
      message: message,
      updatedReference: reference.copyWith(
        cacheState: MetadataArtworkCacheState.failed,
      ),
    );
  }

  bool _generationIsCurrent(String? itemId, int? expectedGeneration) {
    if (itemId == null || expectedGeneration == null) {
      return true;
    }
    final guard = _generationGuard;
    if (guard == null) {
      return true;
    }
    return guard.isCurrent(itemId, expectedGeneration);
  }
}
