import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/screens/folder_screen.dart';
import 'package:ttsplayer/services/catalog_service.dart';
import 'package:ttsplayer/services/library/library_metadata_repository.dart';
import 'package:ttsplayer/theme/app_theme.dart';

class _FakeCatalogService extends CatalogService {
  _FakeCatalogService(this._catalog);

  final Catalog? _catalog;

  @override
  bool get isLoading => false;

  @override
  Catalog? get catalog => _catalog;
}

void main() {
  testWidgets('FolderScreen shows dashboard action when folder is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LibraryMetadataRepository()..initialize(),
            ),
            ChangeNotifierProvider<CatalogService>.value(
              value: _FakeCatalogService(
                Catalog.fromJson({
                  'generated_at': '2026-07-03T00:00:00+00:00',
                  'total_items': 0,
                  'folders': const [],
                }),
              ),
            ),
          ],
          child: const FolderScreen(
            folderPath: r'Y:\Media\Videos\Removed',
            folderName: 'Removed',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back to Dashboard'), findsOneWidget);
    expect(find.textContaining('no longer in the catalogue'), findsOneWidget);
  });

  testWidgets('FolderScreen keeps folder context when catalogue still contains path',
      (tester) async {
    final catalog = Catalog.fromJson({
      'generated_at': '2026-07-03T00:00:00+00:00',
      'total_items': 1,
      'folders': [
        const MediaFolder(
          id: 'videos',
          name: 'Videos',
          path: r'Y:\Media\Videos',
          itemCount: 1,
          items: [],
          subfolders: [],
        ).toJson(),
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LibraryMetadataRepository()..initialize(),
            ),
            ChangeNotifierProvider<CatalogService>.value(
              value: _FakeCatalogService(catalog),
            ),
          ],
          child: const FolderScreen(
            folderPath: r'Y:\Media\Videos',
            folderName: 'Videos',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Videos'), findsWidgets);
    expect(find.text('Back to Dashboard'), findsNothing);
  });
}
