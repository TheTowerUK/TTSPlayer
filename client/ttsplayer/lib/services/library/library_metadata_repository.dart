import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/catalog.dart';
import '../../models/library_metadata.dart';
import '../../models/media_folder.dart';

/// Where persisted library metadata was loaded from.
enum LibraryMetadataLoadSource {
  envelope,
  defaults,
}

/// Outcome of [LibraryMetadataRepository.load] / [initialize].
class LibraryMetadataLoadResult {
  const LibraryMetadataLoadResult({
    required this.metadata,
    required this.source,
    this.recoveryWarnings = const [],
  });

  final LibraryMetadata metadata;
  final LibraryMetadataLoadSource source;
  final List<String> recoveryWarnings;
}

/// Outcome of [LibraryMetadataRepository.save].
class LibraryMetadataSaveResult {
  const LibraryMetadataSaveResult({
    required this.success,
    this.validationErrors = const [],
  });

  final bool success;
  final List<String> validationErrors;
}

/// Outcome of [LibraryMetadataRepository.validateAgainstCatalog].
class CatalogueMetadataValidationResult {
  const CatalogueMetadataValidationResult({
    required this.changed,
    required this.prunedItemCount,
    required this.prunedFolderCount,
    this.persistenceFailed = false,
    this.warning,
  });

  final bool changed;
  final int prunedItemCount;
  final int prunedFolderCount;

  /// True when pruning was needed but persistence could not complete.
  final bool persistenceFailed;

  /// Optional diagnostic when validation or persistence did not fully succeed.
  final String? warning;
}

/// Loads, validates, and persists user-owned library metadata (ADR-007).
///
/// Persistence-only layer — does not mutate [Catalog] or catalogue files.
class LibraryMetadataRepository extends ChangeNotifier {
  LibraryMetadataRepository({LibraryMetadata? initialMetadata})
      : _metadata = initialMetadata ?? LibraryMetadata.defaults();

  static const storageKey = 'ttsplayer_library_metadata_v1';

  LibraryMetadata _metadata;
  bool _isLoaded = false;
  LibraryMetadataLoadSource? _lastLoadSource;
  List<String> _lastRecoveryWarnings = const [];

  /// When true, [save] / persistence writes fail (tests only).
  @visibleForTesting
  bool simulatePersistFailure = false;

  bool get isLoaded => _isLoaded;

  LibraryMetadata get metadata => _metadata;

  FavouritesMetadata get favourites => _metadata.favourites;

  List<String> get lastRecoveryWarnings => _lastRecoveryWarnings;

  List<FavouriteRecord> get favouriteItems => favourites.items;

  List<FavouriteRecord> get favouriteFolders => favourites.folders;

  /// Loads persisted metadata once at startup. Safe to call multiple times.
  Future<LibraryMetadataLoadResult> initialize() async {
    if (_isLoaded) {
      return LibraryMetadataLoadResult(
        metadata: _metadata,
        source: _lastLoadSource ?? LibraryMetadataLoadSource.defaults,
        recoveryWarnings: _lastRecoveryWarnings,
      );
    }
    return load();
  }

  /// Re-reads metadata from storage on every call.
  Future<LibraryMetadataLoadResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    final warnings = <String>[];

    final raw = prefs.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = _parseEnvelopeString(raw, warnings);
      if (parsed != null) {
        _metadata = parsed;
        return _completeLoad(
          LibraryMetadataLoadResult(
            metadata: parsed,
            source: LibraryMetadataLoadSource.envelope,
            recoveryWarnings: warnings,
          ),
        );
      }
    }

    _metadata = LibraryMetadata.defaults();
    return _completeLoad(
      LibraryMetadataLoadResult(
        metadata: _metadata,
        source: LibraryMetadataLoadSource.defaults,
        recoveryWarnings: warnings,
      ),
    );
  }

  LibraryMetadataLoadResult _completeLoad(LibraryMetadataLoadResult result) {
    _isLoaded = true;
    _lastLoadSource = result.source;
    _lastRecoveryWarnings = result.recoveryWarnings;
    notifyListeners();
    return result;
  }

  Future<LibraryMetadataSaveResult> save(LibraryMetadata metadata) async {
    final normalized = _normalizeMetadata(metadata);
    final persisted = await _persist(normalized);
    if (!persisted) {
      return const LibraryMetadataSaveResult(
        success: false,
        validationErrors: ['Could not save library metadata.'],
      );
    }

    _metadata = normalized;
    _isLoaded = true;
    notifyListeners();
    return const LibraryMetadataSaveResult(success: true);
  }

  Future<bool> addItemFavourite(String itemId) async {
    return _addFavourite(
      id: itemId,
      existing: favourites.items,
      update: (items) => favourites.copyWith(items: items),
    );
  }

  Future<bool> addFolderFavourite(String folderId) async {
    return _addFavourite(
      id: folderId,
      existing: favourites.folders,
      update: (folders) => favourites.copyWith(folders: folders),
    );
  }

  Future<bool> removeItemFavourite(String itemId) async {
    return _removeFavourite(
      id: itemId,
      existing: favourites.items,
      update: (items) => favourites.copyWith(items: items),
    );
  }

  Future<bool> removeFolderFavourite(String folderId) async {
    return _removeFavourite(
      id: folderId,
      existing: favourites.folders,
      update: (folders) => favourites.copyWith(folders: folders),
    );
  }

  Future<bool> toggleItemFavourite(String itemId) async {
    if (isItemFavourited(itemId)) {
      await removeItemFavourite(itemId);
      return false;
    }
    await addItemFavourite(itemId);
    return true;
  }

  Future<bool> toggleFolderFavourite(String folderId) async {
    if (isFolderFavourited(folderId)) {
      await removeFolderFavourite(folderId);
      return false;
    }
    await addFolderFavourite(folderId);
    return true;
  }

  bool isItemFavourited(String itemId) =>
      favourites.items.any((r) => r.id == itemId);

  bool isFolderFavourited(String folderId) =>
      favourites.folders.any((r) => r.id == folderId);

  /// Clears all favourites and persists.
  Future<void> resetFavouritesToDefaults() async {
    _metadata = _metadata.copyWith(favourites: FavouritesMetadata.defaults());
    await _persist(_metadata);
    _isLoaded = true;
    notifyListeners();
  }

  /// Clears all library metadata to defaults.
  Future<void> resetAllToDefaults() async {
    _metadata = LibraryMetadata.defaults();
    await _persist(_metadata);
    _isLoaded = true;
    notifyListeners();
  }

  /// Prunes favourites absent from [catalog] after successful catalogue replacement.
  ///
  /// Does not mutate [catalog]. Persists and notifies only when favourites change.
  Future<CatalogueMetadataValidationResult> validateAgainstCatalog(
    Catalog catalog,
  ) async {
    try {
      final itemIds = catalog.allItems.map((i) => i.id).toSet();
      final folderIds = _collectFolderIds(catalog);

      final keptItems =
          favourites.items.where((r) => itemIds.contains(r.id)).toList();
      final keptFolders =
          favourites.folders.where((r) => folderIds.contains(r.id)).toList();

      final prunedItems = favourites.items.length - keptItems.length;
      final prunedFolders = favourites.folders.length - keptFolders.length;
      final changed = prunedItems > 0 || prunedFolders > 0;

      if (!changed) {
        return const CatalogueMetadataValidationResult(
          changed: false,
          prunedItemCount: 0,
          prunedFolderCount: 0,
        );
      }

      final nextMetadata = _metadata.copyWith(
        favourites: FavouritesMetadata(
          items: keptItems,
          folders: keptFolders,
        ),
      );

      final persisted = await _persist(nextMetadata);
      if (!persisted) {
        return const CatalogueMetadataValidationResult(
          changed: false,
          prunedItemCount: 0,
          prunedFolderCount: 0,
          persistenceFailed: true,
          warning: 'Could not persist pruned favourites after catalogue replacement.',
        );
      }

      _metadata = nextMetadata;

      notifyListeners();
      if (kDebugMode && (prunedItems > 0 || prunedFolders > 0)) {
        debugPrint(
          '[LibraryMetadataRepository] pruned $prunedItems item and '
          '$prunedFolders folder favourites after catalogue replacement.',
        );
      }

      return CatalogueMetadataValidationResult(
        changed: true,
        prunedItemCount: prunedItems,
        prunedFolderCount: prunedFolders,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[LibraryMetadataRepository] validateAgainstCatalog failed: $e\n'
        '$stackTrace',
      );
      return CatalogueMetadataValidationResult(
        changed: false,
        prunedItemCount: 0,
        prunedFolderCount: 0,
        persistenceFailed: true,
        warning: 'Catalogue favourite validation failed unexpectedly.',
      );
    }
  }

  Future<bool> _addFavourite({
    required String id,
    required List<FavouriteRecord> existing,
    required FavouritesMetadata Function(List<FavouriteRecord>) update,
  }) async {
    if (id.trim().isEmpty) return false;
    if (existing.any((r) => r.id == id)) {
      return true;
    }

    final record = FavouriteRecord(
      id: id,
      favouritedAt: DateTime.now().toUtc(),
    );
    final next = List<FavouriteRecord>.from(existing)..add(record);
    next.sort(FavouritesMetadata.compareRecords);

    final result = await save(
      _metadata.copyWith(favourites: update(next)),
    );
    return result.success;
  }

  Future<bool> _removeFavourite({
    required String id,
    required List<FavouriteRecord> existing,
    required FavouritesMetadata Function(List<FavouriteRecord>) update,
  }) async {
    if (!existing.any((r) => r.id == id)) {
      return false;
    }

    final next = existing.where((r) => r.id != id).toList();
    final result = await save(
      _metadata.copyWith(favourites: update(next)),
    );
    return result.success;
  }

  LibraryMetadata? _parseEnvelopeString(String raw, List<String> warnings) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        debugPrint('[LibraryMetadataRepository] envelope is not a JSON object.');
        warnings.add('Stored library metadata could not be read.');
        return null;
      }
      return LibraryMetadata.fromJsonWithRecovery(json, warnings: warnings);
    } catch (e) {
      debugPrint('[LibraryMetadataRepository] corrupt metadata JSON: $e');
      warnings.add('Stored library metadata could not be read.');
      return null;
    }
  }

  LibraryMetadata _normalizeMetadata(LibraryMetadata metadata) {
    return metadata.copyWith(
      metadataVersion: LibraryMetadata.currentMetadataVersion,
      favourites: FavouritesMetadata(
        items: FavouritesMetadata.dedupeRecords(
          List<FavouriteRecord>.from(metadata.favourites.items),
        ),
        folders: FavouritesMetadata.dedupeRecords(
          List<FavouriteRecord>.from(metadata.favourites.folders),
        ),
      ),
    );
  }

  Future<bool> _persist(LibraryMetadata metadata) async {
    if (simulatePersistFailure) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        storageKey,
        jsonEncode(metadata.toPersistenceJson()),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[LibraryMetadataRepository] persist failed: $e\n$stackTrace',
      );
      return false;
    }
  }

  static Set<String> _collectFolderIds(Catalog catalog) {
    final ids = <String>{};
    void walk(MediaFolder folder) {
      ids.add(folder.id);
      for (final sub in folder.subfolders) {
        walk(sub);
      }
    }

    for (final folder in catalog.folders) {
      walk(folder);
    }
    return ids;
  }
}
