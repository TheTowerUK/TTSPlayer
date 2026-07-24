import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../services/artwork/library_visual_kind.dart';

/// Shared presentation labels/icons for catalogue media kinds (M6.2).
///
/// Presentation only — does not invent libraries or rename folders.
abstract final class MediaKindPresentation {
  static String label(MediaKind kind) => switch (kind) {
        MediaKind.video => 'Video',
        MediaKind.audio => 'Audio',
        MediaKind.image => 'Image',
        MediaKind.book => 'Book',
        MediaKind.comic => 'Comic',
        MediaKind.unknown => 'Media',
      };

  static String labelFor(MediaItem item) => label(item.mediaKind);

  static IconData icon(MediaKind kind) => switch (kind) {
        MediaKind.video => Icons.movie_outlined,
        MediaKind.audio => Icons.music_note_outlined,
        MediaKind.image => Icons.photo_outlined,
        MediaKind.book => Icons.menu_book_outlined,
        MediaKind.comic => Icons.auto_stories_outlined,
        MediaKind.unknown => Icons.insert_drive_file_outlined,
      };

  static IconData iconFor(MediaItem item) => icon(item.mediaKind);

  /// Semantic / tooltip phrase, e.g. "Book: Owner Manual".
  static String semanticsLabel(MediaItem item) =>
      '${labelFor(item)}: ${item.title}';

  /// Maps kind → placeholder artwork flavour (no filesystem invention).
  static LibraryVisualKind visualKind(MediaKind kind) => switch (kind) {
        MediaKind.video => LibraryVisualKind.videos,
        MediaKind.audio => LibraryVisualKind.music,
        MediaKind.image => LibraryVisualKind.images,
        MediaKind.book => LibraryVisualKind.literature,
        MediaKind.comic => LibraryVisualKind.comics,
        MediaKind.unknown => LibraryVisualKind.unknown,
      };

  static LibraryVisualKind visualKindFor(MediaItem item) =>
      visualKind(item.mediaKind);

  /// Short metadata line under a card title (kind · author/series · year…).
  static String? cardSubtitle(MediaItem item) {
    final parts = <String>[
      labelFor(item),
      if (item.isBook || item.isComic) ...[
        if (item.author != null && item.author!.trim().isNotEmpty)
          item.author!.trim(),
        if (item.series != null && item.series!.trim().isNotEmpty)
          item.series!.trim(),
      ],
      if (item.year != null) '${item.year}',
      if (item.formattedDuration != null) item.formattedDuration!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}
