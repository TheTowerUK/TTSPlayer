import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library/library_metadata_repository.dart';
import '../theme/app_theme.dart';

/// Accessible star toggle for folder or media favourites (ADR-007).
class FavouriteToggleButton extends StatelessWidget {
  const FavouriteToggleButton({
    super.key,
    required this.isFavourited,
    required this.onToggle,
    this.compact = false,
  });

  final bool isFavourited;
  final VoidCallback onToggle;
  final bool compact;

  String get _tooltip =>
      isFavourited ? 'Remove from favourites' : 'Add to favourites';

  String get _semanticsLabel => _tooltip;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? AppIcons.sm : AppIcons.standard;
    final constraints = compact
        ? const BoxConstraints(minWidth: 32, minHeight: 32)
        : const BoxConstraints(minWidth: 40, minHeight: 40);

    return Semantics(
      button: true,
      label: _semanticsLabel,
      child: IconButton(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: compact ? EdgeInsets.zero : null,
        constraints: constraints,
        tooltip: _tooltip,
        icon: Icon(
          isFavourited ? Icons.star : Icons.star_border,
          size: iconSize,
          color: isFavourited ? AppColors.primary : AppColors.textHigh,
        ),
        onPressed: onToggle,
      ),
    );
  }
}

/// Item favourite toggle wired to [LibraryMetadataRepository].
class FavouriteItemToggle extends StatelessWidget {
  const FavouriteItemToggle({
    super.key,
    required this.itemId,
    this.compact = false,
  });

  final String itemId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryMetadataRepository>(
      builder: (context, repository, _) {
        return FavouriteToggleButton(
          compact: compact,
          isFavourited: repository.isItemFavourited(itemId),
          onToggle: () => repository.toggleItemFavourite(itemId),
        );
      },
    );
  }
}

/// Folder favourite toggle wired to [LibraryMetadataRepository].
class FavouriteFolderToggle extends StatelessWidget {
  const FavouriteFolderToggle({
    super.key,
    required this.folderId,
    this.compact = false,
  });

  final String folderId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryMetadataRepository>(
      builder: (context, repository, _) {
        return FavouriteToggleButton(
          compact: compact,
          isFavourited: repository.isFolderFavourited(folderId),
          onToggle: () => repository.toggleFolderFavourite(folderId),
        );
      },
    );
  }
}
