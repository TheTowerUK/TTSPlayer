import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/artwork/artwork_candidate.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/library_visual_kind.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtworkImage decode sizing', () {
    testWidgets('applies cacheWidth and cacheHeight from logical size', (tester) async {
      const candidate = ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.placeholder,
        filePath: null,
        visualKind: LibraryVisualKind.videos,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2.0),
            child: Center(
              child: SizedBox(
                width: 100,
                height: 50,
                child: ArtworkImage(
                  candidate: candidate,
                  logicalDecodeSize: Size(100, 50),
                  mediaLocationResolver: MediaLocationResolver(
                    config: MediaAccessConfig.defaults(),
                    isWindowsDesktop: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('missing artwork renders placeholder without Image widget',
        (tester) async {
      const candidate = ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.placeholder,
        filePath: null,
        visualKind: LibraryVisualKind.videos,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtworkImage(
            candidate: candidate,
            logicalDecodeSize: const Size(56, 84),
            mediaLocationResolver: MediaLocationResolver(
              config: MediaAccessConfig.defaults(),
              isWindowsDesktop: true,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    });
  });

  test('configureArtworkFlutterImageCache sets byte budget', () {
    configureArtworkFlutterImageCache();
    expect(
      PaintingBinding.instance.imageCache.maximumSizeBytes,
      kArtworkFlutterImageCacheMaxBytes,
    );
  });
}
