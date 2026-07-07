import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/models/media_folder.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/card_layout.dart';
import 'package:ttsplayer/widgets/library_card.dart';
import 'package:ttsplayer/widgets/tts_folder_card.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';
import 'package:ttsplayer/features/dashboard/widgets/continue_watching_section.dart';

void main() {
  group('Card layout overflow', () {
    final artworkService = ArtworkService(fileExists: (_) => false);

    test('artwork band height stays within tight grid cell', () {
      const width = 318.0;
      const height = 246.0;
      final artH = CardLayout.artworkBandHeight(
        width: width,
        maxHeight: height,
      );
      expect(artH, lessThanOrEqualTo(height * CardLayout.artworkMaxHeightFraction));
      expect(artH + 96, lessThanOrEqualTo(height));
    });

    testWidgets('LibraryCard fits 318x246 grid cell', (tester) async {
      await tester.pumpWidget(
        _wrap(
          artworkService,
          SizedBox(
            width: 318,
            height: 246,
            child: LibraryCard(
              folder: _folder('Videos'),
              onBrowse: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TtsFolderCard fits 318x246 grid cell', (tester) async {
      await tester.pumpWidget(
        _wrap(
          artworkService,
          SizedBox(
            width: 318,
            height: 246,
            child: TtsFolderCard(
              folder: _folder('Subfolder'),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TtsMediaCard fits portrait grid cell', (tester) async {
      await tester.pumpWidget(
        _wrap(
          artworkService,
          SizedBox(
            width: 280,
            height: 389,
            child: TtsMediaCard(
              item: _item('Sample Film'),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ContinueWatchingCard fits list height', (tester) async {
      await tester.pumpWidget(
        _wrap(
          artworkService,
          ContinueWatchingSection(
            entries: [
              ContinueWatchingEntry(
                item: _item('Long Title That Might Wrap To Two Lines'),
                resume: const ResumeInfo(
                  savedPosition: Duration(seconds: 120),
                  totalDuration: Duration(seconds: 3600),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _wrap(ArtworkService artworkService, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MediaProviderConfigService()),
      Provider(
        create: (context) => MediaLocationResolver(
          config: context.read<MediaProviderConfigService>().mediaAccess,
          isWindowsDesktop: false,
        ),
      ),
      Provider<ArtworkService>.value(value: artworkService),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

MediaFolder _folder(String name) {
  return MediaFolder(
    id: name,
    name: name,
    path: r'Y:\Media\$name',
    itemCount: 12,
    items: const [],
    subfolders: const [],
  );
}

MediaItem _item(String title) {
  return MediaItem(
    id: title,
    title: title,
    filePath: r'Y:\Media\Movies\$title.mp4',
  );
}
