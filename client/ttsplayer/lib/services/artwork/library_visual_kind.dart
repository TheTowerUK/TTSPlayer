import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Cosmetic library/content flavour for placeholder icons.
///
/// Labels always come from folder names — this enum drives icons only.
enum LibraryVisualKind {
  videos,
  music,
  images,
  documents,
  literature,
  comics,
  games,
  archives,
  unknown,
}

extension LibraryVisualKindIcons on LibraryVisualKind {
  IconData get icon => switch (this) {
        LibraryVisualKind.videos => Icons.movie_outlined,
        LibraryVisualKind.music => Icons.music_note_outlined,
        LibraryVisualKind.images => Icons.photo_outlined,
        LibraryVisualKind.documents => Icons.description_outlined,
        LibraryVisualKind.literature => Icons.menu_book_outlined,
        LibraryVisualKind.comics => Icons.auto_stories_outlined,
        LibraryVisualKind.games => Icons.sports_esports_outlined,
        LibraryVisualKind.archives => Icons.archive_outlined,
        LibraryVisualKind.unknown => Icons.folder_outlined,
      };

  /// Subtle accent tint for placeholder backgrounds.
  Color get accentTint => switch (this) {
        LibraryVisualKind.videos => AppColors.primary,
        LibraryVisualKind.music => const Color(0xFF9B7EDE),
        LibraryVisualKind.images => const Color(0xFF5BC0BE),
        LibraryVisualKind.documents => const Color(0xFF8DA4BF),
        LibraryVisualKind.literature => const Color(0xFFC4A77D),
        LibraryVisualKind.comics => const Color(0xFFE07A5F),
        LibraryVisualKind.games => const Color(0xFF6ECB63),
        LibraryVisualKind.archives => const Color(0xFF9AA5B1),
        LibraryVisualKind.unknown => AppColors.textLow,
      };
}
