import 'package:flutter/foundation.dart';

import 'media_item.dart';

T _cast<T>(dynamic value, String model, String field) {
  try {
    return value as T;
  } catch (e) {
    debugPrint(
      '[fromJson] $model.$field — expected $T, '
      'got ${value.runtimeType} = $value',
    );
    rethrow;
  }
}

/// A folder node in the catalog tree.
/// Mirrors the real filesystem — the folder name IS the category label.
class MediaFolder {
  final String id;
  final String name;
  final String path;
  final int itemCount;
  final List<MediaItem> items;
  final List<MediaFolder> subfolders;

  const MediaFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.itemCount,
    required this.items,
    required this.subfolders,
  });

  factory MediaFolder.fromJson(Map<String, dynamic> json) {
    return MediaFolder(
      id: _cast<String>(json['id'], 'MediaFolder', 'id'),
      name: _cast<String>(json['name'], 'MediaFolder', 'name'),
      path: _cast<String>(json['path'], 'MediaFolder', 'path'),
      itemCount: _cast<int>(json['item_count'], 'MediaFolder', 'item_count'),
      items: (_cast<List<dynamic>>(json['items'], 'MediaFolder', 'items'))
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subfolders: (_cast<List<dynamic>>(json['subfolders'], 'MediaFolder', 'subfolders'))
          .map((e) => MediaFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'item_count': itemCount,
        'items': items.map((i) => i.toJson()).toList(),
        'subfolders': subfolders.map((f) => f.toJson()).toList(),
      };

  /// True if this folder has no items and no subfolders.
  bool get isEmpty => items.isEmpty && subfolders.isEmpty;

  /// Total items including all nested subfolders.
  int get totalItems =>
      items.length + subfolders.fold(0, (sum, f) => sum + f.totalItems);
}
