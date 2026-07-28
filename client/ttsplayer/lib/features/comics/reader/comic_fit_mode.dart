import 'package:flutter/material.dart';

/// Presentation fit for the active comic page (Phase 6.4C).
enum ComicFitMode {
  contain,
  fitWidth,
  fitHeight;

  BoxFit get boxFit => switch (this) {
        ComicFitMode.contain => BoxFit.contain,
        ComicFitMode.fitWidth => BoxFit.fitWidth,
        ComicFitMode.fitHeight => BoxFit.fitHeight,
      };

  String get label => switch (this) {
        ComicFitMode.contain => 'Contain',
        ComicFitMode.fitWidth => 'Fit width',
        ComicFitMode.fitHeight => 'Fit height',
      };

  String get semanticsLabel => switch (this) {
        ComicFitMode.contain => 'Fit mode: contain entire page',
        ComicFitMode.fitWidth => 'Fit mode: fit page width',
        ComicFitMode.fitHeight => 'Fit mode: fit page height',
      };
}
