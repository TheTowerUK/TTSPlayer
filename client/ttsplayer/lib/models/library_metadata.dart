/// Versioned user library metadata persisted at `ttsplayer_library_metadata_v1`.
///
/// Catalogue content remains read-only; favourites reference catalogue ids only
/// (ADR-007).
class LibraryMetadata {
  const LibraryMetadata({
    required this.metadataVersion,
    required this.favourites,
  });

  static const currentMetadataVersion = 1;

  final int metadataVersion;
  final FavouritesMetadata favourites;

  factory LibraryMetadata.defaults() {
    return LibraryMetadata(
      metadataVersion: currentMetadataVersion,
      favourites: FavouritesMetadata.defaults(),
    );
  }

  factory LibraryMetadata.fromJson(Map<String, dynamic> json) {
    return LibraryMetadata.fromJsonWithRecovery(json);
  }

  factory LibraryMetadata.fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final version = json['metadataVersion'];
    if (version is! int) {
      warnings?.add('Missing metadataVersion; using defaults for unknown fields.');
    } else if (version > currentMetadataVersion) {
      warnings?.add(
        'Unsupported metadataVersion $version; using known fields only.',
      );
    } else if (version < 1) {
      warnings?.add('Unknown metadataVersion $version; resetting favourites.');
    }

    return LibraryMetadata(
      metadataVersion: currentMetadataVersion,
      favourites: FavouritesMetadata.fromJsonWithRecovery(
        json['favourites'],
        warnings: warnings,
      ),
    );
  }

  LibraryMetadata copyWith({
    int? metadataVersion,
    FavouritesMetadata? favourites,
  }) {
    return LibraryMetadata(
      metadataVersion: metadataVersion ?? this.metadataVersion,
      favourites: favourites ?? this.favourites,
    );
  }

  Map<String, dynamic> toJson() => {
        'metadataVersion': metadataVersion,
        'favourites': favourites.toJson(),
      };

  /// Stable JSON for persistence (deterministic favourite ordering).
  Map<String, dynamic> toPersistenceJson() {
    return {
      'metadataVersion': metadataVersion,
      'favourites': favourites.toPersistenceJson(),
    };
  }
}

/// User-curated favourite bookmarks — items and folders use separate id spaces.
class FavouritesMetadata {
  const FavouritesMetadata({
    required this.items,
    required this.folders,
  });

  final List<FavouriteRecord> items;
  final List<FavouriteRecord> folders;

  factory FavouritesMetadata.defaults() {
    return const FavouritesMetadata(items: [], folders: []);
  }

  factory FavouritesMetadata.fromJsonWithRecovery(
    dynamic json, {
    List<String>? warnings,
  }) {
    if (json is! Map<String, dynamic>) {
      warnings?.add('Favourites metadata was missing or invalid.');
      return FavouritesMetadata.defaults();
    }

    return FavouritesMetadata(
      items: _parseRecordList(json['items'], 'items', warnings),
      folders: _parseRecordList(json['folders'], 'folders', warnings),
    );
  }

  static List<FavouriteRecord> _parseRecordList(
    dynamic raw,
    String label,
    List<String>? warnings,
  ) {
    if (raw == null) return const [];
    if (raw is! List<dynamic>) {
      warnings?.add('Favourite $label list was invalid.');
      return const [];
    }

    final parsed = <FavouriteRecord>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        warnings?.add('Skipped malformed favourite $label record.');
        continue;
      }
      final record = FavouriteRecord.fromJsonWithRecovery(entry, warnings: warnings);
      if (record != null) {
        parsed.add(record);
      }
    }
    return dedupeRecords(parsed);
  }

  /// Deduplicates by id (latest [favouritedAt] wins) and sorts for persistence.
  static List<FavouriteRecord> dedupeRecords(List<FavouriteRecord> records) {
    final byId = <String, FavouriteRecord>{};
    for (final record in records) {
      final existing = byId[record.id];
      if (existing == null || record.favouritedAt.isAfter(existing.favouritedAt)) {
        byId[record.id] = record;
      }
    }
    final deduped = byId.values.toList(growable: false);
    deduped.sort(compareRecords);
    return deduped;
  }

  static int compareRecords(FavouriteRecord a, FavouriteRecord b) {
    final byTime = b.favouritedAt.compareTo(a.favouritedAt);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  }

  FavouritesMetadata copyWith({
    List<FavouriteRecord>? items,
    List<FavouriteRecord>? folders,
  }) {
    return FavouritesMetadata(
      items: items ?? this.items,
      folders: folders ?? this.folders,
    );
  }

  Map<String, dynamic> toJson() => toPersistenceJson();

  Map<String, dynamic> toPersistenceJson() {
    final sortedItems = List<FavouriteRecord>.from(items)..sort(compareRecords);
    final sortedFolders = List<FavouriteRecord>.from(folders)
      ..sort(compareRecords);
    return {
      'items': sortedItems.map((r) => r.toJson()).toList(),
      'folders': sortedFolders.map((r) => r.toJson()).toList(),
    };
  }
}

/// One favourite bookmark referencing a catalogue entity id.
class FavouriteRecord {
  const FavouriteRecord({
    required this.id,
    required this.favouritedAt,
  });

  final String id;
  final DateTime favouritedAt;

  static FavouriteRecord? fromJsonWithRecovery(
    Map<String, dynamic> json, {
    List<String>? warnings,
  }) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      warnings?.add('Skipped favourite record with missing id.');
      return null;
    }

    final atRaw = json['favouritedAt'];
    DateTime? favouritedAt;
    if (atRaw is String) {
      favouritedAt = DateTime.tryParse(atRaw)?.toUtc();
    }
    if (favouritedAt == null) {
      warnings?.add('Skipped favourite record with invalid favouritedAt.');
      return null;
    }

    return FavouriteRecord(id: id, favouritedAt: favouritedAt);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'favouritedAt': favouritedAt.toUtc().toIso8601String(),
      };
}
