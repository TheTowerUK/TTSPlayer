"""Tests for lightweight book/comic metadata extraction."""

from __future__ import annotations

import io
import unittest
import zipfile
from pathlib import Path
import tempfile
import xml.etree.ElementTree as ET

import document_metadata


def _write_minimal_epub(path: Path, title: str, creator: str) -> None:
    container = """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""
    opf = f"""<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>{title}</dc:title>
    <dc:creator>{creator}</dc:creator>
  </metadata>
  <manifest/>
  <spine/>
</package>
"""
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("META-INF/container.xml", container)
        zf.writestr("OEBPS/content.opf", opf)


def _write_cbz_with_comicinfo(
    path: Path,
    *,
    title: str,
    writer: str,
    series: str,
    page_count: int,
) -> None:
    comic_info = ET.Element("ComicInfo")
    ET.SubElement(comic_info, "Title").text = title
    ET.SubElement(comic_info, "Writer").text = writer
    ET.SubElement(comic_info, "Series").text = series
    ET.SubElement(comic_info, "PageCount").text = str(page_count)
    xml_bytes = ET.tostring(comic_info, encoding="utf-8", xml_declaration=True)
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("ComicInfo.xml", xml_bytes)
        zf.writestr("page1.jpg", b"fake-image")


class DocumentMetadataTests(unittest.TestCase):
    def test_pdf_uses_filename_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Some_Book.pdf"
            path.write_bytes(b"%PDF")
            meta = document_metadata.build_book_metadata(path)
            self.assertEqual(meta["title"], "Some Book")
            self.assertNotIn("author", meta)

    def test_epub_reads_opf_title_and_creator(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "file.epub"
            _write_minimal_epub(path, "Embedded Title", "Ada Lovelace")
            meta = document_metadata.build_book_metadata(path)
            self.assertEqual(meta["title"], "Embedded Title")
            self.assertEqual(meta["author"], "Ada Lovelace")

    def test_corrupt_epub_falls_back_to_stem(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Broken_Book.epub"
            path.write_bytes(b"not-a-zip")
            meta = document_metadata.build_book_metadata(path)
            self.assertEqual(meta["title"], "Broken Book")

    def test_cbz_reads_comicinfo(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.cbz"
            _write_cbz_with_comicinfo(
                path,
                title="Night Watch",
                writer="Writer Name",
                series="City Watch",
                page_count=22,
            )
            meta = document_metadata.build_comic_metadata(path)
            self.assertEqual(meta["title"], "Night Watch")
            self.assertEqual(meta["author"], "Writer Name")
            self.assertEqual(meta["series"], "City Watch")
            self.assertEqual(meta["page_count"], 22)


if __name__ == "__main__":
    unittest.main()
