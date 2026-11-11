import 'package:flutter_test/flutter_test.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/utils/video_display_title.dart';

void main() {
  const nowYear = 2026;

  group('VideoDisplayTitle.format', () {
    test('strips resolution and source after a release year', () {
      expect(
        VideoDisplayTitle.format(
          'Big Trouble in Little China 1986 1080p BluRay',
          nowYear: nowYear,
        ),
        'Big Trouble in Little China (1986)',
      );
    });

    test('keeps edition text after a parenthesized year', () {
      expect(
        VideoDisplayTitle.format(
          'Blade Runner 1982 Final Cut',
          nowYear: nowYear,
        ),
        'Blade Runner (1982) Final Cut',
      );
    });

    test('normalizes dotted episode names and strips technical suffixes', () {
      expect(
        VideoDisplayTitle.format(
          'American.Horror.Story.S01E01.1080p.BluRay',
          nowYear: nowYear,
        ),
        'American Horror Story S01E01',
      );
    });

    test('preserves meaningful title numbers', () {
      expect(
        VideoDisplayTitle.format("Ocean's 11", nowYear: nowYear),
        "Ocean's 11",
      );
      expect(
        VideoDisplayTitle.format('Apollo 13', nowYear: nowYear),
        'Apollo 13',
      );
      expect(
        VideoDisplayTitle.format('12 Angry Men', nowYear: nowYear),
        '12 Angry Men',
      );
      expect(
        VideoDisplayTitle.format('Super 8', nowYear: nowYear),
        'Super 8',
      );
      expect(
        VideoDisplayTitle.format('Fantastic 4 1080p', nowYear: nowYear),
        'Fantastic 4',
      );
    });

    test(
        'does not treat a sequel year beyond the current year as a release year',
        () {
      expect(
        VideoDisplayTitle.format('Blade Runner 2049', nowYear: nowYear),
        'Blade Runner 2049',
      );
    });

    test('does not wrap a leading year-only title', () {
      expect(VideoDisplayTitle.format('1917', nowYear: nowYear), '1917');
      expect(
        VideoDisplayTitle.format('2012 1080p BluRay', nowYear: nowYear),
        '2012',
      );
    });

    test('keeps ambiguous trailing tokens', () {
      expect(
        VideoDisplayTitle.format('The Web', nowYear: nowYear),
        'The Web',
      );
      expect(
        VideoDisplayTitle.format('Movie x264-RARBG', nowYear: nowYear),
        'Movie x264-RARBG',
      );
    });

    test('leaves catalogue-ready titles unchanged', () {
      expect(
        VideoDisplayTitle.format('Casablanca', nowYear: nowYear),
        'Casablanca',
      );
    });
  });

  group('VideoDisplayTitle.forItem', () {
    test('formats videos and leaves books unchanged', () {
      const video = MediaItem(
        id: 'vid',
        title: 'Big Trouble in Little China 1986 1080p BluRay',
        filePath: r'Y:\Media\Movies\film.mp4',
        mediaKindRaw: 'video',
      );
      const book = MediaItem(
        id: 'book',
        title: 'Manual 1080p BluRay',
        filePath: r'Y:\Media\Books\manual.pdf',
        mediaKindRaw: 'book',
      );
      expect(
        VideoDisplayTitle.forItem(video, nowYear: nowYear),
        'Big Trouble in Little China (1986)',
      );
      expect(VideoDisplayTitle.forItem(book, nowYear: nowYear), book.title);
      expect(video.title, 'Big Trouble in Little China 1986 1080p BluRay');
      expect(video.id, 'vid');
      expect(video.filePath, r'Y:\Media\Movies\film.mp4');
    });
  });
}
