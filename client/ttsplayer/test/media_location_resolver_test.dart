import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/services/media_access/media_access_config.dart';
import 'package:ttsplayer/services/media_access/media_access_provider.dart';
import 'package:ttsplayer/services/media_access/media_location_resolver.dart';
import 'package:ttsplayer/services/media_access/media_path_utils.dart';

void main() {
  group('MediaPathUtils', () {
    test('relativePathUnderRoots strips Y drive root', () {
      expect(
        MediaPathUtils.relativePathUnderRoots(
          r'Y:\Media\Videos\movie.mp4',
          MediaAccessConfig.defaultMediaRoots,
        ),
        'Videos/movie.mp4',
      );
    });

    test('relativePathUnderRoots strips UNC root case-insensitively', () {
      expect(
        MediaPathUtils.relativePathUnderRoots(
          r'\\MEDIATNAS-B725\Media\Videos\movie.mp4',
          MediaAccessConfig.defaultMediaRoots,
        ),
        'Videos/movie.mp4',
      );
    });

    test('relativePathUnderRoots strips TNAS root', () {
      expect(
        MediaPathUtils.relativePathUnderRoots(
          '/volume1/Media/Videos/movie.mp4',
          MediaAccessConfig.defaultMediaRoots,
        ),
        'Videos/movie.mp4',
      );
    });

    test('encodeRelativePathForUrl encodes spaces per segment', () {
      expect(
        MediaPathUtils.encodeRelativePathForUrl('Home Videos/My Movie.mp4'),
        'Home%20Videos/My%20Movie.mp4',
      );
    });

    test('joinHttpBaseAndRelative appends encoded relative path', () {
      expect(
        MediaPathUtils.joinHttpBaseAndRelative(
          'https://nas.example:8443/media/',
          'Videos/movie.mp4',
        ),
        'https://nas.example:8443/media/Videos/movie.mp4',
      );
    });
  });

  group('MediaLocationResolver', () {
    const httpBase = 'https://mediatnas.local:8443/media/';

    test('passes through existing https URL', () {
      const url = 'https://host/media/Videos/a.mp4';
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(url);
      expect(result.isPlayable, isTrue);
      expect(result.uri, url);
      expect(result.providerType, MediaAccessProviderType.passThrough);
    });

    test('maps Y drive path to file URI on Windows desktop', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      );

      final result = resolver.resolve(r'Y:\Media\Videos\movie.mp4');
      expect(result.isPlayable, isTrue);
      expect(result.providerType, MediaAccessProviderType.localFile);
      expect(result.uri, startsWith('file:///'));
      expect(result.uri, contains('Videos'));
      expect(result.uri, contains('movie.mp4'));
    });

    test('maps UNC path to file URI on Windows desktop', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      );

      final result = resolver.resolve(r'\\MEDIATNAS-B725\Media\Videos\movie.mp4');
      expect(result.isPlayable, isTrue);
      expect(result.providerType, MediaAccessProviderType.localFile);
      expect(result.uri, startsWith('file://'));
      expect(result.uri, contains('movie.mp4'));
    });

    test('maps D drive path to file URI on Windows desktop', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      );

      final result = resolver.resolve(r'D:\Media\Videos\movie.mp4');
      expect(result.isPlayable, isTrue);
      expect(result.providerType, MediaAccessProviderType.localFile);
    });

    test('maps mapped drive path to HTTP on non-Windows when base configured', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          httpMediaBaseUrl: httpBase,
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(r'Y:\Media\Videos\movie.mp4');
      expect(result.isPlayable, isTrue);
      expect(result.providerType, MediaAccessProviderType.httpServing);
      expect(
        result.uri,
        'https://mediatnas.local:8443/media/Videos/movie.mp4',
      );
    });

    test('UNC and Y drive produce same HTTP URL for same relative path', () {
      final config = MediaAccessConfig.development(
        httpMediaBaseUrl: httpBase,
        mode: MediaAccessMode.httpRequired,
      );
      final resolver = MediaLocationResolver(
        config: config,
        isWindowsDesktop: false,
      );

      final fromDrive = resolver.resolve(r'Y:\Media\Videos\movie.mp4');
      final fromUnc =
          resolver.resolve(r'\\MEDIATNAS-B725\Media\Videos\movie.mp4');

      expect(fromDrive.uri, fromUnc.uri);
    });

    test('encodes spaces in HTTP URL', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          httpMediaBaseUrl: httpBase,
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(
        r'Y:\Media\Home Videos\My Movie.mp4',
      );
      expect(result.uri, 'https://mediatnas.local:8443/media/Home%20Videos/My%20Movie.mp4');
    });

    test('unresolved on non-Windows without HTTP base', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(r'Y:\Media\Videos\movie.mp4');
      expect(result.isPlayable, isFalse);
      expect(result.status, MediaLocationResolveStatus.unresolved);
      expect(result.errorReason, isNotNull);
    });

    test('unresolved when HTTP path not under configured roots', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(
          httpMediaBaseUrl: httpBase,
          mode: MediaAccessMode.httpRequired,
        ),
        isWindowsDesktop: false,
      );

      final result = resolver.resolve(r'D:\Other\Videos\movie.mp4');
      expect(result.isPlayable, isFalse);
      expect(result.providerType, MediaAccessProviderType.httpServing);
    });

    test('empty path is unresolved', () {
      final resolver = MediaLocationResolver(
        config: MediaAccessConfig.development(),
        isWindowsDesktop: true,
      );

      final result = resolver.resolve('  ');
      expect(result.isPlayable, isFalse);
    });
  });
}
