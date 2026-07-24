"""Tests for indexer extension handling and library rescan merge."""

from __future__ import annotations

import json
import tempfile
import unittest
import unittest.mock
from datetime import datetime, timezone
from pathlib import Path

import indexer


def _all_items_from_folders(folders: list[dict]) -> list[dict]:
    """Collect every indexed item from a folder tree (depth-first)."""
    items: list[dict] = []
    for folder in folders:
        items.extend(folder.get("items", []))
        items.extend(_all_items_from_folders(folder.get("subfolders", [])))
    return items


class SupportedExtensionTests(unittest.TestCase):
    def test_image_extensions_are_in_supported_set(self):
        for ext in (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff"):
            with self.subTest(ext=ext):
                self.assertIn(ext, indexer.SUPPORTED_EXTENSIONS)

    def test_full_and_library_scan_share_one_extension_source(self):
        self.assertIn(".jpg", indexer.SUPPORTED_EXTENSIONS)
        self.assertIn(".mp4", indexer.SUPPORTED_EXTENSIONS)
        self.assertEqual(
            indexer.SUPPORTED_EXTENSIONS_SORTED,
            sorted(ext.removeprefix(".") for ext in indexer.SUPPORTED_EXTENSIONS),
        )


class MediaIndexingTests(unittest.TestCase):
    def test_handle_media_file_indexes_image_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "photo.jpg"
            image.write_bytes(b"fake")

            warnings: list[dict] = []
            counters = {"items": 0}

            item = indexer._handle_media_file(image, warnings, counters)

            self.assertIsNotNone(item)
            self.assertEqual(item["file_path"], str(image))
            self.assertIsNone(item["duration_seconds"])
            self.assertEqual(counters["items"], 1)

    def test_scan_folder_includes_images_same_as_full_scan_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            library = root / "Images"
            library.mkdir()
            (library / "one.jpg").write_bytes(b"a")
            (library / "two.png").write_bytes(b"b")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}

            direct = indexer.scan_folder(library, warnings, counters, library_name="Images")

            self.assertIsNotNone(direct)
            extensions = {Path(i["file_path"]).suffix.lower() for i in direct["items"]}
            self.assertEqual(extensions, {".jpg", ".png"})

            warnings.clear()
            counters = {"folders": 0, "items": 0}
            folders, total = indexer.scan_root(root, warnings, counters)

            self.assertEqual(total, 2)
            self.assertEqual(len(folders), 1)
            root_extensions = {
                Path(i["file_path"]).suffix.lower() for i in folders[0]["items"]
            }
            self.assertEqual(root_extensions, {".jpg", ".png"})


class ArtworkSidecarTests(unittest.TestCase):
    def test_poster_excluded_beside_video(self):
        with tempfile.TemporaryDirectory() as tmp:
            movies = Path(tmp) / "Movies"
            movies.mkdir()
            (movies / "movie.mp4").write_bytes(b"v")
            (movies / "poster.jpg").write_bytes(b"p")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            node = indexer.scan_folder(movies, warnings, counters, library_name="Movies")

            self.assertIsNotNone(node)
            names = {Path(i["file_path"]).name for i in node["items"]}
            self.assertEqual(names, {"movie.mp4"})

    def test_stem_matched_image_excluded_beside_video(self):
        with tempfile.TemporaryDirectory() as tmp:
            movies = Path(tmp) / "Movies"
            movies.mkdir()
            (movies / "movie.mp4").write_bytes(b"v")
            (movies / "movie.jpg").write_bytes(b"p")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            node = indexer.scan_folder(movies, warnings, counters, library_name="Movies")

            self.assertIsNotNone(node)
            names = {Path(i["file_path"]).name for i in node["items"]}
            self.assertEqual(names, {"movie.mp4"})

    def test_holiday_image_in_images_library_remains(self):
        with tempfile.TemporaryDirectory() as tmp:
            images = Path(tmp) / "Images"
            images.mkdir()
            (images / "holiday.jpg").write_bytes(b"x")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            node = indexer.scan_folder(images, warnings, counters, library_name="Images")

            self.assertIsNotNone(node)
            names = {Path(i["file_path"]).name for i in node["items"]}
            self.assertEqual(names, {"holiday.jpg"})

    def test_named_sidecar_kept_in_image_only_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            images = Path(tmp) / "Images"
            images.mkdir()
            (images / "cover.jpg").write_bytes(b"x")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            node = indexer.scan_folder(images, warnings, counters, library_name="Images")

            self.assertIsNotNone(node)
            names = {Path(i["file_path"]).name for i in node["items"]}
            self.assertEqual(names, {"cover.jpg"})

    def test_folder_sidecar_excluded_beside_video(self):
        with tempfile.TemporaryDirectory() as tmp:
            movies = Path(tmp) / "Movies"
            movies.mkdir()
            (movies / "movie.mp4").write_bytes(b"v")
            (movies / "folder.jpg").write_bytes(b"p")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            node = indexer.scan_folder(movies, warnings, counters, library_name="Movies")

            self.assertIsNotNone(node)
            names = {Path(i["file_path"]).name for i in node["items"]}
            self.assertEqual(names, {"movie.mp4"})

    def test_full_and_library_scan_exclude_sidecars_consistently(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            movies = root / "Movies"
            movies.mkdir()
            (movies / "movie.mp4").write_bytes(b"v")
            (movies / "poster.png").write_bytes(b"p")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            direct = indexer.scan_folder(movies, warnings, counters, library_name="Movies")

            warnings.clear()
            counters = {"folders": 0, "items": 0}
            folders, _ = indexer.scan_root(root, warnings, counters)

            direct_names = {Path(i["file_path"]).name for i in direct["items"]}
            root_names = {Path(i["file_path"]).name for i in folders[0]["items"]}
            self.assertEqual(direct_names, {"movie.mp4"})
            self.assertEqual(root_names, {"movie.mp4"})


class LibraryMergeTests(unittest.TestCase):
    def test_replace_folder_in_tree_updates_nested_branch(self):
        folders = [
            {
                "id": "videos",
                "name": "Videos",
                "path": r"Y:\Media\Videos",
                "item_count": 1,
                "items": [],
                "subfolders": [
                    {
                        "id": "action",
                        "name": "Action",
                        "path": r"Y:\Media\Videos\Action",
                        "item_count": 1,
                        "items": [{"id": "old", "title": "Old"}],
                        "subfolders": [],
                    }
                ],
            }
        ]

        replacement = {
            "id": "action-new",
            "name": "Action",
            "path": r"Y:\Media\Videos\Action",
            "item_count": 2,
            "items": [
                {"id": "a", "title": "A"},
                {"id": "b", "title": "B"},
            ],
            "subfolders": [],
        }

        merged = indexer._replace_folder_in_tree(
            folders,
            indexer.normalize_path(r"Y:\Media\Videos\Action"),
            replacement,
        )

        self.assertTrue(merged)
        self.assertEqual(folders[0]["item_count"], 2)
        self.assertEqual(len(folders[0]["subfolders"][0]["items"]), 2)

    def test_library_rescan_merge_preserves_other_libraries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            images = root / "Images"
            videos = root / "Videos"
            images.mkdir()
            videos.mkdir()
            (images / "holiday.jpg").write_bytes(b"x")
            (videos / "clip.mp4").write_bytes(b"x")

            catalog_path = root / "catalog.json"
            history_path = root / "scan.history.json"
            started = datetime.now(timezone.utc)

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            videos_node = indexer.scan_folder(videos, warnings, counters, library_name="Videos")
            self.assertIsNotNone(videos_node)

            catalog = {
                "catalogue": indexer.make_catalogue_block("test-id"),
                "folders": [videos_node],
                "total_items": videos_node["item_count"],
            }
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")

            indexer._library_rescan(
                str(images),
                started,
                catalog_path,
                history_path,
                max_entries=10,
            )

            merged = json.loads(catalog_path.read_text(encoding="utf-8"))
            names = {folder["name"] for folder in merged["folders"]}
            self.assertEqual(names, {"Videos", "Images"})

            images_node = next(f for f in merged["folders"] if f["name"] == "Images")
            image_exts = {Path(i["file_path"]).suffix.lower() for i in images_node["items"]}
            self.assertIn(".jpg", image_exts)

            videos_node_after = next(f for f in merged["folders"] if f["name"] == "Videos")
            video_exts = {Path(i["file_path"]).suffix.lower() for i in videos_node_after["items"]}
            self.assertIn(".mp4", video_exts)


class MusicIndexingTests(unittest.TestCase):
    def test_audio_extensions_in_supported_set(self):
        for ext in (".mp3", ".flac", ".m4a", ".ogg", ".wav"):
            with self.subTest(ext=ext):
                self.assertIn(ext, indexer.SUPPORTED_EXTENSIONS)

    def test_make_item_audio_emits_media_kind_and_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            album = root / "Artist" / "Album"
            album.mkdir(parents=True)
            track = album / "01 - Song.mp3"
            track.write_bytes(b"fake")

            warnings: list[dict] = []
            with unittest.mock.patch.object(
                indexer.music_metadata,
                "build_music_metadata",
                return_value={
                    "media_kind": "audio",
                    "title": "Song",
                    "artist": "Artist",
                    "album": "Album",
                    "album_artist": "Artist",
                    "track_number": 1,
                    "artist_group_key": "artist",
                    "album_group_key": "artist|album|scope",
                },
            ):
                item = indexer.make_item(track, warnings)

            self.assertIsNotNone(item)
            self.assertEqual(item["media_kind"], "audio")
            self.assertEqual(item["artist"], "Artist")
            self.assertEqual(item["album"], "Album")

    def test_scan_folder_indexes_audio_and_sets_version_three(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            music = root / "Music" / "Artist" / "Album"
            music.mkdir(parents=True)
            (music / "track.mp3").write_bytes(b"x")
            (root / "Videos").mkdir()
            (root / "Videos" / "clip.mp4").write_bytes(b"v")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            with unittest.mock.patch.object(
                indexer.music_metadata,
                "build_music_metadata",
                side_effect=lambda path, tags=None: {
                    "media_kind": "audio",
                    "title": path.stem,
                    "artist": "Artist",
                    "album": "Album",
                    "album_artist": "Artist",
                    "artist_group_key": "artist",
                    "album_group_key": "artist|album|scope",
                },
            ):
                folders, total = indexer.scan_root(root, warnings, counters)

            self.assertGreaterEqual(total, 2)
            audio_items = [
                i
                for i in _all_items_from_folders(folders)
                if i.get("media_kind") == "audio"
            ]
            self.assertTrue(audio_items)

    def test_cover_sidecar_excluded_beside_audio(self):
        with tempfile.TemporaryDirectory() as tmp:
            album = Path(tmp) / "Album"
            album.mkdir()
            (album / "track.mp3").write_bytes(b"a")
            (album / "cover.jpg").write_bytes(b"p")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            with unittest.mock.patch.object(
                indexer.music_metadata,
                "build_music_metadata",
                return_value={
                    "media_kind": "audio",
                    "title": "track",
                    "artist": "A",
                    "album": "Album",
                    "album_artist": "A",
                    "artist_group_key": "a",
                    "album_group_key": "a|album|scope",
                },
            ):
                node = indexer.scan_folder(album, warnings, counters, library_name="Album")

            names = {Path(i["file_path"]).name for i in node["items"]}
            self.assertEqual(names, {"track.mp3"})

    def test_catalogue_version_constant_is_four(self):
        self.assertEqual(indexer.CATALOGUE_VERSION, 4)
        self.assertEqual(indexer.SCANNER_VERSION, "0.5.0")


class BookComicIndexingTests(unittest.TestCase):
    def test_book_and_comic_extensions_supported(self):
        for ext in (".pdf", ".epub", ".cbz", ".cbr"):
            with self.subTest(ext=ext):
                self.assertIn(ext, indexer.SUPPORTED_EXTENSIONS)

    def test_media_kind_for_book_and_comic_suffixes(self):
        self.assertEqual(indexer.media_kind_for_suffix(".pdf"), "book")
        self.assertEqual(indexer.media_kind_for_suffix(".epub"), "book")
        self.assertEqual(indexer.media_kind_for_suffix(".cbz"), "comic")
        self.assertEqual(indexer.media_kind_for_suffix(".cbr"), "comic")

    def test_make_item_pdf_emits_book_kind(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "My_Novel.pdf"
            path.write_bytes(b"%PDF-1.4")
            warnings: list[dict] = []
            item = indexer.make_item(path, warnings)
            self.assertIsNotNone(item)
            self.assertEqual(item["media_kind"], "book")
            self.assertEqual(item["title"], "My Novel")
            self.assertNotIn("author", item)

    def test_make_item_cbz_emits_comic_kind(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Issue_01.cbz"
            path.write_bytes(b"PK\x03\x04")  # not a valid zip; metadata falls back
            warnings: list[dict] = []
            item = indexer.make_item(path, warnings)
            self.assertIsNotNone(item)
            self.assertEqual(item["media_kind"], "comic")
            self.assertEqual(item["title"], "Issue 01")

    def test_make_item_cbr_emits_comic_kind_filename_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Batman_01.cbr"
            path.write_bytes(b"Rar!\x1a\x07")
            warnings: list[dict] = []
            item = indexer.make_item(path, warnings)
            self.assertIsNotNone(item)
            self.assertEqual(item["media_kind"], "comic")
            self.assertEqual(item["title"], "Batman 01")

    def test_scan_root_indexes_mixed_book_comic_video(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Books").mkdir()
            (root / "Books" / "guide.pdf").write_bytes(b"%PDF")
            (root / "Comics").mkdir()
            (root / "Comics" / "issue.cbz").write_bytes(b"PK")
            (root / "Comics" / "issue.cbr").write_bytes(b"Rar")
            (root / "Videos").mkdir()
            (root / "Videos" / "clip.mp4").write_bytes(b"v")

            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            folders, total = indexer.scan_root(root, warnings, counters)
            self.assertGreaterEqual(total, 4)
            kinds = {i.get("media_kind") for i in _all_items_from_folders(folders)}
            self.assertIn("book", kinds)
            self.assertIn("comic", kinds)
            self.assertIn("video", kinds)

            block = indexer.make_catalogue_block("test-id")
            self.assertEqual(block["catalogue_version"], 4)
            self.assertEqual(block["scanner_version"], "0.5.0")
            self.assertIn("pdf", block["supported_extensions"])
            self.assertIn("epub", block["supported_extensions"])
            self.assertIn("cbz", block["supported_extensions"])
            self.assertIn("cbr", block["supported_extensions"])

    def test_cover_sidecar_skipped_beside_book(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / "Books"
            folder.mkdir()
            (folder / "novel.pdf").write_bytes(b"%PDF")
            (folder / "cover.jpg").write_bytes(b"JPEG")
            warnings: list[dict] = []
            counters = {"folders": 0, "items": 0}
            folders, total = indexer.scan_root(root, warnings, counters)
            names = {Path(i["file_path"]).name for i in _all_items_from_folders(folders)}
            self.assertIn("novel.pdf", names)
            self.assertNotIn("cover.jpg", names)
            self.assertEqual(total, 1)


class AddedAtTests(unittest.TestCase):
    def test_apply_added_at_stamps_new_items(self):
        folders = [{"items": [{"id": "a"}, {"id": "b"}], "subfolders": []}]
        default = "2026-07-05T10:00:00+00:00"
        indexer._apply_added_at_to_folders(folders, {}, default)
        self.assertEqual(folders[0]["items"][0]["added_at"], default)
        self.assertEqual(folders[0]["items"][1]["added_at"], default)

    def test_apply_added_at_preserves_existing(self):
        folders = [{"items": [{"id": "a"}], "subfolders": []}]
        lookup = {"a": "2026-01-01T00:00:00+00:00"}
        indexer._apply_added_at_to_folders(
            folders, lookup, "2026-07-05T10:00:00+00:00"
        )
        self.assertEqual(folders[0]["items"][0]["added_at"], "2026-01-01T00:00:00+00:00")

    def test_build_lookup_from_nested_tree(self):
        folders = [
            {
                "items": [{"id": "root"}],
                "subfolders": [
                    {
                        "items": [{"id": "nested", "added_at": "2026-03-01T12:00:00+00:00"}],
                        "subfolders": [],
                    }
                ],
            }
        ]
        lookup = indexer._build_added_at_lookup(folders)
        self.assertEqual(lookup["nested"], "2026-03-01T12:00:00+00:00")
        self.assertNotIn("root", lookup)

    def test_load_added_at_lookup_from_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            catalog_path = Path(tmp) / "catalog.json"
            catalog_path.write_text(
                json.dumps(
                    {
                        "folders": [
                            {
                                "items": [
                                    {
                                        "id": "keep",
                                        "added_at": "2026-02-01T08:00:00+00:00",
                                    }
                                ],
                                "subfolders": [],
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            lookup = indexer._load_added_at_lookup(catalog_path)
            self.assertEqual(lookup["keep"], "2026-02-01T08:00:00+00:00")


if __name__ == "__main__":
    unittest.main()
