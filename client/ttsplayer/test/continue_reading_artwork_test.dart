import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/continue_reading_projection.dart';
import 'package:ttsplayer/features/reading/widgets/continue_reading_section.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_service.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_provider_config_service.dart';
import 'package:ttsplayer/theme/app_theme.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';
import 'package:ttsplayer/widgets/artwork/resolved_media_artwork_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Continue Reading renders resolver sidecar artwork',
      (tester) async {
    const coverPath = r'Y:\Media\Literature\Blott on the Landscape\cover.jpg';
    final item = _book(
      id: 'blott',
      title: 'Blott on the Landscape',
      filePath: r'Y:\Media\Literature\Blott on the Landscape\blott.epub',
    );

    await tester.pumpWidget(
      _wrap(
        artworkService: ArtworkService(
          fileExists: (path) => path == coverPath,
        ),
        child: ContinueReadingSection(entries: [_entry(item)]),
      ),
    );
    await tester.pump();

    expect(find.byType(ResolvedMediaArtworkImage), findsOneWidget);
    final image = tester.widget<ArtworkImage>(find.byType(ArtworkImage));
    expect(image.candidate.source, ArtworkSource.sidecar);
    expect(image.candidate.filePath, coverPath);
    expect(find.text('Blott on the Landscape'), findsOneWidget);
  });

  testWidgets('Continue Reading keeps a placeholder when no artwork exists',
      (tester) async {
    final item = _book(
      id: 'ribbon',
      title: 'The Ribbon Queen 01',
      filePath: r'Y:\Media\Comics\The Ribbon Queen 01.cbz',
    );

    await tester.pumpWidget(
      _wrap(
        artworkService: ArtworkService(fileExists: (_) => false),
        child: ContinueReadingSection(entries: [_entry(item, comic: true)]),
      ),
    );
    await tester.pump();

    expect(find.byType(ResolvedMediaArtworkImage), findsOneWidget);
    final image = tester.widget<ArtworkImage>(find.byType(ArtworkImage));
    expect(image.candidate.source, ArtworkSource.placeholder);
    expect(image.candidate.filePath, isNull);
    expect(find.text('The Ribbon Queen 01'), findsOneWidget);
  });
}

Widget _wrap({
  required ArtworkService artworkService,
  required Widget child,
}) {
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

MediaItem _book({
  required String id,
  required String title,
  required String filePath,
}) {
  final comic = filePath.toLowerCase().endsWith('.cbz');
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath,
    mediaKindRaw: comic ? 'comic' : 'book',
  );
}

ContinueReadingEntry _entry(MediaItem item, {bool comic = false}) {
  return ContinueReadingEntry(
    item: item,
    record: ReadingProgressRecord(
      mediaId: item.id,
      mediaKind: comic ? MediaKind.comic : MediaKind.book,
      readerFormat: comic ? ReadingReaderFormat.cbz : ReadingReaderFormat.epub,
      title: item.title,
      location: comic
          ? const ComicReadingLocationPayload(
              pageIndex: 0,
              pageCountAtSave: 12,
              archiveFormat: ReadingReaderFormat.cbz,
            )
          : const EpubReadingLocationPayload(
              spineIndex: 0,
              spineHref: 'ch1.xhtml',
              spineCountAtSave: 1,
            ),
      progressFraction: 0.2,
      completed: false,
      lastReadAt: DateTime.utc(2026, 11, 10),
    ),
    progressPercent: 20,
    locationLabel: comic ? 'Page 1' : 'Chapter 1',
    availability: ContinueReadingAvailability.available,
  );
}
