import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/features/dashboard/widgets/continue_watching_section.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/tts_media_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final artworkService = ArtworkService(fileExists: (_) => false);

  testWidgets('Videos grid card shows a cleaned display title', (tester) async {
    final item = _video(
      'Big Trouble in Little China 1986 1080p BluRay',
    );
    await tester.pumpWidget(
      _wrap(
        artworkService,
        SizedBox(
          width: 280,
          height: 389,
          child: TtsMediaCard(
            item: item,
            showVideoPoster: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Big Trouble in Little China (1986)'), findsOneWidget);
    expect(find.text(item.title), findsNothing);
    expect(item.title, 'Big Trouble in Little China 1986 1080p BluRay');
  });

  testWidgets('Continue Watching shows a cleaned episode title',
      (tester) async {
    final item = _video('American.Horror.Story.S01E01.1080p.BluRay');
    await tester.pumpWidget(
      _wrap(
        artworkService,
        ContinueWatchingSection(
          entries: [
            ContinueWatchingEntry(
              item: item,
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

    expect(find.text('American Horror Story S01E01'), findsOneWidget);
    expect(find.text(item.title), findsNothing);
  });

  testWidgets('book cards keep catalogue titles', (tester) async {
    const book = MediaItem(
      id: 'book-1',
      title: 'Manual 1080p BluRay',
      filePath: r'Y:\Media\Books\manual.pdf',
      mediaKindRaw: 'book',
    );
    await tester.pumpWidget(
      _wrap(
        artworkService,
        SizedBox(
          width: 280,
          height: 389,
          child: TtsMediaCard(
            item: book,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manual 1080p BluRay'), findsOneWidget);
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

MediaItem _video(String title) {
  return MediaItem(
    id: title,
    title: title,
    filePath: r'Y:\Media\Videos\$title.mkv',
    mediaKindRaw: 'video',
  );
}
