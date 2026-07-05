import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/artwork/artwork_kind.dart';
import 'package:ttsplayer/services/artwork/artwork_candidate.dart';
import 'package:ttsplayer/services/artwork/library_visual_kind.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_access_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/playback_platform.dart';
import 'package:ttsplayer/services/playback_service.dart';
import 'package:ttsplayer/widgets/artwork/artwork_image.dart';

void main() {
  const httpBase = 'https://mediatnas.local:8443/media/';

  group('PlaybackService resolveCataloguePath', () {
    test('maps Y drive to file URI on Windows desktop', () {
      final playback = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: true,
        ),
      );

      final result = playback.resolveCataloguePath(r'Y:\Media\Videos\movie.mp4');
      expect(result.isPlayable, isTrue);
      expect(result.providerType, MediaAccessProviderType.localFile);
      expect(result.uri, startsWith('file://'));
    });

    test('maps catalogue path to HTTP URI when HTTP base configured', () {
      final playback = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(
            httpMediaBaseUrl: httpBase,
            mode: MediaAccessMode.httpRequired,
          ),
          isWindowsDesktop: false,
        ),
      );

      final result = playback.resolveCataloguePath(r'Y:\Media\Videos\movie.mp4');
      expect(result.isPlayable, isTrue);
      expect(result.providerType, MediaAccessProviderType.httpServing);
      expect(
        result.uri,
        'https://mediatnas.local:8443/media/Videos/movie.mp4',
      );
    });

    test('passes through existing https URL', () {
      const url = 'https://host/media/Videos/a.mp4';
      final playback = PlaybackService(
        mediaLocationResolver: MediaLocationResolver(
          config: MediaAccessConfig.development(),
          isWindowsDesktop: false,
        ),
      );

      final result = playback.resolveCataloguePath(url);
      expect(result.uri, url);
      expect(result.providerType, MediaAccessProviderType.passThrough);
    });
  });

  group('mediaUriForPlayback delegation', () {
    test('delegates unresolved catalogue path through resolver', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          httpMediaBaseUrl: httpBase,
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final uri = mediaUriForPlayback(
        r'Y:\Media\Home Videos\poster.jpg',
        resolver: resolver,
      );

      expect(
        uri,
        'https://mediatnas.local:8443/media/Home%20Videos/poster.jpg',
      );
    });
  });

  group('ArtworkImage.loadUriForArtworkPath', () {
    test('resolves sidecar path to file URI on Windows desktop', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      );

      final uri = ArtworkImage.loadUriForArtworkPath(
        r'Y:\Media\Movies\poster.jpg',
        resolver,
      );

      expect(uri, isNotNull);
      expect(uri, startsWith('file://'));
    });

    test('resolves sidecar path to HTTP URI when configured', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          httpMediaBaseUrl: httpBase,
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final uri = ArtworkImage.loadUriForArtworkPath(
        r'\\MEDIATNAS-B725\Media\Movies\poster.jpg',
        resolver,
      );

      expect(uri, 'https://mediatnas.local:8443/media/Movies/poster.jpg');
    });

    test('returns null when HTTP base missing on non-Windows', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final uri = ArtworkImage.loadUriForArtworkPath(
        r'Y:\Media\Movies\poster.jpg',
        resolver,
      );

      expect(uri, isNull);
    });
  });

  group('ArtworkService discovery unchanged', () {
    test('candidate still stores filesystem path not HTTP URL', () {
      final exists = <String, bool>{
        r'Y:\Media\Movies\film.mp4': true,
        r'Y:\Media\Movies\poster.jpg': true,
      };

      // ArtworkService unchanged — discovery uses raw paths.
      final candidate = ArtworkCandidate(
        kind: ArtworkKind.mediaItem,
        source: ArtworkSource.catalogThumbnail,
        filePath: r'Y:\Media\Movies\poster.jpg',
        visualKind: LibraryVisualKind.videos,
      );

      expect(exists[candidate.filePath!], isTrue);
      expect(candidate.filePath, isNot(startsWith('http')));
    });
  });
}
