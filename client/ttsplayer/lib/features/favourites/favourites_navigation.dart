import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import 'favourites_screen.dart';

void openFavouritesScreen(BuildContext context, {required Catalog catalog}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FavouritesScreen(catalog: catalog),
    ),
  );
}
