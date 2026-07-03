import 'package:flutter/material.dart';

import 'search_screen.dart';

/// Opens the global search screen.
void openSearchScreen(BuildContext context, {bool autofocus = false}) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SearchScreen(autofocus: autofocus),
    ),
  );
}
