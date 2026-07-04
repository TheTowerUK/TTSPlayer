"""Tests for indexer extension handling and library rescan merge."""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

import indexer


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


if __name__ == "__main__":
    unittest.main()
