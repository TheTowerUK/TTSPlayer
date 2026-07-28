import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttsplayer/features/music/services/music_listening_repository.dart';
import 'package:ttsplayer/features/music/services/music_playback_session_repository.dart';
import 'package:ttsplayer/features/reading/models/reading_location_payload.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_policy.dart';
import 'package:ttsplayer/features/reading/models/reading_progress_record.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_coordinator.dart';
import 'package:ttsplayer/features/reading/services/reading_progress_repository.dart';
import 'package:ttsplayer/models/catalog.dart';
import 'package:ttsplayer/models/media_item.dart';
import 'package:ttsplayer/models/media_kind.dart';

import 'book_comic_catalog_fixtures.dart';

/// Deterministic clock for Phase 6.5 coordinator tests.
class Phase65TestClock {
  Phase65TestClock([DateTime? start])
      : _now = start ?? DateTime.utc(2026, 7, 27, 12);

  DateTime _now;

  DateTime get now => _now;

  DateTime Function() get fn => () => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void advancePastDebounce() {
    advance(
      ReadingProgressPolicy.persistDebounce + const Duration(milliseconds: 50),
    );
  }
}

DateTime phase65Utc(int year, int month, int day,
    [int hour = 12, int minute = 0]) {
  return DateTime.utc(year, month, day, hour, minute);
}

Future<ReadingProgressRepository> initializedReadingProgressRepository({
  Map<String, Object>? initialPreferences,
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences ?? {});
  final repository = ReadingProgressRepository();
  await repository.initialize();
  return repository;
}

Catalog phase65ReadingCatalog() {
  return Catalog.fromJson(
    jsonDecode(kCatalogV4BookComicFixture) as Map<String, dynamic>,
  );
}

MediaItem phase65BookItem({
  String id = 'book-pdf',
  String title = 'Owner Manual',
  String filePath = r'Y:\Media\Books\Owner_Manual.pdf',
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath,
    mediaKindRaw: 'book',
  );
}

MediaItem phase65EpubItem({
  String id = 'book-epub',
  String title = 'Embedded Title',
  String filePath = r'Y:\Media\Books\novel.epub',
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath,
    mediaKindRaw: 'book',
    author: 'Ada Lovelace',
  );
}

MediaItem phase65ComicItem({
  String id = 'comic-cbz',
  String title = 'Night Watch',
  String filePath = r'Y:\Media\Comics\nw.cbz',
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath,
    mediaKindRaw: 'comic',
    series: 'City Watch',
    pageCount: 22,
  );
}

MediaItem phase65CbrItem({
  String id = 'comic-cbr',
  String title = 'Batman 01',
  String filePath = r'Y:\Media\Comics\Batman_01.cbr',
}) {
  return MediaItem(
    id: id,
    title: title,
    filePath: filePath,
    mediaKindRaw: 'comic',
  );
}

ReadingProgressRecord phase65PdfRecord({
  String mediaId = 'book-pdf',
  String title = 'Owner Manual',
  int pageIndex = 4,
  int pageCountAtSave = 120,
  double progressFraction = 0.04,
  bool completed = false,
  DateTime? lastReadAt,
  DateTime? firstReadAt,
  DateTime? completedAt,
}) {
  final readAt = lastReadAt ?? phase65Utc(2026, 7, 27);
  return ReadingProgressRecord(
    mediaId: mediaId,
    mediaKind: MediaKind.book,
    readerFormat: ReadingReaderFormat.pdf,
    title: title,
    location: PdfReadingLocationPayload(
      pageIndex: pageIndex,
      pageCountAtSave: pageCountAtSave,
    ),
    progressFraction: progressFraction,
    completed: completed,
    lastReadAt: readAt,
    firstReadAt: firstReadAt ?? readAt,
    completedAt: completedAt,
    sourceBasename: 'Owner_Manual.pdf',
  ).normalized();
}

ReadingProgressRecord phase65EpubRecord({
  String mediaId = 'book-epub',
  String title = 'Embedded Title',
  int spineIndex = 2,
  String spineHref = 'chapter3.xhtml',
  int spineCountAtSave = 12,
  double sectionRelativeOffset = 64,
  String? chapterTitle = 'Chapter Three',
  double progressFraction = 0.22,
  bool completed = false,
  DateTime? lastReadAt,
}) {
  final readAt = lastReadAt ?? phase65Utc(2026, 7, 27, 11);
  return ReadingProgressRecord(
    mediaId: mediaId,
    mediaKind: MediaKind.book,
    readerFormat: ReadingReaderFormat.epub,
    title: title,
    location: EpubReadingLocationPayload(
      spineIndex: spineIndex,
      spineHref: spineHref,
      spineCountAtSave: spineCountAtSave,
      chapterTitle: chapterTitle,
      sectionRelativeOffset: sectionRelativeOffset,
    ),
    progressFraction: progressFraction,
    completed: completed,
    lastReadAt: readAt,
    firstReadAt: readAt,
    sourceBasename: 'novel.epub',
  ).normalized();
}

ReadingProgressRecord phase65ComicRecord({
  String mediaId = 'comic-cbz',
  String title = 'Night Watch',
  int pageIndex = 6,
  int pageCountAtSave = 22,
  String? entryName = 'page007.jpg',
  ReadingReaderFormat archiveFormat = ReadingReaderFormat.cbz,
  double progressFraction = 0.32,
  bool completed = false,
  DateTime? lastReadAt,
}) {
  final readAt = lastReadAt ?? phase65Utc(2026, 7, 27, 10);
  return ReadingProgressRecord(
    mediaId: mediaId,
    mediaKind: MediaKind.comic,
    readerFormat: archiveFormat,
    title: title,
    location: ComicReadingLocationPayload(
      pageIndex: pageIndex,
      pageCountAtSave: pageCountAtSave,
      entryName: entryName,
      archiveFormat: archiveFormat,
    ),
    progressFraction: progressFraction,
    completed: completed,
    lastReadAt: readAt,
    firstReadAt: readAt,
    sourceBasename: 'nw.cbz',
  ).normalized();
}

Map<String, Object> phase65IsolationSeedPreferences({
  String videoProbeId = 'phase65-video-probe',
  int videoPosition = 456,
  int videoDuration = 7200,
}) {
  return {
    'position_$videoProbeId': videoPosition,
    'duration_$videoProbeId': videoDuration,
    MusicListeningRepository.storageKey: jsonEncode({
      'stateVersion': MusicListeningRepository.currentStateVersion,
      'records': [
        {
          'trackId': 'phase65-sentinel-track',
          'title': 'Sentinel Track',
          'artist': 'Sentinel Artist',
          'album': 'Sentinel Album',
          'lastPosition': 45000,
          'completed': false,
          'lastPlayedAt': '2026-07-20T12:00:00.000Z',
        },
      ],
    }),
    MusicPlaybackSessionRepository.storageKey: jsonEncode({
      'stateVersion': MusicPlaybackSessionRepository.currentStateVersion,
      'session': {
        'queueTrackIds': ['phase65-sentinel-track', 'phase65-sentinel-track-b'],
        'activeTrackId': 'phase65-sentinel-track',
        'playbackPosition': 45000,
        'updatedAt': '2026-07-20T12:00:00.000Z',
      },
    }),
  };
}

Future<void> phase65AssertIsolationMarkersUnchanged({
  String videoProbeId = 'phase65-video-probe',
  int expectedVideoPosition = 456,
  int expectedVideoDuration = 7200,
  String? expectedListeningRaw,
  String? expectedQueueRaw,
}) async {
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getInt('position_$videoProbeId'), expectedVideoPosition);
  expect(prefs.getInt('duration_$videoProbeId'), expectedVideoDuration);

  final listeningRaw = prefs.getString(MusicListeningRepository.storageKey);
  final queueRaw = prefs.getString(MusicPlaybackSessionRepository.storageKey);

  if (expectedListeningRaw != null) {
    expect(listeningRaw, expectedListeningRaw);
  } else {
    expect(listeningRaw, isNotNull);
    expect(listeningRaw, contains('phase65-sentinel-track'));
  }

  if (expectedQueueRaw != null) {
    expect(queueRaw, expectedQueueRaw);
  } else {
    expect(queueRaw, isNotNull);
    expect(queueRaw, contains('phase65-sentinel-track'));
  }
}

void phase65BeginComicSession(
  ReadingProgressCoordinator coordinator, {
  required MediaItem item,
  int pageIndex = 0,
  int pageCount = 22,
  String? entryName,
  double? progressFraction,
  ReadingReaderFormat archiveFormat = ReadingReaderFormat.cbz,
}) {
  final fraction = progressFraction ??
      ReadingProgressRecord.fractionForComic(pageIndex, pageCount);
  coordinator.beginSession(
    item: item,
    readerFormat: archiveFormat,
    initialLocation: ComicReadingLocationPayload(
      pageIndex: 0,
      pageCountAtSave: pageCount,
      archiveFormat: archiveFormat,
    ),
    progressFraction: 0,
  );
  coordinator.markLayoutReady();
  coordinator.onLocationChanged(
    location: ComicReadingLocationPayload(
      pageIndex: pageIndex,
      pageCountAtSave: pageCount,
      entryName: entryName,
      archiveFormat: archiveFormat,
    ),
    progressFraction: fraction,
  );
}

void phase65BeginPdfSession(
  ReadingProgressCoordinator coordinator, {
  required MediaItem item,
  int pageIndex = 4,
  int pageCount = 120,
  double progressFraction = 0.04,
}) {
  coordinator.beginSession(
    item: item,
    readerFormat: ReadingReaderFormat.pdf,
    initialLocation: PdfReadingLocationPayload(
      pageIndex: 0,
      pageCountAtSave: pageCount,
    ),
    progressFraction: 0,
  );
  coordinator.markLayoutReady();
  coordinator.onLocationChanged(
    location: PdfReadingLocationPayload(
      pageIndex: pageIndex,
      pageCountAtSave: pageCount,
    ),
    progressFraction: progressFraction,
  );
}
