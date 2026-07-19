"""Unit tests for music_metadata normalisation and grouping."""

from __future__ import annotations

import unittest
from pathlib import Path

import music_metadata


class MusicMetadataNormalizationTests(unittest.TestCase):
    def test_normalize_group_key_case_and_whitespace(self):
        self.assertEqual(
            music_metadata.normalize_group_key("  The  Beatles "),
            "the beatles",
        )

    def test_parse_track_number_from_filename(self):
        self.assertEqual(
            music_metadata.parse_track_number_from_filename("01 - Come Together"),
            1,
        )
        self.assertIsNone(
            music_metadata.parse_track_number_from_filename("Come Together"),
        )

    def test_build_music_metadata_uses_tags_then_folder(self):
        path = Path(r"Y:\Media\Music\The Beatles\Abbey Road\01 - Something.mp3")
        tags = {
            "title": "Something",
            "artist": "The Beatles",
            "album": "Abbey Road",
            "album_artist": "The Beatles",
            "track": "2",
            "disc": "1",
            "genre": "Rock",
            "date": "1969",
        }
        meta = music_metadata.build_music_metadata(path, tags=tags)
        self.assertEqual(meta["media_kind"], "audio")
        self.assertEqual(meta["title"], "Something")
        self.assertEqual(meta["artist"], "The Beatles")
        self.assertEqual(meta["album"], "Abbey Road")
        self.assertEqual(meta["track_number"], 2)
        self.assertEqual(meta["disc_number"], 1)
        self.assertEqual(meta["year"], 1969)
        self.assertEqual(meta["artist_group_key"], "the beatles")
        self.assertIn("abbey road", meta["album_group_key"])

    def test_build_music_metadata_missing_tags_use_folder(self):
        path = Path(r"Y:\Media\Music\Artist Name\Album Name\tune.mp3")
        meta = music_metadata.build_music_metadata(path, tags={})
        self.assertEqual(meta["artist"], "Artist Name")
        self.assertEqual(meta["album"], "Album Name")
        self.assertEqual(meta["title"], "tune")

    def test_unknown_album_scoped_by_parent_folder(self):
        path_a = Path(r"Y:\Media\Music\Artist A\Unknown Album\track.mp3")
        path_b = Path(r"Y:\Media\Music\Artist B\Unknown Album\track.mp3")
        meta_a = music_metadata.build_music_metadata(path_a, tags={})
        meta_b = music_metadata.build_music_metadata(path_b, tags={})
        self.assertNotEqual(meta_a["album_group_key"], meta_b["album_group_key"])

    def test_same_album_name_different_artists_do_not_share_album_key(self):
        tags = {"album": "Greatest Hits", "title": "Song"}
        path_a = Path(r"Y:\Media\Music\Artist One\Greatest Hits\a.mp3")
        path_b = Path(r"Y:\Media\Music\Artist Two\Greatest Hits\b.mp3")
        meta_a = music_metadata.build_music_metadata(
            path_a,
            tags={**tags, "artist": "Artist One", "album_artist": "Artist One"},
        )
        meta_b = music_metadata.build_music_metadata(
            path_b,
            tags={**tags, "artist": "Artist Two", "album_artist": "Artist Two"},
        )
        self.assertNotEqual(meta_a["album_group_key"], meta_b["album_group_key"])


if __name__ == "__main__":
    unittest.main()
